import Cocoa
import Quartz

class FileBrowserViewController: NSViewController, NSMenuDelegate, NSGestureRecognizerDelegate, QLPreviewPanelDataSource, QLPreviewPanelDelegate {

    weak var delegate: FileBrowserDelegate?

    private var toolbarViewController: ToolbarViewController!
    private var containerView: NSView! // New container view
    private var scrollView: NSScrollView! // For outlineView
    private var outlineView: NSOutlineView!
    private var collectionView: NSCollectionView! // For icons view
    private var collectionViewScrollView: NSScrollView! // For collection view
    private var browserView: NSBrowser! // For columns view
    private var freeFormLayout: FreeFormCollectionViewLayout? // Custom layout for free-form icon positioning
    
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
    private var searchFilter: String?

    // Sorting state
    private var sortColumn: String = "NameColumn"
    private var sortAscending: Bool = true
    
    // Zoom level (0.5 to 2.0, default 1.0)
    private var zoomLevel: Double = 1.0
    
    // Free-form icon positioning
    private var isFreeFormEnabled: Bool = true

    // Click tracking for delayed rename
    private var lastClickedRow: Int = -1
    private var lastClickTime: TimeInterval = 0
    private let doubleClickTimeWindow: TimeInterval = 0.5 // Time window for double-click detection
    private let renameClickDelay: TimeInterval = 0.5 // Minimum delay between clicks to trigger rename

    var currentPath: String {
        return currentDirectory.path
    }

    init() {
        // Start at startup folder from settings, or default to home directory
        let startupPath = UserDefaults.standard.string(forKey: UserDefaults.Keys.startupFolder.rawValue) ?? NSHomeDirectory()
        self.currentDirectory = URL(fileURLWithPath: startupPath)
        super.init(nibName: nil, bundle: nil)

        NotificationCenter.default.addObserver(forName: .globalFolderColorDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.globalFolderColorDidChange()
        }
        NotificationCenter.default.addObserver(forName: .showFileExtensionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.settingsDidChange()
        }
        NotificationCenter.default.addObserver(forName: .easySelectDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.settingsDidChange()
        }
    }

    required init?(coder: NSCoder) {
        // Start at startup folder from settings, or default to home directory
        let startupPath = UserDefaults.standard.string(forKey: UserDefaults.Keys.startupFolder.rawValue) ?? NSHomeDirectory()
        self.currentDirectory = URL(fileURLWithPath: startupPath)
        super.init(coder: coder)

        NotificationCenter.default.addObserver(forName: .globalFolderColorDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.globalFolderColorDidChange()
        }
        NotificationCenter.default.addObserver(forName: .showFileExtensionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.settingsDidChange()
        }
        NotificationCenter.default.addObserver(forName: .easySelectDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.settingsDidChange()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .globalFolderColorDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .showFileExtensionsDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .easySelectDidChangeNotification, object: nil)
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
        let deleteWithBackspaceOnly = UserDefaults.standard.bool(forKey: UserDefaults.Keys.deleteWithBackspaceOnly.rawValue)

        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "x" {
            cutSelection()
        } else if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "i" {
            // Cmd+I: Get Info
            contextMenuGetInfo(self)
        } else if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "n" {
            // Cmd+N: New Folder
            contextMenuNewFolder(self)
        } else if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "d" {
            // Cmd+D: Duplicate
            duplicateSelection()
        } else if event.modifierFlags.contains(.command) && event.keyCode == 126 { // Cmd+Up Arrow
            navigateToParent()
        } else if event.modifierFlags.contains(.command) && event.keyCode == 125 { // Cmd+Down Arrow
            openSelection()
        } else if event.keyCode == 36 || event.keyCode == 76 { // Return/Enter key
            openSelection()
        } else if event.keyCode == 49 { // Spacebar
            toggleQuickLook()
        } else if event.keyCode == 53 { // Escape key
            clearSelection()
        } else if event.keyCode == 120 { // F2 key
            renameSelection()
        } else if event.keyCode == 51 { // Backspace/Delete key
            if deleteWithBackspaceOnly {
                // Delete with backspace only (no modifier needed)
                deleteSelection()
            } else if event.modifierFlags.contains(.command) {
                // Default behavior: Command+Delete
                deleteSelection()
            }
        } else {
            super.keyDown(with: event)
        }
    }

    private func deleteSelection() {
        contextMenuDelete(self)
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

    private func openSelection() {
        let items = getSelectedItems()
        guard let item = items.first, items.count == 1 else { return }
        
        if item.isDirectory {
            loadDirectory(item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }
    
    private func navigateToParent() {
        let parent = currentDirectory.deletingLastPathComponent()
        if parent.path != currentDirectory.path {
            loadDirectory(parent)
        }
    }
    
    private func duplicateSelection() {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }
        
        let fileManager = FileManager.default
        for item in items {
            var counter = 1
            var newURL: URL
            let nameWithoutExtension = (item.name as NSString).deletingPathExtension
            let fileExtension = (item.name as NSString).pathExtension
            
            repeat {
                let newName: String
                if fileExtension.isEmpty {
                    newName = "\(nameWithoutExtension) copy \(counter)"
                } else {
                    newName = "\(nameWithoutExtension) copy \(counter).\(fileExtension)"
                }
                newURL = currentDirectory.appendingPathComponent(newName)
                counter += 1
            } while fileManager.fileExists(atPath: newURL.path)
            
            do {
                try fileManager.copyItem(at: item.url, to: newURL)
            } catch {
                showError("Failed to duplicate '\(item.name)': \(error.localizedDescription)")
            }
        }
        refreshCurrentDirectory()
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

        let tagsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TagsColumn"))
        tagsColumn.title = "Tags"
        tagsColumn.width = 150
        tagsColumn.minWidth = 100
        tagsColumn.maxWidth = 250
        tagsColumn.resizingMask = .userResizingMask
        let tagsDescriptor = NSSortDescriptor(key: "tags", ascending: true)
        tagsColumn.sortDescriptorPrototype = tagsDescriptor
        outlineView.addTableColumn(tagsColumn)

        scrollView.documentView = outlineView
        
        // Set delegate and dataSource
        outlineView.delegate = self
        outlineView.dataSource = self

        // Enable drag and drop
        outlineView.registerForDraggedTypes([.fileURL])
        outlineView.setDraggingSourceOperationMask([.copy, .move], forLocal: false)
        outlineView.setDraggingSourceOperationMask([.move], forLocal: true)

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
                self.view.window?.makeFirstResponder(self.view)
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
                freeFormLayout = nil
            } else { // .icons mode
                // Use free-form layout for icon view
                let layout = FreeFormCollectionViewLayout()
                layout.itemSize = NSSize(width: CGFloat(100 * zoomLevel), height: CGFloat(120 * zoomLevel))
                layout.isFreeForm = isFreeFormEnabled
                layout.gridSpacing = 10
                layout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
                collectionView.collectionViewLayout = layout
                freeFormLayout = layout
            }

            collectionView.reloadData()

            // Use dispatch to ensure window is ready
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.view.window?.makeFirstResponder(self.view)
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

                self.view.window?.makeFirstResponder(self.view)
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
        newCollectionView.allowsEmptySelection = true
        newCollectionView.backgroundColors = [.clear]
        newCollectionView.delegate = self
        newCollectionView.dataSource = self

        // Enable drag and drop for collection view
        newCollectionView.registerForDraggedTypes([.fileURL])
        newCollectionView.setDraggingSourceOperationMask([.copy, .move], forLocal: false)
        newCollectionView.setDraggingSourceOperationMask([.move], forLocal: true)

        // NOTE: We don't register a class or NIB for FileIconItem
        // Instead, we'll create items manually in the data source method
        // This avoids the NSCollectionView instantiation issues with custom loadView()

        // Add double-click gesture recognizer for handling double-clicks
        let doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleCollectionViewDoubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        newCollectionView.addGestureRecognizer(doubleClickGesture)
        
        // Add pan gesture for dragging icons in free-form mode
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handleIconDrag(_:)))
        panGesture.delegate = self
        panGesture.delaysPrimaryMouseButtonEvents = false
        newCollectionView.addGestureRecognizer(panGesture)

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
    
    private var draggedItemsInitialPositions: [IndexPath: CGPoint] = [:]
    
    // MARK: - NSGestureRecognizerDelegate
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        // Only allow pan gesture if we're dragging a selected item in free-form mode
        guard let panGesture = gestureRecognizer as? NSPanGestureRecognizer,
              currentViewMode == .icons,
              isFreeFormEnabled,
              let collectionView = collectionView else {
            return false
        }
        
        let location = panGesture.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: location) {
            // Only begin if clicking on a selected item
            return collectionView.selectionIndexPaths.contains(indexPath)
        }
        
        return false
    }
    
    @objc private func handleIconDrag(_ sender: NSPanGestureRecognizer) {
        // Only allow dragging in icon view with free-form enabled
        guard currentViewMode == .icons, isFreeFormEnabled, let collectionView = collectionView, let layout = freeFormLayout else {
            return
        }
        
        let location = sender.location(in: collectionView)
        
        switch sender.state {
        case .began:
            // Find the item being dragged and store initial positions
            if let indexPath = collectionView.indexPathForItem(at: location) {
                draggedItemsInitialPositions.removeAll()
                for indexPath in collectionView.selectionIndexPaths {
                    if let pos = layout.position(for: indexPath) {
                        draggedItemsInitialPositions[indexPath] = pos
                    }
                }
                sender.setTranslation(.zero, in: collectionView)
            }
            
        case .changed:
            // Update all selected items' positions by directly modifying frames
            let translation = sender.translation(in: collectionView)
            
            for indexPath in collectionView.selectionIndexPaths {
                if let initialPos = draggedItemsInitialPositions[indexPath],
                   let item = collectionView.item(at: indexPath) {
                    // Calculate new position
                    let newPos = CGPoint(x: initialPos.x + translation.x,
                                        y: initialPos.y + translation.y)
                    
                    // Update item frame directly for smooth dragging
                    var newFrame = item.view.frame
                    newFrame.origin = newPos
                    item.view.frame = newFrame
                }
            }
            
        case .ended:
            // Commit final positions to layout
            let translation = sender.translation(in: collectionView)
            
            for indexPath in collectionView.selectionIndexPaths {
                if let initialPos = draggedItemsInitialPositions[indexPath] {
                    let finalPos = CGPoint(x: initialPos.x + translation.x,
                                          y: initialPos.y + translation.y)
                    layout.setPositionWithoutInvalidation(finalPos, for: indexPath)
                }
            }
            
            // Invalidate layout once at the end
            layout.invalidateLayout()
            draggedItemsInitialPositions.removeAll()
            
        case .cancelled:
            // Restore original positions
            layout.invalidateLayout()
            draggedItemsInitialPositions.removeAll()
            
        default:
            break
        }
    }





    private func loadDirectory(_ url: URL, addToHistory: Bool = true, isSearch: Bool = false) {
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

        if !isSearch {
            currentDirectory = targetURL
        }

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
            let success = item.loadChildren(showsHiddenFiles: self.showsHiddenFiles, recursive: isSearch) { [weak self] errorMessage in
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
                self.applySearchFilter()
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

    private func applySearchFilter() {
        guard let rootItem = rootItem, let searchText = searchFilter, !searchText.isEmpty else { return }

        // Filter children based on search text
        if var children = rootItem.children {
            children = children.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText)
            }
            rootItem.children = children
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
                if let freeFormLayout = freeFormLayout {
                    // Update free-form layout item size
                    let baseWidth: CGFloat = 100
                    let baseHeight: CGFloat = 120
                    freeFormLayout.itemSize = NSSize(width: baseWidth * zoomLevel, height: baseHeight * zoomLevel)
                    freeFormLayout.invalidateLayout()
                } else {
                    // Fallback to flow layout (shouldn't happen)
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

    func snapToGrid() {
        guard currentViewMode == .icons else { return }
        freeFormLayout?.snapToGrid()
    }
    
    func toggleFreeFormPositioning() {
        guard currentViewMode == .icons else { return }
        isFreeFormEnabled.toggle()
        freeFormLayout?.isFreeForm = isFreeFormEnabled
    }

    // MARK: - Context Menu

    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        let showHotkeys = UserDefaults.standard.bool(forKey: UserDefaults.Keys.showContextMenuHotkeys.rawValue)

        menu.addItem(withTitle: "Open", action: #selector(contextMenuOpen(_:)), keyEquivalent: showHotkeys ? "\r" : "")
        menu.addItem(withTitle: "Open in New Tab", action: #selector(contextMenuOpenInNewTab(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Open With...", action: #selector(contextMenuOpenWith(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        
        let getInfoItem = NSMenuItem(title: "Get Info", action: #selector(contextMenuGetInfo(_:)), keyEquivalent: showHotkeys ? "i" : "")
        if showHotkeys {
            getInfoItem.keyEquivalentModifierMask = .command
        }
        menu.addItem(getInfoItem)
        menu.addItem(NSMenuItem.separator())
        
        let copyItem = NSMenuItem(title: "Copy", action: #selector(contextMenuCopy(_:)), keyEquivalent: showHotkeys ? "c" : "")
        if showHotkeys {
            copyItem.keyEquivalentModifierMask = .command
        }
        menu.addItem(copyItem)
        menu.addItem(withTitle: "Copy To...", action: #selector(contextMenuCopyTo(_:)), keyEquivalent: "")
        
        let cutItem = NSMenuItem(title: "Cut", action: #selector(contextMenuCut(_:)), keyEquivalent: showHotkeys ? "x" : "")
        if showHotkeys {
            cutItem.keyEquivalentModifierMask = .command
        }
        menu.addItem(cutItem)
        menu.addItem(withTitle: "Move To...", action: #selector(contextMenuMoveTo(_:)), keyEquivalent: "")
        
        let pasteItem = NSMenuItem(title: "Paste", action: #selector(contextMenuPaste(_:)), keyEquivalent: showHotkeys ? "v" : "")
        if showHotkeys {
            pasteItem.keyEquivalentModifierMask = .command
        }
        menu.addItem(pasteItem)
        menu.addItem(NSMenuItem.separator())
        
        let renameItem = NSMenuItem(title: "Rename", action: #selector(contextMenuRename(_:)), keyEquivalent: "")
        menu.addItem(renameItem)
        
        let deleteItem = NSMenuItem(title: "Move to Trash", action: #selector(contextMenuDelete(_:)), keyEquivalent: showHotkeys ? String(UnicodeScalar(NSDeleteCharacter)!) : "")
        if showHotkeys {
            deleteItem.keyEquivalentModifierMask = .command
        }
        menu.addItem(deleteItem)
        menu.addItem(NSMenuItem.separator())
        
        let newFolderItem = NSMenuItem(title: "New Folder", action: #selector(contextMenuNewFolder(_:)), keyEquivalent: showHotkeys ? "n" : "")
        if showHotkeys {
            newFolderItem.keyEquivalentModifierMask = .command
        }
        menu.addItem(newFolderItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Add to Favorites", action: #selector(contextMenuAddToFavorites(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        let tagsMenuItem = NSMenuItem(title: "Tags", action: nil, keyEquivalent: "")
        let tagsMenu = NSMenu()
        tagsMenuItem.submenu = tagsMenu
        menu.addItem(tagsMenuItem)
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

        if let tagsMenuItem = menu.items.first(where: { $0.title == "Tags" }) {
            let items = getSelectedItems()
            if items.isEmpty {
                tagsMenuItem.isHidden = true
            } else {
                tagsMenuItem.isHidden = false
                let tagsMenu = tagsMenuItem.submenu!
                tagsMenu.removeAllItems()

                let allTags = getAllTags()
                for tag in allTags {
                    let menuItem = NSMenuItem(title: tag, action: #selector(toggleTag(_:)), keyEquivalent: "")
                    menuItem.target = self
                    menuItem.state = items.allSatisfy({ $0.tags.contains(tag) }) ? .on : .off
                    tagsMenu.addItem(menuItem)
                }

                tagsMenu.addItem(NSMenuItem.separator())
                tagsMenu.addItem(withTitle: "Add New Tag...", action: #selector(addNewTag(_:)), keyEquivalent: "")
            }
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

    private func getAllTags() -> [String] {
        let items = getSelectedItems()
        var allTags = Set<String>()
        for item in items {
            allTags.formUnion(item.tags)
        }
        return allTags.sorted()
    }

    @objc private func toggleTag(_ sender: NSMenuItem) {
        let items = getSelectedItems()
        let tag = sender.title
        let add = sender.state == .off

        for item in items {
            var tags = item.tags
            if add {
                if !tags.contains(tag) {
                    tags.append(tag)
                }
            } else {
                tags.removeAll { $0 == tag }
            }

            do {
                try (item.url as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
            } catch {
                showError("Failed to update tags for \(item.name): \(error.localizedDescription)")
            }
        }
        refreshCurrentDirectory()
    }

    @objc private func addNewTag(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Add New Tag"
        alert.informativeText = "Enter a new tag for the selected items:"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let newTag = textField.stringValue
            if !newTag.isEmpty {
                for item in items {
                    var tags = item.tags
                    if !tags.contains(newTag) {
                        tags.append(newTag)
                    }

                    do {
                        try (item.url as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
                    } catch {
                        showError("Failed to update tags for \(item.name): \(error.localizedDescription)")
                    }
                }
                refreshCurrentDirectory()
            }
        }
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
            let totalSize = items.reduce(0) { $0 + $1.size }
            let sizeString = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)

            let availableSpace = try? destinationURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
            let availableSpaceString = availableSpace.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "N/A"

            let alert = NSAlert()
            alert.messageText = "Copy Items"
            alert.informativeText = "Are you sure you want to copy \(items.count) item(s) (\(sizeString)) to \(destinationURL.lastPathComponent)?\n\nAvailable space: \(availableSpaceString)"
            alert.addButton(withTitle: "Copy")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                // let progressViewController = ProgressViewController()
                // self.presentAsSheet(progressViewController)

                DispatchQueue.global(qos: .userInitiated).async {
                    let fileManager = FileManager.default
                    let total = items.count
                    for (index, item) in items.enumerated() {
                        let destinationItemURL = destinationURL.appendingPathComponent(item.name)
                        do {
                            try fileManager.copyItem(at: item.url, to: destinationItemURL)
                            let percent = Double(index + 1) / Double(total) * 100
                            DispatchQueue.main.async {
                                // progressViewController.updateProgress(percent: percent, status: "Copying \(item.name)...")
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self.showError("Failed to copy '\(item.name)': \(error.localizedDescription)")
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        // self.dismiss(progressViewController)
                        self.refreshCurrentDirectory()
                    }
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
            let totalSize = items.reduce(0) { $0 + $1.size }
            let sizeString = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)

            let availableSpace = try? destinationURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
            let availableSpaceString = availableSpace.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "N/A"

            let alert = NSAlert()
            alert.messageText = "Move Items"
            alert.informativeText = "Are you sure you want to move \(items.count) item(s) (\(sizeString)) to \(destinationURL.lastPathComponent)?\n\nAvailable space: \(availableSpaceString)"
            alert.addButton(withTitle: "Move")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                // let progressViewController = ProgressViewController()
                // self.presentAsSheet(progressViewController)

                DispatchQueue.global(qos: .userInitiated).async {
                    let fileManager = FileManager.default
                    let total = items.count
                    for (index, item) in items.enumerated() {
                        let destinationItemURL = destinationURL.appendingPathComponent(item.name)
                        do {
                            try fileManager.moveItem(at: item.url, to: destinationItemURL)
                            let percent = Double(index + 1) / Double(total) * 100
                            DispatchQueue.main.async {
                                // progressViewController.updateProgress(percent: percent, status: "Moving \(item.name)...")
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self.showError("Failed to move '\(item.name)': \(error.localizedDescription)")
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        // self.dismiss(progressViewController)
                        self.refreshCurrentDirectory()
                    }
                }
            }
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

        let totalSize = items.reduce(0) { $0 + $1.size }
        let sizeString = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)

        let alert = NSAlert()
        alert.messageText = "Move to Trash"
        alert.informativeText = "Are you sure you want to move \(items.count) item(s) (\(sizeString)) to trash?"
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

    @objc private func contextMenuAddToFavorites(_ sender: Any) {
        let items = getSelectedItems()
        guard let item = items.first, items.count == 1 else { return }

        delegate?.fileBrowserDidRequestAddToFavorites(self, item: item)
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

    private func settingsDidChange() {
        // Reload all views to apply changed settings (like file extensions, easy select, etc.)
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
            textField.stringValue = fileItem.displayName
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
        } else if identifier == "TagsColumn" {
            let cellView = NSTableCellView()
            let textField = NSTextField()
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = false
            textField.stringValue = fileItem.tags.joined(separator: ", ")
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

    func outlineView(_ outlineView: NSOutlineView, writeItems items: [Any], to pasteboard: NSPasteboard) -> Bool {
        let fileItems = items.compactMap { $0 as? FileItem }
        guard !fileItems.isEmpty else { return false }

        let urls = fileItems.map { $0.url as NSURL }
        pasteboard.clearContents()
        pasteboard.writeObjects(urls)
        return true
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        guard let targetItem = item as? FileItem, targetItem.isDirectory else {
            return []
        }

        // Allow dropping onto folders
        return .copy
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let targetItem = item as? FileItem,
              let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }

        let destinationURL = targetItem.url
        let fileManager = FileManager.default
        var allSucceeded = true

        for sourceURL in urls {
            let fileName = sourceURL.lastPathComponent
            let targetURL = destinationURL.appendingPathComponent(fileName)

            // Skip if source and destination are the same
            if sourceURL == targetURL {
                continue
            }

            do {
                try fileManager.moveItem(at: sourceURL, to: targetURL)
            } catch {
                print("Failed to move \(sourceURL) to \(targetURL): \(error)")
                allSucceeded = false
            }
        }

        // Reload the view to show changes
        if allSucceeded {
            refreshCurrentDirectory()
        }

        return allSucceeded
    }
}

// MARK: - Free Form Collection View Layout

class FreeFormCollectionViewLayout: NSCollectionViewLayout {
    
    // Store item positions - keyed by index path
    private var itemPositions: [IndexPath: CGPoint] = [:]
    private var itemAttributes: [IndexPath: NSCollectionViewLayoutAttributes] = [:]
    
    // Item size
    var itemSize: NSSize = NSSize(width: 100, height: 120)
    
    // Flag to enable/disable free form positioning
    var isFreeForm: Bool = true {
        didSet {
            if !isFreeForm {
                // Reset to grid when disabled
                resetToGrid()
            }
        }
    }
    
    // Grid settings
    var gridSpacing: CGFloat = 10
    var sectionInset: NSEdgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    
    override var collectionViewContentSize: NSSize {
        guard let collectionView = collectionView else { return .zero }
        
        if isFreeForm && !itemPositions.isEmpty {
            // Calculate bounds based on positioned items
            var maxX: CGFloat = 0
            var maxY: CGFloat = 0
            
            for (_, position) in itemPositions {
                maxX = max(maxX, position.x + itemSize.width)
                maxY = max(maxY, position.y + itemSize.height)
            }
            
            return NSSize(width: max(maxX + sectionInset.right, collectionView.bounds.width),
                         height: max(maxY + sectionInset.bottom, collectionView.bounds.height))
        } else {
            // Grid layout - calculate based on number of items
            let numberOfItems = collectionView.numberOfItems(inSection: 0)
            guard numberOfItems > 0 else { return collectionView.bounds.size }
            
            let availableWidth = collectionView.bounds.width - sectionInset.left - sectionInset.right
            let columns = max(1, Int(availableWidth / (itemSize.width + gridSpacing)))
            let rows = Int(ceil(Double(numberOfItems) / Double(columns)))
            
            let contentHeight = sectionInset.top + CGFloat(rows) * (itemSize.height + gridSpacing) + sectionInset.bottom
            
            return NSSize(width: collectionView.bounds.width, height: max(contentHeight, collectionView.bounds.height))
        }
    }
    
    override func prepare() {
        super.prepare()
        
        guard let collectionView = collectionView else { return }
        
        itemAttributes.removeAll()
        
        let numberOfItems = collectionView.numberOfItems(inSection: 0)
        
        for item in 0..<numberOfItems {
            let indexPath = IndexPath(item: item, section: 0)
            let attributes = NSCollectionViewLayoutAttributes(forItemWith: indexPath)
            
            let position: CGPoint
            
            if isFreeForm, let savedPosition = itemPositions[indexPath] {
                // Use saved free-form position
                position = savedPosition
            } else {
                // Calculate grid position
                position = gridPosition(for: item)
                if isFreeForm {
                    // Save initial grid position for free-form mode
                    itemPositions[indexPath] = position
                }
            }
            
            attributes.frame = NSRect(origin: position, size: itemSize)
            itemAttributes[indexPath] = attributes
        }
    }
    
    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        return itemAttributes.values.filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        return itemAttributes[indexPath]
    }
    
    // MARK: - Position Management
    
    func setPosition(_ position: CGPoint, for indexPath: IndexPath) {
        itemPositions[indexPath] = position
        invalidateLayout()
    }
    
    func setPositionWithoutInvalidation(_ position: CGPoint, for indexPath: IndexPath) {
        itemPositions[indexPath] = position
    }
    
    func position(for indexPath: IndexPath) -> CGPoint? {
        return itemPositions[indexPath]
    }
    
    func resetToGrid() {
        itemPositions.removeAll()
        invalidateLayout()
    }
    
    func snapToGrid() {
        // Snap all items to nearest grid position
        guard let collectionView = collectionView else { return }
        
        let numberOfItems = collectionView.numberOfItems(inSection: 0)
        var gridPositions: [CGPoint] = []
        
        // Calculate all grid positions
        for item in 0..<numberOfItems {
            gridPositions.append(gridPosition(for: item))
        }
        
        // For each item, find the closest available grid position
        var usedPositions = Set<Int>()
        var newPositions: [IndexPath: CGPoint] = [:]
        
        for item in 0..<numberOfItems {
            let indexPath = IndexPath(item: item, section: 0)
            guard let currentPos = itemPositions[indexPath] else { continue }
            
            // Find closest grid position
            var closestIndex = 0
            var closestDistance = CGFloat.greatestFiniteMagnitude
            
            for (index, gridPos) in gridPositions.enumerated() {
                if usedPositions.contains(index) { continue }
                
                let distance = hypot(currentPos.x - gridPos.x, currentPos.y - gridPos.y)
                if distance < closestDistance {
                    closestDistance = distance
                    closestIndex = index
                }
            }
            
            usedPositions.insert(closestIndex)
            newPositions[indexPath] = gridPositions[closestIndex]
        }
        
        itemPositions = newPositions
        invalidateLayout()
    }
    
    private func gridPosition(for item: Int) -> CGPoint {
        guard let collectionView = collectionView else { return .zero }
        
        let availableWidth = collectionView.bounds.width - sectionInset.left - sectionInset.right
        let columns = max(1, Int(availableWidth / (itemSize.width + gridSpacing)))
        
        let row = item / columns
        let column = item % columns
        
        let x = sectionInset.left + CGFloat(column) * (itemSize.width + gridSpacing)
        let y = sectionInset.top + CGFloat(row) * (itemSize.height + gridSpacing)
        
        return CGPoint(x: x, y: y)
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
        NotificationCenter.default.post(name: Notification.Name("hiddenFilesToggled"), object: nil)
    }

    func isShowingHiddenFiles() -> Bool {
        return showsHiddenFiles
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

    func toolbarDidSearchTextChange(_ searchText: String) {
        searchFilter = searchText.isEmpty ? nil : searchText
        loadDirectory(currentDirectory, addToHistory: false, isSearch: !searchText.isEmpty)
    }

    func toolbarDidTogglePreviewPane() {
        (parent as? SplitPaneViewController)?.togglePreviewPane()
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
    
    // MARK: - Drag and Drop Support
    
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let fileItem = item as? FileItem else { return nil }
        return fileItem.url as NSURL
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
        let selectedFileItems = indexPaths.compactMap { indexPath -> FileItem? in
            guard let item = self.rootItem.children?[indexPath.item] else { return nil }
            return item
        }

        if selectedFileItems.count == 1 {
            delegate?.fileBrowser(self, didSelectFile: selectedFileItems.first)
        } else {
            delegate?.fileBrowser(self, didSelectFile: nil)
        }
        updateStatusBar()
    }

    func collectionView(_ collectionView: NSCollectionView, writeItemsAt indexPaths: Set<IndexPath>, to pasteboard: NSPasteboard) -> Bool {
        let fileItems = indexPaths.compactMap { indexPath -> FileItem? in
            guard let item = self.rootItem.children?[indexPath.item] else { return nil }
            return item
        }
        guard !fileItems.isEmpty else { return false }

        let urls = fileItems.map { $0.url as NSURL }
        pasteboard.clearContents()
        pasteboard.writeObjects(urls)
        return true
    }

    func collectionView(_ collectionView: NSCollectionView, validateDrop draggingInfo: NSDraggingInfo, proposedIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>, dropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        if dropOperation.pointee == .on {
            let indexPath = proposedIndexPath.pointee
            guard let item = self.rootItem.children?[indexPath.item], item.isDirectory else {
                return []
            }
            return .copy
        }
        return .copy
    }

    func collectionView(_ collectionView: NSCollectionView, acceptDrop draggingInfo: NSDraggingInfo, indexPath: IndexPath, dropOperation: NSCollectionView.DropOperation) -> Bool {
        guard let urls = draggingInfo.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }

        let destinationURL: URL
        if let item = self.rootItem.children?[indexPath.item], item.isDirectory {
            destinationURL = item.url
        } else {
            destinationURL = self.currentDirectory
        }

        let fileManager = FileManager.default
        var allSucceeded = true

        for sourceURL in urls {
            let fileName = sourceURL.lastPathComponent
            let targetURL = destinationURL.appendingPathComponent(fileName)

            // Skip if source and destination are the same
            if sourceURL == targetURL {
                continue
            }

            do {
                try fileManager.moveItem(at: sourceURL, to: targetURL)
            } catch {
                print("Failed to move \(sourceURL) to \(targetURL): \(error)")
                allSucceeded = false
            }
        }

        // Reload the view to show changes
        if allSucceeded {
            refreshCurrentDirectory()
        }

        return allSucceeded
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
        cell.title = fileItem.displayName
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
// MARK: - Quick Look

extension FileBrowserViewController {

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.delegate = self
        panel.dataSource = self
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.delegate = nil
        panel.dataSource = nil
    }

    private func toggleQuickLook() {
        if QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible {
            QLPreviewPanel.shared().orderOut(nil)
        } else {
            QLPreviewPanel.shared().makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        let items = getSelectedItems()
        return items.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        let items = getSelectedItems()
        guard index < items.count else { return nil }
        return items[index].url as QLPreviewItem
    }

    // MARK: - QLPreviewPanelDelegate

    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        // Handle keyboard events in the preview panel
        if event.type == .keyDown {
            if event.keyCode == 49 { // Spacebar - close preview
                panel.orderOut(nil)
                return true
            } else if event.keyCode == 53 { // Escape - close preview
                panel.orderOut(nil)
                return true
            }
        }
        return false
    }

    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        // Return the frame of the selected item for animation
        guard let url = item as? URL else { return .zero }

        // Find the item in the current view
        let items = getSelectedItems()
        guard let index = items.firstIndex(where: { $0.url == url }) else { return .zero }

        // Get the frame based on current view mode
        switch currentViewMode {
        case .list:
            let row = outlineView.selectedRow
            if row >= 0 {
                let rowRect = outlineView.rect(ofRow: row)
                return view.window?.convertToScreen(view.convert(rowRect, to: nil)) ?? .zero
            }
        case .icons, .windowsList:
            if let collectionView = collectionView {
                let indexPath = IndexPath(item: index, section: 0)
                if let itemFrame = collectionView.layoutAttributesForItem(at: indexPath)?.frame {
                    return view.window?.convertToScreen(view.convert(itemFrame, to: nil)) ?? .zero
                }
            }
        case .columns:
            // For column view, use a default position
            return .zero
        }

        return .zero
    }
}
