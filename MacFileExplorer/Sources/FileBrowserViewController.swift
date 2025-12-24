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
    lazy var previewPaneCoordinator = FileBrowserPreviewPaneCoordinator(settings: settings)
    lazy var zoomCoordinator = FileBrowserZoomCoordinator()
    
    // Controllers for focused responsibilities
    lazy var displayController = FileBrowserDisplayController(viewController: self)
    lazy var uiSetupController = FileBrowserUISetupController(viewController: self)
    

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

    // Click tracking for delayed rename - protected by clickTrackingLock
    private let clickTrackingLock = NSLock()
    private var lastClickedRow: Int = -1
    private var lastClickTime: TimeInterval = 0
    private let doubleClickTimeWindow: TimeInterval = 0.5
    private let renameClickDelay: TimeInterval = 0.5
    
    // MARK: - Click Tracking State Management
    
    /// Thread-safe way to record a click on a row
    private func recordClick(row: Int) {
        clickTrackingLock.lock()
        defer { clickTrackingLock.unlock() }
        lastClickedRow = row
        lastClickTime = Date().timeIntervalSince1970
    }
    
    /// Thread-safe way to check if this is a rename-eligible click
    /// Returns true if click is on same row within renameClickDelay window
    private func isRenameEligibleClick(row: Int) -> Bool {
        clickTrackingLock.lock()
        defer { clickTrackingLock.unlock() }
        
        guard lastClickedRow == row else { return false }
        
        let timeSinceLastClick = Date().timeIntervalSince1970 - lastClickTime
        let isWithinWindow = timeSinceLastClick > 0 && timeSinceLastClick < renameClickDelay
        
        return isWithinWindow
    }
    
    /// Thread-safe way to clear click tracking state
    private func clearClickTracking() {
        clickTrackingLock.lock()
        defer { clickTrackingLock.unlock() }
        lastClickedRow = -1
        lastClickTime = 0
    }

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
        
        // Setup coordinators
        zoomCoordinator.delegate = self
        
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
        if defaultShowPreview {
            previewPaneCoordinator.setPreviewPaneVisible(true)
            toolbarViewController.updatePreviewPaneDisplay(showing: true)
        }
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
            selectionCoordinator.clearSelection()
        } else if event.keyCode == 120 { // F2 key
            let items = selectionCoordinator.selectedItems()
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
        // Delegate UI setup to specialized controller
        uiSetupController.setupUI()
        
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Setup column visibility and context menu
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
        outlineView.menu = createContextMenu()
        
        // Display initial view mode
        viewModeCoordinator.displayFiles(for: currentViewMode)
        updateZoomControlVisibility()
        
        // Update toolbar display
        toolbarViewController?.updateViewModeDisplay(for: currentViewMode)
        toolbarViewController?.updateSortDisplay(column: sortColumn, ascending: sortAscending)
    }

    private func setupToolbar() {
        // Legacy method - now handled by uiSetupController
        // Kept for compatibility
        uiSetupController.setupUI()
    }

    private func setupStatusBar() {
        // Legacy method - now handled by uiSetupController
        // Kept for compatibility
    }

    private func setupContainerAndOutlineView() {
        // Legacy method - now handled by uiSetupController
        // Kept for compatibility
    }

    private func setupOutlineViewColumns() {
        // Legacy method - now handled by uiSetupController
        // Kept for compatibility
    }

    private func setupOutlineViewBehavior() {
        // Legacy method - now handled by uiSetupController
        // Kept for compatibility
    }

    private func setupConstraints() {
        // Legacy method - now handled by uiSetupController
        // Kept for compatibility
    }

    // Ensure active content view is embedded in preview split if preview visible
    func ensureContentInPreviewSplit() {
        previewPaneCoordinator.setPreviewPaneVisible(true)
    }

    private func dismantlePreviewSplit() {
        previewPaneCoordinator.setPreviewPaneVisible(false)
    }

    private func currentActiveContentView() -> NSView? {
        return displayController.currentActiveContentView()
    }

    // Update preview pane with a newly selected file or clear if nil/multiple
    func updatePreviewPane(with file: FileItem?) {
        previewPaneCoordinator.updatePreviewPane(with: file)
    }

    @objc func handleBrowserDoubleClick(_ sender: NSBrowser) {
        guard let browserView = browserView else { return }
        let selectedColumn = browserView.selectedColumn
        let selectedRow = browserView.selectedRow(inColumn: selectedColumn)
        
        guard selectedRow >= 0 else { return }
        
        // Record this click for potential delayed rename
        recordClick(row: selectedRow)
        
        let item = fileItemForColumn(selectedColumn)
        guard let children = item?.children,
              selectedRow < children.count else {
            clearClickTracking()
            return
        }
        
        let fileItem = children[selectedRow]
        
        if fileItem.isDirectory {
            navigationCoordinator.loadDirectory(fileItem.url)
        } else {
            FileBrowserActionHelper.openFile(fileItem.url)
        }
        
        // Clear tracking after action
        clearClickTracking()
    }
    
    @objc func handleCollectionViewDoubleClick(_ sender: NSClickGestureRecognizer) {
        guard let collectionView = collectionView else { return }
        let point = sender.location(in: collectionView)
        
        if let indexPath = collectionView.indexPathForItem(at: point),
           let item = collectionView.item(at: indexPath) as? FileIconItem,
           let fileItem = item.fileItem {
            
            // Record this click for potential delayed rename
            recordClick(row: indexPath.item)
            
            if fileItem.isDirectory {
                navigationCoordinator.loadDirectory(fileItem.url)
            } else {
                FileBrowserActionHelper.openFile(fileItem.url)
            }
            
            // Clear tracking after action
            clearClickTracking()
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
        
        // Record this click for potential delayed rename
        recordClick(row: clickedRow)

        if let item = outlineView.item(atRow: clickedRow) as? FileItem {
            if item.isDirectory {
                navigationCoordinator.loadDirectory(item.url)
            } else {
                // Open file with default application
                FileBrowserActionHelper.openFile(item.url)
            }
        }
        
        // Clear tracking after action
        clearClickTracking()
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
        navigationCoordinator.goBack()
    }

    func goForward(to url: URL) {
        navigationCoordinator.loadDirectory(url)
    }

    func navigateToURL(_ url: URL) {
        navigationCoordinator.loadDirectory(url)
    }

    // MARK: - Public Actions

    func cutSelection() {
        let items = selectionCoordinator.selectedItems()
        contextMenuCut(self)
    }

    func copySelection() {
        let items = selectionCoordinator.selectedItems()
        contextMenuCopy(self)
    }

    func pasteSelection() {
        contextMenuPaste(self)
    }

    func snapToGrid() {
        zoomCoordinator.snapToGrid()
    }
    
    func toggleFreeFormPositioning() {
        zoomCoordinator.toggleFreeFormPositioning()
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

// MARK: - FileBrowserZoomCoordinatorDelegate

extension FileBrowserViewController: FileBrowserZoomCoordinatorDelegate {
    func updateZoomDisplay() {
        // Update UI to reflect zoom changes
        toolbarViewController?.updateZoomDisplay(level: zoomLevel)
    }
    
    func refreshViews() {
        displayController.refreshViews()
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
