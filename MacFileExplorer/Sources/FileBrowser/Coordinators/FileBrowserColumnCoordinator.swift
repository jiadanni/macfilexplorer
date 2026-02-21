import Cocoa

protocol FileBrowserColumnCoordinatorDelegate: AnyObject {
    var rootItem: FileItem? { get }
    var showsHiddenFiles: Bool { get }
    var browserView: NSBrowser? { get }
    var settings: SettingsStoreProtocol { get }
    func fileBrowserDidBecomeActive()
}

final class FileBrowserColumnCoordinator: NSObject, NSBrowserDelegate {
    weak var delegate: FileBrowserColumnCoordinatorDelegate?
    weak var selectionCoordinator: FileBrowserSelectionCoordinator?
    weak var dragDropHandler: FileBrowserDragDropHandler?
    
    private var settings: SettingsStoreProtocol {
        delegate?.settings ?? SettingsStore.shared
    }
    
    // MARK: - NSBrowserDelegate
    
    func rootItem(for browser: NSBrowser) -> Any? {
        return delegate?.rootItem
    }
    
    func browser(_ browser: NSBrowser, numberOfChildrenOfItem item: Any?) -> Int {
        guard let fileItem = (item as? FileItem) ?? delegate?.rootItem else { return 0 }
        if fileItem.needsChildLoading {
            fileItem.loadChildren(showsHiddenFiles: delegate?.showsHiddenFiles ?? false)
        }
        return fileItem.children?.count ?? 0
    }
    
    func browser(_ browser: NSBrowser, child index: Int, ofItem item: Any?) -> Any {
        guard let fileItem = (item as? FileItem) ?? delegate?.rootItem else {
            return item as Any
        }
        if let child = fileItem.children?.safe(at: index) {
            return child
        }
        return fileItem
    }
    
    func browser(_ browser: NSBrowser, isLeafItem item: Any?) -> Bool {
        guard let fileItem = item as? FileItem else { return true }
        return !fileItem.isDirectory
    }
    
    func browser(_ browser: NSBrowser, objectValueForItem item: Any?) -> Any? {
        return (item as? FileItem)?.displayName(showExtensions: settings.showFileExtensions)
    }
    
    func browser(_ browser: NSBrowser, willDisplayCell cell: Any, atRow row: Int, column: Int) {
        guard let browserCell = cell as? NSBrowserCell else { return }
        
        let parentItem = fileItemForColumn(column)
        guard let children = parentItem?.children, row < children.count else { return }
        let item = children[row]
        
        browserCell.image = item.icon(useGrayscale: settings.useGrayscaleIcons)
        browserCell.title = item.displayName(showExtensions: settings.showFileExtensions)
        browserCell.isLeaf = !item.isDirectory
    }
    
    func fileItemForColumn(_ column: Int) -> FileItem? {
        if column == 0 {
            return delegate?.rootItem
        }
        
        guard let browserView = delegate?.browserView else { return nil }
        
        let path = browserView.path(toColumn: column)
        var currentItem = delegate?.rootItem
        
        let components = path.components(separatedBy: browserView.pathSeparator)
        let showExtensions = settings.showFileExtensions
        
        for component in components.dropFirst() { // Drop root
            if let child = currentItem?.children?.first(where: { $0.displayName(showExtensions: showExtensions) == component }) {
                currentItem = child
            } else {
                return nil
            }
        }
        return currentItem
    }
    
    private func columnIndex(atWindowPoint point: NSPoint, in browser: NSBrowser) -> Int {
        let location = browser.convert(point, from: nil)
        let totalColumns = browser.numberOfVisibleColumns
        if totalColumns > 0 {
            for column in 0..<totalColumns {
                if browser.frame(ofColumn: column).contains(location) {
                    return column
                }
            }
        }
        return -1
    }
    
    func browser(_ browser: NSBrowser, selectionDidChangeInColumn column: Int) {
        delegate?.fileBrowserDidBecomeActive()
        _ = selectionCoordinator?.handleBrowserSelectionDidChange(column: column)
    }
    
    // MARK: - Drag and Drop for Browser View
    
    func browser(_ browser: NSBrowser, writeRowsWith rowIndexes: IndexSet, inColumn column: Int, to pboard: NSPasteboard) -> Bool {
        guard let parentItem = fileItemForColumn(column),
              let children = parentItem.children else { return false }
        
        let itemsToDrag = rowIndexes.compactMap { children.safe(at: $0) }
        let urls = itemsToDrag.map { $0.url as NSURL }
        
        pboard.clearContents()
        return pboard.writeObjects(urls)
    }
    
    func browser(_ browser: NSBrowser, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        let targetItem: FileItem?
        if let fileItem = item as? FileItem {
            targetItem = fileItem
        } else {
            let proposedColumn = columnIndex(atWindowPoint: info.draggingLocation, in: browser)
            targetItem = proposedColumn >= 0 ? fileItemForColumn(proposedColumn) : nil
        }
        return dragDropHandler?.validateDrop(info, proposedTarget: targetItem) ?? []
    }
    
    func browser(_ browser: NSBrowser, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        let targetItem: FileItem?
        if let fileItem = item as? FileItem {
            targetItem = fileItem
        } else {
            let proposedColumn = columnIndex(atWindowPoint: info.draggingLocation, in: browser)
            targetItem = proposedColumn >= 0 ? fileItemForColumn(proposedColumn) : nil
        }
        return dragDropHandler?.acceptDrop(info, target: targetItem) ?? false
    }
}
