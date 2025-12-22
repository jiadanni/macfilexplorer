import Cocoa

/// Manages file selection state and status updates across view modes.
///
/// Extracted from FileBrowserViewController to isolate selection logic.
protocol FileBrowserSelectionDelegate: AnyObject {
    var currentViewMode: ViewMode { get }
    var outlineView: NSOutlineView! { get }
    var collectionView: NSCollectionView? { get }
    var browserView: NSBrowser? { get }
    var rootItem: FileItem? { get }
    func fileItemForColumn(_ column: Int) -> FileItem?
    func updateStatusBarDisplay(selectedCount: Int, totalSize: Int64)
    func updatePreviewPane(with file: FileItem?)
}

final class FileBrowserSelectionCoordinator {
    weak var delegate: FileBrowserSelectionDelegate?
    private let selectionManager = FileBrowserSelectionManager()

    func currentSingleSelection() -> FileItem? {
        guard let outlineView = delegate?.outlineView else { return nil }
        return selectionManager.currentSingleSelection(outlineView: outlineView)
    }

    func selectedItems(includeClickedRowFallback: Bool = true) -> [FileItem] {
        guard let delegate = delegate else { return [] }

        var items = selectionManager.selectedItems(
            outlineView: delegate.outlineView,
            collectionView: delegate.collectionView,
            browserView: delegate.browserView,
            fileItemForColumn: { [weak delegate] column in delegate?.fileItemForColumn(column) },
            viewMode: delegate.currentViewMode,
            rootItem: delegate.rootItem
        )

        if includeClickedRowFallback, items.isEmpty, delegate.currentViewMode == .list {
            let clickedRow = delegate.outlineView.clickedRow
            if clickedRow >= 0, let item = delegate.outlineView.item(atRow: clickedRow) as? FileItem {
                items.append(item)
            }
        }

        return items
    }

    func clearSelection() {
        guard let delegate = delegate else { return }

        switch delegate.currentViewMode {
        case .list:
            delegate.outlineView.deselectAll(nil)
        case .icons, .windowsList:
            delegate.collectionView?.deselectAll(nil)
        case .columns:
            delegate.browserView?.selectionIndexPaths = []
        }
        delegate.updatePreviewPane(with: nil)
        updateStatusBar()
    }

    func updateStatusBar() {
        guard let delegate = delegate else { return }
        switch delegate.currentViewMode {
        case .list:
            updateStatusBarForOutline()
        case .icons, .windowsList:
            updateStatusBarForCollectionView()
        case .columns:
            updateStatusBarForBrowser()
        }
    }

    func handleOutlineSelectionDidChange() -> FileItem? {
        updateStatusBarForOutline()
        guard let delegate = delegate else { return nil }
        let selectedItem = delegate.outlineView.selectedRow >= 0
            ? delegate.outlineView.item(atRow: delegate.outlineView.selectedRow) as? FileItem
            : nil
        delegate.updatePreviewPane(with: selectedItem)
        return selectedItem
    }

    func handleCollectionSelectionDidChange() -> FileItem? {
        updateStatusBarForCollectionView()
        guard let delegate = delegate, let collectionView = delegate.collectionView else { return nil }
        let items = delegate.rootItem?.children ?? []
        guard collectionView.selectionIndexPaths.count == 1,
              let firstPath = collectionView.selectionIndexPaths.first
        else {
            delegate.updatePreviewPane(with: nil)
            return nil
        }
        let selectedItem = firstPath.item < items.count ? items[firstPath.item] : nil
        delegate.updatePreviewPane(with: selectedItem)
        return selectedItem
    }

    func handleBrowserSelectionDidChange(column: Int) -> FileItem? {
        updateStatusBarForBrowser()
        guard let delegate = delegate, let browserView = delegate.browserView else { return nil }
        let selectedRows = browserView.selectedRowIndexes(inColumn: column)
        guard let selectedRow = selectedRows?.first else {
            delegate.updatePreviewPane(with: nil)
            return nil
        }

        if let parentItem = delegate.fileItemForColumn(column),
           let children = parentItem.children,
           selectedRow < children.count {
            let selectedItem = children[selectedRow]
            delegate.updatePreviewPane(with: selectedItem)
            return selectedItem
        }

        delegate.updatePreviewPane(with: nil)
        return nil
    }

    func updateStatusBarForOutline() {
        guard let delegate = delegate else { return }
        let selectedRows = delegate.outlineView.selectedRowIndexes
        var totalSize: Int64 = 0

        selectedRows.forEach { row in
            if let item = delegate.outlineView.item(atRow: row) as? FileItem {
                totalSize += item.size
            }
        }

        delegate.updateStatusBarDisplay(selectedCount: selectedRows.count, totalSize: totalSize)
    }

    func updateStatusBarForCollectionView() {
        guard let delegate = delegate, let collectionView = delegate.collectionView else { return }
        let selectedIndexPaths = collectionView.selectionIndexPaths
        let selectedCount = selectedIndexPaths.count
        var totalSize: Int64 = 0
        let items = delegate.rootItem?.children ?? []

        selectedIndexPaths.forEach { indexPath in
            if indexPath.item < items.count {
                totalSize += items[indexPath.item].size
            }
        }

        delegate.updateStatusBarDisplay(selectedCount: selectedCount, totalSize: totalSize)
    }

    func updateStatusBarForBrowser() {
        guard let delegate = delegate, let browserView = delegate.browserView else { return }
        let selectedColumn = browserView.selectedColumn
        guard selectedColumn >= 0 else {
            delegate.updateStatusBarDisplay(selectedCount: 0, totalSize: 0)
            return
        }

        let selectedRows = browserView.selectedRowIndexes(inColumn: selectedColumn)
        let selectedCount = selectedRows?.count ?? 0
        var totalSize: Int64 = 0

        selectedRows?.forEach { row in
            if let parentItem = delegate.fileItemForColumn(selectedColumn),
               let children = parentItem.children,
               row < children.count {
                totalSize += children[row].size
            }
        }

        delegate.updateStatusBarDisplay(selectedCount: selectedCount, totalSize: totalSize)
    }
}
