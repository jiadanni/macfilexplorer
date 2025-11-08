import Cocoa

class FileBrowserViewController: NSViewController {

    weak var delegate: FileBrowserDelegate?

    private var scrollView: NSScrollView!
    private var outlineView: NSOutlineView!
    private var currentDirectory: URL
    private var rootItem: FileItem!
    private var fileSystemMonitor: FileSystemMonitor?
    private var selectedItems: Set<FileItem> = []

    var currentPath: String {
        return currentDirectory.path
    }

    init() {
        // Start at user's home directory
        self.currentDirectory = FileManager.default.homeDirectoryForCurrentUser
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.currentDirectory = FileManager.default.homeDirectoryForCurrentUser
        super.init(coder: coder)
    }

    override func loadView() {
        view = NSView()
        setupUI()
        loadDirectory(currentDirectory)
    }

    private func setupUI() {
        // Create scroll view
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        view.addSubview(scrollView)

        // Create outline view (like Finder's list view)
        outlineView = NSOutlineView()
        outlineView.style = .sourceList
        outlineView.floatsGroupRows = false
        outlineView.rowSizeStyle = .default
        outlineView.headerView = nil
        outlineView.allowsMultipleSelection = true
        outlineView.autoresizesOutlineColumn = false
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.doubleAction = #selector(outlineViewDoubleClicked(_:))
        outlineView.target = self

        // Create columns
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("NameColumn"))
        nameColumn.title = "Name"
        nameColumn.width = 300
        nameColumn.minWidth = 100
        outlineView.addTableColumn(nameColumn)
        outlineView.outlineTableColumn = nameColumn

        let sizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SizeColumn"))
        sizeColumn.title = "Size"
        sizeColumn.width = 100
        sizeColumn.minWidth = 60
        outlineView.addTableColumn(sizeColumn)

        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("DateColumn"))
        dateColumn.title = "Date Modified"
        dateColumn.width = 150
        dateColumn.minWidth = 100
        outlineView.addTableColumn(dateColumn)

        scrollView.documentView = outlineView

        // Set up constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Apply Finder-like styling
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    private func loadDirectory(_ url: URL) {
        currentDirectory = url
        rootItem = FileItem(url: url)
        rootItem.loadChildren()

        outlineView.reloadData()
        outlineView.expandItem(nil, expandChildren: true)

        // Set up file system monitoring
        fileSystemMonitor = FileSystemMonitor(url: url) { [weak self] in
            DispatchQueue.main.async {
                self?.refreshCurrentDirectory()
            }
        }

        delegate?.directoryDidChange(to: url.path)
    }

    private func refreshCurrentDirectory() {
        rootItem.loadChildren()
        outlineView.reloadData()
    }

    @objc private func outlineViewDoubleClicked(_ sender: Any) {
        let clickedRow = outlineView.clickedRow
        guard clickedRow >= 0 else { return }

        if let item = outlineView.item(atRow: clickedRow) as? FileItem {
            if item.isDirectory {
                loadDirectory(item.url)
            } else {
                // Open file with default application
                NSWorkspace.shared.open(item.url)
            }
        }
    }

    // MARK: - Public Methods

    func showBulkColorPicker() {
        // Get selected items
        var itemsToColor: [FileItem] = []
        let selectedRows = outlineView.selectedRowIndexes

        selectedRows.forEach { row in
            if let item = outlineView.item(atRow: row) as? FileItem, item.isDirectory {
                itemsToColor.append(item)
            }
        }

        guard !itemsToColor.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No Folders Selected"
            alert.informativeText = "Please select one or more folders to change their colors."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        // Show color picker
        let colorPanel = NSColorPanel.shared
        colorPanel.showsAlpha = false
        colorPanel.orderFront(nil)
        colorPanel.isContinuous = false

        // Store selected items for color application
        selectedItems = Set(itemsToColor)

        // Set up notification observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(colorPanelClosed(_:)),
            name: NSWindow.willCloseNotification,
            object: colorPanel
        )
    }

    @objc private func colorPanelClosed(_ notification: Notification) {
        guard let colorPanel = notification.object as? NSColorPanel else { return }

        let selectedColor = colorPanel.color

        // Apply color to all selected folders
        selectedItems.forEach { item in
            ColorManager.shared.setColor(selectedColor, for: item.url)
        }

        selectedItems.removeAll()
        outlineView.reloadData()

        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: colorPanel)
    }

    func goBack() {
        let parentURL = currentDirectory.deletingLastPathComponent()
        if parentURL != currentDirectory {
            loadDirectory(parentURL)
        }
    }

    func goForward(to url: URL) {
        loadDirectory(url)
    }
}

// MARK: - NSOutlineViewDataSource

extension FileBrowserViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return rootItem.children?.count ?? 0
        }
        guard let fileItem = item as? FileItem else { return 0 }
        return fileItem.children?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return rootItem.children?[index] ?? FileItem(url: currentDirectory)
        }
        guard let fileItem = item as? FileItem else {
            return FileItem(url: currentDirectory)
        }
        return fileItem.children?[index] ?? FileItem(url: currentDirectory)
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let fileItem = item as? FileItem else { return false }
        return fileItem.isDirectory && (fileItem.children?.count ?? 0) > 0
    }
}

// MARK: - NSOutlineViewDelegate

extension FileBrowserViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let fileItem = item as? FileItem else { return nil }

        let identifier = tableColumn?.identifier.rawValue ?? ""

        if identifier == "NameColumn" {
            let cellView = NSTableCellView()
            let textField = NSTextField()
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = false
            textField.stringValue = fileItem.name

            let imageView = NSImageView()
            imageView.image = fileItem.icon
            imageView.imageScaling = .scaleProportionallyDown

            // Apply custom folder color if set
            if fileItem.isDirectory, let customColor = ColorManager.shared.getColor(for: fileItem.url) {
                imageView.contentTintColor = customColor
            }

            cellView.addSubview(imageView)
            cellView.addSubview(textField)

            imageView.translatesAutoresizingMaskIntoConstraints = false
            textField.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),

                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4)
            ])

            cellView.imageView = imageView
            cellView.textField = textField

            return cellView
        } else if identifier == "SizeColumn" {
            let cellView = NSTableCellView()
            let textField = NSTextField()
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = false
            textField.stringValue = fileItem.formattedSize

            cellView.addSubview(textField)
            textField.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4)
            ])

            cellView.textField = textField
            return cellView
        } else if identifier == "DateColumn" {
            let cellView = NSTableCellView()
            let textField = NSTextField()
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = false
            textField.stringValue = fileItem.formattedDate

            cellView.addSubview(textField)
            textField.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4)
            ])

            cellView.textField = textField
            return cellView
        }

        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        return 20
    }
}
