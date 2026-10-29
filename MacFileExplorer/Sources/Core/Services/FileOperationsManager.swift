import Cocoa

protocol FileOperationsManagerDelegate: AnyObject {
    func fileOperationsManager(_ manager: FileOperationsManager, didRequestPresentSheet viewController: NSViewController)
    func fileOperationsManager(_ manager: FileOperationsManager, didRequestPresentError message: String)
    func fileOperationsManagerDidRequestRefresh(_ manager: FileOperationsManager)
    func fileOperationsManagerDidRequestRefreshSource(_ manager: FileOperationsManager, sourcePane: FileBrowserViewController)
    var window: NSWindow? { get }
}

@MainActor
final class FileOperationsManager {
    weak var delegate: FileOperationsManagerDelegate?
    private let settings: SettingsStoreProtocol
    /// Copy/move dialogs are presented as sheets, which retain only the window,
    /// so the controller (and the FileOperation it owns) must be kept alive here.
    private var activeDialogs: [ObjectIdentifier: FileCopyMoveDialog] = [:]
    
    init(delegate: FileOperationsManagerDelegate?, settings: SettingsStoreProtocol = SettingsStore.shared) {
        self.delegate = delegate
        self.settings = settings
    }

    // MARK: - Validation

    /// Pure path-containment check; no actor state touched, safe to call from anywhere.
    nonisolated func isValidDestination(_ destination: URL, for urls: [URL]) -> Bool {
        // Resolve symlinks and standardize to prevent traversal bypasses
        let resolvedDest = destination.resolvingSymlinksInPath().standardizedFileURL

        for source in urls {
            let resolvedSource = source.resolvingSymlinksInPath().standardizedFileURL

            // Check for exact match (using standardized and resolved paths)
            if resolvedSource == resolvedDest || source.standardizedFileURL == destination.standardizedFileURL {
                return false
            }

            // Check if destination is inside source (prevent moving folder into itself)
            // 1. FileID-based ancestor check (robust against symlinks and path aliasing)
            if FileSystemHelpers.isAncestorByFileID(ancestor: resolvedSource, descendant: resolvedDest) {
                return false
            }
            if FileSystemHelpers.isAncestorByFileID(ancestor: source.standardizedFileURL, descendant: destination.standardizedFileURL) {
                return false
            }

            // 2. Fallback path string prefix check (e.g. if one of the paths doesn't exist yet on disk)
            let sourceString = resolvedSource.path
            let destString = resolvedDest.path
            if destString.hasPrefix(sourceString + "/") {
                return false
            }
            let rawSourceString = source.standardizedFileURL.path
            let rawDestString = destination.standardizedFileURL.path
            if rawDestString.hasPrefix(rawSourceString + "/") {
                return false
            }
        }

        return true
    }
    
    nonisolated static func isDirectChild(_ item: URL, of directory: URL) -> Bool {
        let parent = item.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        let dir = directory.resolvingSymlinksInPath().standardizedFileURL
        return parent.path == dir.path
    }

    /// For a move, removes items that already live in `destination` (moving them is a no-op).
    nonisolated static func droppingNoOpMoves(_ items: [URL], operation: FileOperationType, destination: URL?) -> [URL] {
        guard operation == .move, let target = destination else { return items }
        return items.filter { !FileOperation.isSameDirectory($0.deletingLastPathComponent(), target) }
    }

    // MARK: - Drag & Drop Helpers
    
    func preferredDragOperation(from info: NSDraggingInfo, modifierFlags: NSEvent.ModifierFlags? = nil) -> FileOperationType? {
        let osModifierFlags = modifierFlags ?? NSApp.currentEvent?.modifierFlags ?? []
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
        // Resolve once so the confirm and no-confirm paths see the same destination;
        // nil means "the current directory" (e.g. paste).
        let destination: URL? = operation == .delete ? destination : (destination ?? currentDirectory)

        // Moving an item into the folder it already lives in is a no-op, not a rename.
        let items = Self.droppingNoOpMoves(items, operation: operation, destination: destination)
        guard !items.isEmpty else { return }

        // Capture file identities now, at selection time, so the check at execution time
        // spans any confirmation dialog rather than a few instructions.
        let expectedIDs = items.map { FileSystemHelpers.fileID(for: $0) }

        if operation != .delete, let resolvedDestination = destination {
            guard isValidDestination(resolvedDestination, for: items) else {
                delegate?.fileOperationsManager(self, didRequestPresentError: "Can't move or copy an item into itself or one of its subfolders.")
                return
            }
        }

        // If confirmation is enabled, show the dialog first
        let confirmOps: Bool
        switch operation {
        case .copy:
            confirmOps = settings.confirmCopyOperations
        case .move:
            confirmOps = settings.confirmMoveOperations
        case .delete:
            confirmOps = settings.confirmDeleteOperations
        }
        
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
                        self.execute(operation, items: items, destination: destination, sourcePane: sourcePane, autoRename: false, expectedIDs: expectedIDs)
                    }
                }
            } else {
                let opType: FileCopyMoveDialog.OperationType = (operation == .copy) ? .copy : .move
                let confirmationDialog = FileCopyMoveDialog(operationType: opType, sourceFiles: items, destination: destination ?? currentDirectory)
                
                let dialogID = ObjectIdentifier(confirmationDialog)
                activeDialogs[dialogID] = confirmationDialog
                confirmationDialog.onClose = { [weak self] in
                    self?.activeDialogs[dialogID] = nil
                }

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
            execute(operation, items: items, destination: destination, sourcePane: sourcePane, autoRename: autoRename, expectedIDs: expectedIDs)
        }
    }
    
    private func execute(_ operation: FileOperationType, items: [URL], destination: URL?, sourcePane: FileBrowserViewController?, autoRename: Bool, expectedIDs: [FileID?]) {
        let showProgress = settings.showOperationProgress
        let progressVC = showProgress ? ProgressViewController() : nil
        
        if let progressVC = progressVC {
            delegate?.fileOperationsManager(self, didRequestPresentSheet: progressVC)
        }
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            ProcessInfo.processInfo.disableSuddenTermination()
            defer {
                ProcessInfo.processInfo.enableSuddenTermination()
            }
            let fileManager = FileManager.default
            var totalSize: Int64 = 0
            let startTime = Date()
            
            for (index, sourceURL) in items.enumerated() {
                let targetURL = destination?.appendingPathComponent(sourceURL.lastPathComponent)
                
                // FileID captured when the operation was requested (before any confirmation)
                let sourceFileID = index < expectedIDs.count ? expectedIDs[index] : nil
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
                    // For copy/move: size for the metrics log, taken BEFORE the operation.
                    // .size on a directory is the size of the directory entry, not its contents,
                    // and walking a tree just to log it would double the I/O of a move that is
                    // normally a single rename, so only copies of directories are measured.
                    var operationSize: Int64 = 0
                    if let attrs = try? fileManager.attributesOfItem(atPath: sourceURL.path) {
                        if attrs[.type] as? FileAttributeType == .typeDirectory {
                            operationSize = operation == .copy ? FileItem.calculateDirectorySize(at: sourceURL) : 0
                        } else {
                            operationSize = (attrs[.size] as? Int64) ?? 0
                        }
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
                            let newName = ext.isEmpty ? "\(nameWithoutExt) (\(attemptCount + 1))" : "\(nameWithoutExt) (\(attemptCount + 1)).\(ext)"
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

// MARK: - Folder drops (sidebar / outline)

/// Shared implementation for dropping files onto a folder row in the sidebar or the folder
/// tree. Those views used to call `FileManager.moveItem` directly while advertising a
/// *copy* cursor, with no validation, conflict handling or error reporting.
@MainActor
enum FileDropTransfer {
    /// File URLs on the dragging pasteboard (non-file URLs are ignored).
    static func fileURLs(from info: NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
    }

    /// The operation to show and perform, or `[]` if the drop is not allowed.
    /// Copies when ⌥ is held or the destination is on another volume (as Finder does).
    static func operation(for urls: [URL], destination: URL, optionKeyHeld: Bool, sourceMask: NSDragOperation) -> NSDragOperation {
        guard !urls.isEmpty, FileOperationsManager(delegate: nil).isValidDestination(destination, for: urls) else { return [] }
        let isCopy = optionKeyHeld || urls.contains { !sameVolume($0, destination) }
        // Moving everything into the folder it already lives in would do nothing.
        if !isCopy, urls.allSatisfy({ FileOperation.isSameDirectory($0.deletingLastPathComponent(), destination) }) {
            return []
        }
        let desired: NSDragOperation = isCopy ? .copy : .move
        if sourceMask.contains(desired) { return desired }
        // A source that only offers copy can still be honoured as a copy; never turn a
        // requested copy into a move.
        return desired == .move && sourceMask.contains(.copy) ? .copy : []
    }

    /// Performs the transfer. Existing items are never overwritten; every failure is
    /// collected and shown to the user.
    @discardableResult
    static func perform(_ operation: NSDragOperation, urls: [URL], into destination: URL, window: NSWindow?) -> Bool {
        let fileManager = FileManager.default
        var failures: [String] = []

        for source in urls {
            let name = source.lastPathComponent
            if operation == .move, FileOperation.isSameDirectory(source.deletingLastPathComponent(), destination) { continue }
            let target = destination.appendingPathComponent(name)
            if FileOperation.sourceKind(at: target) != .missing {
                failures.append("'\(name)' already exists in '\(destination.lastPathComponent)'.")
                continue
            }
            do {
                if operation == .copy {
                    try fileManager.copyItem(at: source, to: target)
                } else {
                    try fileManager.moveItem(at: source, to: target)
                }
            } catch {
                failures.append("'\(name)': \(error.localizedDescription)")
            }
        }

        if !failures.isEmpty {
            let alert = NSAlert()
            alert.messageText = operation == .copy ? "Some items could not be copied" : "Some items could not be moved"
            alert.informativeText = failures.prefix(8).joined(separator: "\n")
                + (failures.count > 8 ? "\n… and \(failures.count - 8) more." : "")
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            if let window {
                alert.beginSheetModal(for: window)
            } else {
                alert.runModal()
            }
        }
        return failures.isEmpty
    }

    private static func sameVolume(_ lhs: URL, _ rhs: URL) -> Bool {
        let a = try? lhs.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
        let b = try? rhs.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
        guard let a = a ?? nil, let b = b ?? nil else { return true }
        return a.isEqual(b)
    }
}
