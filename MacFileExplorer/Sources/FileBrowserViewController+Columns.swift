import Cocoa

// MARK: - NSBrowserDelegate (Columns View)

extension FileBrowserViewController: NSBrowserDelegate {
    func rootItem(for browser: NSBrowser) -> Any? {
        rootItem
    }

    func browser(_ browser: NSBrowser, numberOfChildrenOfItem item: Any?) -> Int {
        guard let fileItem = (item as? FileItem) ?? rootItem else { return 0 }
        if fileItem.needsChildLoading {
            fileItem.loadChildren(showsHiddenFiles: showsHiddenFiles)
        }
        return fileItem.children?.count ?? 0
    }

    func browser(_ browser: NSBrowser, child index: Int, ofItem item: Any?) -> Any {
        guard let fileItem = (item as? FileItem) ?? rootItem else {
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
        (item as? FileItem)?.displayName
    }

    func browser(_ browser: NSBrowser, willDisplayCell cell: Any, atRow row: Int, column: Int) {
        guard let browserCell = cell as? NSBrowserCell else { return }

        let parentItem = fileItemForColumn(column)
        guard let children = parentItem?.children, row < children.count else { return }
        let item = children[row]

        browserCell.image = item.icon
        browserCell.title = item.displayName
        browserCell.isLeaf = !item.isDirectory
    }

    func fileItemForColumn(_ column: Int) -> FileItem? {
        if column == 0 {
            return rootItem
        }

        guard let browserView = browserView else { return nil }

        let path = browserView.path(toColumn: column)
        var currentItem = rootItem

        let components = path.components(separatedBy: browserView.pathSeparator)
        for component in components.dropFirst() { // Drop root
            if let child = currentItem?.children?.first(where: { $0.displayName == component }) {
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
        notifyPaneBecameActive()
        selectionCoordinator.handleBrowserSelectionDidChange(column: column)
    }

    // MARK: - Drag and Drop for Browser View

    func browser(_ browser: NSBrowser, writeRowsWith rowIndexes: IndexSet, inColumn column: Int, to pboard: NSPasteboard) -> Bool {
        guard let parentItem = fileItemForColumn(column),
              let children = parentItem.children else { return false }

        let itemsToDrag = rowIndexes.compactMap { children[$0] }
        let urls = itemsToDrag.map { $0.url as NSURL }

        pboard.clearContents()
        return pboard.writeObjects(urls)
    }

    func browser(_ browser: NSBrowser, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        guard info.draggingPasteboard.canReadObject(forClasses: [NSURL.self]) else { return [] }

        let targetDirectoryItem: FileItem?
        if let fileItem = item as? FileItem {
            guard fileItem.isDirectory else { return [] }
            targetDirectoryItem = fileItem
        } else {
            let proposedColumn = columnIndex(atWindowPoint: info.draggingLocation, in: browser)
            guard proposedColumn >= 0 else { return [] }
            targetDirectoryItem = fileItemForColumn(proposedColumn)
        }

        guard let destinationURL = targetDirectoryItem?.url else { return [] }

        guard let draggedURLs = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return [] }
        guard isValidDestination(destinationURL, for: draggedURLs) else { return [] }
        guard let op = preferredDragOperation(from: info) else { return [] }
        return op == .copy ? .copy : .move
    }

    func browser(_ browser: NSBrowser, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }

        let targetDirectoryItem: FileItem?
        if let fileItem = item as? FileItem {
            guard fileItem.isDirectory else { return false }
            targetDirectoryItem = fileItem
        } else {
            let proposedColumn = columnIndex(atWindowPoint: info.draggingLocation, in: browser)
            guard proposedColumn >= 0 else { return false }
            targetDirectoryItem = fileItemForColumn(proposedColumn)
        }

        guard let destinationURL = targetDirectoryItem?.url else { return false }

        guard isValidDestination(destinationURL, for: urls) else { return false }
        guard let operation = preferredDragOperation(from: info) else { return false }

        performFileOperation(operation, items: urls, destination: destinationURL, sourcePane: dragSourceFileBrowser(from: info))
        return true
    }
}

// MARK: - Root Drop Handling (Background of Pane)

extension FileBrowserViewController: RootFileBrowserDropDelegate {
    func rootViewPreferredOperation(for info: NSDraggingInfo) -> NSDragOperation {
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return [] }
        guard isValidDestination(currentDirectory, for: urls) else { return [] }
        guard let op = preferredDragOperation(from: info) else { return [] }
        return op == .copy ? .copy : .move
    }

    func rootViewPerformDrop(urls: [URL], operation: FileOperationType, info: NSDraggingInfo) {
        performFileOperation(operation, items: urls, destination: currentDirectory, sourcePane: dragSourceFileBrowser(from: info))
    }
}
