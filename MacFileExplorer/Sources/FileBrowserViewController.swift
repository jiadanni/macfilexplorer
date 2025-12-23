import Cocoa
import Quartz

// Simple toast/info presentation helper.
extension FileBrowserViewController {
    func showInfo(_ message: String) {
        // Non-blocking informational banner (replaces prior modal alert)
        showBanner(message: message, style: .info)
    }

    enum BannerStyle {
        case info
        case error
    }

    private func showBanner(message: String, style: BannerStyle) {
        bannerDismissTask?.cancel()

        if bannerContainer == nil {
            let container = NSView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.wantsLayer = true
            view.addSubview(container)
            NSLayoutConstraint.activate([
                container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
                container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -12),
                container.bottomAnchor.constraint(equalTo: statusBarViewController.view.topAnchor, constant: -6),
                container.heightAnchor.constraint(greaterThanOrEqualToConstant: 24)
            ])
            bannerContainer = container
        }

        guard let bannerContainer else { return }
        bannerContainer.subviews.forEach { $0.removeFromSuperview() }
        bannerContainer.isHidden = false

        let label = NSTextField(labelWithString: message)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = (style == .info) ? .labelColor : .systemRed
        bannerContainer.addSubview(label)

        bannerContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9).cgColor
        bannerContainer.layer?.cornerRadius = 6

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: bannerContainer.topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: bannerContainer.bottomAnchor, constant: -5)
        ])

        bannerDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self?.bannerContainer?.isHidden = true
        }
    }
}

// Cancellation token reference type
extension FileBrowserViewController: NSSplitViewDelegate {
    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard previewVisible, let pv = previewPaneViewController?.view else { return }
        let width = pv.bounds.width
        if width > 100 { // persist only reasonable widths
            settings.previewPaneWidth = width
        }
    }
}
final class CancellationToken {
    private let lock = DispatchSemaphore(value: 1)
    private var _isCancelled = false
    var isCancelled: Bool { lock.wait(); defer { lock.signal() }; return _isCancelled }
    func cancel() { lock.wait(); _isCancelled = true; lock.signal() }
}

class FileBrowserViewController: NSViewController, NSMenuDelegate, NSGestureRecognizerDelegate, QLPreviewPanelDataSource, QLPreviewPanelDelegate, StatusBarDelegate, ToolbarDelegate, NSOutlineViewDelegate, NSOutlineViewDataSource {

    weak var delegate: FileBrowserDelegate?
    
    var settings: SettingsStoreProtocol

    internal var toolbarViewController: ToolbarViewController!
    internal var statusBarViewController: StatusBarViewController!
    var containerView: NSView! // New container view
    var scrollView: NSScrollView! // For outlineView
    var outlineView: NSOutlineView!
    var collectionView: NSCollectionView? // For icons view
    var collectionViewScrollView: NSScrollView! // For collection view
    var browserView: NSBrowser? // For columns view
    var zoomControlsAllowedByPane = true // Gated by active pane; combined with view mode to show/hide slider.
    var freeFormLayout: FreeFormCollectionViewLayout? // Custom layout for free-form icon positioning
    // Per-pane preview management
    private var previewSplitView: NSSplitView?
    private var previewPaneViewController: PreviewPaneViewController?
    var previewVisible: Bool = false
    
    // Constraint management for view switching
    var activeConstraints: [NSLayoutConstraint] = []

    var dataSource: FileBrowserDataSource!

    // Wrapper properties for DataSource delegation
    var currentDirectory: URL {
        return dataSource.currentDirectory
    }
    
    var rootItem: FileItem? {
        return dataSource.rootItem
    }
    
    var showsHiddenFiles: Bool {
        get { dataSource.showsHiddenFiles }
        set { dataSource.showsHiddenFiles = newValue }
    }
    
    var sortColumn: String {
        get { dataSource.sortColumn }
        set { dataSource.sortColumn = newValue }
    }
    
    var sortAscending: Bool {
        get { dataSource.sortAscending }
        set { dataSource.sortAscending = newValue }
    }
    
    var searchFilter: String? {
        get { dataSource.searchFilter }
        set { dataSource.searchFilter = newValue }
    }
    
    var filterCriteria: FilterCriteria {
        get { dataSource.filterCriteria }
        set { dataSource.filterCriteria = newValue }
    }

    var currentViewMode: ViewMode = .list // Default view mode
    private let filterCoordinator = FileBrowserFilterCoordinator()
    let selectionCoordinator = FileBrowserSelectionCoordinator()
    var navigationCoordinator: FileBrowserNavigationCoordinator!
    lazy var viewModeCoordinator = FileBrowserViewModeCoordinator(owner: self)
    

    // Zoom & Layout
    var zoomLevel: Double = 1.0
    var isFreeFormEnabled: Bool = true
    
    // Helpers
    let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    // Banner notification handling
    private var bannerContainer: NSView?
    private var bannerDismissTask: Task<Void, Never>?

    // Click tracking for delayed rename
    private var lastClickedRow: Int = -1
    private var lastClickTime: TimeInterval = 0
    private let doubleClickTimeWindow: TimeInterval = 0.5
    private let renameClickDelay: TimeInterval = 0.5

    var currentPath: String {
        return currentDirectory.path
    }

    lazy var fileOperationsManager: FileOperationsManager = {
        return FileOperationsManager(delegate: self)
    }()

    // MARK: - Validation Wrappers (to be used by extensions)
    
    func isValidDestination(_ destination: URL, for urls: [URL]) -> Bool {
        return fileOperationsManager.isValidDestination(destination, for: urls)
    }
    
    func preferredDragOperation(from info: NSDraggingInfo) -> FileOperationType? {
        return fileOperationsManager.preferredDragOperation(from: info)
    }

    init(settings: SettingsStoreProtocol = SettingsStore.shared) {
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        self.settings = SettingsStore.shared
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        // Start at startup folder from settings, or default to home directory
        let startupPath = settings.startupFolder ?? NSHomeDirectory()
        let startUrl = URL(fileURLWithPath: startupPath)
        
        self.dataSource = FileBrowserDataSource(currentDirectory: startUrl)
        self.dataSource.delegate = self

        navigationCoordinator = FileBrowserNavigationCoordinator()
        navigationCoordinator.delegate = self
        selectionCoordinator.delegate = self
        
        // Load persisted hidden files state
        self.dataSource.showsHiddenFiles = settings.hiddenFilesState
        
        // Load default view & sort (search remains nil)
        currentViewMode = settings.defaultViewMode
        
        let defaultSort = settings.defaultSortColumn
        if !defaultSort.isEmpty {
            self.dataSource.sortColumn = defaultSort
        }
        self.dataSource.sortAscending = settings.defaultSortAscending

        filterCoordinator.delegate = self
        filterCoordinator.initialize()
        filterCriteria = filterCoordinator.getFilterCriteria()

        NotificationCenter.default.addObserver(forName: .globalFolderColorDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshCurrentDirectory()
        }
        NotificationCenter.default.addObserver(forName: .showFileExtensionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshCurrentDirectory()
        }
        NotificationCenter.default.addObserver(forName: .easySelectDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshCurrentDirectory()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .globalFolderColorDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .showFileExtensionsDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .easySelectDidChangeNotification, object: nil)
    }

    override func loadView() {
        let root = RootFileBrowserView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        root.dropDelegate = self
        view = root
        setupUI()
        navigationCoordinator.loadDirectory(currentDirectory)
        // Initial preview visibility from global default applied per pane
        let defaultShowPreview = settings.previewPaneVisible
        if defaultShowPreview { showPreviewPane() }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(outlineView) // Make outlineView the first responder
    }

    override func keyDown(with event: NSEvent) {
        let deleteWithBackspaceOnly = settings.deleteWithBackspaceOnly

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
            navigationCoordinator.navigateToParent()
        } else if event.modifierFlags.contains(.command) && event.keyCode == 125 { // Cmd+Down Arrow
            openSelection()
        } else if event.keyCode == 36 || event.keyCode == 76 { // Return/Enter key
            openSelection()
        } else if event.keyCode == 49 { // Spacebar
            toggleQuickLook()
        } else if event.keyCode == 53 { // Escape key
            clearSelection()
        } else if event.keyCode == 120 { // F2 key
            let items = getSelectedItems()
            if let item = items.first, items.count == 1 {
                contextMenuRename(item)
            }
        } else if event.keyCode == 51 { // Backspace/Delete key
            if deleteWithBackspaceOnly {
                // Delete with backspace only (no modifier needed)
                contextMenuDelete(self)
            } else if event.modifierFlags.contains(.command) {
                // Default behavior: Command+Delete
                contextMenuDelete(self)
            }
        } else {
            super.keyDown(with: event)
        }
    }

    
    private func openSelection() {
        let items = selectionCoordinator.selectedItems()
        guard let item = items.first, items.count == 1 else { return }
        
        if item.isDirectory {
            navigationCoordinator.loadDirectory(item.url)
        } else {
            FileBrowserActionHelper.openFile(item.url)
        }
    }
    
    private func duplicateSelection() {
        let items = selectionCoordinator.selectedItems()
        guard !items.isEmpty else { return }
        
        for item in items {
            do {
                let _ = try FileBrowserActionHelper.duplicate(item.url)
            } catch {
                showError("Failed to duplicate '\(item.name)': \(error.localizedDescription)")
            }
        }
        refreshCurrentDirectory()
    }

    private func setupUI() {
        setupToolbar()
        setupStatusBar()
        setupContainerAndOutlineView()
        setupOutlineViewColumns()
        setupOutlineViewBehavior()
        setupConstraints()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        viewModeCoordinator.displayFiles(for: currentViewMode)
        updateZoomControlVisibility()
    }

    private func setupToolbar() {
        toolbarViewController = ToolbarViewController()
        toolbarViewController.delegate = self
        addChild(toolbarViewController)
        view.addSubview(toolbarViewController.view)
        toolbarViewController.view.translatesAutoresizingMaskIntoConstraints = false
        toolbarViewController?.updateViewModeDisplay(for: currentViewMode)
        toolbarViewController?.updateSortDisplay(column: sortColumn, ascending: sortAscending)
    }

    private func setupStatusBar() {
        statusBarViewController = StatusBarViewController()
        statusBarViewController.delegate = self
        addChild(statusBarViewController)
        view.addSubview(statusBarViewController.view)
        statusBarViewController.view.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupContainerAndOutlineView() {
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        outlineView = NSOutlineView()
        outlineView.setAccessibilityElement(true)
        outlineView.setAccessibilityRole(.table)
        outlineView.setAccessibilityLabel(L10n.text("File list"))
        outlineView.style = .fullWidth
        outlineView.floatsGroupRows = false
        outlineView.rowSizeStyle = .default
        outlineView.usesAlternatingRowBackgroundColors = true
        outlineView.allowsMultipleSelection = true
        outlineView.autoresizesOutlineColumn = false
        outlineView.doubleAction = #selector(outlineViewDoubleClicked(_:))
        outlineView.target = self
        outlineView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        outlineView.headerView = NSTableHeaderView()
        scrollView.documentView = outlineView
    }

    private func setupOutlineViewColumns() {
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(AppConfig.ColumnID.name))
        nameColumn.title = L10n.text("Name")
        nameColumn.width = 250
        nameColumn.minWidth = 100
        nameColumn.maxWidth = 500
        nameColumn.resizingMask = .userResizingMask
        nameColumn.sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true)
        outlineView.addTableColumn(nameColumn)
        outlineView.outlineTableColumn = nameColumn

        let dateModifiedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(AppConfig.ColumnID.dateModified))
        dateModifiedColumn.title = L10n.text("Date Modified")
        dateModifiedColumn.width = 150
        dateModifiedColumn.minWidth = 100
        dateModifiedColumn.maxWidth = 250
        dateModifiedColumn.resizingMask = .userResizingMask
        dateModifiedColumn.sortDescriptorPrototype = NSSortDescriptor(key: "modificationDate", ascending: false)
        outlineView.addTableColumn(dateModifiedColumn)

        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(AppConfig.ColumnID.type))
        typeColumn.title = L10n.text("Type")
        typeColumn.width = 120
        typeColumn.minWidth = 80
        typeColumn.maxWidth = 200
        typeColumn.resizingMask = .userResizingMask
        typeColumn.sortDescriptorPrototype = NSSortDescriptor(key: "kind", ascending: true)
        outlineView.addTableColumn(typeColumn)

        let sizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(AppConfig.ColumnID.size))
        sizeColumn.title = L10n.text("Size")
        sizeColumn.width = 100
        sizeColumn.minWidth = 60
        sizeColumn.maxWidth = 150
        sizeColumn.resizingMask = .userResizingMask
        sizeColumn.sortDescriptorPrototype = NSSortDescriptor(key: "size", ascending: false)
        outlineView.addTableColumn(sizeColumn)

        let dateCreatedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(AppConfig.ColumnID.dateCreated))
        dateCreatedColumn.title = L10n.text("Date Created")
        dateCreatedColumn.width = 150
        dateCreatedColumn.minWidth = 100
        dateCreatedColumn.maxWidth = 250
        dateCreatedColumn.resizingMask = .userResizingMask
        dateCreatedColumn.sortDescriptorPrototype = NSSortDescriptor(key: "creationDate", ascending: false)
        outlineView.addTableColumn(dateCreatedColumn)

        let tagsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TagsColumn"))
        tagsColumn.title = L10n.text("Tags")
        tagsColumn.width = 150
        tagsColumn.minWidth = 100
        tagsColumn.maxWidth = 250
        tagsColumn.resizingMask = .userResizingMask
        tagsColumn.sortDescriptorPrototype = NSSortDescriptor(key: "tags", ascending: true)
        outlineView.addTableColumn(tagsColumn)

        var columnVisibility = settings.columnVisibility
        if columnVisibility.isEmpty {
            columnVisibility = [
                AppConfig.ColumnID.name: true,
                AppConfig.ColumnID.dateModified: true,
                AppConfig.ColumnID.type: true,
                AppConfig.ColumnID.size: true,
                AppConfig.ColumnID.dateCreated: false,
                "TagsColumn": false
            ]
            settings.columnVisibility = columnVisibility
        }
        applyColumnVisibility(columnVisibility)
        outlineView.headerView?.menu = createHeaderColumnsMenu()
    }

    private func setupOutlineViewBehavior() {
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.registerForDraggedTypes([.fileURL])
        outlineView.setDraggingSourceOperationMask([.copy, .move], forLocal: false)
        outlineView.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
        outlineView.menu = createContextMenu()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            toolbarViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            toolbarViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbarViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbarViewController.view.heightAnchor.constraint(equalToConstant: 84),

            containerView.topAnchor.constraint(equalTo: toolbarViewController.view.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: statusBarViewController.view.topAnchor),

            statusBarViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusBarViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusBarViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            statusBarViewController.view.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    // Ensure active content view is embedded in preview split if preview visible
    func ensureContentInPreviewSplit() {
        guard previewVisible else { return }
        guard let contentView = currentActiveContentView() else { return }
        if previewSplitView == nil {
            let split = NSSplitView()
            split.translatesAutoresizingMaskIntoConstraints = false
            split.isVertical = true
            split.dividerStyle = .thin
            previewSplitView = split
            containerView.addSubview(split)
            NSLayoutConstraint.activate([
                split.topAnchor.constraint(equalTo: containerView.topAnchor),
                split.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                split.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                split.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
        }
        guard let split = previewSplitView else { return }
        
        // Ensure preview pane exists first
        if previewPaneViewController == nil {
            let previewVC = PreviewPaneViewController()
            previewVC.position = .right
            addChild(previewVC)
            previewPaneViewController = previewVC
        }

        // Always ensure correct order: content view at index 0, preview at index 1
        // Remove both views first to reset order
        contentView.removeFromSuperview()
        previewPaneViewController?.view.removeFromSuperview()

        // Add content view first (left side)
        split.insertArrangedSubview(contentView, at: 0)

        // Add preview pane second (right side)
        let pv = previewPaneViewController!.view
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        pv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        split.insertArrangedSubview(pv, at: 1)

        // Set delegate only once
        if split.delegate == nil {
            split.delegate = self
        }

        // Apply saved width if available
        let savedWidth = Double(settings.previewPaneWidth)
        let widthToApply = savedWidth > 100 ? savedWidth : 300.0 // Default to 300 if no saved width
        Task { @MainActor [weak split] in
            guard let split else { return }
            let total = split.bounds.width
            let position = max(0, total - CGFloat(widthToApply))
            split.setPosition(position, ofDividerAt: 0)
        }

        // Show current selection
        if let sel = selectionCoordinator.currentSingleSelection() {
            previewPaneViewController?.previewFile(sel)
        }
    }

    private func dismantlePreviewSplit() {
        guard let split = previewSplitView else { return }
        // Move active content view back to container
        if let contentView = currentActiveContentView() {
            contentView.removeFromSuperview()
            containerView.addSubview(contentView)
            NSLayoutConstraint.activate([
                contentView.topAnchor.constraint(equalTo: containerView.topAnchor),
                contentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                contentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
        }
        previewPaneViewController?.view.removeFromSuperview()
        previewPaneViewController?.removeFromParent()
        previewPaneViewController = nil
        split.removeFromSuperview()
        previewSplitView = nil
    }

    private func currentActiveContentView() -> NSView? {
        switch currentViewMode {
        case .list: return scrollView
        case .icons, .windowsList: return collectionViewScrollView
        case .columns: return browserView
        }
    }

    // Update preview pane with a newly selected file or clear if nil/multiple
    func updatePreviewPane(with file: FileItem?) {
        guard previewVisible, let previewVC = previewPaneViewController else { return }
        if let file {
            previewVC.previewFile(file)
        } else {
            previewVC.resetPreview()
        }
    }

    func showPreviewPane() {
        previewVisible = true
        ensureContentInPreviewSplit()
        toolbarViewController.updatePreviewPaneDisplay(showing: true)
    }

    func hidePreviewPane() {
        previewVisible = false
        dismantlePreviewSplit()
        toolbarViewController.updatePreviewPaneDisplay(showing: false)
    }

    @objc func handleBrowserDoubleClick(_ sender: NSBrowser) {
        guard let browserView = browserView else { return }
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
            navigationCoordinator.loadDirectory(fileItem.url)
        } else {
            FileBrowserActionHelper.openFile(fileItem.url)
        }
    }
    
    @objc func handleCollectionViewDoubleClick(_ sender: NSClickGestureRecognizer) {
        guard let collectionView = collectionView else { return }
        let point = sender.location(in: collectionView)
        
        if let indexPath = collectionView.indexPathForItem(at: point),
           let item = collectionView.item(at: indexPath) as? FileIconItem,
           let fileItem = item.fileItem {
            
            if fileItem.isDirectory {
                navigationCoordinator.loadDirectory(fileItem.url)
            } else {
                FileBrowserActionHelper.openFile(fileItem.url)
            }
        }
    }
    
    private var draggedItemsInitialPositions: [IndexPath: CGPoint] = [: ]
    
    // MARK: - NSGestureRecognizerDelegate
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        // Only allow pan gesture if we're dragging a selected item in free-form mode
        guard let panGesture = gestureRecognizer as? NSPanGestureRecognizer,
              currentViewMode == .icons,
              isFreeFormEnabled,
              let collectionView = collectionView else { return false }
        
        let location = panGesture.location(in: collectionView)
        guard let hitIndexPath = collectionView.indexPathForItem(at: location) else { return false }
        return collectionView.selectionIndexPaths.contains(hitIndexPath)
    }
    
    @objc func handleIconDrag(_ sender: NSPanGestureRecognizer) {
        // Only allow dragging in icon view with free-form enabled
        guard currentViewMode == .icons, isFreeFormEnabled, let collectionView = collectionView, let layout = freeFormLayout else { return }
        
        let location = sender.location(in: collectionView)
        
        switch sender.state {
        case .began:
            // Find the item being dragged and store initial positions
            if collectionView.indexPathForItem(at: location) != nil {
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

    func refreshCurrentDirectory() {
        debugLog("Refreshing current directory")
        dataSource.reload()
    }

    // Sorting and Filtering now delegated to DataSource
    func sortItems() {
        // No-op or trigger datasource
        // Delegated to dataSource properties which auto-sort
    }

    func applySearchFilter() {
        // No-op or trigger datasource
        // Delegated to dataSource properties
    }

    private func toggleQuickLook() {
        if QLPreviewPanel.shared()?.isVisible == true {
            QLPreviewPanel.shared()?.orderOut(nil)
        } else if let panel = QLPreviewPanel.shared() {
            panel.dataSource = self
            panel.delegate = self
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func dragSourceFileBrowser(from info: NSDraggingInfo) -> FileBrowserViewController? {
        guard let responder = info.draggingSource as? NSResponder else { return nil }
        var current: NSResponder? = responder
        while let c = current {
            if let vc = c as? FileBrowserViewController { return vc }
            current = c.nextResponder
        }
        return nil
    }

    func updateStatusBarDisplay(selectedCount: Int, totalSize: Int64) {
        let diskSpace = FileBrowserActionHelper.formatDiskSpace(
            FileBrowserActionHelper.getAvailableDiskSpace(for: currentDirectory)
        )
        statusBarViewController?.updateFileInformation(selectedCount: selectedCount, totalSize: totalSize, diskSpace: diskSpace)
        delegate?.fileBrowser(self, didUpdateSelection: selectedCount, totalSize: totalSize)
        delegate?.fileBrowser(self, didUpdateDiskSpace: diskSpace)
    }

    func showError(_ message: String) {
        showBanner(message: message, style: .error)
    }

    @objc private func outlineViewDoubleClicked(_ sender: Any) {
        let clickedRow = outlineView.clickedRow
        guard clickedRow >= 0 else { return }

        if let item = outlineView.item(atRow: clickedRow) as? FileItem {
            if item.isDirectory {
                navigationCoordinator.loadDirectory(item.url)
            } else {
                // Open file with default application
                FileBrowserActionHelper.openFile(item.url)
            }
        }
    }

    // MARK: - Public Methods

    func toggleHiddenFilesState() {
        toolbarDidToggleHiddenFiles(show: !showsHiddenFiles)
    }

    func isShowingHiddenFiles() -> Bool {
        return showsHiddenFiles
    }
    
    func setFilter(_ criteria: FilterCriteria) {
        filterCoordinator.applyFilterCriteria(criteria)
    }
    
    func clearFilters() {
        filterCoordinator.clearFilters()
    }
    
    func showFilterPanel() {
        presentAsSheet(filterPanel)
    }
    func goBack() {
        navigationCoordinator.navigateToParent()
    }

    func goForward(to url: URL) {
        navigationCoordinator.loadDirectory(url)
    }

    func navigateToURL(_ url: URL) {
        navigationCoordinator.loadDirectory(url)
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

}

// MARK: - NSOutlineView delegate/dataSource moved to FileBrowserViewController+Outline.swift

// MARK: - NSCollectionView delegate/dataSource moved to FileBrowserViewController+Collection.swift

// MARK: - NSBrowserDelegate / Root drop handling moved to FileBrowserViewController+Columns.swift

// MARK: - QLPreviewPanelDataSource / QLPreviewPanelDelegate stubs
extension FileBrowserViewController {
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return 0
    }


    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return nil
    }
}

// MARK: - FileBrowserDataSourceDelegate

extension FileBrowserViewController: FileBrowserDataSourceDelegate {
    func dataSource(_ dataSource: FileBrowserDataSource, didLoadItems items: [FileItem]) {
        // Data loaded, update UI
        sortItems() // Sort happens in data source mostly, but update checks UI state
        applySearchFilter() // UI filter logic might still be needed if not fully moved?
        // Actually, dataSource handles sort/filter on its data.
        // But we need to update the views.
        
        // Wait, dataSource.rootItem.children are now ready.
        // We just need to reload views.
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.outlineView.reloadData()
            if self.currentViewMode == .icons || self.currentViewMode == .windowsList {
                self.collectionView?.reloadData()
            } else if self.currentViewMode == .columns {
                self.browserView?.loadColumnZero()
            }
            
            self.delegate?.directoryDidChange(self, to: dataSource.currentDirectory.path)
            self.selectionCoordinator.updateStatusBar()
            
            debugLog("FileBrowserDataSource: didLoadItems - refreshed views")
        }
    }
    
    func dataSource(_ dataSource: FileBrowserDataSource, didFailToLoad error: Error) {
        Task { @MainActor [weak self] in
            self?.showError(error.localizedDescription)
        }
    }
}

// MARK: - Filter Delegate Support

extension FileBrowserViewController: FileBrowserFilterDelegate {
    var filterPanel: FilterPanelViewController! {
        FilterPanelViewController(currentFilter: filterCoordinator.getFilterCriteria()) { [weak self] newFilter in
            self?.filterCoordinator.applyFilterCriteria(newFilter)
        }
    }

    var settingsStore: SettingsStoreProtocol! {
        get { settings }
        set {
            guard let newValue else { return }
            settings = newValue
        }
    }

    func reloadBrowserData() {
        refreshCurrentDirectory()
    }

    func setFilterCriteria(_ criteria: FilterCriteria) {
        filterCriteria = criteria
    }
}
