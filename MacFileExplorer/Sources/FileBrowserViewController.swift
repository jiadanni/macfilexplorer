import Cocoa

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
    private var selectedItems: Set<FileItem> = []
    private var currentViewMode: ViewMode = .list // Default view mode

    // Navigation history
    private var navigationHistory: [URL] = []
    private var currentHistoryIndex: Int = -1
    private var showsHiddenFiles: Bool = false

    // Sorting state
    private var sortColumn: String = "NameColumn"
    private var sortAscending: Bool = true
    
    // Zoom level (0.5 to 2.0, default 1.0)
    private var zoomLevel: Double = 1.0

    // Click tracking for delayed rename
    private var lastClickedRow: Int = -1
    private var lastClickTime: TimeInterval = 0
    private let doubleClickTimeWindow: TimeInterval = 0.5 // Time window for double-click detection
    private let renameClickDelay: TimeInterval = 0.5 // Minimum delay between clicks to trigger rename

    var currentPath: String {
        return currentDirectory.path
    }

    init() {
        // Start at /Applications to avoid triggering permission prompts
        self.currentDirectory = URL(fileURLWithPath: "/Applications")
        super.init(nibName: nil, bundle: nil)

        NotificationCenter.default.addObserver(forName: .globalFolderColorDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.globalFolderColorDidChange()
        }
    }

    required init?(coder: NSCoder) {
        // Start at /Applications to avoid triggering permission prompts
        self.currentDirectory = URL(fileURLWithPath: "/Applications")
        super.init(coder: coder)

        NotificationCenter.default.addObserver(forName: .globalFolderColorDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.globalFolderColorDidChange()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .globalFolderColorDidChangeNotification, object: nil)
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
        } else if event.keyCode == 53 { // Escape key
            clearSelection()
        } else if event.keyCode == 120 { // F2 key
            renameSelection()
        } else {
            super.keyDown(with: event)
        }
    }
    
    private func clearSelection() {
        switch currentViewMode {
        case .list:
            outlineView.deselectAll(nil)
        case .icons, .windowsList:
            collectionView?.deselectAll(nil)
        case .columns:
            browserView?.selectionIndexPaths = []
        }
        delegate?.fileBrowser(self, didSelectFile: nil)
        updateStatusBar()
    }

    private func renameSelection() {
        let items = getSelectedItems()
        guard let item = items.first, items.count == 1 else { return }
        contextMenuRename(item)
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
        
        // Set delegate and dataSource
        outlineView.delegate = self
        outlineView.dataSource = self

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
        print("Displaying files for view mode: \(viewMode)")
        
        // Deactivate any existing constraints
        NSLayoutConstraint.deactivate(activeConstraints)
        activeConstraints.removeAll()
        
        // Hide all views first instead of removing them
        scrollView.isHidden = true
        collectionViewScrollView?.isHidden = true
        browserView?.isHidden = true

        switch viewMode {
        case .list:
            // Use outlineView for list view
            if scrollView.superview == nil {
                containerView.addSubview(scrollView)
            }
            scrollView.isHidden = false
            
            activeConstraints = [
                scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(activeConstraints)
            outlineView.reloadData()

            // Use dispatch to ensure window is ready
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.view.window?.makeFirstResponder(self.outlineView)
            }
            
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
            
            if collectionViewScrollView.superview == nil {
                containerView.addSubview(collectionViewScrollView)
            }
            collectionViewScrollView.isHidden = false
            
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
                flowLayout.itemSize = NSSize(width: 200, height: 20) // Width of an item, height of a row
                flowLayout.sectionInset = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
                flowLayout.minimumLineSpacing = 1 // Vertical spacing between rows in a column
                flowLayout.minimumInteritemSpacing = 5 // Horizontal spacing between columns
                flowLayout.scrollDirection = .vertical // Vertical scrolling for list view
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

            // Use dispatch to ensure window is ready
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.view.window?.makeFirstResponder(self.collectionView)
            }
            
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
            
            if browserView.superview == nil {
                containerView.addSubview(browserView)
            }
            browserView.isHidden = false
            
            activeConstraints = [
                browserView.topAnchor.constraint(equalTo: containerView.topAnchor),
                browserView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                browserView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                browserView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(activeConstraints)
            
            // Use dispatch to ensure layout is complete before loading data
            print("displayFiles: Setting up browser view, rootItem has \(rootItem?.children?.count ?? 0) children")
            DispatchQueue.main.async { [weak self] in
                guard let self, let browserView = self.browserView else { return }

                // Force layout update
                browserView.layoutSubtreeIfNeeded()

                // Load the data
                print("displayFiles: Loading column zero")
                browserView.loadColumnZero()

                // Ensure it's visible and updated
                browserView.setNeedsDisplay(browserView.bounds)

                self.view.window?.makeFirstResponder(browserView)
            }
        }
    }

    private func setupCollectionView() {
        // Prevent duplicate setup
        if collectionView != nil {
            print("CollectionView already initialized, skipping setup")
            return
        }

        let newCollectionView = NSCollectionView()
        newCollectionView.translatesAutoresizingMaskIntoConstraints = false
        newCollectionView.isSelectable = true
        newCollectionView.allowsMultipleSelection = true
        newCollectionView.backgroundColors = [.clear]
        newCollectionView.delegate = self
        newCollectionView.dataSource = self

        // NOTE: We don't register a class or NIB for FileIconItem
        // Instead, we'll create items manually in the data source method
        // This avoids the NSCollectionView instantiation issues with custom loadView()

        // Add double-click gesture recognizer for handling double-clicks
        let doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleCollectionViewDoubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        newCollectionView.addGestureRecognizer(doubleClickGesture)

        let newScrollView = NSScrollView()
        newScrollView.translatesAutoresizingMaskIntoConstraints = false
        newScrollView.hasVerticalScroller = true
        newScrollView.hasHorizontalScroller = true
        newScrollView.autohidesScrollers = true
        newScrollView.borderType = .noBorder
        newScrollView.documentView = newCollectionView

        collectionView = newCollectionView
        collectionViewScrollView = newScrollView
    }
    
    private func setupBrowserView() {
        // Prevent duplicate setup
        if browserView != nil {
            print("BrowserView already initialized, skipping setup")
            return
        }

        let newBrowser = NSBrowser()
        newBrowser.translatesAutoresizingMaskIntoConstraints = false
        newBrowser.delegate = self
        newBrowser.allowsMultipleSelection = true
        newBrowser.allowsEmptySelection = true
        newBrowser.takesTitleFromPreviousColumn = false
        newBrowser.separatesColumns = true
        newBrowser.rowHeight = 22.0  // Slightly taller rows for better readability
        newBrowser.hasHorizontalScroller = true
        newBrowser.autohidesScroller = true

        // Set minimum and maximum column widths for better spacing
        newBrowser.minColumnWidth = 180  // Minimum width for each column
        newBrowser.maxVisibleColumns = 4  // Maximum number of visible columns

        // Don't use autosave as it can cause layout issues
        // newBrowser.columnsAutosaveName = "FileBrowserColumns"

        newBrowser.doubleAction = #selector(handleBrowserDoubleClick(_:))
        newBrowser.target = self

        // Set the cell class that NSBrowser will use
        newBrowser.setCellClass(NSBrowserCell.self)

        // Set up context menu
        newBrowser.menu = createContextMenu()

        browserView = newBrowser
        print("BrowserView setup completed with minColumnWidth: 180")
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

        // Special handling for Google Drive CloudStorage root - redirect to "My Drive"
        var targetURL = url
        if url.path.contains("/Library/CloudStorage/GoogleDrive-") &&
           url.lastPathComponent.hasPrefix("GoogleDrive-") {
            let myDriveURL = url.appendingPathComponent("My Drive")
            if FileManager.default.fileExists(atPath: myDriveURL.path) {
                print("  → Redirecting to My Drive: \(myDriveURL.path)")
                targetURL = myDriveURL
            }
        }

        currentDirectory = targetURL

        // Update navigation history
        if addToHistory {
            // Remove any forward history
            if currentHistoryIndex < navigationHistory.count - 1 {
                navigationHistory.removeSubrange((currentHistoryIndex + 1)...)
            }
            navigationHistory.append(targetURL)
            currentHistoryIndex = navigationHistory.count - 1
        }

        // Update toolbar
        let canGoBack = currentHistoryIndex > 0
        let canGoForward = currentHistoryIndex < navigationHistory.count - 1
        toolbarViewController?.updatePath(targetURL, canGoBack: canGoBack, canGoForward: canGoForward, history: navigationHistory, currentIndex: currentHistoryIndex)

        // Set delegate and dataSource if not already set
        if outlineView.delegate == nil {
            outlineView.delegate = self
            outlineView.dataSource = self
        }

        // Load directory contents on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let item = FileItem(url: targetURL)
            let success = item.loadChildren(showsHiddenFiles: self.showsHiddenFiles) { [weak self] errorMessage in
                // Handle error on main thread
                DispatchQueue.main.async {
                    self?.showError(errorMessage)
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.rootItem = item
                print("FileBrowserViewController: loadDirectory - rootItem URL: \(self.rootItem.url.path), children count: \(self.rootItem.children?.count ?? 0), success: \(success)")
                self.sortItems()
                self.outlineView.reloadData() // Reloads the outline view
                print("FileBrowserViewController: outlineView reloaded.")
                if self.currentViewMode == .icons || self.currentViewMode == .windowsList {
                    self.collectionView.reloadData()
                } else if self.currentViewMode == .columns {
                    self.browserView.loadColumnZero()
                }
                self.outlineView.expandItem(nil, expandChildren: true) // This expands the *root* item

                // Set up file system monitoring (correctly handled)

                self.delegate?.directoryDidChange(to: targetURL.path)
                self.updateStatusBar()
            }
        }
    }

    private func refreshCurrentDirectory() {
        print("Refreshing current directory")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            self.rootItem.loadChildren(showsHiddenFiles: self.showsHiddenFiles) { [weak self] errorMessage in
                // Handle error on main thread
                DispatchQueue.main.async {
                    self?.showError(errorMessage)
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.sortItems()
                self.outlineView.reloadData()
                if self.currentViewMode == .icons || self.currentViewMode == .windowsList {
                    self.collectionView.reloadData()
                } else if self.currentViewMode == .columns {
                    self.browserView.loadColumnZero()
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

    func setClosePaneButtonVisible(_ visible: Bool) {
        toolbarViewController?.setClosePaneButtonVisible(visible)
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
        case .list:
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
    
    @objc func changeFolderColor() {
        // Get selected folder items
        let selectedRows = outlineView.selectedRowIndexes
        var selectedFolders: [FileItem] = []
        
        selectedRows.forEach { row in
            if let item = outlineView.item(atRow: row) as? FileItem, item.isDirectory {
                selectedFolders.append(item)
            }
        }
        
        guard !selectedFolders.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No Folders Selected"
            alert.informativeText = "Please select one or more folders to change their colors."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // Show the color picker
        let colorPanel = NSColorPanel.shared
        colorPanel.showsAlpha = false
        colorPanel.mode = .wheel
        
        // Set a target-action callback for when color changes
        // We'll use a notification approach instead
        colorPanel.isContinuous = false
        
        // Store the selected folders temporarily
        var tempFolders = selectedFolders
        
        // Create a completion handler
        let completionHandler: (NSColorPanel) -> Void = { [weak self] panel in
            let selectedColor = panel.color
            
            // Apply color to all selected folders by name
            let folderNames = Set(tempFolders.map { $0.name })
            folderNames.forEach { folderName in
                ColorManager.shared.setColor(selectedColor, forFolderName: folderName)
            }
            
            // Reload the view to show the new colors
            self?.outlineView.reloadData()
            if self?.currentViewMode == .icons || self?.currentViewMode == .windowsList {
                self?.collectionView.reloadData()
            } else if self?.currentViewMode == .columns {
                self?.browserView.loadColumnZero()
            }
        }
        
        // Use a one-shot notification observer
        var observer: NSObjectProtocol?
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: colorPanel,
            queue: .main
        ) { [weak self] notification in
            if let colorPanel = notification.object as? NSColorPanel {
                completionHandler(colorPanel)
            }
            if let obs = observer {
                NotificationCenter.default.removeObserver(obs)
            }
        }
        
        colorPanel.orderFront(nil)
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
        menu.addItem(withTitle: "Copy To...", action: #selector(contextMenuCopyTo(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Cut", action: #selector(contextMenuCut(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Move To...", action: #selector(contextMenuMoveTo(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Paste", action: #selector(contextMenuPaste(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Rename", action: #selector(contextMenuRename(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Move to Trash", action: #selector(contextMenuDelete(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "New Folder", action: #selector(contextMenuNewFolder(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Change Folder Color...", action: #selector(changeFolderColor), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Show in Finder", action: #selector(contextMenuShowInFinder(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Close Pane", action: #selector(contextMenuClosePane(_:)), keyEquivalent: "")

        menu.delegate = self
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        // Get the selected items to determine if we should show/hide certain menu items
        let selectedItems = getSelectedItems()

        // Apply context menu visibility settings from UserDefaults
        if let openWithItem = menu.items.first(where: { $0.title == "Open With..." }) {
            // Hide "Open With..." for folders, when multiple items are selected, or if disabled in settings
            let shouldHideOpenWith = UserDefaults.standard.bool(forKey: UserDefaults.Keys.hideOpenWith.rawValue) ||
                                     selectedItems.isEmpty ||
                                     selectedItems.count > 1 ||
                                     selectedItems.first?.isDirectory == true
            openWithItem.isHidden = shouldHideOpenWith
        }

        if let getInfoItem = menu.items.first(where: { $0.title == "Get Info" }) {
            getInfoItem.isHidden = UserDefaults.standard.bool(forKey: UserDefaults.Keys.hideGetInfo.rawValue)
        }

        if let copyItem = menu.items.first(where: { $0.title == "Copy" }) {
            copyItem.isHidden = UserDefaults.standard.bool(forKey: UserDefaults.Keys.hideCopy.rawValue)
        }

        if let cutItem = menu.items.first(where: { $0.title == "Cut" }) {
            cutItem.isHidden = UserDefaults.standard.bool(forKey: UserDefaults.Keys.hideCut.rawValue)
        }

        if let pasteItem = menu.items.first(where: { $0.title == "Paste" }) {
            pasteItem.isHidden = UserDefaults.standard.bool(forKey: UserDefaults.Keys.hidePaste.rawValue)
        }

        if let renameItem = menu.items.first(where: { $0.title == "Rename" }) {
            renameItem.isHidden = UserDefaults.standard.bool(forKey: UserDefaults.Keys.hideRename.rawValue)
        }

        if let deleteItem = menu.items.first(where: { $0.title == "Move to Trash" }) {
            deleteItem.isHidden = UserDefaults.standard.bool(forKey: UserDefaults.Keys.hideMoveToTrash.rawValue)
        }

        if let showInFinderItem = menu.items.first(where: { $0.title == "Show in Finder" }) {
            showInFinderItem.isHidden = UserDefaults.standard.bool(forKey: UserDefaults.Keys.hideShowInFinder.rawValue)
        }

        // Hide "Change Folder Color..." if settings say so or if not a folder
        if let changeFolderColorItem = menu.items.first(where: { $0.title == "Change Folder Color..." }) {
            let shouldHide = UserDefaults.standard.bool(forKey: UserDefaults.Keys.hideChangeFolderColor.rawValue) ||
                           selectedItems.isEmpty ||
                           selectedItems.first?.isDirectory != true
            changeFolderColorItem.isHidden = shouldHide
        }

        // Hide "New Folder" if settings say so
        if let newFolderItem = menu.items.first(where: { $0.title == "New Folder" }) {
            newFolderItem.isHidden = UserDefaults.standard.bool(forKey: UserDefaults.Keys.hideNewFolder.rawValue)
        }
    }

    private func getSelectedItems() -> [FileItem] {
        var items: [FileItem] = []

        switch currentViewMode {
        case .list:
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

        case .icons, .windowsList:
            guard let collectionView = collectionView else { return items }
            let selectedIndexPaths = collectionView.selectionIndexPaths

            if !selectedIndexPaths.isEmpty {
                selectedIndexPaths.forEach { indexPath in
                    if let item = collectionView.item(at: indexPath) as? FileIconItem,
                       let fileItem = item.fileItem {
                        items.append(fileItem)
                    }
                }
            }

        case .columns:
            guard let browserView = browserView else { return items }
            let selectedColumn = browserView.selectedColumn

            if selectedColumn >= 0 {
                let selectedRows = browserView.selectedRowIndexes(inColumn: selectedColumn)
                selectedRows?.forEach { row in
                    if let item = fileItemForColumn(selectedColumn),
                       let children = item.children,
                       row < children.count {
                        items.append(children[row])
                    }
                }
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
        guard let item = items.first else { return }

        let alert = NSAlert()
        alert.messageText = "File Information"
        alert.informativeText = formatFileInfo(for: item)
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Show in Finder")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            // Show in Finder was clicked
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }
    }

    private func formatFileInfo(for item: FileItem) -> String {
        var info = ""
        info += "Name: \(item.name)\n"
        info += "Kind: \(item.kind)\n"
        info += "Size: \(item.sizeString)\n"
        info += "Modified: \(item.formattedDate)\n"
        info += "Created: \(item.formattedCreationDate)\n"
        info += "Location: \(item.url.deletingLastPathComponent().path)\n"
        if !item.permissions.isEmpty {
            info += "Permissions: \(item.permissions)\n"
        }
        if !item.owner.isEmpty {
            info += "Owner: \(item.owner)\n"
        }
        return info
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

        // Reload views to show visual change
        outlineView.reloadData()
        collectionView.reloadData()
        browserView.reloadColumn(browserView.lastColumn)
    }

    @objc private func contextMenuCopyTo(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }

        // Show folder selection dialog
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose destination folder to copy \(items.count) item(s)"

        if panel.runModal() == .OK, let destinationURL = panel.url {
            let fileManager = FileManager.default
            for item in items {
                let destinationItemURL = destinationURL.appendingPathComponent(item.name)
                do {
                    try fileManager.copyItem(at: item.url, to: destinationItemURL)
                } catch {
                    showError("Failed to copy '\(item.name)': \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func contextMenuMoveTo(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }

        // Show folder selection dialog
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose destination folder to move \(items.count) item(s)"

        if panel.runModal() == .OK, let destinationURL = panel.url {
            let fileManager = FileManager.default
            for item in items {
                let destinationItemURL = destinationURL.appendingPathComponent(item.name)
                do {
                    try fileManager.moveItem(at: item.url, to: destinationItemURL)
                } catch {
                    showError("Failed to move '\(item.name)': \(error.localizedDescription)")
                }
            }
            // Refresh after moving files
            refreshCurrentDirectory()
        }
    }

    // Helper method to check if a file is in the cut state
    private func isFileCut(_ url: URL) -> Bool {
        let pasteboard = NSPasteboard.general
        guard pasteboard.string(forType: NSPasteboard.PasteboardType("com.macfileexplorer.cutOperation")) == "cut",
              let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else {
            return false
        }
        return urls.contains(url)
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
                showError("Failed to \(isCutOperation ? "move" : "copy"):\(error.localizedDescription)")
            }
        }

        // Clear the pasteboard after a successful paste operation
        pasteboard.clearContents()

        refreshCurrentDirectory()
        // Reload all views to update visual state
        outlineView.reloadData()
        collectionView.reloadData()
        browserView.reloadColumn(browserView.lastColumn)
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
                NSWorkspace.shared.recycle([item.url]) { [weak self] _, _ in
                    DispatchQueue.main.async {
                        self?.refreshCurrentDirectory()
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



    @objc private func contextMenuShowInFinder(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }

        NSWorkspace.shared.activateFileViewerSelecting(items.map { $0.url })
    }
    
    @objc private func contextMenuClosePane(_ sender: Any) {
        delegate?.fileBrowserDidRequestClosePane(self)
    }

    @objc private func checkboxToggled(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0, row < outlineView.numberOfRows else { return }

        if sender.state == .on {
            // Add to selection
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: true)
        } else {
            // Remove from selection
            var currentSelection = outlineView.selectedRowIndexes
            currentSelection.remove(row)
            outlineView.selectRowIndexes(currentSelection, byExtendingSelection: false)
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    private func globalFolderColorDidChange() {
        // Reload all views to apply the new global folder color
        outlineView.reloadData()
        collectionView?.reloadData()
        browserView?.reloadColumn(browserView?.lastColumn ?? 0)
    }
    
    private func updateStatusBar() {
        // Calculate selected items size
        var totalSelectedSize: Int64 = 0
        let selectedFileItems = getSelectedItems()
        for item in selectedFileItems {
            totalSelectedSize += item.size
        }

        // If files are selected, show selection info. Otherwise show disk space
        if selectedFileItems.count > 0 {
            delegate?.fileBrowser(self, didUpdateSelection: selectedFileItems.count, totalSize: totalSelectedSize)
        } else {
            // Calculate disk space only when no files are selected
            let diskSpace = calculateDiskSpace()
            delegate?.fileBrowser(self, didUpdateDiskSpace: diskSpace)
        }
    }
    
    private func calculateDiskSpace() -> String? {
        let fileURL = currentDirectory
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                return ByteCountFormatter.string(fromByteCount: capacity, countStyle: .file)
            }
        } catch {
            print("Error getting disk space: \(error.localizedDescription)")
        }
        return nil
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

            // Check if Easy Select is enabled
            let easySelectEnabled = UserDefaults.standard.bool(forKey: UserDefaults.Keys.enableEasySelect.rawValue)

            imageView.translatesAutoresizingMaskIntoConstraints = false
            textField.translatesAutoresizingMaskIntoConstraints = false

            if easySelectEnabled {
                // Add checkbox for Easy Select mode
                let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
                checkbox.translatesAutoresizingMaskIntoConstraints = false
                checkbox.state = outlineView.selectedRowIndexes.contains(outlineView.row(forItem: item)) ? .on : .off
                checkbox.tag = outlineView.row(forItem: item)
                checkbox.target = self
                checkbox.action = #selector(checkboxToggled(_:))

                cellView.addSubview(checkbox)
                cellView.addSubview(imageView)
                cellView.addSubview(textField)

                NSLayoutConstraint.activate([
                    checkbox.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                    checkbox.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                    checkbox.widthAnchor.constraint(equalToConstant: 18),

                    imageView.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 4),
                    imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                    imageView.widthAnchor.constraint(equalToConstant: 16),
                    imageView.heightAnchor.constraint(equalToConstant: 16),

                    textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                    textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                    textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4)
                ])
            } else {
                // Standard layout without checkbox
                cellView.addSubview(imageView)
                cellView.addSubview(textField)

                NSLayoutConstraint.activate([
                    imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                    imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                    imageView.widthAnchor.constraint(equalToConstant: 16),
                    imageView.heightAnchor.constraint(equalToConstant: 16),

                    textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                    textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                    textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4)
                ])
            }

            cellView.imageView = imageView
            cellView.textField = textField

            // Apply dimmed appearance for cut files
            if isFileCut(fileItem.url) {
                imageView.alphaValue = 0.5
                textField.alphaValue = 0.5
            } else {
                imageView.alphaValue = 1.0
                textField.alphaValue = 1.0
            }

            return cellView
        } else if identifier == "SizeColumn" {
            let cellView = NSTableCellView()
            let textField = NSTextField()
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = false
            textField.alignment = .right  // Right-align like Windows Explorer
            textField.stringValue = fileItem.sizeString

            cellView.addSubview(textField)
            textField.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4)
            ])

            cellView.textField = textField

            // Apply dimmed appearance for cut files
            if isFileCut(fileItem.url) {
                textField.alphaValue = 0.5
            } else {
                textField.alphaValue = 1.0
            }

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

            // Apply dimmed appearance for cut files
            if isFileCut(fileItem.url) {
                textField.alphaValue = 0.5
            } else {
                textField.alphaValue = 1.0
            }

            return cellView
        } else if identifier == "TypeColumn" {
            let cellView = NSTableCellView()
            let textField = NSTextField()
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = false
            textField.stringValue = fileItem.kind
            textField.lineBreakMode = .byTruncatingTail
            textField.cell?.truncatesLastVisibleLine = true
            textField.maximumNumberOfLines = 1

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

            // Apply dimmed appearance for cut files
            if isFileCut(fileItem.url) {
                textField.alphaValue = 0.5
            } else {
                textField.alphaValue = 1.0
            }

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

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        let clickedRow = outlineView.clickedRow
        let currentTime = Date().timeIntervalSinceReferenceDate
        let timeSinceLastClick = currentTime - lastClickTime

        // Check if this is a delayed second click on the same row
        if clickedRow == lastClickedRow &&
           clickedRow == outlineView.selectedRow &&
           timeSinceLastClick > renameClickDelay &&
           timeSinceLastClick < 2.0 { // Maximum time window for rename
            // Trigger rename
            if let fileItem = item as? FileItem {
                DispatchQueue.main.async { [weak self] in
                    self?.contextMenuRename(fileItem)
                }
            }
            return false // Don't change selection
        }

        lastClickedRow = clickedRow
        lastClickTime = currentTime
        return true
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let selectedRows = outlineView.selectedRowIndexes
        if selectedRows.count == 1, let selectedRow = selectedRows.first {
            if let selectedFileItem = outlineView.item(atRow: selectedRow) as? FileItem {
                delegate?.fileBrowser(self, didSelectFile: selectedFileItem)
            } else {
                delegate?.fileBrowser(self, didSelectFile: nil)
            }
        } else {
            delegate?.fileBrowser(self, didSelectFile: nil)
        }
        updateStatusBar()
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

    func toolbarDidRequestClosePane() {
        delegate?.fileBrowserDidRequestClosePane(self)
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
            guard let children = rootItem.children, index >= 0, index < children.count else {
                return FileItem(url: currentDirectory)
            }
            return children[index]
        }
        guard let fileItem = item as? FileItem else {
            return FileItem(url: currentDirectory)
        }
        guard let children = fileItem.children, index >= 0, index < children.count else {
            return FileItem(url: currentDirectory)
        }
        return children[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let fileItem = item as? FileItem else { return false }
        return fileItem.isDirectory && (fileItem.children?.count ?? 0) > 0
    }
}

// MARK: - NSCollectionViewDataSource

extension FileBrowserViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let rootItem = rootItem else {
            print("CollectionViewDataSource: rootItem is nil")
            return 0
        }
        let count = rootItem.children?.count ?? 0
        print("CollectionViewDataSource: numberOfItemsInSection: \(count)")
        return count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        print("CollectionViewDataSource: itemForRepresentedObjectAt: \(indexPath)")
        
        // Verify rootItem exists and has children
        guard let rootItem = rootItem, 
              let children = rootItem.children, 
              indexPath.item < children.count else {
            print("CollectionViewDataSource: rootItem or children are nil, or indexPath is out of bounds")
            // Return a basic item as fallback
            let fallbackItem = NSCollectionViewItem()
            fallbackItem.loadView()
            return fallbackItem
        }

        // Create item manually instead of using makeItem(withIdentifier:)
        // This avoids NSCollectionView's complex instantiation which doesn't work well
        // with our custom loadView() implementation
        let item = FileIconItem(nibName: nil, bundle: nil)

        // Set the layout mode, zoom level, and checkbox visibility before loading the view
        item.isListMode = (currentViewMode == .windowsList)
        item.zoomLevel = zoomLevel
        item.showCheckbox = UserDefaults.standard.bool(forKey: UserDefaults.Keys.enableEasySelect.rawValue)

        item.loadView() // Explicitly load the view
        item.viewDidLoad() // Explicitly call viewDidLoad to set up UI
        item.fileItem = children[indexPath.item]

        print("Successfully created and configured FileIconItem for \(children[indexPath.item].name) in \(item.isListMode ? "list" : "icon") mode")

        return item
    }
}

// MARK: - NSCollectionViewDelegate

extension FileBrowserViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        updateSelectionForDelegate(in: collectionView)
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        updateSelectionForDelegate(in: collectionView)
    }
    
    private func updateSelectionForDelegate(in collectionView: NSCollectionView) {
        let selectedIndexPaths = collectionView.selectionIndexPaths
        if selectedIndexPaths.count == 1, let indexPath = selectedIndexPaths.first {
            if let item = collectionView.item(at: indexPath) as? FileIconItem, let fileItem = item.fileItem {
                delegate?.fileBrowser(self, didSelectFile: fileItem)
            } else {
                delegate?.fileBrowser(self, didSelectFile: nil)
            }
        } else {
            delegate?.fileBrowser(self, didSelectFile: nil)
        }
        updateStatusBar()
    }
}

// MARK: - NSBrowserDelegate

extension FileBrowserViewController: NSBrowserDelegate {
    func browser(_ browser: NSBrowser, numberOfRowsInColumn column: Int) -> Int {
        print("BrowserDelegate: numberOfRowsInColumn: \(column)")
        guard let item = fileItemForColumn(column) else {
            print("BrowserDelegate: fileItemForColumn returned nil for column \(column)")
            return 0
        }
        let count = item.children?.count ?? 0
        print("BrowserDelegate: numberOfRowsInColumn: \(column) -> \(count)")
        return count
    }
    
    func browser(_ browser: NSBrowser, willDisplayCell cell: Any, atRow row: Int, column: Int) {
        print("BrowserDelegate: willDisplayCell at row \(row), column \(column)")
        guard let cell = cell as? NSBrowserCell,
              let item = fileItemForColumn(column),
              let children = item.children,
              row < children.count else {
            print("BrowserDelegate: willDisplayCell guard failed")
            return
        }

        let fileItem = children[row]
        cell.title = fileItem.name
        cell.isLeaf = !fileItem.isDirectory

        if fileItem.isDirectory {
            let icon = NSWorkspace.shared.icon(forFile: fileItem.url.path)

            // Apply custom folder color if set
            if let customColor = ColorManager.shared.getColor(for: fileItem.url) {
                // Create a tinted version of the icon
                let tintedIcon = icon.copy() as! NSImage
                tintedIcon.lockFocus()
                customColor.set()
                let imageRect = NSRect(origin: .zero, size: tintedIcon.size)
                imageRect.fill(using: .sourceAtop)
                tintedIcon.unlockFocus()
                cell.image = tintedIcon
            } else {
                cell.image = icon
            }
        } else {
            cell.image = NSWorkspace.shared.icon(forFile: fileItem.url.path)
        }
    }
    
    func browser(_ browser: NSBrowser, selectRow row: Int, inColumn column: Int) -> Bool {
        print("BrowserDelegate: selectRow \(row) in column \(column)")

        // Get the item for the current column
        guard let item = fileItemForColumn(column),
              let children = item.children,
              row < children.count else {
            print("BrowserDelegate: selectRow guard failed")
            return true
        }

        let selectedItem = children[row]
        print("BrowserDelegate: Selected item: \(selectedItem.name), isDirectory: \(selectedItem.isDirectory)")

        // If this is a directory, load its children
        if selectedItem.isDirectory {
            // Load children if not already loaded
            if selectedItem.children == nil || selectedItem.children?.isEmpty == true {
                print("BrowserDelegate: Loading children for \(selectedItem.name)")
                selectedItem.loadChildren(showsHiddenFiles: showsHiddenFiles) { [weak self] errorMessage in
                    DispatchQueue.main.async {
                        self?.showError(errorMessage)
                    }
                }
                // Sort the children
                if var childrenToSort = selectedItem.children {
                    sortChildren(&childrenToSort)
                    selectedItem.children = childrenToSort
                }
            }
        }

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
        print("BrowserDelegate: fileItemForColumn: \(column)")
        if column == 0 {
            return rootItem
        }
        
        var item = rootItem
        for col in 0..<column {
            let selectedRow = browserView.selectedRow(inColumn: col)
            guard selectedRow >= 0,
                  let children = item?.children,
                  selectedRow < children.count else {
                print("BrowserDelegate: fileItemForColumn guard failed at column \(col)")
                return nil
            }
            item = children[selectedRow]
        }
        
        return item
    }

    func browser(_ browser: NSBrowser, didChangeSelectionInColumn column: Int) {
        if let selectedRows = browser.selectedRowIndexes(inColumn: column),
           selectedRows.count == 1,
           let selectedRow = selectedRows.first {
            if let item = fileItemForColumn(column),
               let children = item.children,
               selectedRow < children.count {
                delegate?.fileBrowser(self, didSelectFile: children[selectedRow])
            } else {
                delegate?.fileBrowser(self, didSelectFile: nil)
            }
        } else {
            delegate?.fileBrowser(self, didSelectFile: nil)
        }
        updateStatusBar()
    }
}