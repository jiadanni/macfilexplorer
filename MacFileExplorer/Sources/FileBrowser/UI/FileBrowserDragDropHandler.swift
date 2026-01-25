import Cocoa

/// Delegate for FileBrowserDragDropHandler to interact with the view controller.
protocol FileBrowserDragDropDelegate: AnyObject {
    var currentDirectory: URL { get }
    func performFileOperation(_ operation: FileOperationType, items: [URL], destination: URL?, sourcePane: FileBrowserViewController?)
    func isValidDestination(_ destination: URL, for urls: [URL]) -> Bool
    func preferredDragOperation(from info: NSDraggingInfo) -> FileOperationType?
    func dragSourceFileBrowser(from info: NSDraggingInfo) -> FileBrowserViewController?
}

/// Centralizes Drag & Drop logic for the File Browser.
class FileBrowserDragDropHandler {
    weak var delegate: FileBrowserDragDropDelegate?
    
    init(delegate: FileBrowserDragDropDelegate) {
        self.delegate = delegate
    }
    
    // MARK: - Drop Validation
    
    /// Validates a drop operation.
    /// - Parameters:
    ///   - info: The dragging info.
    ///   - proposedTarget: The item the user is hovering over (if any).
    /// - Returns: The allowed drag operation.
    func validateDrop(_ info: NSDraggingInfo, proposedTarget item: FileItem?) -> NSDragOperation {
        guard let delegate = delegate,
              let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              !urls.isEmpty else { return [] }
        
        let destinationURL: URL
        if let fileItem = item {
            destinationURL = fileItem.isDirectory ? fileItem.url : delegate.currentDirectory
        } else {
            destinationURL = delegate.currentDirectory
        }
        
        guard delegate.isValidDestination(destinationURL, for: urls) else { return [] }
        guard let op = delegate.preferredDragOperation(from: info) else { return [] }
        
        return op == .copy ? .copy : .move
    }
    
    // MARK: - Drop Acceptance
    
    /// Accepts a drop operation.
    /// - Parameters:
    ///   - info: The dragging info.
    ///   - target: The item the user dropped onto (if any).
    /// - Returns: Whether the drop was accepted.
    func acceptDrop(_ info: NSDraggingInfo, target item: FileItem?) -> Bool {
        guard let delegate = delegate,
              let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              !urls.isEmpty else { return false }
        
        let destinationURL: URL
        if let fileItem = item {
            destinationURL = fileItem.isDirectory ? fileItem.url : delegate.currentDirectory
        } else {
            destinationURL = delegate.currentDirectory
        }
        
        guard delegate.isValidDestination(destinationURL, for: urls) else { return false }
        guard let op = delegate.preferredDragOperation(from: info) else { return false }
        
        delegate.performFileOperation(op, items: urls, destination: destinationURL, sourcePane: delegate.dragSourceFileBrowser(from: info))
        return true
    }
}
