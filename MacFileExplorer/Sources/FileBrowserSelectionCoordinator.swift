import Cocoa

/// Manages file selection state and operations across different view modes.
///
/// Extracted from FileBrowserViewController to isolate selection logic.
/// Handles:
/// - Selection state tracking
/// - View mode-specific selection
/// - Multi-select operations
/// - Selection queries and statistics

protocol FileBrowserSelectionDelegate: AnyObject {
    var currentViewMode: ViewMode { get }
    var outlineView: NSOutlineView? { get }
    var collectionView: NSCollectionView? { get }
    var browserView: NSBrowser? { get }
    var dataSource: FileBrowserDataSource? { get }
    func updateStatusBar()
}

class FileBrowserSelectionCoordinator: NSObject {
    weak var delegate: FileBrowserSelectionDelegate?
    
    private var selectedItems: Set<FileItem> = []
    
    /// Returns currently selected items.
    func getSelectedItems() -> [FileItem] {
        guard let delegate = delegate else { return [] }
        
        switch delegate.currentViewMode {
        case .list:
            return getSelectedItemsFromOutline()
        case .icons, .windowsList:
            return getSelectedItemsFromCollection()
        case .columns:
            return getSelectedItemsFromBrowser()
        }
    }
    
    /// Returns single selection or nil if none or multiple.
    func getSingleSelection() -> FileItem? {
        let items = getSelectedItems()
        guard items.count == 1 else { return nil }
        return items.first
    }
    
    /// Selects the given items in the current view.
    func selectItems(_ items: [FileItem]) {
        guard let delegate = delegate else { return }
        
        switch delegate.currentViewMode {
        case .list:
            selectItemsInOutline(items)
        case .icons, .windowsList:
            selectItemsInCollection(items)
        case .columns:
            selectItemsInBrowser(items)
        }
        
        selectedItems = Set(items)
        delegate.updateStatusBar()
    }
    
    /// Clears all selections in the current view.
    func clearSelection() {
        guard let delegate = delegate else { return }
        
        switch delegate.currentViewMode {
        case .list:
            delegate.outlineView?.deselectAll(nil)
        case .icons, .windowsList:
            delegate.collectionView?.deselectAll(nil)
        case .columns:
            delegate.browserView?.selectionIndexPaths = []
        }
        
        selectedItems.removeAll()
        delegate.updateStatusBar()
    }
    
    /// Returns count of selected items.
    func getSelectionCount() -> Int {
        return getSelectedItems().count
    }
    
    /// Returns total size of selected items.
    func getSelectionSize() -> UInt64 {
        return getSelectedItems().reduce(0) { $0 + $1.size }
    }
    
    /// Checks if any items are selected.
    func hasSelection() -> Bool {
        return !getSelectedItems().isEmpty
    }
    
    /// Checks if multiple items are selected.
    func hasMultipleSelection() -> Bool {
        return getSelectedItems().count > 1
    }
    
    // MARK: - Private: View-Specific Selection
    
    private func getSelectedItemsFromOutline() -> [FileItem] {
        guard let delegate = delegate, let outlineView = delegate.outlineView else { return [] }
        let selectedRows = outlineView.selectedRowIndexes
        return selectedRows.compactMap { outlineView.item(atRow: $0) as? FileItem }
    }
    
    private func getSelectedItemsFromCollection() -> [FileItem] {
        guard let delegate = delegate, let collectionView = delegate.collectionView else { return [] }
        let selectedIndexPaths = collectionView.selectionIndexPaths
        return selectedIndexPaths.compactMap { indexPath in
            guard let item = collectionView.item(at: indexPath) else { return nil }
            return item as? FileItem
        }
    }
    
    private func getSelectedItemsFromBrowser() -> [FileItem] {
        guard let delegate = delegate, let browserView = delegate.browserView else { return [] }
        let selectedIndexPaths = browserView.selectionIndexPaths
        return selectedIndexPaths.compactMap { indexPath in
            // Browser uses column-row coordinates
            guard !indexPath.isEmpty else { return nil }
            return browserView.item(atIndexPath: indexPath) as? FileItem
        }
    }
    
    private func selectItemsInOutline(_ items: [FileItem]) {
        guard let delegate = delegate, let outlineView = delegate.outlineView else { return }
        
        var indexSet = IndexSet()
        for item in items {
            let row = outlineView.row(forItem: item)
            if row >= 0 {
                indexSet.insert(row)
            }
        }
        outlineView.selectRowIndexes(indexSet, byExtendingSelection: false)
    }
    
    private func selectItemsInCollection(_ items: [FileItem]) {
        guard let delegate = delegate, let collectionView = delegate.collectionView else { return }
        guard let dataSource = delegate.dataSource else { return }
        
        var indexPaths = Set<IndexPath>()
        for item in items {
            // Find index of item in datasource
            if let index = dataSource.items.firstIndex(where: { $0.id == item.id }) {
                indexPaths.insert(IndexPath(item: index, section: 0))
            }
        }
        collectionView.selectionIndexPaths = indexPaths
    }
    
    private func selectItemsInBrowser(_ items: [FileItem]) {
        guard let delegate = delegate, let browserView = delegate.browserView else { return }
        
        var indexPaths = Set<IndexPath>()
        for item in items {
            // Browser requires finding the item path
            if let indexPath = findItemInBrowser(item, in: browserView) {
                indexPaths.insert(indexPath)
            }
        }
        browserView.selectionIndexPaths = indexPaths
    }
    
    private func findItemInBrowser(_ item: FileItem, in browserView: NSBrowser) -> IndexPath? {
        // This is a simplified implementation
        // In practice, would need to traverse browser columns to find item
        return nil
    }
}
