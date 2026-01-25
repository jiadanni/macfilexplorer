import Cocoa

protocol FileBrowserDragDropCoordinatorDelegate: AnyObject {
    func isValidDestination(_ destination: URL, for urls: [URL]) -> Bool
    func preferredDragOperation(from info: NSDraggingInfo) -> FileOperationType?
}

final class FileBrowserDragDropCoordinator: NSObject, RootFileBrowserDropDelegate {
    weak var delegate: FileBrowserDragDropCoordinatorDelegate?
    weak var dragDropHandler: FileBrowserDragDropHandler?
    
    // MARK: - RootFileBrowserDropDelegate
    
    func rootViewPreferredOperation(for info: NSDraggingInfo) -> NSDragOperation {
        return dragDropHandler?.validateDrop(info, proposedTarget: nil) ?? []
    }
    
    func rootViewPerformDrop(urls: [URL], operation: FileOperationType, info: NSDraggingInfo) {
        _ = dragDropHandler?.acceptDrop(info, target: nil)
    }
}
