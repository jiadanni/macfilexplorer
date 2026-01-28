import Cocoa

/// Encapsulates selection-related helpers for the file browser so the view controller
/// can delegate common selection logic.
final class FileBrowserSelectionManager {
    func currentSingleSelection(outlineView: NSOutlineView) -> FileItem? {
        let selected = outlineView.selectedRowIndexes
        guard selected.count == 1, let row = selected.first else { return nil }
        return outlineView.item(atRow: row) as? FileItem
    }

    func selectedItems(outlineView: NSOutlineView?, collectionView: NSCollectionView?, browserView: NSBrowser?, fileItemForColumn: ((Int) -> FileItem?)?, viewMode: ViewMode, rootItem: FileItem?) -> [FileItem] {
        switch viewMode {
        case .list:
            guard let outlineView else { return [] }
            return outlineView.selectedRowIndexes.compactMap { idx in
                outlineView.item(atRow: idx) as? FileItem
            }
        case .icons, .windowsList:
            guard let collectionView, let children = rootItem?.children else { return [] }
            return collectionView.selectionIndexes.compactMap { index in
                guard index >= 0, index < children.count else { return nil }
                return children[index]
            }
        case .columns:
            guard
                let browserView,
                let resolver = fileItemForColumn
            else { return [] }

            let selectedColumn = browserView.selectedColumn
            guard selectedColumn >= 0 else { return [] }

            var items: [FileItem] = []
            if let selectedRows = browserView.selectedRowIndexes(inColumn: selectedColumn) {
                selectedRows.forEach { row in
                    if let parent = resolver(selectedColumn),
                       let children = parent.children,
                       row >= 0, row < children.count {
                        items.append(children[row])
                    }
                }
            }
            return items

        }
    }
}
