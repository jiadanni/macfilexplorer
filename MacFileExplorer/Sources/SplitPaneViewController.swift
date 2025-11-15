import Cocoa

enum SplitOrientation {
    case vertical
    case horizontal
}

// Layout preset structure
struct PaneLayout: Codable {
    var paneCount: Int
    var orientation: String // "vertical" or "horizontal"
    var panePaths: [String]
    var paneSizes: [CGFloat]
    var activePaneIndex: Int

    init(paneCount: Int, orientation: SplitOrientation, panePaths: [String], paneSizes: [CGFloat], activePaneIndex: Int) {
        self.paneCount = paneCount
        self.orientation = orientation == .vertical ? "vertical" : "horizontal"
        self.panePaths = panePaths
        self.paneSizes = paneSizes
        self.activePaneIndex = activePaneIndex
    }
}

// Pane bookmark structure
struct PaneBookmark: Codable, Identifiable {
    var id: String
    var name: String
    var layout: PaneLayout
    var createdAt: Date
    var keyboardShortcut: Int? // 1-5 for Cmd+Option+1-5

    init(id: String = UUID().uuidString, name: String, layout: PaneLayout, keyboardShortcut: Int? = nil) {
        self.id = id
        self.name = name
        self.layout = layout
        self.createdAt = Date()
        self.keyboardShortcut = keyboardShortcut
    }
}

// Session structure
struct PaneSession: Codable, Identifiable {
    var id: String
    var name: String
    var layouts: [PaneLayout]
    var activeLayoutIndex: Int
    var createdAt: Date
    var lastModified: Date

    init(id: String = UUID().uuidString, name: String, layouts: [PaneLayout], activeLayoutIndex: Int = 0) {
        self.id = id
        self.name = name
        self.layouts = layouts
        self.activeLayoutIndex = activeLayoutIndex
        self.createdAt = Date()
        self.lastModified = Date()
    }
}

// Pane history entry
struct PaneHistoryEntry: Codable {
    var path: String
    var timestamp: Date
    var paneIndex: Int
}

// Pane filter
enum PaneFilter: Codable {
    case fileType(extensions: [String])
    case size(min: Int64?, max: Int64?)
    case date(after: Date?, before: Date?)
    case custom(name: String, predicate: String)
}

// Pane theme
struct PaneTheme: Codable {
    var name: String
    var backgroundColor: String // Hex color
    var borderColor: String
    var textColor: String
    var accentColor: String
    var transparency: Double
}

// Pane analytics
struct PaneAnalytics: Codable {
    var paneIndex: Int
    var visitedPaths: [String: Int] // path: visit count
    var timeSpent: [String: TimeInterval] // path: time in seconds
    var operations: [String: Int] // operation type: count
    var lastVisit: Date
}

protocol FileBrowserDelegate: AnyObject {
    func directoryDidChange(to path: String)
    func openInNewTab(url: URL)
    func fileBrowserDidRequestSplit(_ fileBrowser: FileBrowserViewController, orientation: SplitOrientation)
    func fileBrowser(_ fileBrowser: FileBrowserViewController, didSelectFile file: FileItem?)
    func fileBrowserDidRequestClosePane(_ fileBrowser: FileBrowserViewController)
    func fileBrowser(_ fileBrowser: FileBrowserViewController, didUpdateSelection selectedCount: Int, totalSize: Int64)
    func fileBrowser(_ fileBrowser: FileBrowserViewController, didUpdateDiskSpace diskSpace: String?)
    func fileBrowserDidRequestAddToFavorites(_ fileBrowser: FileBrowserViewController, item: FileItem)
}

protocol SplitPaneViewControllerDelegate: AnyObject {
    func splitPaneDirectoryDidChange(to path: String)
    func splitPaneOpenInNewTab(url: URL)
    func splitPane(_ splitPane: SplitPaneViewController, didUpdateSelection selectedCount: Int, totalSize: Int64)
    func splitPane(_ splitPane: SplitPaneViewController, didUpdateDiskSpace diskSpace: String?)
    func splitPaneDidRequestAddToFavorites(item: FileItem)
}

class SplitPaneViewController: NSSplitViewController, FileBrowserDelegate {

    weak var delegate: SplitPaneViewControllerDelegate?

    private var panes: [FileBrowserViewController] = []
    private var activePaneIndex: Int = 0
    private var previewPaneViewController: PreviewPaneViewController?
    private var previewPaneSplitItem: NSSplitViewItem?
    private var selectedFileItem: FileItem?

    // Nested split view for file browser panes
    private var fileBrowserSplitViewController: NSSplitViewController?
    private var fileBrowserSplitItem: NSSplitViewItem?
    private var currentPaneOrientation: SplitOrientation = .vertical

    // For pane size persistence
    private static let PaneSizesKey = "SplitPaneViewController.PaneSizes"
    private static let PreviewPaneSizeKey = "SplitPaneViewController.PreviewPaneSize"

    // Named observer for memory management
    private var previewPaneObserver: NSObjectProtocol?

    // Active pane visual indicator
    private var activePaneBorderLayers: [CALayer] = []

    // Pane synchronization
    private var panesAreSynchronized: Bool = false

    // Maximize/restore state
    private var maximizedPaneIndex: Int?
    private var savedPaneSizesBeforeMaximize: [CGFloat]?

    // Performance optimization - throttle save operations
    private var savePaneSizesWorkItem: DispatchWorkItem?

    // Layout presets
    private static let PaneLayoutPresetsKey = "SplitPaneViewController.LayoutPresets"
    private static let CurrentLayoutKey = "SplitPaneViewController.CurrentLayout"

    // Bookmarks
    private var bookmarks: [PaneBookmark] = []
    private static let BookmarksKey = "SplitPaneViewController.Bookmarks"

    // Sessions
    private var sessions: [PaneSession] = []
    private var currentSession: PaneSession?
    private static let SessionsKey = "SplitPaneViewController.Sessions"
    private static let CurrentSessionKey = "SplitPaneViewController.CurrentSession"

    // History
    private var paneHistories: [[PaneHistoryEntry]] = []
    private var globalHistory: [PaneHistoryEntry] = []
    private static let HistoryKey = "SplitPaneViewController.History"
    private static let MaxHistoryEntries = 100

    // Filters
    private var paneFilters: [Int: PaneFilter] = [:] // paneIndex: filter

    // Comparison mode
    private var comparisonMode: Bool = false
    private var comparisonPanes: (Int, Int)? // Indices of panes being compared

    // Analytics
    private var paneAnalytics: [PaneAnalytics] = []
    private var analyticsTimers: [Int: Date] = [:] // paneIndex: start time
    private static let AnalyticsKey = "SplitPaneViewController.Analytics"

    // Themes
    private var paneThemes: [Int: PaneTheme] = [:] // paneIndex: theme
    private static let ThemesKey = "SplitPaneViewController.Themes"
    private static let DefaultThemes: [PaneTheme] = [
        PaneTheme(name: "Default", backgroundColor: "#FFFFFF", borderColor: "#007AFF", textColor: "#000000", accentColor: "#007AFF", transparency: 1.0),
        PaneTheme(name: "Dark", backgroundColor: "#1E1E1E", borderColor: "#0A84FF", textColor: "#FFFFFF", accentColor: "#0A84FF", transparency: 1.0),
        PaneTheme(name: "Sepia", backgroundColor: "#F4ECD8", borderColor: "#8B4513", textColor: "#5D4037", accentColor: "#8B4513", transparency: 1.0)
    ]

    // Gestures
    private var swipeGestureRecognizer: NSPanGestureRecognizer?

    // Performance monitoring
    private var performanceMetrics: [Int: (memoryUsage: UInt64, loadTime: TimeInterval, fileCount: Int)] = [:]

    var currentPath: String {
        guard activePaneIndex < panes.count else { return "/" }
        return panes[activePaneIndex].currentPath
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadPersistentData()
        setupUI()
        setupNotificationObservers()
        setupGestures()
        startAnalyticsTracking()
    }

    deinit {
        removeNotificationObservers()
        stopAnalyticsTracking()
        savePersistentData()
    }

    // MARK: - Notification Management

    private func setupNotificationObservers() {
        previewPaneObserver = NotificationCenter.default.addObserver(
            forName: .previewPaneCloseRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.togglePreviewPane()
        }
    }

    private func removeNotificationObservers() {
        if let observer = previewPaneObserver {
            NotificationCenter.default.removeObserver(observer)
            previewPaneObserver = nil
        }
    }

    private func setupUI() {
        // Configure the main split view for preview pane (always vertical or horizontal based on preview position)
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self

        // Create nested split view for file browser panes
        let nestedSplitVC = NSSplitViewController()
        nestedSplitVC.splitView.isVertical = true
        nestedSplitVC.splitView.dividerStyle = .thin
        nestedSplitVC.splitView.delegate = self
        fileBrowserSplitViewController = nestedSplitVC

        // Add nested split view to main split view
        addChild(nestedSplitVC)
        let nestedSplitItem = NSSplitViewItem(viewController: nestedSplitVC)
        nestedSplitItem.canCollapse = false
        fileBrowserSplitItem = nestedSplitItem
        addSplitViewItem(nestedSplitItem)

        // Try to restore saved layout first
        if !restoreSavedLayout() {
            // Add initial file browser pane if no layout was restored
            addPane()

            // Restore pane sizes
            restorePaneSizes()
        }

        // Check if preview pane should be shown by default
        let showPreview = UserDefaults.standard.bool(forKey: UserDefaults.Keys.showPreviewPane.rawValue)
        if showPreview {
            showPreviewPane()
        }
    }

    // MARK: - Public Methods

    func addPane(url: URL? = nil) {
        guard let nestedSplitVC = fileBrowserSplitViewController else { return }

        let fileBrowser = FileBrowserViewController()
        fileBrowser.delegate = self

        // Enable layer-backed view for visual indicators
        fileBrowser.view.wantsLayer = true

        // Add click gesture recognizer to track active pane
        let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(paneClicked(_:)))
        fileBrowser.view.addGestureRecognizer(clickRecognizer)

        // Add double-click gesture for maximize/restore
        let doubleClickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(paneDoubleClicked(_:)))
        doubleClickRecognizer.numberOfClicksRequired = 2
        fileBrowser.view.addGestureRecognizer(doubleClickRecognizer)

        // Add context menu
        setupPaneContextMenu(for: fileBrowser)

        panes.append(fileBrowser)

        nestedSplitVC.addChild(fileBrowser)
        let splitItem = NSSplitViewItem(viewController: fileBrowser)
        splitItem.canCollapse = false
        nestedSplitVC.addSplitViewItem(splitItem)

        // Navigate to URL if provided
        if let url = url {
            do {
                try navigateToURLWithErrorHandling(url, in: fileBrowser)
            } catch {
                showNavigationError(error, for: url)
            }
        }

        // Update active pane
        activePaneIndex = panes.count - 1
        setActivePaneKeyboardFocus()

        // Add visual indicator for active pane
        updateActivePaneIndicator()

        // Update close button visibility for all panes
        updateClosePaneButtonVisibility()

        // Set accessibility
        setupAccessibility(for: fileBrowser, index: panes.count - 1)

        // Save pane sizes after a short delay (throttled)
        throttledSavePaneSizes()

        // Save layout
        saveCurrentLayout()
    }

    @objc private func paneClicked(_ sender: NSClickGestureRecognizer) {
        guard let clickedView = sender.view,
              let clickedPane = panes.first(where: { $0.view == clickedView }),
              let index = panes.firstIndex(of: clickedPane) else { return }

        activePaneIndex = index
        setActivePaneKeyboardFocus()
        updateActivePaneIndicator()
        delegate?.splitPaneDirectoryDidChange(to: panes[activePaneIndex].currentPath)
    }

    @objc private func paneDoubleClicked(_ sender: NSClickGestureRecognizer) {
        guard let clickedView = sender.view,
              let clickedPane = panes.first(where: { $0.view == clickedView }),
              let index = panes.firstIndex(of: clickedPane) else { return }

        activePaneIndex = index
        togglePaneMaximize()
    }

    func removeActivePane() {
        guard panes.count > 1, activePaneIndex < panes.count,
              let nestedSplitVC = fileBrowserSplitViewController else { return }

        let paneToRemove = panes[activePaneIndex]
        panes.remove(at: activePaneIndex)

        // Find and remove the split view item by matching the view controller
        if let itemIndex = nestedSplitVC.splitViewItems.firstIndex(where: { $0.viewController == paneToRemove }) {
            nestedSplitVC.removeSplitViewItem(nestedSplitVC.splitViewItems[itemIndex])
        }

        paneToRemove.removeFromParent()

        // Update active pane index
        if activePaneIndex >= panes.count {
            activePaneIndex = panes.count - 1
        }

        // Set focus to new active pane
        setActivePaneKeyboardFocus()
        updateActivePaneIndicator()

        // Notify delegate of new active path
        if activePaneIndex < panes.count {
            delegate?.splitPaneDirectoryDidChange(to: panes[activePaneIndex].currentPath)
        }

        // Update close button visibility for all remaining panes
        updateClosePaneButtonVisibility()

        // Save pane sizes (throttled)
        throttledSavePaneSizes()

        // Save layout
        saveCurrentLayout()
    }

    func splitVertically() {
        guard let nestedSplitVC = fileBrowserSplitViewController else { return }

        // Get current directory from active pane
        let currentURL = URL(fileURLWithPath: currentPath)

        // Update the nested split view orientation
        nestedSplitVC.splitView.isVertical = true
        currentPaneOrientation = .vertical

        // Add new pane with same directory
        addPane(url: currentURL)
    }

    func splitHorizontally() {
        guard let nestedSplitVC = fileBrowserSplitViewController else { return }

        // Update the nested split view orientation
        nestedSplitVC.splitView.isVertical = false
        currentPaneOrientation = .horizontal

        // Get current directory from active pane
        let currentURL = URL(fileURLWithPath: currentPath)

        // Add new pane with same directory
        addPane(url: currentURL)
    }

    func navigateToURL(_ url: URL) {
        print("SplitPaneViewController: navigateToURL - Received URL: \(url.path)")
        guard activePaneIndex < panes.count else { return }

        do {
            try navigateToURLWithErrorHandling(url, in: panes[activePaneIndex])
        } catch {
            showNavigationError(error, for: url)
        }
    }

    func cutSelection() {
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].cutSelection()
    }

    func copySelection() {
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].copySelection()
    }

    func pasteSelection() {
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].pasteSelection()
    }

    func setViewMode(_ viewMode: ViewMode) {
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].toolbarDidChangeViewMode(viewMode)
    }
    
    func toggleHiddenFiles() {
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].toggleHiddenFilesState()
    }

    func isShowingHiddenFiles() -> Bool {
        guard activePaneIndex < panes.count else { return false }
        return panes[activePaneIndex].isShowingHiddenFiles()
    }

    func updateZoomLevel(to level: Double) {
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].setZoomLevel(level)
    }

    func goBack() {
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].toolbarDidRequestBack()
    }

    func goForward() {
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].toolbarDidRequestForward()
    }

    // MARK: - Pane Navigation

    func switchToPane(at index: Int) {
        guard index >= 0, index < panes.count else { return }
        activePaneIndex = index
        setActivePaneKeyboardFocus()
        updateActivePaneIndicator()
        delegate?.splitPaneDirectoryDidChange(to: panes[activePaneIndex].currentPath)
    }

    func switchToNextPane() {
        let nextIndex = (activePaneIndex + 1) % panes.count
        switchToPane(at: nextIndex)
    }

    func switchToPreviousPane() {
        let previousIndex = (activePaneIndex - 1 + panes.count) % panes.count
        switchToPane(at: previousIndex)
    }

    // MARK: - Pane Synchronization

    func togglePaneSynchronization() {
        panesAreSynchronized.toggle()
    }

    func arePanesSynchronized() -> Bool {
        return panesAreSynchronized
    }

    // MARK: - Pane Swapping

    func swapPanes(at index1: Int, with index2: Int) {
        guard index1 >= 0, index1 < panes.count,
              index2 >= 0, index2 < panes.count,
              index1 != index2,
              let nestedSplitVC = fileBrowserSplitViewController else { return }

        // Swap in the panes array
        panes.swapAt(index1, index2)

        // Get the split items
        guard let item1 = nestedSplitVC.splitViewItems.first(where: { $0.viewController == panes[index2] }),
              let item2 = nestedSplitVC.splitViewItems.first(where: { $0.viewController == panes[index1] }) else { return }

        // Remove both items
        nestedSplitVC.removeSplitViewItem(item1)
        nestedSplitVC.removeSplitViewItem(item2)

        // Re-insert in swapped positions
        nestedSplitVC.insertSplitViewItem(item2, at: index1)
        nestedSplitVC.insertSplitViewItem(item1, at: index2)

        // Save layout
        saveCurrentLayout()
    }

    func swapActiveWithNextPane() {
        guard panes.count > 1 else { return }
        let nextIndex = (activePaneIndex + 1) % panes.count
        swapPanes(at: activePaneIndex, with: nextIndex)
    }

    func togglePreviewPane() {
        if previewPaneViewController != nil {
            hidePreviewPane()
        } else {
            showPreviewPane()
        }

        // Save preference
        UserDefaults.standard.set(previewPaneViewController != nil, forKey: UserDefaults.Keys.showPreviewPane.rawValue)
        NotificationCenter.default.post(name: Notification.Name("previewPaneToggled"), object: nil)
    }

    private func showPreviewPane() {
        guard previewPaneViewController == nil else { return }

        let previewVC = PreviewPaneViewController()
        previewPaneViewController = previewVC

        // Get preferred position
        let positionString = UserDefaults.standard.string(forKey: UserDefaults.Keys.previewPanePosition.rawValue) ?? "right"
        let position: PreviewPanePosition = positionString == "bottom" ? .bottom : .right

        // Update main split view orientation based on preview position
        splitView.isVertical = (position == .right)

        previewVC.position = position

        addChild(previewVC)
        let splitItem = NSSplitViewItem(viewController: previewVC)
        splitItem.minimumThickness = 250
        splitItem.maximumThickness = 600
        splitItem.canCollapse = false
        previewPaneSplitItem = splitItem
        addSplitViewItem(splitItem)

        // Restore preview pane size
        restorePreviewPaneSize()

        // Preview the currently selected file
        if let selectedFile = selectedFileItem {
            previewVC.previewFile(selectedFile)
        }
    }

    private func hidePreviewPane() {
        guard let previewVC = previewPaneViewController,
              let splitItem = previewPaneSplitItem else { return }

        // Save preview pane size before hiding
        savePreviewPaneSize()

        removeSplitViewItem(splitItem)
        previewVC.removeFromParent()
        previewPaneViewController = nil
        previewPaneSplitItem = nil

        // Restore vertical orientation for main split view
        splitView.isVertical = true
    }

    // MARK: - Private Methods

    private func updateClosePaneButtonVisibility() {
        // Show close button only when there are multiple panes
        let shouldShowCloseButton = panes.count > 1
        for pane in panes {
            pane.setClosePaneButtonVisible(shouldShowCloseButton)
        }
    }

    // MARK: - Focus Management

    private func setActivePaneKeyboardFocus() {
        guard activePaneIndex < panes.count else { return }
        let activePane = panes[activePaneIndex]

        // Make the active pane's view the first responder
        DispatchQueue.main.async {
            activePane.view.window?.makeFirstResponder(activePane.view)
        }
    }

    // MARK: - Error Handling

    enum NavigationError: LocalizedError {
        case pathDoesNotExist(URL)
        case permissionDenied(URL)
        case notADirectory(URL)
        case unknown(URL, Error)

        var errorDescription: String? {
            switch self {
            case .pathDoesNotExist(let url):
                return "The path '\(url.path)' does not exist."
            case .permissionDenied(let url):
                return "Permission denied accessing '\(url.path)'."
            case .notADirectory(let url):
                return "The path '\(url.path)' is not a directory."
            case .unknown(let url, let error):
                return "Failed to navigate to '\(url.path)': \(error.localizedDescription)"
            }
        }
    }

    private func navigateToURLWithErrorHandling(_ url: URL, in fileBrowser: FileBrowserViewController) throws {
        let fileManager = FileManager.default

        // Check if path exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw NavigationError.pathDoesNotExist(url)
        }

        // Check if it's a directory
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard isDirectory.boolValue else {
            throw NavigationError.notADirectory(url)
        }

        // Check if readable
        guard fileManager.isReadableFile(atPath: url.path) else {
            throw NavigationError.permissionDenied(url)
        }

        // Navigate
        fileBrowser.navigateToURL(url)
    }

    private func showNavigationError(_ error: Error, for url: URL) {
        let alert = NSAlert()
        alert.messageText = "Navigation Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Retry")
        alert.addButton(withTitle: "Go to Parent")

        let response = alert.runModal()

        switch response {
        case .alertSecondButtonReturn: // Retry
            do {
                try navigateToURLWithErrorHandling(url, in: panes[activePaneIndex])
            } catch {
                // Show error again if retry fails
                showNavigationError(error, for: url)
            }
        case .alertThirdButtonReturn: // Go to Parent
            let parentURL = url.deletingLastPathComponent()
            do {
                try navigateToURLWithErrorHandling(parentURL, in: panes[activePaneIndex])
            } catch {
                showNavigationError(error, for: parentURL)
            }
        default:
            break
        }
    }

    // MARK: - Pane Size Persistence

    private func savePaneSizes() {
        guard let nestedSplitVC = fileBrowserSplitViewController else { return }

        let positions = nestedSplitVC.splitView.arrangedSubviews.map { subview in
            nestedSplitVC.splitView.isVertical ? subview.frame.width : subview.frame.height
        }

        UserDefaults.standard.set(positions, forKey: SplitPaneViewController.PaneSizesKey)
    }

    private func restorePaneSizes() {
        guard let nestedSplitVC = fileBrowserSplitViewController,
              let positions = UserDefaults.standard.array(forKey: SplitPaneViewController.PaneSizesKey) as? [CGFloat],
              positions.count == nestedSplitVC.splitView.arrangedSubviews.count else { return }

        DispatchQueue.main.async {
            for (index, subview) in nestedSplitVC.splitView.arrangedSubviews.enumerated() {
                if nestedSplitVC.splitView.isVertical {
                    subview.setFrameSize(NSSize(width: positions[index], height: subview.frame.height))
                } else {
                    subview.setFrameSize(NSSize(width: subview.frame.width, height: positions[index]))
                }
            }
            nestedSplitVC.splitView.adjustSubviews()
        }
    }

    private func savePreviewPaneSize() {
        guard let splitItem = previewPaneSplitItem else { return }
        let size = splitView.isVertical ? splitItem.viewController.view.frame.width : splitItem.viewController.view.frame.height
        UserDefaults.standard.set(size, forKey: SplitPaneViewController.PreviewPaneSizeKey)
    }

    private func restorePreviewPaneSize() {
        guard let splitItem = previewPaneSplitItem else { return }
        let savedSize = UserDefaults.standard.double(forKey: SplitPaneViewController.PreviewPaneSizeKey)

        if savedSize > 0 {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let view = splitItem.viewController.view
                if self.splitView.isVertical {
                    view.setFrameSize(NSSize(width: savedSize, height: view.frame.height))
                } else {
                    view.setFrameSize(NSSize(width: view.frame.width, height: savedSize))
                }
                self.splitView.adjustSubviews()
            }
        }
    }

    private func throttledSavePaneSizes() {
        // Cancel any pending save operation
        savePaneSizesWorkItem?.cancel()

        // Create new work item
        let workItem = DispatchWorkItem { [weak self] in
            self?.savePaneSizes()
        }
        savePaneSizesWorkItem = workItem

        // Execute after delay (throttle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    // MARK: - Layout Persistence

    private func saveCurrentLayout() {
        guard let nestedSplitVC = fileBrowserSplitViewController else { return }

        let panePaths = panes.map { $0.currentPath }
        let paneSizes = nestedSplitVC.splitView.arrangedSubviews.map { subview in
            nestedSplitVC.splitView.isVertical ? subview.frame.width : subview.frame.height
        }

        let layout = PaneLayout(
            paneCount: panes.count,
            orientation: currentPaneOrientation,
            panePaths: panePaths,
            paneSizes: paneSizes,
            activePaneIndex: activePaneIndex
        )

        if let encoded = try? JSONEncoder().encode(layout) {
            UserDefaults.standard.set(encoded, forKey: SplitPaneViewController.CurrentLayoutKey)
        }
    }

    private func restoreSavedLayout() -> Bool {
        guard let layoutData = UserDefaults.standard.data(forKey: SplitPaneViewController.CurrentLayoutKey),
              let layout = try? JSONDecoder().decode(PaneLayout.self, from: layoutData),
              let nestedSplitVC = fileBrowserSplitViewController else {
            return false
        }

        // Set orientation
        let isVertical = layout.orientation == "vertical"
        nestedSplitVC.splitView.isVertical = isVertical
        currentPaneOrientation = isVertical ? .vertical : .horizontal

        // Add panes with saved paths
        for path in layout.panePaths {
            let url = URL(fileURLWithPath: path)
            addPane(url: url)
        }

        // Restore active pane
        if layout.activePaneIndex < panes.count {
            activePaneIndex = layout.activePaneIndex
            setActivePaneKeyboardFocus()
            updateActivePaneIndicator()
        }

        return true
    }

    // MARK: - Visual Indicators

    private func updateActivePaneIndicator() {
        // Remove all existing border layers
        for layer in activePaneBorderLayers {
            layer.removeFromSuperlayer()
        }
        activePaneBorderLayers.removeAll()

        guard activePaneIndex < panes.count else { return }
        let activePane = panes[activePaneIndex]

        // Create border layer for active pane
        let borderLayer = CALayer()
        borderLayer.frame = activePane.view.bounds
        borderLayer.borderColor = NSColor.controlAccentColor.cgColor
        borderLayer.borderWidth = 2.0
        borderLayer.cornerRadius = 4.0
        borderLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

        activePane.view.layer?.addSublayer(borderLayer)
        activePaneBorderLayers.append(borderLayer)
    }

    // MARK: - Context Menu

    private func setupPaneContextMenu(for fileBrowser: FileBrowserViewController) {
        let menu = NSMenu()

        let closeItem = NSMenuItem(title: "Close This Pane", action: #selector(contextMenuClosePane(_:)), keyEquivalent: "")
        closeItem.target = self
        closeItem.representedObject = fileBrowser
        menu.addItem(closeItem)

        let closeOthersItem = NSMenuItem(title: "Close Other Panes", action: #selector(contextMenuCloseOtherPanes(_:)), keyEquivalent: "")
        closeOthersItem.target = self
        closeOthersItem.representedObject = fileBrowser
        menu.addItem(closeOthersItem)

        menu.addItem(NSMenuItem.separator())

        let splitVerticalItem = NSMenuItem(title: "Split Vertically", action: #selector(contextMenuSplitVertically(_:)), keyEquivalent: "")
        splitVerticalItem.target = self
        splitVerticalItem.representedObject = fileBrowser
        menu.addItem(splitVerticalItem)

        let splitHorizontalItem = NSMenuItem(title: "Split Horizontally", action: #selector(contextMenuSplitHorizontally(_:)), keyEquivalent: "")
        splitHorizontalItem.target = self
        splitHorizontalItem.representedObject = fileBrowser
        menu.addItem(splitHorizontalItem)

        menu.addItem(NSMenuItem.separator())

        let swapItem = NSMenuItem(title: "Swap with Next Pane", action: #selector(contextMenuSwapWithNext(_:)), keyEquivalent: "")
        swapItem.target = self
        swapItem.representedObject = fileBrowser
        menu.addItem(swapItem)

        menu.addItem(NSMenuItem.separator())

        let maximizeItem = NSMenuItem(title: "Maximize/Restore", action: #selector(contextMenuMaximize(_:)), keyEquivalent: "")
        maximizeItem.target = self
        maximizeItem.representedObject = fileBrowser
        menu.addItem(maximizeItem)

        fileBrowser.view.menu = menu
    }

    @objc private func contextMenuClosePane(_ sender: NSMenuItem) {
        guard let fileBrowser = sender.representedObject as? FileBrowserViewController,
              let index = panes.firstIndex(of: fileBrowser) else { return }
        activePaneIndex = index
        removeActivePane()
    }

    @objc private func contextMenuCloseOtherPanes(_ sender: NSMenuItem) {
        guard let fileBrowser = sender.representedObject as? FileBrowserViewController,
              let keepIndex = panes.firstIndex(of: fileBrowser),
              let nestedSplitVC = fileBrowserSplitViewController else { return }

        // Remove all panes except the selected one
        for i in (0..<panes.count).reversed() {
            if i != keepIndex {
                let paneToRemove = panes[i]
                panes.remove(at: i)

                if let itemIndex = nestedSplitVC.splitViewItems.firstIndex(where: { $0.viewController == paneToRemove }) {
                    nestedSplitVC.removeSplitViewItem(nestedSplitVC.splitViewItems[itemIndex])
                }
                paneToRemove.removeFromParent()
            }
        }

        // Update active pane to the remaining one
        activePaneIndex = 0
        setActivePaneKeyboardFocus()
        updateActivePaneIndicator()
        updateClosePaneButtonVisibility()
        saveCurrentLayout()
    }

    @objc private func contextMenuSplitVertically(_ sender: NSMenuItem) {
        guard let fileBrowser = sender.representedObject as? FileBrowserViewController,
              let index = panes.firstIndex(of: fileBrowser) else { return }
        activePaneIndex = index
        splitVertically()
    }

    @objc private func contextMenuSplitHorizontally(_ sender: NSMenuItem) {
        guard let fileBrowser = sender.representedObject as? FileBrowserViewController,
              let index = panes.firstIndex(of: fileBrowser) else { return }
        activePaneIndex = index
        splitHorizontally()
    }

    @objc private func contextMenuSwapWithNext(_ sender: NSMenuItem) {
        guard let fileBrowser = sender.representedObject as? FileBrowserViewController,
              let index = panes.firstIndex(of: fileBrowser) else { return }
        activePaneIndex = index
        swapActiveWithNextPane()
    }

    @objc private func contextMenuMaximize(_ sender: NSMenuItem) {
        guard let fileBrowser = sender.representedObject as? FileBrowserViewController,
              let index = panes.firstIndex(of: fileBrowser) else { return }
        activePaneIndex = index
        togglePaneMaximize()
    }

    // MARK: - Maximize/Restore

    private func togglePaneMaximize() {
        if maximizedPaneIndex != nil {
            restorePaneLayout()
        } else {
            maximizeActivePane()
        }
    }

    private func maximizeActivePane() {
        guard activePaneIndex < panes.count,
              let nestedSplitVC = fileBrowserSplitViewController,
              maximizedPaneIndex == nil else { return }

        // Save current sizes
        savedPaneSizesBeforeMaximize = nestedSplitVC.splitView.arrangedSubviews.map { subview in
            nestedSplitVC.splitView.isVertical ? subview.frame.width : subview.frame.height
        }

        // Hide all other panes
        for (index, item) in nestedSplitVC.splitViewItems.enumerated() {
            if index != activePaneIndex {
                item.isCollapsed = true
            }
        }

        maximizedPaneIndex = activePaneIndex
    }

    private func restorePaneLayout() {
        guard let nestedSplitVC = fileBrowserSplitViewController,
              let savedSizes = savedPaneSizesBeforeMaximize else { return }

        // Show all panes
        for item in nestedSplitVC.splitViewItems {
            item.isCollapsed = false
        }

        // Restore sizes
        DispatchQueue.main.async {
            for (index, subview) in nestedSplitVC.splitView.arrangedSubviews.enumerated() {
                guard index < savedSizes.count else { continue }
                if nestedSplitVC.splitView.isVertical {
                    subview.setFrameSize(NSSize(width: savedSizes[index], height: subview.frame.height))
                } else {
                    subview.setFrameSize(NSSize(width: subview.frame.width, height: savedSizes[index]))
                }
            }
            nestedSplitVC.splitView.adjustSubviews()
        }

        maximizedPaneIndex = nil
        savedPaneSizesBeforeMaximize = nil
    }

    // MARK: - Accessibility

    private func setupAccessibility(for fileBrowser: FileBrowserViewController, index: Int) {
        fileBrowser.view.setAccessibilityLabel("File Browser Pane \(index + 1)")
        fileBrowser.view.setAccessibilityRole(.group)
        fileBrowser.view.setAccessibilityHelp("File browser pane showing \(fileBrowser.currentPath)")
    }

    // MARK: - Data Persistence

    private func loadPersistentData() {
        loadBookmarks()
        loadSessions()
        loadHistory()
        loadAnalytics()
        loadThemes()
    }

    private func savePersistentData() {
        saveBookmarks()
        saveSessions()
        saveHistory()
        saveAnalytics()
        saveThemes()
    }

    // MARK: - Bookmarks Management

    private func loadBookmarks() {
        if let data = UserDefaults.standard.data(forKey: SplitPaneViewController.BookmarksKey),
           let loaded = try? JSONDecoder().decode([PaneBookmark].self, from: data) {
            bookmarks = loaded
        }
    }

    private func saveBookmarks() {
        if let encoded = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(encoded, forKey: SplitPaneViewController.BookmarksKey)
        }
    }

    func createBookmark(name: String, keyboardShortcut: Int? = nil) {
        guard let nestedSplitVC = fileBrowserSplitViewController else { return }

        let panePaths = panes.map { $0.currentPath }
        let paneSizes = nestedSplitVC.splitView.arrangedSubviews.map { subview in
            nestedSplitVC.splitView.isVertical ? subview.frame.width : subview.frame.height
        }

        let layout = PaneLayout(
            paneCount: panes.count,
            orientation: currentPaneOrientation,
            panePaths: panePaths,
            paneSizes: paneSizes,
            activePaneIndex: activePaneIndex
        )

        let bookmark = PaneBookmark(name: name, layout: layout, keyboardShortcut: keyboardShortcut)
        bookmarks.append(bookmark)
        saveBookmarks()
    }

    func restoreBookmark(_ bookmark: PaneBookmark) {
        restoreLayout(bookmark.layout)
    }

    func deleteBookmark(id: String) {
        bookmarks.removeAll { $0.id == id }
        saveBookmarks()
    }

    func getBookmarks() -> [PaneBookmark] {
        return bookmarks
    }

    private func restoreLayout(_ layout: PaneLayout) {
        guard let nestedSplitVC = fileBrowserSplitViewController else { return }

        // Remove all existing panes
        for pane in panes.reversed() {
            if let itemIndex = nestedSplitVC.splitViewItems.firstIndex(where: { $0.viewController == pane }) {
                nestedSplitVC.removeSplitViewItem(nestedSplitVC.splitViewItems[itemIndex])
            }
            pane.removeFromParent()
        }
        panes.removeAll()

        // Set orientation
        let isVertical = layout.orientation == "vertical"
        nestedSplitVC.splitView.isVertical = isVertical
        currentPaneOrientation = isVertical ? .vertical : .horizontal

        // Add panes with saved paths
        for path in layout.panePaths {
            let url = URL(fileURLWithPath: path)
            addPane(url: url)
        }

        // Restore active pane
        if layout.activePaneIndex < panes.count {
            activePaneIndex = layout.activePaneIndex
            setActivePaneKeyboardFocus()
            updateActivePaneIndicator()
        }
    }

    // MARK: - Session Management

    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: SplitPaneViewController.SessionsKey),
           let loaded = try? JSONDecoder().decode([PaneSession].self, from: data) {
            sessions = loaded
        }

        if let data = UserDefaults.standard.data(forKey: SplitPaneViewController.CurrentSessionKey),
           let current = try? JSONDecoder().decode(PaneSession.self, from: data) {
            currentSession = current
        }
    }

    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: SplitPaneViewController.SessionsKey)
        }

        if let current = currentSession,
           let encoded = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(encoded, forKey: SplitPaneViewController.CurrentSessionKey)
        }
    }

    func createSession(name: String) {
        guard let nestedSplitVC = fileBrowserSplitViewController else { return }

        let panePaths = panes.map { $0.currentPath }
        let paneSizes = nestedSplitVC.splitView.arrangedSubviews.map { subview in
            nestedSplitVC.splitView.isVertical ? subview.frame.width : subview.frame.height
        }

        let layout = PaneLayout(
            paneCount: panes.count,
            orientation: currentPaneOrientation,
            panePaths: panePaths,
            paneSizes: paneSizes,
            activePaneIndex: activePaneIndex
        )

        let session = PaneSession(name: name, layouts: [layout])
        sessions.append(session)
        currentSession = session
        saveSessions()
    }

    func switchToSession(_ session: PaneSession) {
        currentSession = session
        if !session.layouts.isEmpty {
            let layout = session.layouts[session.activeLayoutIndex]
            restoreLayout(layout)
        }
        saveSessions()
    }

    func getSessions() -> [PaneSession] {
        return sessions
    }

    // MARK: - History Navigation

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: SplitPaneViewController.HistoryKey),
           let loaded = try? JSONDecoder().decode([PaneHistoryEntry].self, from: data) {
            globalHistory = loaded
        }
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(globalHistory) {
            UserDefaults.standard.set(encoded, forKey: SplitPaneViewController.HistoryKey)
        }
    }

    private func addToHistory(path: String, paneIndex: Int) {
        let entry = PaneHistoryEntry(path: path, timestamp: Date(), paneIndex: paneIndex)
        globalHistory.append(entry)

        // Maintain max entries
        if globalHistory.count > SplitPaneViewController.MaxHistoryEntries {
            globalHistory.removeFirst(globalHistory.count - SplitPaneViewController.MaxHistoryEntries)
        }

        saveHistory()
    }

    func getHistory() -> [PaneHistoryEntry] {
        return globalHistory
    }

    func navigateToHistoryEntry(_ entry: PaneHistoryEntry) {
        if entry.paneIndex < panes.count {
            activePaneIndex = entry.paneIndex
            let url = URL(fileURLWithPath: entry.path)
            navigateToURL(url)
        }
    }

    func clearHistory() {
        globalHistory.removeAll()
        paneHistories.removeAll()
        saveHistory()
    }

    // MARK: - Filters and Views

    func setFilter(_ filter: PaneFilter, for paneIndex: Int) {
        paneFilters[paneIndex] = filter
        // Apply filter to pane (would need to integrate with FileBrowserViewController)
    }

    func removeFilter(for paneIndex: Int) {
        paneFilters.removeValue(forKey: paneIndex)
    }

    func getFilter(for paneIndex: Int) -> PaneFilter? {
        return paneFilters[paneIndex]
    }

    // MARK: - Comparison Mode

    func toggleComparisonMode(pane1: Int, pane2: Int) {
        if comparisonMode {
            disableComparisonMode()
        } else {
            enableComparisonMode(pane1: pane1, pane2: pane2)
        }
    }

    private func enableComparisonMode(pane1: Int, pane2: Int) {
        guard pane1 < panes.count, pane2 < panes.count, pane1 != pane2 else { return }
        comparisonMode = true
        comparisonPanes = (pane1, pane2)
        // Enable synchronized scrolling between the two panes
    }

    private func disableComparisonMode() {
        comparisonMode = false
        comparisonPanes = nil
    }

    func isInComparisonMode() -> Bool {
        return comparisonMode
    }

    // MARK: - Analytics

    private func loadAnalytics() {
        if let data = UserDefaults.standard.data(forKey: SplitPaneViewController.AnalyticsKey),
           let loaded = try? JSONDecoder().decode([PaneAnalytics].self, from: data) {
            paneAnalytics = loaded
        }
    }

    private func saveAnalytics() {
        if let encoded = try? JSONEncoder().encode(paneAnalytics) {
            UserDefaults.standard.set(encoded, forKey: SplitPaneViewController.AnalyticsKey)
        }
    }

    private func startAnalyticsTracking() {
        // Start tracking time spent in active pane
        analyticsTimers[activePaneIndex] = Date()
    }

    private func stopAnalyticsTracking() {
        // Stop all tracking and save
        updateAnalyticsForPane(activePaneIndex)
        saveAnalytics()
    }

    private func updateAnalyticsForPane(_ paneIndex: Int) {
        guard paneIndex < panes.count else { return }

        let path = panes[paneIndex].currentPath
        let analytics: PaneAnalytics

        if let existing = paneAnalytics.first(where: { $0.paneIndex == paneIndex }) {
            analytics = existing
        } else {
            analytics = PaneAnalytics(paneIndex: paneIndex, visitedPaths: [:], timeSpent: [:], operations: [:], lastVisit: Date())
            paneAnalytics.append(analytics)
        }

        // Update visit count
        var visitedPaths = analytics.visitedPaths
        visitedPaths[path, default: 0] += 1

        // Update time spent
        var timeSpent = analytics.timeSpent
        if let startTime = analyticsTimers[paneIndex] {
            let duration = Date().timeIntervalSince(startTime)
            timeSpent[path, default: 0] += duration
        }

        // Update analytics
        if let index = paneAnalytics.firstIndex(where: { $0.paneIndex == paneIndex }) {
            paneAnalytics[index] = PaneAnalytics(
                paneIndex: paneIndex,
                visitedPaths: visitedPaths,
                timeSpent: timeSpent,
                operations: analytics.operations,
                lastVisit: Date()
            )
        }
    }

    func getAnalytics() -> [PaneAnalytics] {
        return paneAnalytics
    }

    // MARK: - Themes

    private func loadThemes() {
        if let data = UserDefaults.standard.data(forKey: SplitPaneViewController.ThemesKey),
           let loaded = try? JSONDecoder().decode([Int: PaneTheme].self, from: data) {
            paneThemes = loaded
        }
    }

    private func saveThemes() {
        if let encoded = try? JSONEncoder().encode(paneThemes) {
            UserDefaults.standard.set(encoded, forKey: SplitPaneViewController.ThemesKey)
        }
    }

    func applyTheme(_ theme: PaneTheme, to paneIndex: Int) {
        guard paneIndex < panes.count else { return }
        paneThemes[paneIndex] = theme

        let pane = panes[paneIndex]

        // Apply theme colors
        if let bgColor = NSColor(hexString: theme.backgroundColor) {
            pane.view.layer?.backgroundColor = bgColor.cgColor
        }

        pane.view.alphaValue = theme.transparency

        saveThemes()
        updateActivePaneIndicator() // Refresh visual indicators
    }

    func getTheme(for paneIndex: Int) -> PaneTheme? {
        return paneThemes[paneIndex]
    }

    static func getDefaultThemes() -> [PaneTheme] {
        return DefaultThemes
    }

    // MARK: - Gestures

    private func setupGestures() {
        let swipeGesture = NSPanGestureRecognizer(target: self, action: #selector(handleSwipeGesture(_:)))
        swipeGestureRecognizer = swipeGesture
        view.addGestureRecognizer(swipeGesture)
    }

    @objc private func handleSwipeGesture(_ gesture: NSPanGestureRecognizer) {
        let translation = gesture.translation(in: view)

        if gesture.state == .ended {
            // Swipe right to go to next pane
            if translation.x > 100 {
                switchToNextPane()
            }
            // Swipe left to go to previous pane
            else if translation.x < -100 {
                switchToPreviousPane()
            }
        }
    }

    // MARK: - Performance Monitoring

    func getPerformanceMetrics(for paneIndex: Int) -> (memoryUsage: UInt64, loadTime: TimeInterval, fileCount: Int)? {
        return performanceMetrics[paneIndex]
    }

    private func updatePerformanceMetrics(for paneIndex: Int) {
        guard paneIndex < panes.count else { return }

        // Measure memory usage (simplified)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        let memoryUsage = kerr == KERN_SUCCESS ? info.resident_size : 0

        performanceMetrics[paneIndex] = (
            memoryUsage: memoryUsage,
            loadTime: 0.0, // Would measure actual load time
            fileCount: 0 // Would get from FileBrowserViewController
        )
    }

    // MARK: - FileBrowserDelegate

    func fileBrowserDidRequestAddToFavorites(_ fileBrowser: FileBrowserViewController, item: FileItem) {
        delegate?.splitPaneDidRequestAddToFavorites(item: item)
    }

    func directoryDidChange(to path: String) {
        // Find which pane changed and make it active
        if let index = panes.firstIndex(where: { $0.currentPath == path }) {
            // Update analytics for previous pane
            updateAnalyticsForPane(activePaneIndex)

            activePaneIndex = index
            setActivePaneKeyboardFocus()
            updateActivePaneIndicator()

            // Start tracking time for new pane
            analyticsTimers[activePaneIndex] = Date()

            // Add to history
            addToHistory(path: path, paneIndex: index)

            // Update performance metrics
            updatePerformanceMetrics(for: index)

            // Synchronize other panes if enabled
            if panesAreSynchronized {
                synchronizeOtherPanes(to: path, except: index)
            }
        }

        delegate?.splitPaneDirectoryDidChange(to: path)
        saveCurrentLayout()
    }

    private func synchronizeOtherPanes(to path: String, except excludeIndex: Int) {
        let url = URL(fileURLWithPath: path)
        for (index, pane) in panes.enumerated() {
            if index != excludeIndex {
                pane.navigateToURL(url)
            }
        }
    }

    func openInNewTab(url: URL) {
        delegate?.splitPaneOpenInNewTab(url: url)
    }

    func fileBrowserDidRequestSplit(_ fileBrowser: FileBrowserViewController, orientation: SplitOrientation) {
        guard let nestedSplitVC = fileBrowserSplitViewController,
              let paneIndex = panes.firstIndex(of: fileBrowser) else { return }

        // Update active pane to the one requesting the split
        activePaneIndex = paneIndex

        // Update nested split view orientation
        let isVertical = orientation == .vertical
        nestedSplitVC.splitView.isVertical = isVertical
        currentPaneOrientation = orientation

        // Add a new pane with the same directory
        let currentPath = fileBrowser.currentPath
        let currentURL = URL(fileURLWithPath: currentPath)
        addPane(url: currentURL)
    }

    func fileBrowser(_ fileBrowser: FileBrowserViewController, didSelectFile file: FileItem?) {
        // Update active pane based on which pane selected a file
        if let index = panes.firstIndex(of: fileBrowser) {
            activePaneIndex = index
        }

        selectedFileItem = file
        previewPaneViewController?.previewFile(file)
    }

    func fileBrowserDidRequestClosePane(_ fileBrowser: FileBrowserViewController) {
        guard panes.count > 1,
              let nestedSplitVC = fileBrowserSplitViewController else {
            let alert = NSAlert()
            alert.messageText = "Cannot Close Last Pane"
            alert.informativeText = "At least one file browser pane must remain open."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        guard let index = panes.firstIndex(of: fileBrowser) else { return }

        let paneToRemove = panes[index]
        panes.remove(at: index)

        // Find and remove the split view item by matching the view controller
        if let itemIndex = nestedSplitVC.splitViewItems.firstIndex(where: { $0.viewController == paneToRemove }) {
            nestedSplitVC.removeSplitViewItem(nestedSplitVC.splitViewItems[itemIndex])
        }

        paneToRemove.removeFromParent()

        // Adjust active pane index
        if activePaneIndex == index {
            activePaneIndex = min(index, panes.count - 1)
        } else if activePaneIndex > index {
            activePaneIndex -= 1
        }

        // Set focus to new active pane
        setActivePaneKeyboardFocus()

        // Notify delegate of new active path
        if activePaneIndex < panes.count {
            delegate?.splitPaneDirectoryDidChange(to: panes[activePaneIndex].currentPath)
        }

        // Update close button visibility
        updateClosePaneButtonVisibility()

        // Save pane sizes (throttled)
        throttledSavePaneSizes()

        // Save layout
        saveCurrentLayout()
    }

    func fileBrowser(_ fileBrowser: FileBrowserViewController, didUpdateSelection selectedCount: Int, totalSize: Int64) {
        delegate?.splitPane(self, didUpdateSelection: selectedCount, totalSize: totalSize)
    }

    func fileBrowser(_ fileBrowser: FileBrowserViewController, didUpdateDiskSpace diskSpace: String?) {
        delegate?.splitPane(self, didUpdateDiskSpace: diskSpace)
    }
}

// MARK: - NSSplitViewDelegate
extension SplitPaneViewController {
    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)

        // Save pane sizes when user manually resizes (throttled for performance)
        throttledSavePaneSizes()

        // Save preview pane size if it's visible
        if previewPaneViewController != nil {
            savePreviewPaneSize()
        }

        // Save layout
        saveCurrentLayout()
    }

    override func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        return false
    }

    override func splitView(_ splitView: NSSplitView, shouldAdjustSizeOfSubview view: NSView) -> Bool {
        return true
    }

    // Enable pane reordering via drag and drop
    override func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        return proposedEffectiveRect
    }
}

// MARK: - Pane Reordering
extension SplitPaneViewController {
    func reorderPane(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < panes.count,
              destinationIndex >= 0, destinationIndex < panes.count,
              let nestedSplitVC = fileBrowserSplitViewController else { return }

        // Save the pane being moved
        let movedPane = panes[sourceIndex]

        // Reorder in the panes array
        panes.remove(at: sourceIndex)
        panes.insert(movedPane, at: destinationIndex)

        // Find the split view item for the moved pane
        guard let movedItem = nestedSplitVC.splitViewItems.first(where: { $0.viewController == movedPane }) else { return }

        // Remove and re-insert the split view item
        nestedSplitVC.removeSplitViewItem(movedItem)
        nestedSplitVC.insertSplitViewItem(movedItem, at: destinationIndex)

        // Update active pane index if necessary
        if activePaneIndex == sourceIndex {
            activePaneIndex = destinationIndex
        } else if sourceIndex < activePaneIndex && destinationIndex >= activePaneIndex {
            activePaneIndex -= 1
        } else if sourceIndex > activePaneIndex && destinationIndex <= activePaneIndex {
            activePaneIndex += 1
        }

        // Save the new pane order
        savePaneSizes()
    }

    func canReorderPanes() -> Bool {
        return panes.count > 1
    }
}

// MARK: - NSColor Extension
extension NSColor {
    convenience init?(hexString: String) {
        var hexSanitized = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
