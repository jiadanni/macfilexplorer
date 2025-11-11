import Cocoa
import AppKit
import AppKit

class FileBrowserViewController: NSViewController, NSMenuDelegate {

    weak var delegate: FileBrowserDelegate?

    private var toolbarViewController: ToolbarViewController!
    private var containerView: NSView! // New container view
    private var scrollView: NSScrollView! // For outlineView
    private var outlineView: NSOutlineView!
    private var collectionView: NSCollectionView! // For icons view
    private var collectionViewScrollView: NSScrollView! // For collection view
    private var browserView: NSBrowser! // For columns view
    
    // Constraint management for view switching
    private var activeConstraints: [NSLayoutConstraint] = []

    private var currentDirectory: URL
    private var rootItem: FileItem!
    private var fileSystemMonitor: FileSystemMonitor?
    private var selectedItems: Set<FileItem> = []
    private var currentViewMode: ViewMode = .details // Default view mode

    // Navigation history
    private var navigationHistory: [URL] = []
    private var currentHistoryIndex: Int = -1
    private var showsHiddenFiles: Bool = false

    // Sorting state
    private var sortColumn: String = "NameColumn"
    private var sortAscending: Bool = true
    
    // Zoom level (0.5 to 2.0, default 1.0)
    private var zoomLevel: Double = 1.0

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
        toolbarViewController?.updateViewModeDisplay(for: currentViewMode)
        toolbarViewController?.updateSortDisplay(column: sortColumn, ascending: sortAscending)

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
        // Deactivate any existing constraints
        NSLayoutConstraint.deactivate(activeConstraints)
        activeConstraints.removeAll()
        
        // Remove all subviews from the container
        containerView.subviews.forEach { $0.removeFromSuperview() }

        switch viewMode {
        case .list, .details:
            // Use outlineView for list and details
            containerView.addSubview(scrollView)
            activeConstraints = [
                scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(activeConstraints)
            outlineView.reloadData()
            view.window?.makeFirstResponder(outlineView)
        case .icons, .windowsList: // Handle both icons and windowsList with collectionView
            // Ensure collectionView is set up
            if collectionView == nil {
                setupCollectionView()
            }
            
            // Safety check
            guard let collectionView = collectionView, let collectionViewScrollView = collectionViewScrollView else {
                print("Error: CollectionView not properly initialized")
                currentViewMode = .list
                displayFiles(for: .list)
                return
            }
            
            containerView.addSubview(collectionViewScrollView)
            activeConstraints = [
                collectionViewScrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
                collectionViewScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                collectionViewScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                collectionViewScrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(activeConstraints)

            // Configure layout based on viewMode
            if viewMode == .windowsList {
                let flowLayout = NSCollectionViewFlowLayout()
                flowLayout.itemSize = NSSize(width: 150, height: 20) // Width of an item, height of a row
                flowLayout.sectionInset = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
                flowLayout.minimumLineSpacing = 2 // Vertical spacing between rows in a column
                flowLayout.minimumInteritemSpacing = 10 // Horizontal spacing between columns
                flowLayout.scrollDirection = .horizontal // Primary scrolling direction is horizontal
                collectionView.collectionViewLayout = flowLayout
            } else { // .icons mode
                let flowLayout = NSCollectionViewFlowLayout()
                flowLayout.itemSize = NSSize(width: 100, height: 120) // Adjust as needed
                flowLayout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
                flowLayout.minimumLineSpacing = 10
                flowLayout.minimumInteritemSpacing = 10
                flowLayout.scrollDirection = .vertical // Default for icons
                collectionView.collectionViewLayout = flowLayout
            }

            collectionView.reloadData()
            view.window?.makeFirstResponder(collectionView)
        case .columns:
            // Use NSBrowser for columns view
            if browserView == nil {
                setupBrowserView()
            }
            
            guard let browserView = browserView else {
                print("Error: BrowserView not properly initialized")
                currentViewMode = .list
                displayFiles(for: .list)
                return
            }
            
            containerView.addSubview(browserView)
            activeConstraints = [
                browserView.topAnchor.constraint(equalTo: containerView.topAnchor),
                browserView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                browserView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                browserView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(activeConstraints)
            
            browserView.loadColumnZero()
            view.window?.makeFirstResponder(browserView)
        }
    }

    private func setupCollectionView() {
        collectionView = NSCollectionView()
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true
        collectionView.backgroundColors = [.clear]
        collectionView.delegate = self
        collectionView.dataSource = self

        // Register item prototype
        collectionView.register(FileIconItem.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("FileIconItem"))
        
        // Add double-click gesture recognizer for handling double-clicks
        let doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleCollectionViewDoubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        collectionView.addGestureRecognizer(doubleClickGesture)

        collectionViewScrollView = NSScrollView()
        collectionViewScrollView.translatesAutoresizingMaskIntoConstraints = false
        collectionViewScrollView.hasVerticalScroller = true
        collectionViewScrollView.hasHorizontalScroller = true
        collectionViewScrollView.autohidesScrollers = true
        collectionViewScrollView.borderType = .noBorder
        collectionViewScrollView.documentView = collectionView
    }
    
    private func setupBrowserView() {
        browserView = NSBrowser()
        browserView.translatesAutoresizingMaskIntoConstraints = false
        browserView.delegate = self
        browserView.allowsMultipleSelection = true
        browserView.allowsEmptySelection = true
        browserView.takesTitleFromPreviousColumn = false
        browserView.separatesColumns = true
        browserView.rowHeight = 20.0
        browserView.hasHorizontalScroller = true
        browserView.autohidesScroller = true
        browserView.columnsAutosaveName = "FileBrowserColumns"
        browserView.doubleAction = #selector(handleBrowserDoubleClick(_:))
        browserView.target = self
    }
    
    @objc private func handleBrowserDoubleClick(_ sender: NSBrowser) {
        let selectedColumn = browserView.selectedColumn
        let selectedRow = browserView.selectedRow(inColumn: selectedColumn)
        
        guard selectedRow >= 0 else { return }
        
        let item = fileItemForColumn(selectedColumn)
        guard let children = item?.children,
              selectedRow < children.count else {
            return
        }
        
        let fileItem = children[selectedRow]
        
        if fileItem.isDirectory {
            loadDirectory(fileItem.url)
        } else {
            NSWorkspace.shared.open(fileItem.url)
        }
    }
    
    @objc private func handleCollectionViewDoubleClick(_ sender: NSClickGestureRecognizer) {
        guard let collectionView = collectionView else { return }
        let point = sender.location(in: collectionView)
        
        if let indexPath = collectionView.indexPathForItem(at: point),
           let item = collectionView.item(at: indexPath) as? FileIconItem,
           let fileItem = item.fileItem {
            
            if fileItem.isDirectory {
                loadDirectory(fileItem.url)
            } else {
                NSWorkspace.shared.open(fileItem.url)
            }
        }
    }





    private func loadDirectory(_ url: URL, addToHistory: Bool = true) {
        print("FileBrowserViewController: loadDirectory - Loading URL: \(url.path)")
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
            item.loadChildren(showsHiddenFiles: self.showsHiddenFiles) // This loads children for the *new* root item

            DispatchQueue.main.async {
                self.rootItem = item
                print("FileBrowserViewController: loadDirectory - rootItem URL: \(self.rootItem.url.path), children count: \(self.rootItem.children?.count ?? 0)")
                self.sortItems()
                self.outlineView.reloadData() // Reloads the outline view
                print("FileBrowserViewController: outlineView reloaded.")
                if self.currentViewMode == .icons {
                    self.collectionView.reloadData()
                } else if self.currentViewMode == .columns {
                    // browserView.reloadData() // Temporarily disabled
                }
                self.outlineView.expandItem(nil, expandChildren: true) // This expands the *root* item

                // Set up file system monitoring (correctly handled)

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
                } else if self.currentViewMode == .columns {
                    // self.browserView.reloadData() // Temporarily disabled
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
    
    func setZoomLevel(_ level: Double) {
        zoomLevel = max(0.5, min(2.0, level)) // Clamp between 0.5 and 2.0
        applyZoomToCurrentView()
    }
    
    private func applyZoomToCurrentView() {
        switch currentViewMode {
        case .icons, .windowsList:
            guard let collectionView = collectionView else { return }
            
            if currentViewMode == .windowsList {
                let flowLayout = NSCollectionViewFlowLayout()
                let baseWidth: CGFloat = 150
                let baseHeight: CGFloat = 20
                flowLayout.itemSize = NSSize(width: baseWidth * zoomLevel, height: baseHeight * zoomLevel)
                flowLayout.sectionInset = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
                flowLayout.minimumLineSpacing = 2
                flowLayout.minimumInteritemSpacing = 10
                flowLayout.scrollDirection = .horizontal
                collectionView.collectionViewLayout = flowLayout
            } else { // .icons mode
                let flowLayout = NSCollectionViewFlowLayout()
                let baseWidth: CGFloat = 100
                let baseHeight: CGFloat = 120
                flowLayout.itemSize = NSSize(width: baseWidth * zoomLevel, height: baseHeight * zoomLevel)
                flowLayout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
                flowLayout.minimumLineSpacing = 10
                flowLayout.minimumInteritemSpacing = 10
                flowLayout.scrollDirection = .vertical
                collectionView.collectionViewLayout = flowLayout
            }
        case .list, .details:
            // For outline view, adjust row height
            if let outlineView = outlineView {
                let baseRowHeight: CGFloat = 20
                outlineView.rowHeight = baseRowHeight * zoomLevel
            }
        case .columns:
            // Browser view doesn't need zoom adjustments
            break
        }
    }

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
    }

    @objc private func contextMenuCut(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Write URLs to pasteboard
        pasteboard.writeObjects(items.map { $0.url as NSURL })

        // Write a custom type to indicate a "cut" operation
        pasteboard.setString("cut", forType: NSPasteboard.PasteboardType("com.macfileexplorer.cutOperation"))

        // No longer need to manage cutItems instance variable or visual state here
        // The visual state will be handled by checking the pasteboard in outlineView(_:viewFor:item:)
        outlineView.reloadData() // Reload to show visual change (if any)
    }

    @objc private func contextMenuPaste(_ sender: Any) {
        let fileManager = FileManager.default
        let destinationFolderURL = self.currentDirectory
        let pasteboard = NSPasteboard.general

        // Check if it's a "cut" operation
        let isCutOperation = pasteboard.string(forType: NSPasteboard.PasteboardType("com.macfileexplorer.cutOperation")) == "cut"

        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else { return }

        for url in urls {
            let destinationURL = destinationFolderURL.appendingPathComponent(url.lastPathComponent)
            do {
                if isCutOperation {
                    try fileManager.moveItem(at: url, to: destinationURL)
                } else {
                    try fileManager.copyItem(at: url, to: destinationURL)
                }
            } catch {
                showError("Failed to \(isCutOperation ? "move" : "copy"): \(error.localizedDescription)")
            }
        }

        // Clear the pasteboard after a successful paste operation
        pasteboard.clearContents()

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
        toolbarViewController?.updateSortDisplay(column: column, ascending: ascending)
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
        toolbarViewController?.updateHiddenFilesDisplay(showing: show)
    }
    
    func toggleHiddenFilesState() {
        toolbarDidToggleHiddenFiles(show: !showsHiddenFiles)
    }

    func toolbarDidChangeViewMode(_ viewMode: ViewMode) {
        currentViewMode = viewMode
        displayFiles(for: viewMode)
        toolbarViewController?.updateViewModeDisplay(for: viewMode)
    }

    func toolbarDidRequestSplitVertically() {
        delegate?.fileBrowserDidRequestSplit(self, orientation: .vertical)
    }

    func toolbarDidRequestSplitHorizontally() {
        delegate?.fileBrowserDidRequestSplit(self, orientation: .horizontal)
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
        // Update status bar or toolbar with selection count
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        // Handle deselection if needed
    }
}

// MARK: - NSBrowserDelegate

extension FileBrowserViewController: NSBrowserDelegate {
    func browser(_ browser: NSBrowser, numberOfRowsInColumn column: Int) -> Int {
        let item = fileItemForColumn(column)
        return item?.children?.count ?? 0
    }
    
    func browser(_ browser: NSBrowser, willDisplayCell cell: Any, atRow row: Int, column: Int) {
        guard let cell = cell as? NSBrowserCell,
              let item = fileItemForColumn(column),
              let children = item.children,
              row < children.count else {
            return
        }
        
        let fileItem = children[row]
        cell.title = fileItem.name
        cell.isLeaf = !fileItem.isDirectory
        
        if fileItem.isDirectory {
            cell.image = NSWorkspace.shared.icon(forFile: fileItem.url.path)
        }
    }
    
    func browser(_ browser: NSBrowser, selectRow row: Int, inColumn column: Int) -> Bool {
        return true
    }
    
    func browser(_ browser: NSBrowser, titleOfColumn column: Int) -> String? {
        if column == 0 {
            return currentDirectory.lastPathComponent
        }
        
        let item = fileItemForColumn(column - 1)
        let selectedRow = browser.selectedRow(inColumn: column - 1)
        
        if let children = item?.children, selectedRow >= 0, selectedRow < children.count {
            return children[selectedRow].name
        }
        
        return nil
    }
    
    private func fileItemForColumn(_ column: Int) -> FileItem? {
        if column == 0 {
            return rootItem
        }
        
        var item = rootItem
        for col in 0..<column {
            let selectedRow = browserView.selectedRow(inColumn: col)
            guard selectedRow >= 0,
                  let children = item?.children,
                  selectedRow < children.count else {
                return nil
            }
            item = children[selectedRow]
        }
        
        return item
    }
}



