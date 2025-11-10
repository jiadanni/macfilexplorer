import Cocoa

class FileBrowserViewController: NSViewController {

    weak var delegate: FileBrowserDelegate?

    private var toolbarViewController: ToolbarViewController!
    private var containerView: NSView! // New container view
    private var scrollView: NSScrollView! // For outlineView
    private var outlineView: NSOutlineView!
    private var collectionView: NSCollectionView! // For icons view
    private var currentDirectory: URL
    private var rootItem: FileItem!
    private var fileSystemMonitor: FileSystemMonitor?
    private var selectedItems: Set<FileItem> = []
    private var cutItems: [FileItem]?
    private var currentViewMode: ViewMode = .details // Default view mode

    // Navigation history
    private var navigationHistory: [URL] = []
    private var currentHistoryIndex: Int = -1
    private var showsHiddenFiles: Bool = false

    // Sorting state
    private var sortColumn: String = "NameColumn"
    private var sortAscending: Bool = true

    var currentPath: String {
        return currentDirectory.path
    }

    init() {
        // Start at /Applications to avoid triggering permission prompts
        self.currentDirectory = URL(fileURLWithPath: "/Applications")
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        // Start at /Applications to avoid triggering permission prompts
        self.currentDirectory = URL(fileURLWithPath: "/Applications")
        super.init(coder: coder)
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        setupUI()
        loadDirectory(currentDirectory)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(outlineView) // Make outlineView the first responder
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "x" {
            cutSelection()
        } else {
            super.keyDown(with: event)
        }
    }

    private func setupUI() {
        // Create toolbar
        toolbarViewController = ToolbarViewController()
        toolbarViewController.delegate = self
        addChild(toolbarViewController)
        view.addSubview(toolbarViewController.view)
        toolbarViewController.view.translatesAutoresizingMaskIntoConstraints = false

        // Create container view for file display
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Create scroll view for outline view
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        // scrollView will be added to containerView later

        // Create outline view (Windows Explorer list view style)
        outlineView = NSOutlineView()
        outlineView.style = .fullWidth  // More Windows Explorer-like
        outlineView.floatsGroupRows = false
        outlineView.rowSizeStyle = .default
        outlineView.usesAlternatingRowBackgroundColors = true  // Like Windows Explorer
        outlineView.allowsMultipleSelection = true
        outlineView.autoresizesOutlineColumn = false
        outlineView.doubleAction = #selector(outlineViewDoubleClicked(_:))
        outlineView.target = self
        outlineView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        // Create and configure header view
        let headerView = NSTableHeaderView()
        outlineView.headerView = headerView

        // Create columns - Windows Explorer style
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("NameColumn"))
        nameColumn.title = "Name"
        nameColumn.width = 250
        nameColumn.minWidth = 100
        nameColumn.maxWidth = 500
        nameColumn.resizingMask = .userResizingMask
        let nameDescriptor = NSSortDescriptor(key: "name", ascending: true)
        nameColumn.sortDescriptorPrototype = nameDescriptor
        outlineView.addTableColumn(nameColumn)
        outlineView.outlineTableColumn = nameColumn

        let dateModifiedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("DateModifiedColumn"))
        dateModifiedColumn.title = "Date Modified"
        dateModifiedColumn.width = 150
        dateModifiedColumn.minWidth = 100
        dateModifiedColumn.maxWidth = 250
        dateModifiedColumn.resizingMask = .userResizingMask
        let dateModifiedDescriptor = NSSortDescriptor(key: "modificationDate", ascending: false)
        dateModifiedColumn.sortDescriptorPrototype = dateModifiedDescriptor
        outlineView.addTableColumn(dateModifiedColumn)

        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TypeColumn"))
        typeColumn.title = "Type"
        typeColumn.width = 120
        typeColumn.minWidth = 80
        typeColumn.maxWidth = 200
        typeColumn.resizingMask = .userResizingMask
        let typeDescriptor = NSSortDescriptor(key: "kind", ascending: true)
        typeColumn.sortDescriptorPrototype = typeDescriptor
        outlineView.addTableColumn(typeColumn)

        let sizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SizeColumn"))
        sizeColumn.title = "Size"
        sizeColumn.width = 100
        sizeColumn.minWidth = 60
        sizeColumn.maxWidth = 150
        sizeColumn.resizingMask = .userResizingMask
        let sizeDescriptor = NSSortDescriptor(key: "size", ascending: false)
        sizeColumn.sortDescriptorPrototype = sizeDescriptor
        outlineView.addTableColumn(sizeColumn)

        let dateCreatedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("DateCreatedColumn"))
        dateCreatedColumn.title = "Date Created"
        dateCreatedColumn.width = 150
        dateCreatedColumn.minWidth = 100
        dateCreatedColumn.maxWidth = 250
        dateCreatedColumn.resizingMask = .userResizingMask
        let dateCreatedDescriptor = NSSortDescriptor(key: "creationDate", ascending: false)
        dateCreatedColumn.sortDescriptorPrototype = dateCreatedDescriptor
        outlineView.addTableColumn(dateCreatedColumn)

        scrollView.documentView = outlineView

        // Set up context menu
        outlineView.menu = createContextMenu()

        // Set up constraints
        NSLayoutConstraint.activate([
            toolbarViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            toolbarViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbarViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbarViewController.view.heightAnchor.constraint(equalToConstant: 40),

            containerView.topAnchor.constraint(equalTo: toolbarViewController.view.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Apply Windows Explorer-like styling
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Set initial view mode
        displayFiles(for: currentViewMode)
    }

    private func displayFiles(for viewMode: ViewMode) {
        // Remove all subviews from the container
        containerView.subviews.forEach { $0.removeFromSuperview() }

        switch viewMode {
        case .list, .details:
            // Use outlineView for list and details
            containerView.addSubview(scrollView)
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            outlineView.reloadData()
            view.window?.makeFirstResponder(outlineView)
        case .icons:
            if collectionView == nil {
                setupCollectionView()
            }
            containerView.addSubview(collectionView)
            NSLayoutConstraint.activate([
                collectionView.topAnchor.constraint(equalTo: containerView.topAnchor),
                collectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                collectionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                collectionView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            collectionView.reloadData()
            view.window?.makeFirstResponder(collectionView)
        case .columns:
            // Placeholder for columns view
            let label = NSTextField(labelWithString: "Columns View - Not Implemented Yet")
            label.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
            ])
        }
    }

    private func setupCollectionView() {
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: 100, height: 120) // Adjust as needed
        flowLayout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        flowLayout.minimumLineSpacing = 10
        flowLayout.minimumInteritemSpacing = 10

        collectionView = NSCollectionView()
        collectionView.collectionViewLayout = flowLayout
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true
        collectionView.backgroundColors = [.clear]
        collectionView.delegate = self
        collectionView.dataSource = self

        // Register item prototype
        collectionView.register(FileIconItem.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("FileIconItem"))
    }

    private func loadDirectory(_ url: URL, addToHistory: Bool = true) {
        currentDirectory = url

        // Update navigation history
        if addToHistory {
            // Remove any forward history
            if currentHistoryIndex < navigationHistory.count - 1 {
                navigationHistory.removeSubrange((currentHistoryIndex + 1)...)
            }
            navigationHistory.append(url)
            currentHistoryIndex = navigationHistory.count - 1
        }

        // Update toolbar
        let canGoBack = currentHistoryIndex > 0
        let canGoForward = currentHistoryIndex < navigationHistory.count - 1
        toolbarViewController?.updatePath(url, canGoBack: canGoBack, canGoForward: canGoForward, history: navigationHistory, currentIndex: currentHistoryIndex)

        // Set delegate and dataSource if not already set
        if outlineView.delegate == nil {
            outlineView.delegate = self
            outlineView.dataSource = self
        }

        // Load directory contents on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let item = FileItem(url: url)
            item.loadChildren(showsHiddenFiles: self.showsHiddenFiles)

            DispatchQueue.main.async {
                self.rootItem = item
                self.sortItems()
                self.outlineView.reloadData()
                if self.currentViewMode == .icons {
                    self.collectionView.reloadData()
                }
                self.outlineView.expandItem(nil, expandChildren: true)

                // Clear any cut items when changing directory
                self.cutItems?.forEach { $0.isCut = false }
                self.cutItems = nil

                // Set up file system monitoring
                self.fileSystemMonitor = FileSystemMonitor(url: url) { [weak self] in
                    DispatchQueue.main.async {
                        self?.refreshCurrentDirectory()
                    }
                }

                self.delegate?.directoryDidChange(to: url.path)
            }
        }
    }

    private func refreshCurrentDirectory() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            self.rootItem.loadChildren(showsHiddenFiles: self.showsHiddenFiles)

            DispatchQueue.main.async {
                self.sortItems()
                self.outlineView.reloadData()
                if self.currentViewMode == .icons {
                    self.collectionView.reloadData()
                }
            }
        }
    }

    private func sortItems() {
        guard let rootItem = rootItem, var items = rootItem.children else { return }

        switch sortColumn {
        case "NameColumn":
            items.sort { item1, item2 in
                if sortAscending {
                    return item1.name.localizedStandardCompare(item2.name) == .orderedAscending
                } else {
                    return item1.name.localizedStandardCompare(item2.name) == .orderedDescending
                }
            }
        case "SizeColumn":
            items.sort { item1, item2 in
                // Directories always first, then by size
                if item1.isDirectory != item2.isDirectory {
                    return item1.isDirectory
                }
                return sortAscending ? item1.size < item2.size : item1.size > item2.size
            }
        case "DateModifiedColumn":
            items.sort { item1, item2 in
                guard let date1 = item1.modificationDate, let date2 = item2.modificationDate else {
                    return false
                }
                return sortAscending ? date1 < date2 : date1 > date2
            }
        case "DateCreatedColumn":
            items.sort { item1, item2 in
                guard let date1 = item1.creationDate, let date2 = item2.creationDate else {
                    return false
                }
                return sortAscending ? date1 < date2 : date1 > date2
            }
        case "TypeColumn":
            items.sort { item1, item2 in
                if sortAscending {
                    return item1.kind.localizedStandardCompare(item2.kind) == .orderedAscending
                } else {
                    return item1.kind.localizedStandardCompare(item2.kind) == .orderedDescending
                }
            }
        default:
            break
        }

        rootItem.children = items

        // Sort children recursively
        items.forEach { item in
            if item.isDirectory, var children = item.children {
                sortChildren(&children)
                item.children = children
            }
        }
    }

    private func sortChildren(_ children: inout [FileItem]) {
        switch sortColumn {
        case "NameColumn":
            children.sort { item1, item2 in
                if sortAscending {
                    return item1.name.localizedStandardCompare(item2.name) == .orderedAscending
                } else {
                    return item1.name.localizedStandardCompare(item2.name) == .orderedDescending
                }
            }
        case "SizeColumn":
            children.sort { item1, item2 in
                if item1.isDirectory != item2.isDirectory {
                    return item1.isDirectory
                }
                return sortAscending ? item1.size < item2.size : item1.size > item2.size
            }
        case "DateModifiedColumn":
            children.sort { item1, item2 in
                guard let date1 = item1.modificationDate, let date2 = item2.modificationDate else {
                    return false
                }
                return sortAscending ? date1 < date2 : date1 > date2
            }
        case "DateCreatedColumn":
            children.sort { item1, item2 in
                guard let date1 = item1.creationDate, let date2 = item2.creationDate else {
                    return false
                }
                return sortAscending ? date1 < date2 : date1 > date2
            }
        case "TypeColumn":
            children.sort { item1, item2 in
                if sortAscending {
                    return item1.kind.localizedStandardCompare(item2.kind) == .orderedAscending
                } else {
                    return item1.kind.localizedStandardCompare(item2.kind) == .orderedDescending
                }
            }
        default:
            break
        }
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

        // Get unique folder names
        let folderNames = Set(itemsToColor.map { $0.name })

        // Show informative alert about global color application
        let alert = NSAlert()
        alert.messageText = "Change Folder Color"
        if folderNames.count == 1 {
            alert.informativeText = "The color will be applied globally to all folders named \"\(folderNames.first!)\"."
        } else {
            alert.informativeText = "The color will be applied globally to all folders with these names:\n\n" + folderNames.sorted().joined(separator: "\n")
        }
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

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

        // Apply color globally to all folders with these names
        let folderNames = Set(selectedItems.map { $0.name })
        folderNames.forEach { folderName in
            ColorManager.shared.setColor(selectedColor, forFolderName: folderName)
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

    func navigateToURL(_ url: URL) {
        loadDirectory(url)
    }

    // MARK: - Public Actions

    func cutSelection() {
        contextMenuCut(self)
    }

    func copySelection() {
        contextMenuCopy(self)
    }

    func pasteSelection() {
        contextMenuPaste(self)
    }

    // MARK: - Context Menu

    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(withTitle: "Open", action: #selector(contextMenuOpen(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Open in New Tab", action: #selector(contextMenuOpenInNewTab(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Open With...", action: #selector(contextMenuOpenWith(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Get Info", action: #selector(contextMenuGetInfo(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Copy", action: #selector(contextMenuCopy(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Cut", action: #selector(contextMenuCut(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Paste", action: #selector(contextMenuPaste(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Rename", action: #selector(contextMenuRename(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Move to Trash", action: #selector(contextMenuDelete(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "New Folder", action: #selector(contextMenuNewFolder(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Change Folder Color...", action: #selector(contextMenuChangeColor(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Show in Finder", action: #selector(contextMenuShowInFinder(_:)), keyEquivalent: "")

        menu.delegate = self
        return menu
    }

    private func getSelectedItems() -> [FileItem] {
        var items: [FileItem] = []
        let selectedRows = outlineView.selectedRowIndexes

        // If there are selected rows, use those
        if !selectedRows.isEmpty {
            selectedRows.forEach { row in
                if let item = outlineView.item(atRow: row) as? FileItem {
                    items.append(item)
                }
            }
        } else {
            // If no selection, check if there's a clicked row (for context menu)
            let clickedRow = outlineView.clickedRow
            if clickedRow >= 0, let item = outlineView.item(atRow: clickedRow) as? FileItem {
                items.append(item)
            }
        }

        return items
    }

    @objc private func contextMenuOpen(_ sender: Any) {
        let items = getSelectedItems()
        items.forEach { item in
            if item.isDirectory {
                loadDirectory(item.url)
            } else {
                NSWorkspace.shared.open(item.url)
            }
        }
    }

    @objc private func contextMenuOpenInNewTab(_ sender: Any) {
        let items = getSelectedItems()
        // Only open directories in new tabs
        let directories = items.filter { $0.isDirectory }

        directories.forEach { item in
            delegate?.openInNewTab(url: item.url)
        }
    }

    @objc private func contextMenuOpenWith(_ sender: Any) {
        let items = getSelectedItems()
        guard let firstItem = items.first else { return }

        NSWorkspace.shared.openApplication(at: firstItem.url, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func contextMenuGetInfo(_ sender: Any) {
        let items = getSelectedItems()
        items.forEach { item in
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }
    }

    @objc private func contextMenuCopy(_ sender: Any) {
        let items = getSelectedItems()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items.map { $0.url as NSURL })
        cutItems = nil // Clear any pending cut operation
    }

    @objc private func contextMenuCut(_ sender: Any) {
        // Clear any previously cut items' visual state
        rootItem.children?.forEach { $0.isCut = false }

        let items = getSelectedItems()
        items.forEach { $0.isCut = true } // Mark selected items as cut
        cutItems = items // Store FileItem objects
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items.map { $0.url as NSURL })
        outlineView.reloadData() // Reload to show visual change
    }

    @objc private func contextMenuPaste(_ sender: Any) {
        let fileManager = FileManager.default
        let destinationFolderURL = self.currentDirectory

        if let cutItemsToMove = cutItems {
            // This is a "cut" operation (move)
            for item in cutItemsToMove {
                let destinationURL = destinationFolderURL.appendingPathComponent(item.url.lastPathComponent)
                do {
                    try fileManager.moveItem(at: item.url, to: destinationURL)
                    item.isCut = false // Clear cut state after successful move
                } catch {
                    showError("Failed to move: \(error.localizedDescription)")
                }
            }
            cutItems = nil // Clear cut items after paste
        } else {
            // This is a "copy" operation
            let pasteboard = NSPasteboard.general
            guard let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else { return }

            for url in urls {
                let destinationURL = destinationFolderURL.appendingPathComponent(url.lastPathComponent)
                do {
                    try fileManager.copyItem(at: url, to: destinationURL)
                } catch {
                    showError("Failed to paste: \(error.localizedDescription)")
                }
            }
        }

        refreshCurrentDirectory()
        outlineView.reloadData() // Reload to update visual state
    }

    @objc private func contextMenuRename(_ sender: Any) {
        let items = getSelectedItems()
        guard let item = items.first, items.count == 1 else { return }

        let alert = NSAlert()
        alert.messageText = "Rename"
        alert.informativeText = "Enter new name for '\(item.name)':"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = item.name
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let newName = textField.stringValue
            guard !newName.isEmpty else { return }

            let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newName)
            do {
                try FileManager.default.moveItem(at: item.url, to: newURL)
                refreshCurrentDirectory()
            } catch {
                showError("Failed to rename: \(error.localizedDescription)")
            }
        }
    }

    @objc private func contextMenuDelete(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Move to Trash"
        alert.informativeText = "Are you sure you want to move \(items.count) item(s) to trash?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            for item in items {
                NSWorkspace.shared.recycle([item.url]) { _, _ in
                    DispatchQueue.main.async {
                        self.refreshCurrentDirectory()
                    }
                }
            }
        }
    }

    @objc private func contextMenuNewFolder(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "New Folder"
        alert.informativeText = "Enter name for new folder:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = "Untitled Folder"
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let folderName = textField.stringValue
            guard !folderName.isEmpty else { return }

            let newFolderURL = currentDirectory.appendingPathComponent(folderName)
            do {
                try FileManager.default.createDirectory(at: newFolderURL, withIntermediateDirectories: false)
                refreshCurrentDirectory()
            } catch {
                showError("Failed to create folder: \(error.localizedDescription)")
            }
        }
    }

    @objc private func contextMenuChangeColor(_ sender: Any) {
        showBulkColorPicker()
    }

    @objc private func contextMenuShowInFinder(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }

        NSWorkspace.shared.activateFileViewerSelecting(items.map { $0.url })
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
            textField.lineBreakMode = .byTruncatingTail

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

            if fileItem.isCut {
                textField.textColor = NSColor.secondaryLabelColor // Darker shade for cut items
            }

            return cellView
        } else if identifier == "SizeColumn" {
            let cellView = NSTableCellView()
            let textField = NSTextField()
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = false
            textField.alignment = .right  // Right-align like Windows Explorer
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
        } else if identifier == "DateModifiedColumn" {
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
        } else if identifier == "TypeColumn" {
            let cellView = NSTableCellView()
            let textField = NSTextField()
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = false
            textField.stringValue = fileItem.kind
            textField.lineBreakMode = .byCharWrapping

            cellView.addSubview(textField)
            textField.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4)
            ])

            cellView.textField = textField
            return cellView
        } else if identifier == "DateCreatedColumn" {
            let cellView = NSTableCellView()
            let textField = NSTextField()
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = false
            textField.stringValue = fileItem.formattedCreationDate

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

    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = outlineView.sortDescriptors.first else { return }
        if let columnIdentifier = outlineView.tableColumns.first(where: { $0.sortDescriptorPrototype === sortDescriptor })?.identifier.rawValue {
            sortColumn = columnIdentifier
            sortAscending = sortDescriptor.ascending
            sortItems()
            outlineView.reloadData()
        }
    }
}

// MARK: - ToolbarDelegate

extension FileBrowserViewController: ToolbarDelegate {
    func toolbarDidRequestBack() {
        guard currentHistoryIndex > 0 else { return }
        currentHistoryIndex -= 1
        let url = navigationHistory[currentHistoryIndex]
        loadDirectory(url, addToHistory: false)
    }

    func toolbarDidRequestForward() {
        guard currentHistoryIndex < navigationHistory.count - 1 else { return }
        currentHistoryIndex += 1
        let url = navigationHistory[currentHistoryIndex]
        loadDirectory(url, addToHistory: false)
    }

    func toolbarDidRequestNavigate(to url: URL) {
        loadDirectory(url)
    }

    func toolbarDidChangeSortColumn(_ column: String, ascending: Bool) {
        sortColumn = column
        sortAscending = ascending
        if let tableColumn = outlineView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(column)),
           let sortDescriptor = tableColumn.sortDescriptorPrototype {
            outlineView.sortDescriptors = [sortDescriptor]
        }
        sortItems()
        outlineView.reloadData()
    }

    func toolbarDidRequestNavigateToHistoryIndex(_ index: Int) {
        guard index >= 0 && index < navigationHistory.count else { return }
        currentHistoryIndex = index
        let url = navigationHistory[index]
        loadDirectory(url, addToHistory: false)
    }

    func toolbarDidRequestNewFolder() {
        contextMenuNewFolder(self)
    }

    func toolbarDidToggleHiddenFiles(show: Bool) {
        showsHiddenFiles = show
        refreshCurrentDirectory()
    }

    func toolbarDidChangeViewMode(_ viewMode: ViewMode) {
        currentViewMode = viewMode
        displayFiles(for: viewMode)
    }
}

// MARK: - NSOutlineViewDataSource

extension FileBrowserViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        // Guard against nil rootItem to prevent crashes during initialization
        guard let rootItem = rootItem else { return 0 }

        if item == nil {
            return rootItem.children?.count ?? 0
        }
        guard let fileItem = item as? FileItem else { return 0 }
        return fileItem.children?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        // Guard against nil rootItem to prevent crashes during initialization
        guard let rootItem = rootItem else { return FileItem(url: currentDirectory) }

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

// MARK: - NSCollectionViewDataSource

extension FileBrowserViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return rootItem?.children?.count ?? 0
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        guard let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("FileIconItem"), for: indexPath) as? FileIconItem else {
            fatalError("Unable to create FileIconItem")
        }

        if let fileItem = rootItem?.children?[indexPath.item] {
            item.fileItem = fileItem
        }
        return item
    }
}

// MARK: - NSCollectionViewDelegate

extension FileBrowserViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        // Handle selection if needed
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        // Handle deselection if needed
    }

    func collectionView(_ collectionView: NSCollectionView, doubleClickOn item: NSCollectionViewItem) {
        guard let fileIconItem = item as? FileIconItem, let fileItem = fileIconItem.fileItem else { return }

        if fileItem.isDirectory {
            loadDirectory(fileItem.url)
        } else {
            NSWorkspace.shared.open(fileItem.url)
        }
    }
}



