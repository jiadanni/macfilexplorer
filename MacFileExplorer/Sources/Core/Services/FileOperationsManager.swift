import Cocoa

protocol FileOperationsManagerDelegate: AnyObject {
    func fileOperationsManager(_ manager: FileOperationsManager, didRequestPresentSheet viewController: NSViewController)
    func fileOperationsManager(_ manager: FileOperationsManager, didRequestPresentError message: String)
    func fileOperationsManagerDidRequestRefresh(_ manager: FileOperationsManager)
    func fileOperationsManagerDidRequestRefreshSource(_ manager: FileOperationsManager, sourcePane: FileBrowserViewController)
    var window: NSWindow? { get }
}

final class FileOperationsManager {
    weak var delegate: FileOperationsManagerDelegate?
    private let settings: SettingsStoreProtocol
    
    init(delegate: FileOperationsManagerDelegate?, settings: SettingsStoreProtocol = SettingsStore.shared) {
        self.delegate = delegate
        self.settings = settings
    }

    // MARK: - Validation

    func isValidDestination(_ destination: URL, for urls: [URL]) -> Bool {
        // Use canonical paths to prevent path traversal bypasses
        let canonicalDest = destination.standardizedFileURL

        for source in urls {
            let canonicalSource = source.standardizedFileURL

            // Check for exact match
            if canonicalSource == canonicalDest { return false }

            // Check if destination is inside source (prevent moving folder into itself)
            let sourceString = canonicalSource.path
            let destString = canonicalDest.path
            if destString.hasPrefix(sourceString + "/") {
                return false
            }
        }

        return true
    }
    
    // MARK: - Drag & Drop Helpers
    
    func preferredDragOperation(from info: NSDraggingInfo, modifierFlags: NSEvent.ModifierFlags = NSApp.currentEvent?.modifierFlags ?? []) -> FileOperationType? {
        let osModifierFlags = modifierFlags
        let sourceMask = info.draggingSourceOperationMask

        if osModifierFlags.contains(.option), sourceMask.contains(.copy) {
            return .copy
        }
        if sourceMask.contains(.move) {
            return .move
        }
        if sourceMask.contains(.copy) {
            return .copy
        }
        return nil
    }

    // MARK: - Operations

    func perform(_ operation: FileOperationType, items: [URL], destination: URL?, sourcePane: FileBrowserViewController? = nil, currentDirectory: URL) {
        guard !items.isEmpty else { return }
        
        // If confirmation is enabled, show the dialog first
        let confirmOps = settings.confirmFileOperations
        
        if confirmOps {
            if operation == .delete {
                Task { @MainActor in
                    let alert = NSAlert()
                    alert.messageText = "Delete \(items.count) item(s)?"
                    alert.informativeText = "Are you sure you want to move \(items.count) item(s) to the Trash? This action can be undone from the Trash."
                    alert.addButton(withTitle: "Delete")
                    alert.addButton(withTitle: "Cancel")
                    alert.alertStyle = .warning
                    
                    let response: NSApplication.ModalResponse
                    if let window = self.delegate?.window {
                        response = await alert.beginSheetModal(for: window)
                    } else {
                        response = alert.runModal()
                    }
                    
                    if response == .alertFirstButtonReturn {
                        // Proceed with delete
                        // Note: Auto-rename is irrelevant for delete (uses Trash)
                        self.execute(operation, items: items, destination: destination, sourcePane: sourcePane, autoRename: false)
                    }
                }
            } else {
                let opType: FileCopyMoveDialog.OperationType = (operation == .copy) ? .copy : .move
                let confirmationDialog = FileCopyMoveDialog(operationType: opType, sourceFiles: items, destination: destination ?? currentDirectory)
                
                confirmationDialog.onCompletion = { [weak self] in
                    guard let self else { return }
                    self.delegate?.fileOperationsManagerDidRequestRefresh(self)
                    if operation == .move, let sourcePane {
                        self.delegate?.fileOperationsManagerDidRequestRefreshSource(self, sourcePane: sourcePane)
                    }
                }
                
                if let hostWindow = delegate?.window, let sheet = confirmationDialog.window {
                    hostWindow.beginSheet(sheet, completionHandler: nil)
                } else {
                    // Fallback if no window available (shouldn't happen in normal flow)
                    confirmationDialog.showWindow(nil)
                }
            }
        } else {
            // Execute immediately without confirmation
            // NOTE: Auto-rename defaults to setting if skipping dialog
            let autoRename = settings.autoRenameOnConflict
            execute(operation, items: items, destination: destination, sourcePane: sourcePane, autoRename: autoRename)
        }
    }
    
    private func execute(_ operation: FileOperationType, items: [URL], destination: URL?, sourcePane: FileBrowserViewController?, autoRename: Bool) {
        let showProgress = settings.showOperationProgress
        let progressVC = showProgress ? ProgressViewController() : nil
        
        if let progressVC = progressVC {
            delegate?.fileOperationsManager(self, didRequestPresentSheet: progressVC)
        }
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let fileManager = FileManager.default
            var totalSize: Int64 = 0
            let startTime = Date()
            
            for (index, sourceURL) in items.enumerated() {
                let targetURL = destination?.appendingPathComponent(sourceURL.lastPathComponent)
                
                // Capture FileID at the start for TOCTOU validation
                let sourceFileID = FileSystemHelpers.fileID(for: sourceURL)
                let sourcePath = sourceURL.path
                
                if operation == .delete {
                    // Validate FileID before delete
                    if let expectedID = sourceFileID, !FileSystemHelpers.validateFileID(expectedID, for: sourceURL) {
                        await MainActor.run {
                            self.delegate?.fileOperationsManager(self, didRequestPresentError: "File was modified before deletion: \(sourceURL.lastPathComponent)")
                        }
                        continue
                    }
                    
                    do {
                        try fileManager.trashItem(at: sourceURL, resultingItemURL: nil)
                    } catch {
                        await MainActor.run {
                            self.delegate?.fileOperationsManager(self, didRequestPresentError: "Failed to move '\(sourceURL.lastPathComponent)' to Trash: \(error.localizedDescription)")
                        }
                    }
                } else if let targetURL = targetURL {
                    // For copy/move: calculate size BEFORE operation
                    var operationSize: Int64 = 0
                    if let attrs = try? fileManager.attributesOfItem(atPath: sourceURL.path) {
                        operationSize = (attrs[.size] as? Int64) ?? 0
                    }
                    
                    // Handle name conflicts atomically via operation error handling
                    // Prevent TOCTOU race: let FileManager report the error, then auto-rename if enabled
                    var finalURL = targetURL
                    var attemptCount = 0
                    let maxAttempts = AppConfig.Limits.maxAutoRenameAttempts
                    var operationSucceeded = false
                    var lastError: Error? = nil
                    
                    while attemptCount < maxAttempts && !operationSucceeded {
                        // Validate source file still exists with same FileID (TOCTOU check)
                        if !fileManager.fileExists(atPath: sourcePath) {
                            lastError = NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError, 
                                               userInfo: [NSLocalizedDescriptionKey: "Source file was removed during operation"])
                            break
                        }
                        
                        // Validate FileID hasn't changed (detect file replacement attacks)
                        if let expectedID = sourceFileID, !FileSystemHelpers.validateFileID(expectedID, for: sourceURL) {
                            lastError = NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError,
                                               userInfo: [NSLocalizedDescriptionKey: "Source file was replaced during operation"])
                            break
                        }
                        
                        do {
                            if operation == .copy {
                                try fileManager.copyItem(at: sourceURL, to: finalURL)
                                operationSucceeded = true
                                totalSize += operationSize
                            } else { // .move
                                try fileManager.moveItem(at: sourceURL, to: finalURL)
                                operationSucceeded = true
                                totalSize += operationSize
                            }
                        } catch CocoaError.fileWriteFileExists where autoRename && attemptCount < maxAttempts - 1 {
                            // Atomic error: file exists and auto-rename is enabled, try with new name
                            let nameWithoutExt = (sourceURL.lastPathComponent as NSString).deletingPathExtension
                            let ext = (sourceURL.lastPathComponent as NSString).pathExtension
                            let newName = ext.isEmpty ? "\(nameWithoutExt) \(attemptCount + 1)" : "\(nameWithoutExt) \(attemptCount + 1).\(ext)"
                            finalURL = (targetURL.deletingLastPathComponent()).appendingPathComponent(newName)
                            attemptCount += 1
                        } catch {
                            lastError = error
                            break
                        }
                    }
                    
                    if !operationSucceeded {
                        let displayError = lastError ?? NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError, userInfo: [NSLocalizedDescriptionKey: "Failed after \(attemptCount) rename attempts"])
                        await MainActor.run {
                            self.delegate?.fileOperationsManager(self, didRequestPresentError: "Failed to \(operation.rawValue) '\(sourceURL.lastPathComponent)': \(displayError.localizedDescription)")
                        }
                    }
                }
                
                // Update progress
                await MainActor.run {
                    progressVC?.updateProgress(percent: Double(index + 1) / Double(items.count), status: "Processing: \(sourceURL.lastPathComponent)")
                }
            }
            
            // Finalize
            OperationMetricsManager.append(type: operation.rawValue, bytes: totalSize, files: items.count, start: startTime, end: Date())
            await MainActor.run {
                progressVC?.dismiss(nil)
                self.delegate?.fileOperationsManagerDidRequestRefresh(self)
                if operation == .move, let sourcePane = sourcePane {
                    self.delegate?.fileOperationsManagerDidRequestRefreshSource(self, sourcePane: sourcePane)
                }
            }
        }
    }
}
