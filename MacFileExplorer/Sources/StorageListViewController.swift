//
//  StorageListViewController.swift
//  MacFileExplorer
//
//  List view for storage analyzer with sortable table
//

import Cocoa

protocol StorageListViewDelegate: AnyObject {
    func listViewDidSelectItem(_ item: StorageItem)
    func listViewDidDoubleClickItem(_ item: StorageItem)
    func listViewDidRequestAction(_ action: StorageAction, items: [StorageItem])
}

enum StorageAction {
    case open
    case quickLook
    case showInMainViewer
    case moveToTrash
    case revealInFinder
    case copyPath
}

class StorageListViewController: NSViewController {
    // MARK: - Properties

    weak var delegate: StorageListViewDelegate?

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var breadcrumbBar: NSView!
    private var breadcrumbLabel: NSTextField!

    private var currentItem: StorageItem?
    private var displayedItems: [StorageItem] = []
    private var filteredItems: [StorageItem] = []

    private var searchText: String = "" {
        didSet {
            applyFilter()
        }
    }

    private var sortColumn: String = "size"
    private var sortAscending: Bool = false

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Breadcrumb bar
        setupBreadcrumbBar()

        // Table view
        setupTableView()

        // Layout
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        breadcrumbBar.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            breadcrumbBar.topAnchor.constraint(equalTo: view.topAnchor),
            breadcrumbBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            breadcrumbBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            breadcrumbBar.heightAnchor.constraint(equalToConstant: 30),

            scrollView.topAnchor.constraint(equalTo: breadcrumbBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupBreadcrumbBar() {
        breadcrumbBar = NSView()
        breadcrumbBar.wantsLayer = true
        breadcrumbBar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        breadcrumbLabel = NSTextField(labelWithString: "/")
        breadcrumbLabel.font = NSFont.systemFont(ofSize: 11)
        breadcrumbLabel.textColor = .secondaryLabelColor
        breadcrumbLabel.lineBreakMode = .byTruncatingMiddle
        breadcrumbLabel.translatesAutoresizingMaskIntoConstraints = false

        breadcrumbBar.addSubview(breadcrumbLabel)

        NSLayoutConstraint.activate([
            breadcrumbLabel.leadingAnchor.constraint(equalTo: breadcrumbBar.leadingAnchor, constant: 8),
            breadcrumbLabel.trailingAnchor.constraint(equalTo: breadcrumbBar.trailingAnchor, constant: -8),
            breadcrumbLabel.centerYAnchor.constraint(equalTo: breadcrumbBar.centerYAnchor)
        ])

        view.addSubview(breadcrumbBar)
    }

    private func setupTableView() {
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        tableView = NSTableView()
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.allowsColumnReordering = true
        tableView.allowsColumnResizing = true
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClicked(_:))

        // Setup columns
        addColumn(identifier: "name", title: "Name", width: 250)
        addColumn(identifier: "size", title: "Size", width: 100)
        addColumn(identifier: "percentage", title: "%", width: 60)
        addColumn(identifier: "items", title: "Items", width: 80)
        addColumn(identifier: "modified", title: "Modified", width: 120)
        addColumn(identifier: "type", title: "Type", width: 100)

        scrollView.documentView = tableView

        view.addSubview(scrollView)

        // Setup menu
        let menu = NSMenu()
        menu.delegate = self
        tableView.menu = menu
    }

    private func addColumn(identifier: String, title: String, width: CGFloat) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.width = width
        column.minWidth = 50

        let sortDescriptor = NSSortDescriptor(key: identifier, ascending: true)
        column.sortDescriptorPrototype = sortDescriptor

        tableView.addTableColumn(column)
    }

    // MARK: - Public Methods

    func setRootItem(_ item: StorageItem) {
        currentItem = item
        displayedItems = item.children
        applyFilter()
        updateBreadcrumb()
    }

    func drillDown(to item: StorageItem) {
        guard item.isDirectory else { return }
        currentItem = item
        displayedItems = item.children
        applyFilter()
        updateBreadcrumb()
    }

    func drillUp() {
        guard let parent = currentItem?.parent else { return }
        drillDown(to: parent)
    }

    func setSearchText(_ text: String) {
        searchText = text
    }

    func selectedItems() -> [StorageItem] {
        let indexes = tableView.selectedRowIndexes
        return indexes.compactMap { filteredItems[safe: $0] }
    }

    // MARK: - Private Methods

    private func applyFilter() {
        if searchText.isEmpty {
            filteredItems = displayedItems
        } else {
            filteredItems = displayedItems.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        applySorting()
        tableView.reloadData()
    }

    private func applySorting() {
        filteredItems.sort { lhs, rhs in
            let result: Bool

            switch sortColumn {
            case "name":
                result = lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case "size":
                result = lhs.totalSize < rhs.totalSize
            case "percentage":
                result = lhs.percentage < rhs.percentage
            case "items":
                result = lhs.fileCount < rhs.fileCount
            case "modified":
                let lhsDate = lhs.modificationDate ?? Date.distantPast
                let rhsDate = rhs.modificationDate ?? Date.distantPast
                result = lhsDate < rhsDate
            case "type":
                result = lhs.category.rawValue.localizedCaseInsensitiveCompare(rhs.category.rawValue) == .orderedAscending
            default:
                result = false
            }

            return sortAscending ? result : !result
        }
    }

    private func updateBreadcrumb() {
        guard let current = currentItem else {
            breadcrumbLabel.stringValue = "/"
            return
        }

        var path = current.name
        var item = current

        while let parent = item.parent {
            path = "\(parent.name) / \(path)"
            item = parent
        }

        breadcrumbLabel.stringValue = path
    }

    @objc private func tableViewDoubleClicked(_ sender: Any) {
        let row = tableView.clickedRow
        guard row >= 0, row < filteredItems.count else { return }

        let item = filteredItems[row]

        if item.isDirectory {
            drillDown(to: item)
        }

        delegate?.listViewDidDoubleClickItem(item)
    }

    // MARK: - Context Menu Actions

    @objc private func openAction(_ sender: Any) {
        let items = selectedItems()
        delegate?.listViewDidRequestAction(.open, items: items)
    }

    @objc private func quickLookAction(_ sender: Any) {
        let items = selectedItems()
        delegate?.listViewDidRequestAction(.quickLook, items: items)
    }

    @objc private func showInMainViewerAction(_ sender: Any) {
        let items = selectedItems()
        delegate?.listViewDidRequestAction(.showInMainViewer, items: items)
    }

    @objc private func moveToTrashAction(_ sender: Any) {
        let items = selectedItems()
        delegate?.listViewDidRequestAction(.moveToTrash, items: items)
    }

    @objc private func revealInFinderAction(_ sender: Any) {
        let items = selectedItems()
        delegate?.listViewDidRequestAction(.revealInFinder, items: items)
    }

    @objc private func copyPathAction(_ sender: Any) {
        let items = selectedItems()
        delegate?.listViewDidRequestAction(.copyPath, items: items)
    }
}

// MARK: - NSTableViewDataSource
extension StorageListViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredItems.count
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else { return }

        sortColumn = sortDescriptor.key ?? "size"
        sortAscending = sortDescriptor.ascending

        applySorting()
        tableView.reloadData()
    }
}

// MARK: - NSTableViewDelegate
extension StorageListViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredItems.count else { return nil }

        let item = filteredItems[row]
        let identifier = tableColumn?.identifier.rawValue ?? ""

        let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("Cell"), owner: self) as? NSTableCellView
            ?? NSTableCellView()

        cellView.identifier = NSUserInterfaceItemIdentifier("Cell")

        if cellView.textField == nil {
            let textField = NSTextField()
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = false
            textField.isSelectable = false
            textField.translatesAutoresizingMaskIntoConstraints = false

            cellView.addSubview(textField)
            cellView.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 2),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -2),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
        }

        switch identifier {
        case "name":
            cellView.textField?.stringValue = item.name
            cellView.imageView?.image = item.isDirectory ? NSImage(systemSymbolName: "folder", accessibilityDescription: nil) : NSImage(systemSymbolName: "doc", accessibilityDescription: nil)
        case "size":
            cellView.textField?.stringValue = item.formattedSize
        case "percentage":
            cellView.textField?.stringValue = item.formattedPercentage
        case "items":
            cellView.textField?.stringValue = item.isDirectory ? "\(item.fileCount) files" : "-"
        case "modified":
            if let date = item.modificationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                cellView.textField?.stringValue = formatter.string(from: date)
            } else {
                cellView.textField?.stringValue = "-"
            }
        case "type":
            cellView.textField?.stringValue = item.category.rawValue
        default:
            cellView.textField?.stringValue = ""
        }

        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let item = selectedItems().first else { return }
        delegate?.listViewDidSelectItem(item)
    }
}

// MARK: - NSMenuDelegate
extension StorageListViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        guard !selectedItems().isEmpty else { return }

        menu.addItem(withTitle: "Open", action: #selector(openAction(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Quick Look", action: #selector(quickLookAction(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Show in Main Viewer", action: #selector(showInMainViewerAction(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Reveal in Finder", action: #selector(revealInFinderAction(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Copy Path", action: #selector(copyPathAction(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Move to Trash", action: #selector(moveToTrashAction(_:)), keyEquivalent: "")
    }
}

// MARK: - Array Safe Subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
