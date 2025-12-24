import Cocoa

// MARK: - NSCollectionViewDataSource / NSCollectionViewDelegate

extension FileBrowserViewController: NSCollectionViewDataSource {
    // Ensure we always have a loaded (and optionally sorted/filtered) children list for collection-based views.
    // Ensure we always have a loaded (and optionally sorted/filtered) children list for collection-based views.
    private func collectionItems() -> [FileItem] {
        // DataSource manages data loading and filtering. We just display what's ready.
        return rootItem?.children ?? []
    }

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        collectionItems().count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = FileIconItem()
        let items = collectionItems()
        if let fileItem = items.safe(at: indexPath.item) {
            item.fileItem = fileItem
        }
        item.isListMode = (currentViewMode == .windowsList)
        item.zoomLevel = zoomLevel
        item.showCheckbox = SettingsStore.shared.enableEasySelect
        return item
    }
}

extension FileBrowserViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        notifyPaneBecameActive()
        selectionCoordinator.handleCollectionSelectionDidChange()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        notifyPaneBecameActive()
        selectionCoordinator.handleCollectionSelectionDidChange()
    }


    // MARK: - Drag and Drop for CollectionView

    func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        true
    }

    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        let items = collectionItems()
        guard let item = items.safe(at: indexPath.item) else { return nil }
        return item.url as NSURL
    }

    func collectionView(_ collectionView: NSCollectionView, validateDrop draggingInfo: NSDraggingInfo, proposedIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>, dropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        guard let urls = draggingInfo.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return [] }

        let items = collectionItems()
        let destinationURL: URL
        if dropOperation.pointee == .on {
            guard let item = items.safe(at: proposedIndexPath.pointee.item) else { return [] }
            guard item.isDirectory else { return [] }
            destinationURL = item.url
        } else {
            destinationURL = currentDirectory
        }

        guard isValidDestination(destinationURL, for: urls) else { return [] }
        guard let op = preferredDragOperation(from: draggingInfo) else { return [] }
        return op == .copy ? .copy : .move
    }

    func collectionView(_ collectionView: NSCollectionView, acceptDrop draggingInfo: NSDraggingInfo, indexPath: IndexPath, dropOperation: NSCollectionView.DropOperation) -> Bool {
        guard let urls = draggingInfo.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return false }
        let items = collectionItems()

        let destinationURL: URL
        if dropOperation == .on {
            guard let item = items.safe(at: indexPath.item) else { return false }
            guard item.isDirectory else { return false }
            destinationURL = item.url
        } else {
            destinationURL = currentDirectory
        }

        guard isValidDestination(destinationURL, for: urls) else { return false }
        guard let op = preferredDragOperation(from: draggingInfo) else { return false }
        performFileOperation(op, items: urls, destination: destinationURL, sourcePane: dragSourceFileBrowser(from: draggingInfo))
        return true
    }
}
