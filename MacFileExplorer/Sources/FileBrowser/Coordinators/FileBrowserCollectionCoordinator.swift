import Cocoa

protocol FileBrowserCollectionCoordinatorDelegate: AnyObject {
    var rootItem: FileItem? { get }
    var currentViewMode: ViewMode { get }
    var zoomLevel: Double { get }
    func fileBrowserDidBecomeActive()
}

final class FileBrowserCollectionCoordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
    weak var delegate: FileBrowserCollectionCoordinatorDelegate?
    weak var selectionCoordinator: FileBrowserSelectionCoordinator?
    weak var dragDropHandler: FileBrowserDragDropHandler?
    
    private func collectionItems() -> [FileItem] {
        return delegate?.rootItem?.children ?? []
    }
    
    // MARK: - NSCollectionViewDataSource
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return collectionItems().count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = FileIconItem()
        let items = collectionItems()
        if let fileItem = items.safe(at: indexPath.item) {
            item.fileItem = fileItem
        }
        item.isListMode = (delegate?.currentViewMode == .windowsList)
        item.zoomLevel = delegate?.zoomLevel ?? 1.0
        item.showCheckbox = SettingsStore.shared.enableEasySelect
        return item
    }
    
    // MARK: - NSCollectionViewDelegate
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        delegate?.fileBrowserDidBecomeActive()
        _ = selectionCoordinator?.handleCollectionSelectionDidChange()
    }
    
    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        delegate?.fileBrowserDidBecomeActive()
        _ = selectionCoordinator?.handleCollectionSelectionDidChange()
    }
    
    // MARK: - Drag and Drop for CollectionView
    
    func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        let items = collectionItems()
        guard let item = items.safe(at: indexPath.item) else { return nil }
        return item.url as NSURL
    }
    
    func collectionView(_ collectionView: NSCollectionView, validateDrop draggingInfo: NSDraggingInfo, proposedIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>, dropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        let items = collectionItems()
        let targetItem = dropOperation.pointee == .on ? items.safe(at: proposedIndexPath.pointee.item) : nil
        return dragDropHandler?.validateDrop(draggingInfo, proposedTarget: targetItem) ?? []
    }
    
    func collectionView(_ collectionView: NSCollectionView, acceptDrop draggingInfo: NSDraggingInfo, indexPath: IndexPath, dropOperation: NSCollectionView.DropOperation) -> Bool {
        let items = collectionItems()
        let targetItem = dropOperation == .on ? items.safe(at: indexPath.item) : nil
        return dragDropHandler?.acceptDrop(draggingInfo, target: targetItem) ?? false
    }
}
