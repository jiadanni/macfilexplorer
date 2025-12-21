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
        for source in urls {
            if source == destination { return false }
            if destination.path.hasPrefix(source.path + "/") { return false }
        }
        return true
    }
    
    // MARK: - Drag & Drop Helpers
    
    func preferredDragOperation(from info: NSDraggingInfo) -> FileOperationType? {
        let osModifierFlags = NSApp.currentEvent?.modifierFlags ?? []
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
        
        if confirmOps && operation != .delete {
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
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fileManager = FileManager.default
            var totalSize: Int64 = 0
            let startTime = Date()
            
            for (index, sourceURL) in items.enumerated() {
                let targetURL = destination?.appendingPathComponent(sourceURL.lastPathComponent)
                
                if operation == .delete {
                    do {
                        try fileManager.trashItem(at: sourceURL, resultingItemURL: nil)
                    } catch {
                        DispatchQueue.main.async {
                            self.delegate?.fileOperationsManager(self, didRequestPresentError: "Failed to move '\(sourceURL.lastPathComponent)' to Trash: \(error.localizedDescription)")
                        }
                    }
                } else if var targetURL = targetURL {
                    // Handle name conflicts
                    if autoRename && fileManager.fileExists(atPath: targetURL.path) {
                        var counter = 1
                        let nameWithoutExt = (sourceURL.lastPathComponent as NSString).deletingPathExtension
                        let ext = (sourceURL.lastPathComponent as NSString).pathExtension
                        repeat {
                            let newName = ext.isEmpty ? "\(nameWithoutExt) \(counter)" : "\(nameWithoutExt) \(counter).\(ext)"
                            targetURL = (targetURL.deletingLastPathComponent()).appendingPathComponent(newName)
                            counter += 1
                        } while fileManager.fileExists(atPath: targetURL.path)
                    }
                    
                    do {
                        if operation == .copy {
                            try fileManager.copyItem(at: sourceURL, to: targetURL)
                            // Calculate size for metrics if needed
                             if let attrs = try? fileManager.attributesOfItem(atPath: sourceURL.path) {
                                totalSize += (attrs[.size] as? Int64) ?? 0
                            }
                        } else { // .move
                             if let attrs = try? fileManager.attributesOfItem(atPath: sourceURL.path) {
                                totalSize += (attrs[.size] as? Int64) ?? 0
                            }
                            try fileManager.moveItem(at: sourceURL, to: targetURL)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.delegate?.fileOperationsManager(self, didRequestPresentError: "Failed to \(operation.rawValue) '\(sourceURL.lastPathComponent)': \(error.localizedDescription)")
                        }
                    }
                }
                
                // Update progress
                DispatchQueue.main.async {
                    progressVC?.updateProgress(percent: Double(index + 1) / Double(items.count), status: "Processing: \(sourceURL.lastPathComponent)")
                }
            }
            
            // Finalize
            OperationMetricsManager.append(type: operation.rawValue, bytes: totalSize, files: items.count, start: startTime, end: Date())
            DispatchQueue.main.async {
                progressVC?.dismiss(nil)
                self.delegate?.fileOperationsManagerDidRequestRefresh(self)
                if operation == .move, let sourcePane = sourcePane {
                    self.delegate?.fileOperationsManagerDidRequestRefreshSource(self, sourcePane: sourcePane)
                }
            }
        }
    }
}
