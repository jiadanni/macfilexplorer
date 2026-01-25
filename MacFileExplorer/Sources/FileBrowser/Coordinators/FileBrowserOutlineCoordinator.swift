import Cocoa

protocol FileBrowserOutlineCoordinatorDelegate: AnyObject {
    var rootItem: FileItem? { get }
    var showsHiddenFiles: Bool { get }
    var shortDateFormatter: DateFormatter { get }
    func fileBrowserDidBecomeActive()
    func didSelectFile(_ item: FileItem?)
}

final class FileBrowserOutlineCoordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    weak var delegate: FileBrowserOutlineCoordinatorDelegate?
    weak var selectionCoordinator: FileBrowserSelectionCoordinator?
    weak var dragDropHandler: FileBrowserDragDropHandler?
    
    // MARK: - NSOutlineViewDataSource
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        let fileItem = item as? FileItem ?? delegate?.rootItem
        if fileItem?.needsChildLoading == true {
            fileItem?.loadChildren(showsHiddenFiles: delegate?.showsHiddenFiles ?? false)
        }
        return fileItem?.children?.count ?? 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? FileItem)?.isDirectory ?? false
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let fileItem = item as? FileItem ?? delegate?.rootItem
        if fileItem?.needsChildLoading == true {
            fileItem?.loadChildren(showsHiddenFiles: delegate?.showsHiddenFiles ?? false)
        }
        if let child = fileItem?.children?.safe(at: index) {
            return child as Any
        }
        return fileItem as Any
    }
    
    // MARK: - NSOutlineViewDelegate
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let fileItem = item as? FileItem, let tableColumn else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("Cell_\(tableColumn.identifier.rawValue)")
        let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? createCell(withIdentifier: identifier)
        
        let value: String
        let showExtensions = SettingsStore.shared.showFileExtensions
        let useGrayscale = SettingsStore.shared.useGrayscaleIcons
        let dateFormatter = delegate?.shortDateFormatter ?? DateFormatter()
        
        switch tableColumn.identifier.rawValue {
        case AppConfig.ColumnID.name:
            value = fileItem.displayName(showExtensions: showExtensions)
            cell.imageView?.image = fileItem.icon(useGrayscale: useGrayscale)
        case AppConfig.ColumnID.dateModified:
            value = fileItem.modificationDate.map { dateFormatter.string(from: $0) } ?? ""
        case AppConfig.ColumnID.type:
            value = fileItem.kind
        case AppConfig.ColumnID.size:
            value = ByteCountFormatter.string(fromByteCount: fileItem.size, countStyle: .file)
        case AppConfig.ColumnID.dateCreated:
            value = fileItem.creationDate.map { dateFormatter.string(from: $0) } ?? ""
        case "TagsColumn":
            value = fileItem.tags.joined(separator: ", ")
        default:
            value = fileItem.displayName(showExtensions: showExtensions)
        }
        
        cell.textField?.stringValue = value
        cell.setAccessibilityElement(true)
        cell.setAccessibilityRole(.row)
        if let columnTitle = tableColumn.title as String? {
            cell.setAccessibilityLabel("\(fileItem.displayName(showExtensions: showExtensions)), \(columnTitle): \(value)")
        } else {
            cell.setAccessibilityLabel(fileItem.displayName(showExtensions: showExtensions))
        }
        cell.textField?.setAccessibilityLabel(value)
        cell.textField?.setAccessibilityRole(.staticText)
        return cell
    }
    
    private func createCell(withIdentifier identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
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
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        delegate?.fileBrowserDidBecomeActive()
        let selectedItem = selectionCoordinator?.handleOutlineSelectionDidChange()
        delegate?.didSelectFile(selectedItem)
    }
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        return 22.0
    }
    
    // MARK: - NSOutlineView Drag & Drop
    
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        return dragDropHandler?.validateDrop(info, proposedTarget: item as? FileItem) ?? []
    }
    
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        return dragDropHandler?.acceptDrop(info, target: item as? FileItem) ?? false
    }
}
