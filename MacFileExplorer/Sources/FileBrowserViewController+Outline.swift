import Cocoa

// MARK: - NSOutlineViewDataSource / NSOutlineViewDelegate

extension FileBrowserViewController {
    func notifyPaneBecameActive() {
        delegate?.fileBrowserDidBecomeActive(self)
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        let fileItem = item as? FileItem ?? rootItem
        if fileItem?.needsChildLoading == true {
            fileItem?.loadChildren(showsHiddenFiles: showsHiddenFiles)
        }
        return fileItem?.children?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? FileItem)?.isDirectory ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let fileItem = item as? FileItem ?? rootItem
        if fileItem?.needsChildLoading == true {
            fileItem?.loadChildren(showsHiddenFiles: showsHiddenFiles)
        }
        return fileItem?.children?[index] as Any
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let fileItem = item as? FileItem, let tableColumn else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("Cell_\(tableColumn.identifier.rawValue)")
        let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? {
            let view = NSTableCellView()
            view.identifier = identifier
            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyDown
            imageView.setContentHuggingPriority(.required, for: .horizontal)
            view.addSubview(imageView)
            view.imageView = imageView
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(textField)
            view.textField = textField
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
                imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),

                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
                textField.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
                textField.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -2)
            ])
            return view
        }()

        let value: String
        switch tableColumn.identifier.rawValue {
        case "NameColumn":
            value = fileItem.displayName
            cell.imageView?.image = fileItem.icon
        case "DateModifiedColumn":
            value = fileItem.modificationDate.map { shortDateFormatter.string(from: $0) } ?? ""
        case "TypeColumn":
            value = fileItem.kind
        case "SizeColumn":
            value = ByteCountFormatter.string(fromByteCount: fileItem.size, countStyle: .file)
        case "DateCreatedColumn":
            value = fileItem.creationDate.map { shortDateFormatter.string(from: $0) } ?? ""
        case "TagsColumn":
            value = fileItem.tags.joined(separator: ", ")
        default:
            value = fileItem.displayName
        }

        cell.textField?.stringValue = value
        cell.setAccessibilityElement(true)
        cell.setAccessibilityRole(.row)
        if let columnTitle = tableColumn.title as String? {
            cell.setAccessibilityLabel("\(fileItem.displayName), \(columnTitle): \(value)")
        } else {
            cell.setAccessibilityLabel(fileItem.displayName)
        }
        cell.textField?.setAccessibilityLabel(value)
        cell.textField?.setAccessibilityRole(.staticText)
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        notifyPaneBecameActive()
        updateStatusBarForOutline()
        if let item = outlineView.item(atRow: outlineView.selectedRow) as? FileItem {
            updatePreviewPane(with: item)
            delegate?.fileBrowser(self, didSelectFile: item)
        } else {
            updatePreviewPane(with: nil)
            delegate?.fileBrowser(self, didSelectFile: nil)
        }
    }
    
    // MARK: - Row Height (macOS 15+ Compatibility)
    
    /// Provides row height for outline view.
    /// Replaces deprecated `outlineView.rowHeight` property which crashes on macOS 15+.
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        return 22.0
    }
}

// MARK: - NSOutlineView Drag & Drop

extension FileBrowserViewController {
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return [] }
        let destinationURL: URL
        if let fileItem = item as? FileItem {
            destinationURL = fileItem.isDirectory ? fileItem.url : currentDirectory
        } else {
            destinationURL = currentDirectory
        }
        guard isValidDestination(destinationURL, for: urls) else { return [] }
        guard let op = preferredDragOperation(from: info) else { return [] }
        return op == .copy ? .copy : .move
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return false }
        let destinationURL: URL
        if let fileItem = item as? FileItem {
            destinationURL = fileItem.isDirectory ? fileItem.url : currentDirectory
        } else {
            destinationURL = currentDirectory
        }
        guard isValidDestination(destinationURL, for: urls) else { return false }
        guard let op = preferredDragOperation(from: info) else { return false }
        performFileOperation(op, items: urls, destination: destinationURL, sourcePane: dragSourceFileBrowser(from: info))
        return true
    }
}
