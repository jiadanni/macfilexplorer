import Cocoa
import Quartz

// MARK: - Filter Criteria

struct FilterCriteria {
    var fileTypes: Set<String> = []  // Extensions like "pdf", "jpg", "txt"
    var sizeMin: Int64? = nil         // Minimum size in bytes
    var sizeMax: Int64? = nil         // Maximum size in bytes
    var dateMin: Date? = nil          // Minimum modification date
    var dateMax: Date? = nil          // Maximum modification date
    
    var isActive: Bool {
        return !fileTypes.isEmpty || sizeMin != nil || sizeMax != nil || dateMin != nil || dateMax != nil
    }
    
    func matches(_ item: FileItem) -> Bool {
        // File type filter
        if !fileTypes.isEmpty {
            let ext = item.url.pathExtension.lowercased()
            if !fileTypes.contains(ext) && !fileTypes.contains("*") {
                return false
            }
        }
        
        // Size filter
        if let min = sizeMin, item.size < min {
            return false
        }
        if let max = sizeMax, item.size > max {
            return false
        }
        
        // Date filter
        if let min = dateMin, let modDate = item.modificationDate, modDate < min {
            return false
        }
        if let max = dateMax, let modDate = item.modificationDate, modDate > max {
            return false
        }
        
        return true
    }
}

// Root container view that provides a visual highlight when a drag session enters the pane.
class RootFileBrowserView: NSView {
    private var highlightLayer: CALayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
    }

    private func setHighlighted(_ highlighted: Bool) {
        if highlighted {
            if highlightLayer == nil {
                let layer = CALayer()
                layer.borderColor = NSColor.controlAccentColor.cgColor
                layer.borderWidth = 3
                layer.cornerRadius = 6
                layer.frame = bounds.insetBy(dx: 1, dy: 1)
                layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
                highlightLayer = layer
                self.layer?.addSublayer(layer)
            }
        } else {
            highlightLayer?.removeFromSuperlayer()
            highlightLayer = nil
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        setHighlighted(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setHighlighted(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        setHighlighted(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        // We do not handle drops at the root level; child views manage actual operations.
        setHighlighted(false)
        return false
    }
}

// MARK: - Operation Metrics Manager
struct OperationMetric: Codable {
    let type: String
    let bytes: Int64
    let files: Int
    let duration: TimeInterval
    let timestamp: Date
}

class OperationMetricsManager {
    private static let key = "operationMetricsLog"
    private static let maxRecords = 200

    static func append(type: String, bytes: Int64, files: Int, start: Date, end: Date) {
        let duration = end.timeIntervalSince(start)
        var existing = load()
        existing.append(OperationMetric(type: type, bytes: bytes, files: files, duration: duration, timestamp: Date()))
        if existing.count > maxRecords { existing.removeFirst(existing.count - maxRecords) }
        if let data = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> [OperationMetric] {
        guard let data = UserDefaults.standard.data(forKey: key), let decoded = try? JSONDecoder().decode([OperationMetric].self, from: data) else { return [] }
        return decoded
    }
}

// Simple toast/info presentation helper.
extension FileBrowserViewController {
    func showInfo(_ message: String) {
        // Non-blocking informational banner (replaces prior modal alert)
        showBanner(message: message, style: .info)
    }
}

// Cancellation token reference type
extension FileBrowserViewController: NSSplitViewDelegate {
    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard previewVisible, let pv = previewPaneViewController?.view else { return }
        let width = pv.bounds.width
        if width > 100 { // persist only reasonable widths
            UserDefaults.standard.set(width, forKey: UserDefaults.Keys.previewPaneWidth.rawValue)
        }
    }
}
final class CancellationToken {
    private let lock = DispatchSemaphore(value: 1)
    private var _isCancelled = false
    var isCancelled: Bool { lock.wait(); defer { lock.signal() }; return _isCancelled }
    func cancel() { lock.wait(); _isCancelled = true; lock.signal() }
}

// Simple sheet controller used during asynchronous size calculation prior to confirmation dialogs.
class SizeCalculationViewController: NSViewController {
    private var progressIndicator: NSProgressIndicator!
    private var statusLabel: NSTextField!
    private var cancelButton: NSButton!
    private var isCancelled = false
    var cancelHandler: (() -> Void)?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 120))
        setupUI()
    }

    private func setupUI() {
        progressIndicator = NSProgressIndicator()
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.style = .spinning
        progressIndicator.startAnimation(self)
        view.addSubview(progressIndicator)

        statusLabel = NSTextField(labelWithString: "Calculating total size...")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.alignment = .center
        view.addSubview(statusLabel)

        cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped(_:)))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressIndicator.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),

            statusLabel.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            cancelButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    func updateStatus(_ text: String) { statusLabel.stringValue = text }

    @objc private func cancelTapped(_ sender: Any) {
        guard !isCancelled else { return }
        isCancelled = true
        cancelHandler?()
        dismiss(self)
    }
}

class FileBrowserViewController: NSViewController, NSMenuDelegate, NSGestureRecognizerDelegate, QLPreviewPanelDataSource, QLPreviewPanelDelegate, StatusBarDelegate {

    weak var delegate: FileBrowserDelegate?

    internal var toolbarViewController: ToolbarViewController!
    internal var statusBarViewController: StatusBarViewController!
    private var containerView: NSView! // New container view
    private var scrollView: NSScrollView! // For outlineView
    private var outlineView: NSOutlineView!
    private var collectionView: NSCollectionView! // For icons view
    private var collectionViewScrollView: NSScrollView! // For collection view
    private var browserView: NSBrowser! // For columns view
    private enum BrowserSetupState { case idle, preparing, creatingBrowser, ready, failed }
    private var browserSetupState: BrowserSetupState = .idle {
        didSet {
            let msg = "DEBUG: browserSetupState -> \(browserSetupState)"
            print(msg)
            if let handle = FileHandle(forWritingAtPath: "/tmp/macfileexplorer_column_debug.log") {
                handle.seekToEndOfFile()
                if let data = (msg + "\n").data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
            }
        }
    }

    private let browserSerialQueue = DispatchQueue(label: "com.macfileexplorer.browserSetup")

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
            let msg = "DEBUG: beginBrowserSetup blocked; state=\(browserSetupState)"
            print(msg)
            if let handle = FileHandle(forWritingAtPath: "/tmp/macfileexplorer_column_debug.log") {
                handle.seekToEndOfFile()
                if let data = (msg + "\n").data(using: .utf8) { handle.write(data) }
                handle.closeFile()
            }
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

    private var suppressedDisplayCalls = 0
    private var freeFormLayout: FreeFormCollectionViewLayout? // Custom layout for free-form icon positioning
    // Per-pane preview management
    private var previewSplitView: NSSplitView?
    private var previewPaneViewController: PreviewPaneViewController?
    private var previewVisible: Bool = false
    
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
    private var filterCriteria: FilterCriteria = FilterCriteria()

    // Sorting state
    private var sortColumn: String = "NameColumn"
    private var sortAscending: Bool = true
    
    // Zoom level (0.5 to 2.0, default 1.0)
    private var zoomLevel: Double = 1.0
    
    // Free-form icon positioning
    private var isFreeFormEnabled: Bool = true

    // Banner notification handling
    private var bannerContainer: NSView?
    private var bannerDismissWorkItem: DispatchWorkItem?

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
        // Load persisted hidden files state
        self.showsHiddenFiles = UserDefaults.standard.bool(forKey: UserDefaults.Keys.hiddenFilesState.rawValue)
        // Load default view & sort (initial values before folder-specific overrides)
        if let defaultView = UserDefaults.standard.string(forKey: UserDefaults.Keys.defaultViewMode.rawValue) {
            switch defaultView {
            case "icons": currentViewMode = .icons
            case "columns": currentViewMode = .columns
            case "windowsList": currentViewMode = .windowsList
            default: currentViewMode = .list
            }
        }
        if let defaultSort = UserDefaults.standard.string(forKey: UserDefaults.Keys.defaultSortColumn.rawValue) {
            sortColumn = defaultSort
        }
        if UserDefaults.standard.object(forKey: UserDefaults.Keys.defaultSortAscending.rawValue) != nil {
            sortAscending = UserDefaults.standard.bool(forKey: UserDefaults.Keys.defaultSortAscending.rawValue)
        }

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
        // Load persisted hidden files state
        self.showsHiddenFiles = UserDefaults.standard.bool(forKey: UserDefaults.Keys.hiddenFilesState.rawValue)
        // Load default view & sort
        if let defaultView = UserDefaults.standard.string(forKey: UserDefaults.Keys.defaultViewMode.rawValue) {
            switch defaultView {
            case "icons": currentViewMode = .icons
            case "columns": currentViewMode = .columns
            case "windowsList": currentViewMode = .windowsList
            default: currentViewMode = .list
            }
        }
        if let defaultSort = UserDefaults.standard.string(forKey: UserDefaults.Keys.defaultSortColumn.rawValue) {
            sortColumn = defaultSort
        }
        if UserDefaults.standard.object(forKey: UserDefaults.Keys.defaultSortAscending.rawValue) != nil {
            sortAscending = UserDefaults.standard.bool(forKey: UserDefaults.Keys.defaultSortAscending.rawValue)
        }

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
        Notification.default.removeObserver(self, name: .showFileExtensionsDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .easySelectDidChangeNotification, object: nil)
    }

    override func loadView() {
        view = RootFileBrowserView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        setupUI()
        loadDirectory(currentDirectory)
        // Initial preview visibility from global default applied per pane
        let defaultShowPreview = UserDefaults.standard.bool(forKey: UserDefaults.Keys.showPreviewPane.rawValue)
        if defaultShowPreview { showPreviewPane() }
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

        // Create status bar
        statusBarViewController = StatusBarViewController()
        statusBarViewController.delegate = self
        addChild(statusBarViewController)
        view.addSubview(statusBarViewController.view)
        statusBarViewController.view.translatesAutoresizingMaskIntoConstraints = false

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
        
        // Column visibility preferences (initialize defaults if missing)
        var columnVisibility = UserDefaults.standard.dictionary(forKey: UserDefaults.Keys.columnVisibility.rawValue) as? [String: Bool] ?? [: ]
        if columnVisibility.isEmpty {
            columnVisibility = [
                "NameColumn": true,
                "DateModifiedColumn": true,
                "TypeColumn": true,
                "SizeColumn": true,
                // Hidden by default as requested
                "DateCreatedColumn": false,
                "TagsColumn": false
            ]
            UserDefaults.standard.set(columnVisibility, forKey: UserDefaults.Keys.columnVisibility.rawValue)
        }
        applyColumnVisibility(columnVisibility)
        // Header right-click menu for toggling columns
        outlineView.headerView?.menu = createHeaderColumnsMenu()
        
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

        // Apply Windows Explorer-like styling
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Set initial view mode
        displayFiles(for: currentViewMode)
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
        let savedWidth = UserDefaults.standard.double(forKey: UserDefaults.Keys.previewPaneWidth.rawValue)
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
        let selected = outlineView.selectedRowIndexes
        guard selected.count == 1, let row = selected.first else { return nil }
        return outlineView.item(atRow: row) as? FileItem
    }

    // Update preview pane with a newly selected file or clear if nil/multiple
    private func updatePreviewPane(with file: FileItem?) {
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
            let msg = "DEBUG: displayFiles blocked (state=\(browserSetupState)) count=\(suppressedDisplayCalls)"
            print(msg)
            if let handle = FileHandle(forWritingAtPath: "/tmp/macfileexplorer_column_debug.log") {
                handle.seekToEndOfFile()
                if let data = (msg + "\n").data(using: .utf8) { handle.write(data) }
                handle.closeFile()
            }
            return
        }
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
            
            if !previewVisible {
                activeConstraints = [
                    scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
                    scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                    scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
                ]
                NSLayoutConstraint.activate(activeConstraints)
            }
            outlineView.reloadData() // Reloads the outline view

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

            // Configure layout based on viewMode
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

            collectionView.reloadData()

            // Use dispatch to ensure window is ready
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.view.window?.makeFirstResponder(self.view)
            }
            
        case .columns:
            // Use NSBrowser for columns view
            if browserView == nil {
                enqueueBrowserSetupIfNeeded()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    guard let self else {
                        return
                    }
                    if self.browserView != nil && self.browserSetupState == .ready {
                        let msg = "DEBUG: Retrying displayFiles after browser ready; suppressedDisplayCalls=\(self.suppressedDisplayCalls)"
                        print(msg)
                        if let handle = FileHandle(forWritingAtPath: "/tmp/macfileexplorer_column_debug.log") {
                            handle.seekToEndOfFile()
                            if let data = (msg + "\n").data(using: .utf8) { handle.write(data) }
                            handle.closeFile()
                        }
                        self.suppressedDisplayCalls = 0
                        self.displayFiles(for: .columns)
                    }
                }
                return
            }
            
            guard let browserView = browserView else {
                print("Error: BrowserView not properly initialized")
                currentViewMode = .list
                displayFiles(for: .list)
                return
            }
            
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
            
            // Use dispatch to ensure layout is complete before loading data
            print("displayFiles: Setting up browser view, rootItem has \(self.rootItem?.children?.count ?? 0) children")
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
        // If preview visible, ensure split embedding stays consistent after view switch
        if previewVisible { ensureContentInPreviewSplit() }
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
        assert(Thread.isMainThread, "setupBrowserView must run on main thread")
        // Prevent duplicate setup
        if browserView != nil {
            print("BrowserView already initialized, skipping setup")
            return
        }

        guard let token = beginBrowserSetup() else { return }
        token.markCreating()

        // Construct NSBrowser here to avoid cross-file visibility issues
        let newBrowser = NSBrowser()
        newBrowser.translatesAutoresizingMaskIntoConstraints = false
        newBrowser.allowsMultipleSelection = true
        newBrowser.allowsEmptySelection = true
        newBrowser.takesTitleFromPreviousColumn = false
        newBrowser.separatesColumns = true
        newBrowser.dividerStyle = .thin
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

        browserView = newBrowser

        // Set delegate AFTER creation and assignment
        browserView.delegate = self

        print("BrowserView setup completed with minColumnWidth: 180")

        token.markReady()
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
        print("FileBrowserViewController: loadDirectory - Loading URL: \(url.path)")

        // Validate URL exists and is accessible
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            print("  ✗ Error: Path does not exist: \(url.path)")
            showError("The folder \"\(url.lastPathComponent)\" could not be opened because it doesn't exist.")
            return
        }
        
        guard isDirectory.boolValue else {
            print("  ✗ Error: Path is not a directory: \(url.path)")
            showError("The item \"\(url.lastPathComponent)\" is not a folder.")
            return
        }

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
                // Load stored sort preference for this folder before sorting
                if let prefs = UserDefaults.standard.dictionary(forKey: UserDefaults.Keys.folderSortPreferences.rawValue) as? [String:String] {
                    if let stored = prefs[targetURL.path] {
                        let parts = stored.components(separatedBy: "|")
                        if parts.count >= 2 {
                            let storedColumn = parts[0]
                            let storedDirection = parts[1]
                            self.sortColumn = storedColumn
                            self.sortAscending = (storedDirection == "asc")
                            self.toolbarViewController?.updateSortDisplay(column: self.sortColumn, ascending: self.sortAscending)
                        }
                    }
                }
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
                let result = naturalCompare(item1.name, item2.name)
                return sortAscending ? (result == .orderedAscending) : (result == .orderedDescending)
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
                guard let date1 = item1.modificationDate, let date2 = item2.modificationDate else { return false }
                return sortAscending ? date1 < date2 : date1 > date2
            }
        case "DateCreatedColumn":
            items.sort { item1, item2 in
                guard let date1 = item1.creationDate, let date2 = item2.creationDate else { return false }
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
        items.forEach {
            if $0.isDirectory, var children = $0.children {
                sortChildren(&children)
                $0.children = children
            }
        }
    }

    private func sortChildren(_ children: inout [FileItem]) {
        switch sortColumn {
        case "NameColumn":
            children.sort { item1, item2 in
                let result = naturalCompare(item1.name, item2.name)
                return sortAscending ? (result == .orderedAscending) : (result == .orderedDescending)
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
                guard let date1 = item1.modificationDate, let date2 = item2.modificationDate else { return false }
                return sortAscending ? date1 < date2 : date1 > date2
            }
        case "DateCreatedColumn":
            children.sort { item1, item2 in
                guard let date1 = item1.creationDate, let date2 = item2.creationDate else { return false }
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

    // Natural comparison for filenames with numeric segments
    private func naturalCompare(_ a: String, _ b: String) -> ComparisonResult {
        // Fast path
        if a == b { return .orderedSame }

        let aTokens = tokenizeNatural(a)
        let bTokens = tokenizeNatural(b)
        let count = max(aTokens.count, bTokens.count)
        for i in 0..<count {
            let aToken = i < aTokens.count ? aTokens[i] : nil
            let bToken = i < bTokens.count ? bTokens[i] : nil
            if aToken == nil { return .orderedAscending }
            if bToken == nil { return .orderedDescending }
            switch (aToken!, bToken!) {
            case let (.number(aNum, aRaw), .number(bNum, bRaw)):
                if aNum != bNum { return aNum < bNum ? .orderedAscending : .orderedDescending }
                // If numeric values equal, shorter raw (fewer leading zeros) comes first
                if aRaw.count != bRaw.count { return aRaw.count < bRaw.count ? .orderedAscending : .orderedDescending }
            case let (.text(aText), .text(bText)):
                let cmp = aText.localizedCaseInsensitiveCompare(bText)
                if cmp != .orderedSame { return cmp }
            case (.number, .text):
                // Numbers before text for intuitive ordering
                return .orderedAscending
            case (.text, .number):
                return .orderedDescending
            }
        }
        return .orderedSame
    }

    private enum NaturalToken {
        case number(Int, String)
        case text(String)
    }

    private func tokenizeNatural(_ s: String) -> [NaturalToken] {
        var tokens: [NaturalToken] = []
        var current = ""
        var isNumber = false
        func flush() {
            guard !current.isEmpty else { return }
            if isNumber, let intVal = Int(current) {
                tokens.append(.number(intVal, current))
            } else {
                tokens.append(.text(current))
            }
            current.removeAll()
        }
        for ch in s {
            if ch.isNumber {
                if !isNumber { flush(); isNumber = true }
                current.append(ch)
            } else {
                if isNumber { flush(); isNumber = false }
                current.append(ch)
            }
        }
        flush()
        return tokens
    }

    private func applySearchFilter() {
        guard let rootItem = rootItem else { return }
        
        // Check if any filtering is active
        let hasSearchText = searchFilter != nil && !searchFilter!.isEmpty
        let hasFilterCriteria = filterCriteria.isActive
        
        guard hasSearchText || hasFilterCriteria else { return }

        // Filter children based on search text and filter criteria
        if var children = rootItem.children {
            children = children.filter {
                // Apply text search filter
                if hasSearchText, let searchText = searchFilter {
                    if !item.name.localizedCaseInsensitiveContains(searchText) {
                        return false
                    }
                }
                
                // Apply advanced filters (but not to folders unless explicitly filtering by them)
                if hasFilterCriteria && !item.isDirectory {
                    if !filterCriteria.matches(item) {
                        return false
                    }
                }
                
                return true
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

    func setZoomControlsVisible(_ visible: Bool) {
        statusBarViewController.setZoomControlsVisible(visible)
    }

    func setZoomLevel(_ level: Double) {
        zoomLevel = max(0.5, min(2.0, level)) // Clamp between 0.5 and 2.0
        statusBarViewController?.setZoomLevel(zoomLevel)
        applyZoomToCurrentView()
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
        menu.addItem(withTitle: "Advanced Copy To...", action: #selector(contextMenuAdvancedCopyTo(_:)), keyEquivalent: "")
        
        let cutItem = NSMenuItem(title: "Cut", action: #selector(contextMenuCut(_:)), keyEquivalent: showHotkeys ? "x" : "")
        if showHotkeys {
            cutItem.keyEquivalentModifierMask = .command
        }
        menu.addItem(cutItem)
        menu.addItem(withTitle: "Move To...", action: #selector(contextMenuMoveTo(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Advanced Move To...", action: #selector(contextMenuAdvancedMoveTo(_:)), keyEquivalent: "")
        
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
        let visibility = UserDefaults.standard.dictionary(forKey: UserDefaults.Keys.columnVisibility.rawValue) as? [String: Bool] ?? [: ]
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
        var visibility = UserDefaults.standard.dictionary(forKey: UserDefaults.Keys.columnVisibility.rawValue) as? [String: Bool] ?? [: ]
        let current = visibility[identifier] ?? true
        visibility[identifier] = !current
        UserDefaults.standard.set(visibility, forKey: UserDefaults.Keys.columnVisibility.rawValue)
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
        UserDefaults.standard.set(defaults, forKey: UserDefaults.Keys.columnVisibility.rawValue)
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

        // Remove global folder color item (no longer per-folder)
        if let changeFolderColorItem = menu.items.first(where: { $0.title == "Change Folder Color..." }) {
            menu.removeItem(changeFolderColorItem)
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

    func getSelectedItems() -> [FileItem] {
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
            // If no selection, check if there's a clicked column/row (for context menu)
            let clickedColumn = browserView.clickedColumn
            let clickedRow = browserView.clickedRow(inColumn: clickedColumn)
            if clickedColumn >= 0 && clickedRow >= 0 {
                if let item = fileItemForColumn(clickedColumn),
                   let children = item.children, clickedRow < children.count {
                    items.append(children[clickedRow])
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
        alert.informativeText = "Enter the name for the selected items:"
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
                NSWorkspace.shared.open(item.url)
            }
        } else if items.count > 1 {
            NSWorkspace.shared.open(items.map { $0.url })
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
        
        NSWorkspace.shared.open([item.url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc func openWithOther(_ sender: Any) {
        let items = getSelectedItems()
        guard let item = items.first, items.count == 1 else { return }
        
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        openPanel.allowedContentTypes = [.application]
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let appURL = openPanel.url {
            NSWorkspace.shared.open([item.url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
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
        pasteboard.declareTypes([.fileURL], owner: nil)
        
        let fileURLs = items.map { $0.url as NSURL }
        pasteboard.writeObjects(fileURLs)
        
        // Add a custom type to indicate it's a cut operation
        pasteboard.setString("cut", forType: .string)
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

        let isCut = pasteboard.string(forType: .string) == "cut"
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

        // Confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Delete \(items.count) item(s)?"
        alert.informativeText = "Are you sure you want to move \(items.count) item(s) to the Trash?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            performFileOperation(.delete, items: items.map { $0.url }, destination: nil)
        }
    }

    @objc func contextMenuNewFolder(_ sender: Any) {
        let newFolderName = "Untitled Folder"
        var finalName = newFolderName
        var counter = 1
        while FileManager.default.fileExists(atPath: currentDirectory.appendingPathComponent(finalName).path) {
            finalName = "\(newFolderName) \(counter)"
            counter += 1
        }
        
        let newFolderURL = currentDirectory.appendingPathComponent(finalName)
        
        do {
            try FileManager.default.createDirectory(at: newFolderURL, withIntermediateDirectories: false, attributes: nil)
            refreshCurrentDirectory()
        } catch {
            showError("Failed to create folder: \(error.localizedDescription)")
        }
    }

    @objc func contextMenuNewFile(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "New File"
        alert.informativeText = "Enter the name for the new file:"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = "untitled.txt"
        alert.accessoryView = textField
        
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let newFileName = textField.stringValue
            if !newFileName.isEmpty {
                let newFileURL = currentDirectory.appendingPathComponent(newFileName)
                if !FileManager.default.fileExists(atPath: newFileURL.path) {
                    FileManager.default.createFile(atPath: newFileURL.path, contents: nil, attributes: nil)
                    refreshCurrentDirectory()
                } else {
                    showError("A file with this name already exists.")
                }
            }
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
            NSWorkspace.shared.activateFileViewerSelecting([currentDirectory])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting(items.map { $0.url })
        }
    }
    
    @objc func contextMenuOpenInTerminal(_ sender: Any) {
        delegate?.toolbarDidRequestOpenInTerminal()
    }

    @objc func contextMenuClosePane(_ sender: Any) {
        delegate?.fileBrowserDidRequestClosePane(self)
    }

    @objc func contextMenuAddToFavorites(_ sender: Any) {
        let items = getSelectedItems()
        guard let item = items.first, items.count == 1 else { return }
        delegate?.fileBrowserDidRequestAddToFavorites(self, item: item)
    }
    
    private func performFileOperation(_ operation: FileOperationType, items: [URL], destination: URL?) {
        guard !items.isEmpty else { return }
        
        // If confirmation is enabled, show the dialog first
        let confirmOps = UserDefaults.standard.bool(forKey: UserDefaults.Keys.confirmFileOperations.rawValue)
        
        if confirmOps && operation != .delete {
            // Use the existing FileCopyMoveDialog initializer which starts the operation.
            let opType: FileCopyMoveDialog.OperationType = (operation == .copy) ? .copy : .move
            let confirmationDialog = FileCopyMoveDialog(operationType: opType, sourceFiles: items, destination: destination ?? currentDirectory)
            presentAsSheet(confirmationDialog)
        } else {
            // Execute immediately without confirmation
            executeFileOperation(operation, items: items, destination: destination)
        }
    }
    
    private func executeFileOperation(_ operation: FileOperationType, items: [URL], destination: URL?) {
        let showProgress = UserDefaults.standard.bool(forKey: UserDefaults.Keys.showOperationProgress.rawValue)
        let progressVC = showProgress ? ProgressViewController() : nil
        if let progressVC = progressVC {
            presentAsSheet(progressVC)
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fileManager = FileManager.default
            let autoRename = UserDefaults.standard.bool(forKey: UserDefaults.Keys.autoRenameOnConflict.rawValue)
            var totalSize: Int64 = 0
            let startTime = Date()
            
            for (index, sourceURL) in items.enumerated() {
                var targetURL = destination?.appendingPathComponent(sourceURL.lastPathComponent)
                
                if operation == .delete {
                    do {
                        try fileManager.trashItem(at: sourceURL, resultingItemURL: nil)
                    } catch {
                        DispatchQueue.main.async {
                            self?.showError("Failed to move '\(sourceURL.lastPathComponent)' to Trash: \(error.localizedDescription)")
                        }
                    }
                } else if var targetURL = targetURL {
                    // Handle name conflicts
                    if autoRename && fileManager.fileExists(atPath: targetURL.path) {
                        var counter = 1
                        let nameWithoutExt = (sourceURL.lastPathComponent as NSString).deletingPathExtension
                        let ext = (sourceURL.lastPathComponent as NSString).pathExtension
                        repeat {
                            let newName = ext.isEmpty ? "\(nameWithoutExt) \(counter)" : "\(nameWithoutExt) \(counter).\(ext)"
                            targetURL = destination!.appendingPathComponent(newName)
                            counter += 1
                        } while fileManager.fileExists(atPath: targetURL.path)
                    }
                    
                    do {
                        if operation == .copy {
                            try fileManager.copyItem(at: sourceURL, to: targetURL)
                        } else { // .move
                            try fileManager.moveItem(at: sourceURL, to: targetURL)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self?.showError("Failed to \(operation.rawValue) '\(sourceURL.lastPathComponent)': \(error.localizedDescription)")
                        }
                    }
                }
                
                // Update progress
                DispatchQueue.main.async {
                    progressVC?.updateProgress(to: Double(index + 1) / Double(items.count), description: "Processing: \(sourceURL.lastPathComponent)")
                }
            }
            
            // Finalize
            OperationMetricsManager.append(type: operation.rawValue, bytes: totalSize, files: items.count, start: startTime, end: Date())
            DispatchQueue.main.async {
                progressVC?.dismiss(self)
                self?.refreshCurrentDirectory()
            }
        }
    }
}
enum FileOperationType: String {
    case copy = "copy"
    case move = "move"
    case delete = "delete"
}
// MARK: - ToolbarDelegate

extension FileBrowserViewController: ToolbarDelegate {
    func toolbarDidRequestBack() {
        if currentHistoryIndex > 0 {
            let previousURL = navigationHistory[currentHistoryIndex - 1]
            currentHistoryIndex -= 1
            loadDirectory(previousURL, addToHistory: false)
        }
    }

    func toolbarDidRequestForward() {
        if currentHistoryIndex < navigationHistory.count - 1 {
            let nextURL = navigationHistory[currentHistoryIndex + 1]
            currentHistoryIndex += 1
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
        var prefs = UserDefaults.standard.dictionary(forKey: UserDefaults.Keys.folderSortPreferences.rawValue) as? [String:String] ?? [: ]
        prefs[currentDirectory.path] = "\(column)|\(ascending ? "asc" : "desc")"
        UserDefaults.standard.set(prefs, forKey: UserDefaults.Keys.folderSortPreferences.rawValue)
    }

    func toolbarDidRequestNavigateToHistoryIndex(_ index: Int) {
        guard index >= 0, index < navigationHistory.count else { return }
        currentHistoryIndex = index
        let url = navigationHistory[index]
        loadDirectory(url, addToHistory: false)
    }

    func toolbarDidRequestNewFolder() {
        contextMenuNewFolder(self)
    }

    func toolbarDidToggleHiddenFiles(show: Bool) {
        showsHiddenFiles = show
        // Persist hidden files state globally
        UserDefaults.standard.set(show, forKey: UserDefaults.Keys.hiddenFilesState.rawValue)
        refreshCurrentDirectory()
    }
    
    func toolbarDidChangeViewMode(_ viewMode: ViewMode) {
        currentViewMode = viewMode
        toolbarViewController?.updateViewModeDisplay(for: viewMode)
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
        UserDefaults.standard.set(previewVisible, forKey: UserDefaults.Keys.showPreviewPane.rawValue)
        NotificationCenter.default.post(name: .previewPaneToggled, object: nil)
    }
    
    func toolbarDidRequestShowFilter() {
        showFilterPanel()
    }
    
    func toolbarDidRequestOpenInTerminal() {
        delegate?.toolbarDidRequestOpenInTerminal()
    }
}

// MARK: - NSCollectionViewDataSource

extension FileBrowserViewController: NSCollectionViewDataSource {
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return rootItem?.children?.count ?? 0
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = FileIconItem()
        if let fileItem = rootItem?.children?[indexPath.item] {
            item.fileItem = fileItem
        }
        return item
    }
}

// MARK: - NSCollectionViewDelegate

extension FileBrowserViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        updateStatusBarForCollectionView()
        
        let items = indexPaths.compactMap { rootItem.children?[$0.item] }
        if items.count == 1 {
            updatePreviewPane(with: items.first)
        } else {
            updatePreviewPane(with: nil)
        }
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        updateStatusBarForCollectionView()
        if collectionView.selectionIndexPaths.count == 1, let firstPath = collectionView.selectionIndexPaths.first {
            let item = rootItem.children?[firstPath.item]
            updatePreviewPane(with: item)
        } else {
            updatePreviewPane(with: nil)
        }
    }

    private func updateStatusBarForCollectionView() {
        let selectedIndexPaths = collectionView.selectionIndexPaths
        let selectedCount = selectedIndexPaths.count
        var totalSize: Int64 = 0
        
        selectedIndexPaths.forEach {
            if let item = rootItem.children?[$0.item] {
                totalSize += item.size
            }
        }
        
        delegate?.fileBrowser(self, didUpdateSelection: selectedCount, totalSize: totalSize)
    }
    
    // MARK: - Drag and Drop for CollectionView
    
    func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        guard let item = rootItem.children?[indexPath.item] else { return nil }
        return item.url as NSURL
    }
    
    func collectionView(_ collectionView: NSCollectionView, validateDrop draggingInfo: NSDraggingInfo, proposedIndexPath: UnsafeMutablePointer<IndexPath>, dropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        // Allow dropping onto an item (folder) or between items
        if dropOperation.pointee == .on {
            return .copy
        } else {
            return .move
        }
    }
    
    func collectionView(_ collectionView: NSCollectionView, acceptDrop draggingInfo: NSDraggingInfo, indexPath: IndexPath, dropOperation: NSCollectionView.DropOperation) -> Bool {
        guard let urls = draggingInfo.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return false }
        
        // Determine destination
        let destinationURL: URL
        if dropOperation == .on {
            // Dropped onto a folder
            guard let item = rootItem.children?[indexPath.item], item.isDirectory else { return false }
            destinationURL = item.url
        } else {
            // Dropped between items, use current directory
            destinationURL = currentDirectory
        }
        
        // Perform the move/copy
        performFileOperation(.move, items: urls, destination: destinationURL)
        return true
    }
}

// MARK: - NSBrowserDelegate

extension FileBrowserViewController: NSBrowserDelegate {
    func rootItem(for browser: NSBrowser) -> Any? {
        return rootItem
    }

    func browser(_ browser: NSBrowser, numberOfChildrenOfItem item: Any?) -> Int {
        guard let fileItem = item as? FileItem else { return 0 }
        if fileItem.children == nil {
            fileItem.loadChildren(showsHiddenFiles: showsHiddenFiles)
        }
        return fileItem.children?.count ?? 0
    }

    func browser(_ browser: NSBrowser, child index: Int, ofItem item: Any?) -> Any {
        guard let fileItem = item as? FileItem else {
            fatalError("Invalid item for browser")
        }
        return fileItem.children?[index] as Any
    }

    func browser(_ browser: NSBrowser, isLeafItem item: Any?) -> Bool {
        guard let fileItem = item as? FileItem else { return true }
        return !fileItem.isDirectory
    }

    func browser(_ browser: NSBrowser, objectValueForItem item: Any?) -> Any? {
        guard let fileItem = item as? FileItem else { return nil }
        return fileItem.displayName
    }

    func browser(_ browser: NSBrowser, willDisplayCell cell: Any, atRow row: Int, column: Int) {
        guard let browserCell = cell as? NSBrowserCell else { return }
        
        // Get the item for the cell
        let parentItem = fileItemForColumn(column)
        guard let children = parentItem?.children, row < children.count else { return }
        let item = children[row]
        
        browserCell.image = item.icon
        browserCell.title = item.displayName
        browserCell.isLeaf = !item.isDirectory
    }
    
    private func fileItemForColumn(_ column: Int) -> FileItem? {
        if column == 0 {
            return rootItem
        }
        
        let path = browserView.path(toColumn: column)
        var currentItem = rootItem
        
        let components = path.components(separatedBy: browserView.pathSeparator)
        for component in components.dropFirst() { // Drop root
            if let child = currentItem?.children?.first(where: { $0.displayName == component }) {
                currentItem = child
            } else {
                return nil
            }
        }
        return currentItem
    }

    func browser(_ browser: NSBrowser, selectionDidChangeInColumn column: Int) {
        updateStatusBarForBrowser()
        
        // Get selected item
        let selectedRows = browser.selectedRowIndexes(inColumn: column)
        guard let selectedRow = selectedRows?.first else {
            updatePreviewPane(with: nil)
            return
        }
        
        if let parentItem = fileItemForColumn(column),
           let children = parentItem.children, selectedRow < children.count {
            let selectedItem = children[selectedRow]
            updatePreviewPane(with: selectedItem)
        } else {
            updatePreviewPane(with: nil)
        }
    }
    
    private func updateStatusBarForBrowser() {
        let selectedColumn = browserView.selectedColumn
        guard selectedColumn >= 0 else {
            delegate?.fileBrowser(self, didUpdateSelection: 0, totalSize: 0)
            return
        }
        
        let selectedRows = browserView.selectedRowIndexes(inColumn: selectedColumn)
        let selectedCount = selectedRows?.count ?? 0
        var totalSize: Int64 = 0
        
        selectedRows?.forEach {
            if let parentItem = fileItemForColumn(selectedColumn),
               let children = parentItem.children, $0 < children.count {
                totalSize += children[$0].size
            }
        }
        
        delegate?.fileBrowser(self, didUpdateSelection: selectedCount, totalSize: totalSize)
    }

    // MARK: - Drag and Drop for Browser View
    
    func browser(_ browser: NSBrowser, writeRowsWith rowIndexes: IndexSet, inColumn column: Int, to pboard: NSPasteboard) -> Bool {
        guard let parentItem = fileItemForColumn(column),
              let children = parentItem.children else { return false }
        
        let itemsToDrag = rowIndexes.compactMap { children[$0] }
        let urls = itemsToDrag.map { $0.url as NSURL }
        
        pboard.clearContents()
        return pboard.writeObjects(urls)
    }
    
    func browser(_ browser: NSBrowser, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        // Only accept file URLs
        guard info.draggingPasteboard.canReadObject(forClasses: [NSURL.self]) else { return [] }

        // Determine the target directory for the drop
        let targetDirectoryItem: FileItem?
        if let fileItem = item as? FileItem {
            // Dropping on a specific item. Only allow if it's a directory.
            guard fileItem.isDirectory else { return [] }
            targetDirectoryItem = fileItem
        } else {
            // Dropping into empty space in a column. This means dropping into the directory represented by that column.
            let proposedColumn = browser.column(at: info.draggingLocation)
            guard proposedColumn >= 0 else { return [] }
            targetDirectoryItem = fileItemForColumn(proposedColumn)
        }
        
        guard let destinationURL = targetDirectoryItem?.url else { return [] }

        // Determine operation based on modifier keys (Option key for copy)
        var operation: NSDragOperation = []
        if info.modifierFlags.contains(.option) {
            operation = .copy
        } else {
            operation = .move
        }
        
        // Prevent dropping a dragged item onto itself or into one of its subfolders.
        if let draggedURLs = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for draggedURL in draggedURLs {
                if draggedURL == destinationURL || destinationURL.path.hasPrefix(draggedURL.path + "/") {
                    return []
                }
            }
        }
        
        // The source operation mask tells us what the source is willing to do.
        // We should only return an operation that the source also supports.
        if !info.draggingSourceOperationMask.contains(operation) {
            return []
        }

        return operation
    }
    
        func browser(_ browser: NSBrowser, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
    
            guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
    
                return false
    
            }
    
            
    
            // Determine the target directory for the drop
    
            let targetDirectoryItem: FileItem?
    
            if let fileItem = item as? FileItem {
    
                // Dropping on a specific item. Only allow if it's a directory.
    
                guard fileItem.isDirectory else { return false }
    
                targetDirectoryItem = fileItem
    
            } else {
    
                // Dropping into empty space in a column. This means dropping into the directory represented by that column.
    
                let proposedColumn = browser.column(at: info.draggingLocation)
    
                guard proposedColumn >= 0 else { return false }
    
                targetDirectoryItem = fileItemForColumn(proposedColumn)
    
            }
    
            
    
            guard let destinationURL = targetDirectoryItem?.url else { return false }
    
    
    
            // Determine operation from validateDrop's return value (draggingDestinationOperationMask)
    
            let operation: FileOperationType
    
            if info.draggingDestinationOperationMask.contains(.copy) {
    
                operation = .copy
    
            } else if info.draggingDestinationOperationMask.contains(.move) {
    
                operation = .move
    
            } else {
    
                return false // Should not happen if validateDrop is correct
    
            }
    
            
    
            performFileOperation(operation, items: urls, destination: destinationURL)
    
            return true
    
        }
    
    }
    
    // MARK: - Notification Handling
    
    extension FileBrowserViewController {
    
        @objc private func handleTabDidChange(_ notification: Notification) {
    
            if let tabVC = notification.object as? NSViewController {
    
                // The zoom slider should only be visible for the main file browser view, which is contained in a SplitPaneViewController.
    
                // Other special tab types like Start, Settings, etc., should not show it.
    
                let isZoomable = tabVC is SplitPaneViewController
    
                statusBarViewController.setZoomControlsVisible(isZoomable)
    
            }
    
        }

    }

// MARK: - QLPreviewPanelDataSource / QLPreviewPanelDelegate stubs
extension FileBrowserViewController {
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return 0
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return nil
    }
}
