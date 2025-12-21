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
        bannerDismissWorkItem?.cancel()

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

        let workItem = DispatchWorkItem { [weak self] in
            self?.bannerContainer?.isHidden = true
        }
        bannerDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
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

class FileBrowserViewController: NSViewController, NSMenuDelegate, NSGestureRecognizerDelegate, QLPreviewPanelDataSource, QLPreviewPanelDelegate, StatusBarDelegate, ToolbarDelegate, NSOutlineViewDelegate, NSOutlineViewDataSource, NavigationManagerDelegate {

    weak var delegate: FileBrowserDelegate?
    
    private var settings: SettingsStoreProtocol

    internal var toolbarViewController: ToolbarViewController!
    internal var statusBarViewController: StatusBarViewController!
    private var containerView: NSView! // New container view
    private var scrollView: NSScrollView! // For outlineView
    var outlineView: NSOutlineView!
    var collectionView: NSCollectionView! // For icons view
    private var collectionViewScrollView: NSScrollView! // For collection view
    var browserView: NSBrowser! // For columns view
    private enum BrowserSetupState { case idle, preparing, creatingBrowser, ready, failed }
    private var browserSetupState: BrowserSetupState = .idle {
        didSet {
#if DEBUG
            debugLog("DEBUG: browserSetupState -> \(browserSetupState)")
#endif
        }
    }

    private let browserSerialQueue = DispatchQueue(label: "com.macfileexplorer.browserSetup")
    private var zoomControlsAllowedByPane = true // Gated by active pane; combined with view mode to show/hide slider.

    private class BrowserSetupToken {
        weak var owner: FileBrowserViewController?
        init(owner: FileBrowserViewController) {
            self.owner = owner
            owner.browserSetupState = .preparing
        }
        func markCreating() { owner?.browserSetupState = .creatingBrowser }
        func markReady() { owner?.browserSetupState = .ready }
        func markFailed() { owner?.browserSetupState = .failed }
        deinit {
            guard let owner = owner else { return }
            if owner.browserSetupState == .preparing || owner.browserSetupState == .creatingBrowser {
                owner.browserSetupState = .failed
            }
        }
    }

    private func beginBrowserSetup() -> BrowserSetupToken? {
        guard browserSetupState == .idle || browserSetupState == .failed else {
#if DEBUG
            debugLog("DEBUG: beginBrowserSetup blocked; state=\(browserSetupState)")
#endif
            return nil
        }
        return BrowserSetupToken(owner: self)
    }

    private func enqueueBrowserSetupIfNeeded() {
        if browserView == nil {
            browserSerialQueue.async { [weak self] in
                DispatchQueue.main.async {
                    self?.setupBrowserView()
                }
            }
        }
    }

    private func withBrowserReady(_ completion: @escaping (NSBrowser) -> Void) {
        if let browserView, browserSetupState == .ready {
            completion(browserView)
            return
        }

        enqueueBrowserSetupIfNeeded()

        // Retry shortly after setup kicks off; keep lightweight to avoid blocking UI.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, let browserView = self.browserView, self.browserSetupState == .ready else { return }
            completion(browserView)
        }
    }

    private var suppressedDisplayCalls = 0
    var freeFormLayout: FreeFormCollectionViewLayout? // Custom layout for free-form icon positioning
    // Per-pane preview management
    private var previewSplitView: NSSplitView?
    private var previewPaneViewController: PreviewPaneViewController?
    var previewVisible: Bool = false
    
    // Constraint management for view switching
    private var activeConstraints: [NSLayoutConstraint] = []

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

    private var selectedItems: Set<FileItem> = []
    var currentViewMode: ViewMode = .list // Default view mode
    private let selectionManager = FileBrowserSelectionManager()

    // Navigation management
    private let navigationManager = NavigationManager()
    

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
    private var bannerDismissWorkItem: DispatchWorkItem?

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
        
        // Set navigation manager delegate
        self.navigationManager.delegate = self
        
        // Load persisted hidden files state
        self.dataSource.showsHiddenFiles = settings.hiddenFilesState
        
        // Load default view & sort (search remains nil)
        currentViewMode = settings.defaultViewMode
        
        let defaultSort = settings.defaultSortColumn
        if !defaultSort.isEmpty {
            self.dataSource.sortColumn = defaultSort
        }
        self.dataSource.sortAscending = settings.defaultSortAscending

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
        loadDirectory(currentDirectory)
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
            FileBrowserActionHelper.openFile(item.url)
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
        displayFiles(for: currentViewMode)
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
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("NameColumn"))
        nameColumn.title = L10n.text("Name")
        nameColumn.width = 250
        nameColumn.minWidth = 100
        nameColumn.maxWidth = 500
        nameColumn.resizingMask = .userResizingMask
        nameColumn.sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true)
        outlineView.addTableColumn(nameColumn)
        outlineView.outlineTableColumn = nameColumn

        let dateModifiedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("DateModifiedColumn"))
        dateModifiedColumn.title = L10n.text("Date Modified")
        dateModifiedColumn.width = 150
        dateModifiedColumn.minWidth = 100
        dateModifiedColumn.maxWidth = 250
        dateModifiedColumn.resizingMask = .userResizingMask
        dateModifiedColumn.sortDescriptorPrototype = NSSortDescriptor(key: "modificationDate", ascending: false)
        outlineView.addTableColumn(dateModifiedColumn)

        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TypeColumn"))
        typeColumn.title = L10n.text("Type")
        typeColumn.width = 120
        typeColumn.minWidth = 80
        typeColumn.maxWidth = 200
        typeColumn.resizingMask = .userResizingMask
        typeColumn.sortDescriptorPrototype = NSSortDescriptor(key: "kind", ascending: true)
        outlineView.addTableColumn(typeColumn)

        let sizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SizeColumn"))
        sizeColumn.title = L10n.text("Size")
        sizeColumn.width = 100
        sizeColumn.minWidth = 60
        sizeColumn.maxWidth = 150
        sizeColumn.resizingMask = .userResizingMask
        sizeColumn.sortDescriptorPrototype = NSSortDescriptor(key: "size", ascending: false)
        outlineView.addTableColumn(sizeColumn)

        let dateCreatedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("DateCreatedColumn"))
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
                "NameColumn": true,
                "DateModifiedColumn": true,
                "TypeColumn": true,
                "SizeColumn": true,
                "DateCreatedColumn": false,
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
    private func ensureContentInPreviewSplit() {
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
        DispatchQueue.main.async { [weak split] in
            guard let split = split else { return }
            let total = split.bounds.width
            let position = max(0, total - CGFloat(widthToApply))
            split.setPosition(position, ofDividerAt: 0)
        }

        // Show current selection
        if let sel = currentSingleSelection() {
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

    private func currentSingleSelection() -> FileItem? {
        selectionManager.currentSingleSelection(outlineView: outlineView)
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

    private func showPreviewPane() {
        previewVisible = true
        ensureContentInPreviewSplit()
        toolbarViewController.updatePreviewPaneDisplay(showing: true)
    }

    private func hidePreviewPane() {
        previewVisible = false
        dismantlePreviewSplit()
        toolbarViewController.updatePreviewPaneDisplay(showing: false)
    }

    private func displayFiles(for viewMode: ViewMode) {
        assert(Thread.isMainThread, "displayFiles must run on main thread")
        if browserSetupState == .preparing || browserSetupState == .creatingBrowser {
            suppressedDisplayCalls += 1
#if DEBUG
            debugLog("DEBUG: displayFiles blocked (state=\(browserSetupState)) count=\(suppressedDisplayCalls)")
#endif
            return
        }
        debugLog("Displaying files for view mode: \(viewMode)")
        
        // Deactivate any existing constraints
        NSLayoutConstraint.deactivate(activeConstraints)
        activeConstraints.removeAll()
        
        // Hide all views first instead of removing them
        scrollView.isHidden = true
        collectionViewScrollView?.isHidden = true
        browserView?.isHidden = true

        switch viewMode {
        case .list:
            displayListView()
        case .icons, .windowsList:
            displayCollectionView(for: viewMode)
        case .columns:
            displayColumnsView()
        }
        
        // If preview visible, ensure split embedding stays consistent after view switch
        if previewVisible { ensureContentInPreviewSplit() }
    }

    private func displayListView() {
        // Use outlineView for list view
        if scrollView.superview == nil {
            containerView.addSubview(scrollView)
        }
        scrollView.isHidden = false
        
        if !previewVisible {
            activeConstraints = [
                scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(activeConstraints)
        }
        outlineView.reloadData()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.view.window?.makeFirstResponder(self.view)
        }
    }

    private func displayCollectionView(for viewMode: ViewMode) {
        // Ensure collectionView is set up
        if collectionView == nil {
            setupCollectionView()
        }
        
        // Safety check
        guard let collectionView = collectionView, let collectionViewScrollView = collectionViewScrollView else {
            debugLog("Error: CollectionView not properly initialized")
            currentViewMode = .list
            displayFiles(for: .list)
            return
        }
        
        // Add to container if not in split view (preview will handle embedding)
        if collectionViewScrollView.superview == nil && !previewVisible {
            containerView.addSubview(collectionViewScrollView)
        }
        collectionViewScrollView.isHidden = false
        
        // Only set constraints if preview is not visible (preview split will manage layout)
        if !previewVisible {
            activeConstraints = [
                collectionViewScrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
                collectionViewScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                collectionViewScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                collectionViewScrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(activeConstraints)
        }

        configureCollectionViewLayout(for: viewMode, collectionView: collectionView)
        
        collectionView.reloadData()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.view.window?.makeFirstResponder(self.view)
        }
    }

    private func configureCollectionViewLayout(for viewMode: ViewMode, collectionView: NSCollectionView) {
        if viewMode == .windowsList {
            let flowLayout = NSCollectionViewFlowLayout()
            let baseWidth: CGFloat = 150
            let baseHeight: CGFloat = 20
            let baseLineSpacing: CGFloat = 2
            let baseInteritemSpacing: CGFloat = 10
            flowLayout.itemSize = NSSize(width: baseWidth * zoomLevel, height: baseHeight * zoomLevel)
            flowLayout.sectionInset = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            flowLayout.minimumLineSpacing = baseLineSpacing * zoomLevel
            flowLayout.minimumInteritemSpacing = baseInteritemSpacing * zoomLevel
            flowLayout.scrollDirection = .horizontal
            collectionView.collectionViewLayout = flowLayout
            freeFormLayout = nil
        } else { // .icons mode
            if let freeFormLayout = freeFormLayout {
                // Update free-form layout item size and spacing
                let baseWidth: CGFloat = 110  // Matches icon base: 85pt + padding
                let baseHeight: CGFloat = 130 // Matches icon base: 85pt + spacing + label
                let baseSpacing: CGFloat = 10
                freeFormLayout.itemSize = NSSize(width: baseWidth * zoomLevel, height: baseHeight * zoomLevel)
                freeFormLayout.gridSpacing = baseSpacing * zoomLevel
                freeFormLayout.invalidateLayout()
            } else {
                // Fallback to flow layout (shouldn't happen)
                let flowLayout = NSCollectionViewFlowLayout()
                let baseWidth: CGFloat = 110
                let baseHeight: CGFloat = 130
                let baseSpacing: CGFloat = 10
                flowLayout.itemSize = NSSize(width: baseWidth * zoomLevel, height: baseHeight * zoomLevel)
                flowLayout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
                flowLayout.minimumLineSpacing = baseSpacing * zoomLevel
                flowLayout.minimumInteritemSpacing = baseSpacing * zoomLevel
                flowLayout.scrollDirection = .vertical
                collectionView.collectionViewLayout = flowLayout
            }
        }
    }

    private func displayColumnsView() {
        // Use NSBrowser for columns view
        withBrowserReady { [weak self] browserView in
            guard let self else { return }

            if browserView.superview == nil && !previewVisible {
                containerView.addSubview(browserView)
            }
            browserView.isHidden = false
            
            if !previewVisible {
                activeConstraints = [
                    browserView.topAnchor.constraint(equalTo: containerView.topAnchor),
                    browserView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    browserView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                    browserView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
                ]
                NSLayoutConstraint.activate(activeConstraints)
            }
            
            // Force layout update and load current directory into column zero
            debugLog("displayFiles: Setting up browser view, rootItem has \(self.rootItem?.children?.count ?? 0) children")
            browserView.layoutSubtreeIfNeeded()
            browserView.loadColumnZero()
            browserView.setNeedsDisplay(browserView.bounds)

            self.view.window?.makeFirstResponder(self.view)
        }
    }

    private func setupCollectionView() {
        // Prevent duplicate setup
        if collectionView != nil {
            debugLog("CollectionView already initialized, skipping setup")
            return
        }

        let newCollectionView = NSCollectionView()
        newCollectionView.translatesAutoresizingMaskIntoConstraints = false
        newCollectionView.isSelectable = true
        newCollectionView.allowsMultipleSelection = true
        newCollectionView.allowsEmptySelection = true
        newCollectionView.backgroundColors = [.clear]
        newCollectionView.setAccessibilityElement(true)
        newCollectionView.setAccessibilityRole(.group)
        newCollectionView.setAccessibilityLabel(L10n.text("Icon grid"))
        newCollectionView.delegate = self
        newCollectionView.dataSource = self

        // Enable drag and drop for collection view
        newCollectionView.registerForDraggedTypes([.fileURL])
        newCollectionView.setDraggingSourceOperationMask([.copy, .move], forLocal: false)
        newCollectionView.setDraggingSourceOperationMask([.copy, .move], forLocal: true)

        // NOTE: We don't register a class or NIB for FileIconItem
        // Instead, we'll create items manually in the data source method
        // This avoids the NSCollectionView instantiation issues with custom loadView()

        setupCollectionViewGestures(newCollectionView)

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

    private func setupCollectionViewGestures(_ collectionView: NSCollectionView) {
        // Add double-click gesture recognizer for handling double-clicks
        let doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleCollectionViewDoubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        collectionView.addGestureRecognizer(doubleClickGesture)
        
        // Add pan gesture for dragging icons in free-form mode
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handleIconDrag(_:)))
        panGesture.delegate = self
        panGesture.delaysPrimaryMouseButtonEvents = false
        collectionView.addGestureRecognizer(panGesture)
    }
    
    private func setupBrowserView() {
        assert(Thread.isMainThread, "setupBrowserView must run on main thread")
        // Prevent duplicate setup
        if browserView != nil {
            debugLog("BrowserView already initialized, skipping setup")
            return
        }

        guard let token = beginBrowserSetup() else { return }
        token.markCreating()

        let newBrowser = createBrowserControl()
        browserView = newBrowser

        // Set delegate AFTER creation and assignment
        browserView.delegate = self

        debugLog("BrowserView setup completed with minColumnWidth: 180")

        token.markReady()
    }

    private func createBrowserControl() -> NSBrowser {
        // Construct NSBrowser here to avoid cross-file visibility issues
        let newBrowser = NSBrowser()
        newBrowser.translatesAutoresizingMaskIntoConstraints = false
        newBrowser.allowsMultipleSelection = true
        newBrowser.allowsEmptySelection = true
        newBrowser.takesTitleFromPreviousColumn = false
        newBrowser.separatesColumns = true
        // Note: rowHeight is deprecated and causes crashes on macOS 15+
        // NSBrowser automatically sizes rows based on font and cell type
        newBrowser.hasHorizontalScroller = true
        newBrowser.autohidesScroller = true
        newBrowser.minColumnWidth = 180
        newBrowser.maxVisibleColumns = 4
        newBrowser.doubleAction = #selector(handleBrowserDoubleClick(_:))
        newBrowser.target = self
        newBrowser.setCellClass(NSBrowserCell.self)
        newBrowser.menu = createContextMenu()
        return newBrowser
    }
    
    @objc func handleBrowserDoubleClick(_ sender: NSBrowser) {
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
            FileBrowserActionHelper.openFile(fileItem.url)
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
    
    @objc private func handleIconDrag(_ sender: NSPanGestureRecognizer) {
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

    private func loadDirectory(_ url: URL, addToHistory: Bool = true, isSearch: Bool = false) {
        debugLog("FileBrowserViewController: loadDirectory - Loading URL: \(url.path)")
        
        // Update navigation history via NavigationManager
        navigationManager.navigate(to: url, addToHistory: addToHistory)

        // Delegate loading to DataSource
        dataSource.navigate(to: url, isSearch: isSearch)
    }

    // Google Drive logic moved to DataSource

    private func refreshCurrentDirectory() {
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

    private func updateStatusBar() {
        switch currentViewMode {
        case .list:
            updateStatusBarForOutline()
        case .icons, .windowsList:
            updateStatusBarForCollectionView()
        case .columns:
            updateStatusBarForBrowser()
        }
    }

    func updateStatusBarDisplay(selectedCount: Int, totalSize: Int64) {
        let diskSpace = FileBrowserActionHelper.formatDiskSpace(
            FileBrowserActionHelper.getAvailableDiskSpace(for: currentDirectory)
        )
        statusBarViewController?.updateFileInformation(selectedCount: selectedCount, totalSize: totalSize, diskSpace: diskSpace)
        delegate?.fileBrowser(self, didUpdateSelection: selectedCount, totalSize: totalSize)
        delegate?.fileBrowser(self, didUpdateDiskSpace: diskSpace)
    }

    private func showError(_ message: String) {
        showBanner(message: message, style: .error)
    }

    @objc private func outlineViewDoubleClicked(_ sender: Any) {
        let clickedRow = outlineView.clickedRow
        guard clickedRow >= 0 else { return }

        if let item = outlineView.item(atRow: clickedRow) as? FileItem {
            if item.isDirectory {
                loadDirectory(item.url)
            } else {
                // Open file with default application
                FileBrowserActionHelper.openFile(item.url)
            }
        }
    }

    // MARK: - Public Methods

    func setZoomControlsVisible(_ visible: Bool) {
        zoomControlsAllowedByPane = visible
        updateZoomControlVisibility()
    }

    func setZoomLevel(_ level: Double) {
        zoomLevel = max(0.5, min(2.0, level)) // Clamp between 0.5 and 2.0
        statusBarViewController?.setZoomLevel(zoomLevel)
        applyZoomToCurrentView()
    }

    private func isZoomableViewMode(_ mode: ViewMode) -> Bool {
        return mode == .icons || mode == .windowsList
    }

    private func updateZoomControlVisibility() {
        let shouldShow = zoomControlsAllowedByPane && isZoomableViewMode(currentViewMode)
        statusBarViewController?.setZoomControlsVisible(shouldShow)
    }

    func toggleHiddenFilesState() {
        toolbarDidToggleHiddenFiles(show: !showsHiddenFiles)
    }

    func isShowingHiddenFiles() -> Bool {
        return showsHiddenFiles
    }
    
    func setFilter(_ criteria: FilterCriteria) {
        filterCriteria = criteria
        refreshCurrentDirectory()
    }
    
    func clearFilters() {
        filterCriteria = FilterCriteria()
        refreshCurrentDirectory()
    }
    
    func showFilterPanel() {
        let filterPanel = FilterPanelViewController(currentFilter: filterCriteria) { [weak self] newFilter in
            self?.setFilter(newFilter)
        }
        
        presentAsSheet(filterPanel)
    }

    // MARK: - StatusBarDelegate

    func zoomLevelDidChange(to level: Double) {
        setZoomLevel(level)
    }

    func setClosePaneButtonVisible(_ visible: Bool) {
        toolbarViewController?.setClosePaneButtonVisible(visible)
    }

    func updateSplitButtonsState(_ canAddMore: Bool) {
        toolbarViewController?.updateSplitButtonsState(canAddMore: canAddMore)
    }

    private func applyZoomToCurrentView() {
        switch currentViewMode {
        case .icons, .windowsList:
            guard let collectionView = collectionView else { return }
            
            if currentViewMode == .windowsList {
                let flowLayout = NSCollectionViewFlowLayout()
                let baseWidth: CGFloat = 150
                let baseHeight: CGFloat = 20
                let baseLineSpacing: CGFloat = 2
                let baseInteritemSpacing: CGFloat = 10
                flowLayout.itemSize = NSSize(width: baseWidth * zoomLevel, height: baseHeight * zoomLevel)
                flowLayout.sectionInset = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
                flowLayout.minimumLineSpacing = baseLineSpacing * zoomLevel
                flowLayout.minimumInteritemSpacing = baseInteritemSpacing * zoomLevel
                flowLayout.scrollDirection = .horizontal
                collectionView.collectionViewLayout = flowLayout
                freeFormLayout = nil
            } else { // .icons mode
                if let freeFormLayout = freeFormLayout {
                    // Update free-form layout item size and spacing
                    let baseWidth: CGFloat = 110  // Matches icon base: 85pt + padding
                    let baseHeight: CGFloat = 130 // Matches icon base: 85pt + spacing + label
                    let baseSpacing: CGFloat = 10
                    freeFormLayout.itemSize = NSSize(width: baseWidth * zoomLevel, height: baseHeight * zoomLevel)
                    freeFormLayout.gridSpacing = baseSpacing * zoomLevel
                    freeFormLayout.invalidateLayout()
                } else {
                    // Fallback to flow layout (shouldn't happen)
                    let flowLayout = NSCollectionViewFlowLayout()
                    let baseWidth: CGFloat = 110
                    let baseHeight: CGFloat = 130
                    let baseSpacing: CGFloat = 10
                    flowLayout.itemSize = NSSize(width: baseWidth * zoomLevel, height: baseHeight * zoomLevel)
                    flowLayout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
                    flowLayout.minimumLineSpacing = baseSpacing * zoomLevel
                    flowLayout.minimumInteritemSpacing = baseSpacing * zoomLevel
                    flowLayout.scrollDirection = .vertical
                    collectionView.collectionViewLayout = flowLayout
                }
            }

            collectionView.reloadData()

            // Use dispatch to ensure window is ready
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.view.window?.makeFirstResponder(self.view)
            }
            
        case .columns:
            // Browser view doesn't need zoom adjustments
            break
        case .list:
            // Outline view sizing stays automatic for list mode.
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

    func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        let showHotkeys = settings.showContextMenuHotkeys

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
        menu.addItem(withTitle: "New File", action: #selector(contextMenuNewFile(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Add to Favorites", action: #selector(contextMenuAddToFavorites(_:)), keyEquivalent: "")
        // Remove possible extra separator if previous item was a separator
        if let last = menu.items.last, let prev = menu.items.dropLast().last, last.isSeparatorItem, prev.isSeparatorItem {
            menu.removeItem(last)
        }
        let tagsMenuItem = NSMenuItem(title: "Tags", action: nil, keyEquivalent: "")
        let tagsMenu = NSMenu()
        tagsMenuItem.submenu = tagsMenu
        menu.addItem(tagsMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Show in Finder", action: #selector(contextMenuShowInFinder(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Open in Terminal", action: #selector(contextMenuOpenInTerminal(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Close Pane", action: #selector(contextMenuClosePane(_:)), keyEquivalent: "")

        // Final pass: remove leading/trailing/consecutive separators
        var cleaned: [NSMenuItem] = []
        var previousWasSeparator = false
        for item in menu.items {
            if item.isSeparatorItem {
                if previousWasSeparator || cleaned.isEmpty { continue }
                previousWasSeparator = true
                cleaned.append(item)
            } else {
                previousWasSeparator = false
                cleaned.append(item)
            }
        }
        // Remove trailing separator
        if let last = cleaned.last, last.isSeparatorItem { cleaned.removeLast() }
        menu.removeAllItems()
        cleaned.forEach { menu.addItem($0) }

        menu.delegate = self
        return menu
    }

    // MARK: - Column Visibility

    private func createHeaderColumnsMenu() -> NSMenu {
        let menu = NSMenu(title: "Columns")
        let visibility = settings.columnVisibility
        for column in outlineView.tableColumns {
            let identifier = column.identifier.rawValue
            let title = column.title
            let item = NSMenuItem(title: title, action: #selector(toggleColumnVisibility(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = identifier
            let isVisible = visibility[identifier] ?? true
            item.state = isVisible ? .on : .off
            // Prevent hiding the NameColumn entirely
            if identifier == "NameColumn" { item.isEnabled = false }
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
        let resetItem = NSMenuItem(title: "Reset to Defaults", action: #selector(resetColumnVisibility(_:)), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)
        return menu
    }

    @objc private func toggleColumnVisibility(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String, identifier != "NameColumn" else { return }
        var visibility = settings.columnVisibility
        let current = visibility[identifier] ?? true
        visibility[identifier] = !current
        settings.columnVisibility = visibility
        applyColumnVisibility(visibility)
        // Refresh header menu to update states
        outlineView.headerView?.menu = createHeaderColumnsMenu()
    }

    @objc private func resetColumnVisibility(_ sender: NSMenuItem) {
        let defaults: [String: Bool] = [
            "NameColumn": true,
            "DateModifiedColumn": true,
            "TypeColumn": true,
            "SizeColumn": true,
            "DateCreatedColumn": false,
            "TagsColumn": false
        ]
        settings.columnVisibility = defaults
        applyColumnVisibility(defaults)
        outlineView.headerView?.menu = createHeaderColumnsMenu()
    }

    private func applyColumnVisibility(_ visibility: [String: Bool]) {
        for column in outlineView.tableColumns {
            let id = column.identifier.rawValue
            if id == "NameColumn" { // Always visible
                column.isHidden = false
                continue
            }
            let shouldShow = visibility[id] ?? true
            column.isHidden = !shouldShow
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        // Get the selected items to determine if we should show/hide certain menu items
        let selectedItems = getSelectedItems()

        // Apply context menu visibility settings from SettingsStore
        if let openWithItem = menu.items.first(where: { $0.title == "Open With..." }) {
            // Hide "Open With..." for folders, when multiple items are selected, or if disabled in settings
            let shouldHideOpenWith = settings.hideOpenWith ||
                                     selectedItems.isEmpty ||
                                     selectedItems.count > 1 ||
                                     selectedItems.first?.isDirectory == true
            openWithItem.isHidden = shouldHideOpenWith
        }

        if let getInfoItem = menu.items.first(where: { $0.title == "Get Info" }) {
            getInfoItem.isHidden = settings.hideGetInfo
        }

        if let copyItem = menu.items.first(where: { $0.title == "Copy" }) {
            copyItem.isHidden = settings.hideCopy
        }

        if let cutItem = menu.items.first(where: { $0.title == "Cut" }) {
            cutItem.isHidden = settings.hideCut
        }

        if let pasteItem = menu.items.first(where: { $0.title == "Paste" }) {
            pasteItem.isHidden = settings.hidePaste
        }

        if let renameItem = menu.items.first(where: { $0.title == "Rename" }) {
            renameItem.isHidden = settings.hideRename
        }

        if let deleteItem = menu.items.first(where: { $0.title == "Move to Trash" }) {
            deleteItem.isHidden = settings.hideMoveToTrash
        }

        if let showInFinderItem = menu.items.first(where: { $0.title == "Show in Finder" }) {
            showInFinderItem.isHidden = settings.hideShowInFinder
        }

        // Remove global folder color item (no longer per-folder)
        if let changeFolderColorItem = menu.items.first(where: { $0.title == "Change Folder Color..." }) {
            menu.removeItem(changeFolderColorItem)
        }

        // Hide "New Folder" if settings say so
        if let newFolderItem = menu.items.first(where: { $0.title == "New Folder" }) {
            newFolderItem.isHidden = settings.hideNewFolder
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

    func getSelectedItems() -> [FileItem] {
        var items = selectionManager.selectedItems(
            outlineView: outlineView,
            collectionView: collectionView,
            browserView: browserView,
            fileItemForColumn: { [weak self] column in self?.fileItemForColumn(column) },
            viewMode: currentViewMode,
            rootItem: rootItem
        )

        // Fallback for context menu when nothing is formally selected.
        if items.isEmpty && currentViewMode == .list {
            let clickedRow = outlineView.clickedRow
            if clickedRow >= 0, let item = outlineView.item(atRow: clickedRow) as? FileItem {
                items.append(item)
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

        guard let newTag = FileBrowserDialogHelper.showTextInputDialog(
            title: "Add New Tag",
            message: "Enter the name for the selected items:"
        ), !newTag.isEmpty else { return }

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

    private func getSelectedFileURLs() -> [URL] {
        return getSelectedItems().map { $0.url }
    }

    @objc func contextMenuOpen(_ sender: Any) {
        let items = getSelectedItems()
        if items.count == 1 {
            let item = items[0]
            if item.isDirectory {
                loadDirectory(item.url)
            } else {
                FileBrowserActionHelper.openFile(item.url)
            }
        } else if items.count > 1 {
            for url in items.map({ $0.url }) {
                FileBrowserActionHelper.openFile(url)
            }
        }
    }

    @objc func contextMenuOpenInNewTab(_ sender: Any) {
        let items = getSelectedItems()
        if items.count == 1 {
            let item = items[0]
            if item.isDirectory {
                delegate?.openInNewTab(url: item.url)
            }
        }
    }

    @objc func contextMenuOpenWith(_ sender: Any) {
        let items = getSelectedItems()
        guard let item = items.first, items.count == 1, !item.isDirectory else { return }
        
        let openWithMenu = NSMenu()
        let url = item.url as CFURL
        let defaultAppURL = LSCopyDefaultApplicationURLForURL(url, .all, nil)?.takeRetainedValue() as? URL
        let appURLs = LSCopyApplicationURLsForURL(url, .all)?.takeRetainedValue() as? [URL] ?? []
        
        for appURL in appURLs {
            let appName = appURL.deletingPathExtension().lastPathComponent
            let menuItem = NSMenuItem(title: appName, action: #selector(openWithApp(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = appURL
            menuItem.image = NSWorkspace.shared.icon(forFile: appURL.path)
            if appURL == defaultAppURL {
                menuItem.state = .on
            }
            openWithMenu.addItem(menuItem)
        }
        
        openWithMenu.addItem(NSMenuItem.separator())
        openWithMenu.addItem(withTitle: "Other...", action: #selector(openWithOther(_:)), keyEquivalent: "")
        
        // Show menu at mouse location
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(openWithMenu, with: event, for: view)
        }
    }

    @objc func openWithApp(_ sender: NSMenuItem) {
        guard let appURL = sender.representedObject as? URL else { return }
        let items = getSelectedItems()
        guard let item = items.first, items.count == 1 else { return }
        
        FileBrowserActionHelper.openFile(item.url, withApplication: appURL)
    }

    @objc func openWithOther(_ sender: Any) {
        let items = getSelectedItems()
        guard let item = items.first, items.count == 1 else { return }
        
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        openPanel.allowedContentTypes = [.application]
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let appURL = openPanel.url {
            FileBrowserActionHelper.openFile(item.url, withApplication: appURL)
        }
    }

    @objc func contextMenuGetInfo(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }
        // NSWorkspace.shared.showInformation(for: items.map { $0.url })
        // Implement custom Get Info window
    }

    @objc func contextMenuCopy(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items.map { $0.url as NSURL })
    }
    
    @objc private func contextMenuCopyTo(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }

        let openPanel = NSOpenPanel()
        openPanel.title = "Copy To..."
        openPanel.prompt = "Copy"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true

        openPanel.begin { [weak self] response in
            guard response == .OK, let destinationURL = openPanel.url else { return }
            self?.performFileOperation(.copy, items: items.map { $0.url }, destination: destinationURL)
        }
    }

    @objc private func contextMenuCut(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Declare both fileURL and our custom cut marker type
        let customCutMarkerType = NSPasteboard.PasteboardType("com.macfileexplorer.cutMarker")
        pasteboard.declareTypes([.fileURL, customCutMarkerType], owner: nil)

        let fileURLs = items.map { $0.url as NSURL }
        pasteboard.writeObjects(fileURLs)

        // Add a custom type to indicate it's a cut operation
        pasteboard.setString("cut", forType: customCutMarkerType)
    }

    @objc private func contextMenuMoveTo(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }

        let openPanel = NSOpenPanel()
        openPanel.title = "Move To..."
        openPanel.prompt = "Move"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true

        openPanel.begin { [weak self] response in
            guard response == .OK, let destinationURL = openPanel.url else { return }
            self?.performFileOperation(.move, items: items.map { $0.url }, destination: destinationURL)
        }
    }

    @objc private func contextMenuPaste(_ sender: Any) {
        let pasteboard = NSPasteboard.general
        guard let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !fileURLs.isEmpty else { return }

        // Check for our custom cut marker type
        let customCutMarkerType = NSPasteboard.PasteboardType("com.macfileexplorer.cutMarker")
        let isCut = pasteboard.string(forType: customCutMarkerType) == "cut"
        let operation: FileOperationType = isCut ? .move : .copy

        performFileOperation(operation, items: fileURLs, destination: currentDirectory)

        // Clear pasteboard after a cut operation
        if isCut {
            pasteboard.clearContents()
        }
    }

    @objc private func contextMenuRename(_ sender: Any) {
        let selectedItems = getSelectedItems()
        guard let item = selectedItems.first, selectedItems.count == 1 else { return }

        if let outlineView = self.outlineView, currentViewMode == .list, let row = outlineView.item(atRow: outlineView.selectedRow) as? FileItem, row == item {
            let rowView = outlineView.rowView(atRow: outlineView.selectedRow, makeIfNecessary: false)
            if let cell = rowView?.view(atColumn: 0) as? NSTableCellView, let textField = cell.textField {
                textField.isEditable = true
                view.window?.makeFirstResponder(textField)
            }
        }
        // Similar logic needed for collectionView and browserView
    }

    @objc func contextMenuDelete(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }

        let confirmed = FileBrowserDialogHelper.showConfirmationDialog(
            title: "Delete \(items.count) item(s)?",
            message: "Are you sure you want to move \(items.count) item(s) to the Trash?"
        )
        
        if confirmed {
            performFileOperation(.delete, items: items.map { $0.url }, destination: nil)
        }
    }

    @objc func contextMenuNewFolder(_ sender: Any) {
        guard let folderName = FileBrowserDialogHelper.showNewFolderDialog() else { return }
        
        let newFolderURL = currentDirectory.appendingPathComponent(folderName)
        
        do {
            try FileManager.default.createDirectory(at: newFolderURL, withIntermediateDirectories: false, attributes: nil)
            refreshCurrentDirectory()
        } catch {
            showError("Failed to create folder: \(error.localizedDescription)")
        }
    }

    @objc func contextMenuNewFile(_ sender: Any) {
        guard let newFileName = FileBrowserDialogHelper.showNewFileDialog() else { return }
        
        let newFileURL = currentDirectory.appendingPathComponent(newFileName)
        if !FileManager.default.fileExists(atPath: newFileURL.path) {
            FileManager.default.createFile(atPath: newFileURL.path, contents: nil, attributes: nil)
            refreshCurrentDirectory()
        } else {
            showError("A file with this name already exists.")
        }
    }

    @objc private func contextMenuAdvancedCopyTo(_ sender: Any) {
        // Implement advanced copy dialog (e.g., with options to overwrite, skip, etc.)
    }

    @objc private func contextMenuAdvancedMoveTo(_ sender: Any) {
        // Implement advanced move dialog
    }

    @objc func contextMenuShowInFinder(_ sender: Any) {
        let items = getSelectedItems()
        if items.isEmpty {
            FileBrowserActionHelper.revealInFinder(currentDirectory)
        } else {
            for item in items {
                FileBrowserActionHelper.revealInFinder(item.url)
            }
        }
    }
    
    @objc func contextMenuOpenInTerminal(_ sender: Any) {
        delegate?.toolbarDidRequestOpenInTerminal(from: self)
    }

    @objc func contextMenuClosePane(_ sender: Any) {
        delegate?.fileBrowserDidRequestClosePane(self)
    }

    @objc func contextMenuAddToFavorites(_ sender: Any) {
        let items = getSelectedItems()
        guard let item = items.first, items.count == 1 else { return }
        delegate?.fileBrowserDidRequestAddToFavorites(self, item: item)
    }
    
    func performFileOperation(_ operation: FileOperationType, items: [URL], destination: URL?, sourcePane: FileBrowserViewController? = nil) {
        fileOperationsManager.perform(operation, items: items, destination: destination, sourcePane: sourcePane, currentDirectory: currentDirectory)
    }
}

extension FileBrowserViewController: FileOperationsManagerDelegate {
    func fileOperationsManager(_ manager: FileOperationsManager, didRequestPresentSheet viewController: NSViewController) {
        presentAsSheet(viewController)
    }

    func fileOperationsManager(_ manager: FileOperationsManager, didRequestPresentError message: String) {
        showError(message)
    }

    func fileOperationsManagerDidRequestRefresh(_ manager: FileOperationsManager) {
        refreshCurrentDirectory()
    }

    func fileOperationsManagerDidRequestRefreshSource(_ manager: FileOperationsManager, sourcePane: FileBrowserViewController) {
        sourcePane.refreshCurrentDirectory()
    }
    
    var window: NSWindow? { view.window }
}
// MARK: - ToolbarDelegate

extension FileBrowserViewController {
    func toolbarDidRequestBack() {
        if let previousURL = navigationManager.goBack() {
            loadDirectory(previousURL, addToHistory: false)
        }
    }

    func toolbarDidRequestForward() {
        if let nextURL = navigationManager.goForward() {
            loadDirectory(nextURL, addToHistory: false)
        }
    }

    func toolbarDidRequestNavigate(to url: URL) {
        loadDirectory(url)
    }

    func toolbarDidChangeSortColumn(_ column: String, ascending: Bool) {
        sortColumn = column
        sortAscending = ascending
        toolbarViewController.updateSortDisplay(column: column, ascending: ascending)
        sortItems()
        outlineView.reloadData()
        
        // Persist folder-specific sort preference
        var prefs = settings.folderSortPreferences
        prefs[currentDirectory.path] = "\(column)|\(ascending ? "asc" : "desc")"
        settings.folderSortPreferences = prefs
    }

    func toolbarDidRequestNavigateToHistoryIndex(_ index: Int) {
        if let url = navigationManager.navigateToHistoryIndex(index) {
            loadDirectory(url, addToHistory: false)
        }
    }

    func toolbarDidRequestNewFolder() {
        contextMenuNewFolder(self)
    }

    func toolbarDidToggleHiddenFiles(show: Bool) {
        showsHiddenFiles = show
        // Persist hidden files state globally
        settings.hiddenFilesState = show
        refreshCurrentDirectory()
    }
    
    func toolbarDidChangeViewMode(_ viewMode: ViewMode) {
        currentViewMode = viewMode
        toolbarViewController?.updateViewModeDisplay(for: viewMode)
        updateZoomControlVisibility()
        displayFiles(for: viewMode)
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
        searchFilter = searchText
        refreshCurrentDirectory()
    }

    func toolbarDidTogglePreviewPane() {
        if previewVisible { hidePreviewPane() } else { showPreviewPane() }
        settings.previewPaneVisible = previewVisible
    }
    
    func toolbarDidRequestShowFilter() {
        showFilterPanel()
    }
    
    func toolbarDidRequestOpenInTerminal() {
        delegate?.toolbarDidRequestOpenInTerminal(from: self)
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
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.outlineView.reloadData()
            if self.currentViewMode == .icons || self.currentViewMode == .windowsList {
                self.collectionView.reloadData()
            } else if self.currentViewMode == .columns {
                self.browserView.loadColumnZero()
            }
            
            self.delegate?.directoryDidChange(self, to: dataSource.currentDirectory.path)
            self.updateStatusBar()
            
            debugLog("FileBrowserDataSource: didLoadItems - refreshed views")
        }
    }
    
    func dataSource(_ dataSource: FileBrowserDataSource, didFailToLoad error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.showError(error.localizedDescription)
        }
    }
}

// MARK: - NavigationManagerDelegate

extension FileBrowserViewController {
    func navigationManager(_ manager: NavigationManager, didUpdateState state: NavigationState) {
        // Update toolbar with new navigation state
        toolbarViewController?.updatePath(
            state.currentURL,
            canGoBack: state.canGoBack,
            canGoForward: state.canGoForward,
            history: state.history,
            currentIndex: state.currentIndex
        )
    }
}
