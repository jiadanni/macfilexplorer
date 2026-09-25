import Cocoa
import Quartz

class FileBrowserViewController: NSViewController, NSMenuDelegate, NSGestureRecognizerDelegate, StatusBarDelegate, FileBrowserFilterDelegate, FileBrowserContextMenuDelegate, FileBrowserDragDropDelegate, FileBrowserOutlineCoordinatorDelegate, FileBrowserCollectionCoordinatorDelegate, FileBrowserColumnCoordinatorDelegate, FileBrowserStatusBarCoordinatorDelegate {

    weak var delegate: FileBrowserDelegate?
    
    var settings: SettingsStoreProtocol
    
    // Extracted handlers for reduced VC complexity
    lazy var bannerManager = BannerNotificationManager(view: view, statusBarAnchor: statusBarViewController.view)
    lazy var gestureHandler = FileBrowserGestureHandler()
    lazy var keyboardHandler = FileBrowserKeyboardHandler()

    internal var toolbarViewController: ToolbarViewController!
    internal var statusBarViewController: StatusBarViewController!
    var containerView: NSView! // New container view
    var scrollView: NSScrollView! // For outlineView
    var outlineView: NSOutlineView!
    var collectionView: NSCollectionView? // For icons view
    var collectionViewScrollView: NSScrollView! // For collection view
    var browserView: NSBrowser? // For columns view
    
    private enum BrowserSetupState {
        case idle, preparing, creatingBrowser, ready, failed
    }

    private var _browserSetupState: BrowserSetupState = .idle
    private let browserLock = NSLock()

    private var browserSetupState: BrowserSetupState {
        get {
            browserLock.lock()
            defer { browserLock.unlock() }
            return _browserSetupState
        }
        set {
            browserLock.lock()
            _browserSetupState = newValue
            browserLock.unlock()
#if DEBUG
            debugLog("DEBUG: browserSetupState -> \(newValue)")
#endif
        }
    }

    private func transitionBrowserState(from: BrowserSetupState, to: BrowserSetupState) -> Bool {
        browserLock.lock()
        defer { browserLock.unlock() }
        guard _browserSetupState == from else { return false }
        _browserSetupState = to
#if DEBUG
        debugLog("DEBUG: browserSetupState -> \(to) (transitioned)")
#endif
        return true
    }
    var zoomControlsAllowedByPane = true // Gated by active pane; combined with view mode to show/hide slider.
    var freeFormLayout: FreeFormCollectionViewLayout? // Custom layout for free-form icon positioning
    // Per-pane preview management
    var previewSplitView: NSSplitView?

    
    /// Read-only computed property: preview visibility delegates to coordinator (SSOT)
    var previewVisible: Bool {
        return previewPaneCoordinator.isVisible
    }
    
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
        get { hiddenFilesCoordinator.isVisible }
        set { hiddenFilesCoordinator.isVisible = newValue }
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
    lazy var filterCoordinator = FileBrowserFilterCoordinator(settingsStore: settings)
    let selectionCoordinator = FileBrowserSelectionCoordinator()
    var navigationCoordinator: FileBrowserNavigationCoordinator!
    lazy var viewModeCoordinator = FileBrowserViewModeCoordinator(owner: self)
    lazy var previewPaneCoordinator = FileBrowserPreviewPaneCoordinator(settings: settings)
    lazy var hiddenFilesCoordinator = HiddenFilesVisibilityCoordinator(settingsStore: settings)
    lazy var zoomCoordinator = FileBrowserZoomCoordinator()
    
    // New specialized coordinators
    lazy var outlineCoordinator = FileBrowserOutlineCoordinator()
    lazy var collectionCoordinator = FileBrowserCollectionCoordinator()
    lazy var columnCoordinator = FileBrowserColumnCoordinator()
    lazy var quickLookCoordinator = FileBrowserQuickLookCoordinator()
    lazy var interactionCoordinator = FileBrowserInteractionCoordinator()
    lazy var statusBarCoordinator = FileBrowserStatusBarCoordinator()
    lazy var dragDropCoordinator = FileBrowserDragDropCoordinator()
    
    // Controllers for focused responsibilities
    private var _cachedFilterPanel: FilterPanelViewController?
    var filterPanel: FilterPanelViewController {
        if let existing = _cachedFilterPanel { return existing }
        let panel = FilterPanelViewController(currentFilter: filterCoordinator.getFilterCriteria()) { [weak self] newFilter in
            self?.filterCoordinator.applyFilterCriteria(newFilter)
        }
        _cachedFilterPanel = panel
        return panel
    }
    
    lazy var displayController = FileBrowserDisplayController(viewController: self)
    lazy var uiSetupController = FileBrowserUISetupController(viewController: self)
    lazy var contextMenuProvider: FileBrowserContextMenuProvider = {
        let provider = FileBrowserContextMenuProvider(settings: settings)
        provider.delegate = self
        return provider
    }()
    lazy var stateHandler = FileBrowserStateHandler(viewController: self)
    lazy var actionHandler = FileBrowserActionHandler(viewController: self)
    
    lazy var dragDropHandler: FileBrowserDragDropHandler = {
        return FileBrowserDragDropHandler(delegate: self)
    }()
    
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

    // Click tracking is now managed by interactionCoordinator

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
        
        self.dataSource = FileBrowserDataSource(currentDirectory: startUrl, settings: settings)
        self.dataSource.delegate = self

        navigationCoordinator = FileBrowserNavigationCoordinator()
        navigationCoordinator.delegate = self
        selectionCoordinator.delegate = self
        
        // Setup coordinators
        zoomCoordinator.delegate = self

        // Setup preview pane coordinator delegate
        previewPaneCoordinator.delegate = stateHandler

        // Setup hidden files coordinator delegate
        hiddenFilesCoordinator.delegate = stateHandler

        // The coordinator initializes from settings in its init, where didSet doesn't
        // fire, so the persisted state must be pushed to the data source explicitly.
        dataSource.applyInitialHiddenFilesState(hiddenFilesCoordinator.isVisible)

        // Setup new coordinators
        outlineCoordinator.delegate = self
        outlineCoordinator.selectionCoordinator = selectionCoordinator
        outlineCoordinator.dragDropHandler = dragDropHandler
        
        collectionCoordinator.delegate = self
        collectionCoordinator.selectionCoordinator = selectionCoordinator
        collectionCoordinator.dragDropHandler = dragDropHandler
        
        columnCoordinator.delegate = self
        columnCoordinator.selectionCoordinator = selectionCoordinator
        columnCoordinator.dragDropHandler = dragDropHandler
        
        quickLookCoordinator.delegate = actionHandler
        interactionCoordinator.delegate = actionHandler
        statusBarCoordinator.delegate = self
        dragDropCoordinator.dragDropHandler = dragDropHandler
        
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
        
        // Register as delegate
        settings.addDelegate(stateHandler)
    }

    deinit {
        settings.removeDelegate(stateHandler)
    }

    override func loadView() {
        let root = RootFileBrowserView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        root.dropDelegate = dragDropCoordinator
        view = root
        setupUI()
        navigationCoordinator.loadDirectory(currentDirectory)
        // Initial toolbar state sync
        toolbarViewController.updatePreviewPaneDisplay(showing: previewPaneCoordinator.isVisible)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(outlineView) // Make outlineView the first responder
    }

    override func keyDown(with event: NSEvent) {
        if !keyboardHandler.handleKeyDown(event) {
            super.keyDown(with: event)
        }
    }

    func openSelection() {
        let items = selectionCoordinator.selectedItems()
        guard let item = items.first, items.count == 1 else { return }

        openItem(item)
    }

    func openItem(_ item: FileItem) {
        if item.isDirectory {
            navigationCoordinator.loadDirectory(item.url)
        } else {
            FileBrowserActionHelper.openFile(item.url)
        }
    }
    
    func duplicateSelection() {
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
        
        statusBarCoordinator.statusBarViewController = statusBarViewController
        statusBarCoordinator.updateZoomControlVisibility()
        
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
        outlineView.headerView?.menu = contextMenuProvider.createColumnVisibilityMenu(columns: outlineView.tableColumns)
        outlineView.menu = contextMenuProvider.createContextMenu()
        
        // Display initial view mode
        viewModeCoordinator.displayFiles(for: currentViewMode)
        
        // Update toolbar display
        toolbarViewController?.updateViewModeDisplay(for: currentViewMode)
        toolbarViewController?.updateSortDisplay(column: sortColumn, ascending: sortAscending)
        
        // Set handler delegates once during setup (avoid reassigning on every event)
        keyboardHandler.delegate = actionHandler
        gestureHandler.delegate = actionHandler
    }

    func applyColumnVisibility(_ visibility: [String: Bool]) {
        for column in outlineView.tableColumns {
            let id = column.identifier.rawValue
            if id == AppConfig.ColumnID.name {
                column.isHidden = false
                continue
            }
            let shouldShow = visibility[id] ?? true
            column.isHidden = !shouldShow
        }
    }

    func createContextMenu() -> NSMenu {
        return contextMenuProvider.createContextMenu()
    }

    func createHeaderColumnsMenu() -> NSMenu {
        return contextMenuProvider.createColumnVisibilityMenu(columns: outlineView.tableColumns)
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
        
        interactionCoordinator.recordClick(row: selectedRow)
        handleDoubleClick(at: selectedRow)
    }
    
    @objc func handleCollectionViewDoubleClick(_ sender: NSClickGestureRecognizer) {
        gestureHandler.handleCollectionViewDoubleClick(sender)
    }
    
    // MARK: - Gesture Recognition (delegated to FileBrowserGestureHandler)
    
    @objc func handleIconDrag(_ sender: NSPanGestureRecognizer) {
        gestureHandler.handleIconDrag(sender)
    }

    func refreshCurrentDirectory() {
        debugLog("Refreshing current directory")
        dataSource.reload()
    }

    func toggleQuickLook() {
        quickLookCoordinator.toggleQuickLook()
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
        
        statusBarCoordinator.updateFileInformation(selectedCount: selectedCount, totalSize: totalSize, diskSpace: diskSpace ?? "Unknown")
        delegate?.fileBrowser(self, didUpdateSelection: selectedCount, totalSize: totalSize)
        delegate?.fileBrowser(self, didUpdateDiskSpace: diskSpace)
    }

    func showError(_ message: String) {
        bannerManager.showError(message)
    }
    
    func showInfo(_ message: String) {
        bannerManager.showInfo(message)
    }

    @objc func outlineViewDoubleClicked(_ sender: Any) {
        let clickedRow = outlineView.clickedRow
        guard clickedRow >= 0 else { return }
        
        interactionCoordinator.recordClick(row: clickedRow)
        handleDoubleClick(at: clickedRow)
    }

    func handleDoubleClick(at row: Int) {
        switch currentViewMode {
        case .list:
            guard let item = outlineView.item(atRow: row) as? FileItem else { return }
            interactionCoordinator.handleDoubleClick(on: item)
        case .icons, .windowsList:
            guard let item = rootItem?.children?.safe(at: row) else { return }
            interactionCoordinator.handleDoubleClick(on: item)
        case .columns:
            guard let browserView = browserView else { return }
            let selectedColumn = browserView.selectedColumn
            guard selectedColumn >= 0,
                  let parentItem = fileItemForColumn(selectedColumn),
                  let children = parentItem.children,
                  row < children.count else { return }
            interactionCoordinator.handleDoubleClick(on: children[row])
        }
    }

    // MARK: - Public Methods

    func toggleHiddenFilesState() {
        hiddenFilesCoordinator.toggleVisibility()
    }
    func showsHiddenFilesState() -> Bool {
        return showsHiddenFiles
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
        // Validate URL before navigation
        guard url.isFileURL else {
            showError("Invalid URL")
            return
        }

        // Check for path traversal attacks on the raw path; resolution below would
        // silently collapse ".." components, so this must run before resolving.
        let rawPath = url.path
        if rawPath.contains("/../") || rawPath.hasPrefix("..") || rawPath.hasSuffix("/..") {
            showError("Invalid path: path traversal detected")
            return
        }

        let resolvedURL = url.resolvingSymlinksInPath()

        // For sandboxed builds, check permissions
        let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        if isSandboxed {
            if !PermissionsManager.shared.hasGrantedDirectory(resolvedURL) {
                showError("Access denied: You don't have permission to open this folder")
                return
            }
        }

        navigationCoordinator.loadDirectory(resolvedURL)
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
        zoomCoordinator.snapToGrid()
    }
    
    func toggleFreeFormPositioning() {
        zoomCoordinator.toggleFreeFormPositioning()
    }
}

// MARK: - Column Auto-Sizing

extension FileBrowserViewController {
    /// Resizes the Name column to fit the widest filename in the current directory,
    /// including the file icon and outline indentation, so nothing is clipped on load.
    func autoSizeNameColumn() {
        guard currentViewMode == .list,
              let nameColumn = outlineView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(AppConfig.ColumnID.name))
        else { return }

        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let iconWidth: CGFloat = 16   // NSImageView width from createCell
        let iconGap: CGFloat   = 6    // gap between icon and textField
        let cellPadding: CGFloat = 4  // leading padding
        let disclosureWidth: CGFloat = 16 // disclosure triangle per level
        let minAllowedWidth: CGFloat = nameColumn.minWidth

        var maxWidth: CGFloat = 0
        let rowCount = outlineView.numberOfRows
        let showExtensions = settings.showFileExtensions

        for row in 0..<rowCount {
            guard let item = outlineView.item(atRow: row) as? FileItem else { continue }
            let level = CGFloat(outlineView.level(forRow: row))
            let name = item.displayName(showExtensions: showExtensions)
            let textWidth = (name as NSString).size(withAttributes: attributes).width
            let totalWidth = cellPadding + disclosureWidth * (level + 1) + iconWidth + iconGap + textWidth + cellPadding
            if totalWidth > maxWidth { maxWidth = totalWidth }
        }

        if maxWidth > minAllowedWidth {
            nameColumn.width = maxWidth
        }
    }
}

// MARK: - NSOutlineView delegate/dataSource moved to FileBrowserViewController+Outline.swift

// MARK: - NSCollectionView delegate/dataSource moved to FileBrowserViewController+Collection.swift

// MARK: - NSBrowserDelegate / Root drop handling moved to FileBrowserViewController+Columns.swift

// QLPreviewPanelDataSource / QLPreviewPanelDelegate removed - handled by FileBrowserQuickLookCoordinator

// MARK: - FileBrowserZoomCoordinatorDelegate

extension FileBrowserViewController: FileBrowserZoomCoordinatorDelegate {
    func updateZoomDisplay() {
        // Update UI to reflect zoom changes
        // Zoom display is handled via collection view layout updates
        displayController.updateCollectionViewForZoom()
    }
    
    func refreshViews() {
        displayController.refreshViews()
    }
}

// MARK: - FileBrowserDataSourceDelegate

extension FileBrowserViewController: FileBrowserDataSourceDelegate {
    func dataSource(_ dataSource: FileBrowserDataSource, didLoadItems items: [FileItem]) {
        // Data loaded, update UI. Filtering and sorting are handled by the data source.
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
            
            self.autoSizeNameColumn()
            
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


// MARK: - FileBrowserContextMenuDelegate
extension FileBrowserViewController {
    func performFileOperation(_ operation: FileOperationType, items: [URL], destination: URL?) {
        performFileOperation(operation, items: items, destination: destination, sourcePane: nil)
    }
    


    func getAllFolders() -> [URL] {
        // Return potentially relevant folders for move/copy
        return [FileManager.default.homeDirectoryForCurrentUser]
    }

    func getCurrentDirectory() -> URL {
        return currentDirectory
    }
    
    func getSelectedItems() -> [FileItem] {
        return selectionCoordinator.selectedItems()
    }
    
    func reloadBrowserData() {
        refreshCurrentDirectory()
    }
    
    func setFilterCriteria(_ criteria: FilterCriteria) {
        filterCriteria = criteria
    }

    func refreshDirectory() {
        refreshCurrentDirectory()
    }

    func openFile(_ url: URL, withApplication: URL?) {
        if let appURL = withApplication {
            FileBrowserActionHelper.openFile(url, withApplication: appURL)
        } else {
            FileBrowserActionHelper.openFile(url)
        }
    }

    func openInNewTab(url: URL) {
        delegate?.openInNewTab(url: url)
    }

    func addToFavorites(item: FileItem) {
        delegate?.fileBrowserDidRequestAddToFavorites(self, item: item)
    }

    func openInTerminal() {
        delegate?.toolbarDidRequestOpenInTerminal(from: self)
    }

    func closePane() {
        delegate?.fileBrowserDidRequestClosePane(self)
    }

    func getOutlineView() -> NSOutlineView? {
        return outlineView
    }

    func getView() -> NSView {
        return view
    }
}

// MARK: - FileBrowserDragDropDelegate
// Note: Methods implemented directly in main class body; extension conforms to protocol only
extension FileBrowserViewController {}
