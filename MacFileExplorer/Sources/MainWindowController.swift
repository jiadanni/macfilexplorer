import Cocoa

class MainWindowController: NSWindowController, SplitViewControllerDelegate, SplitPaneViewControllerDelegate {

    private var splitViewController: SplitViewController?

    init() {
        // Compute a sensible default frame: half the main screen width, centered vertically and horizontally
        let screenFrame: NSRect
        if let screen = NSScreen.main {
            screenFrame = screen.visibleFrame
        } else {
            screenFrame = NSScreen.screens.first?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        }

        // Choose half the screen width and keep a 16:10-ish height ratio, respecting a minimum size.
        let defaultWidth = max(600.0, floor(screenFrame.width / 2.0))
        let defaultHeight = max(400.0, floor(defaultWidth * 10.0 / 16.0))
        let defaultX = screenFrame.origin.x + floor((screenFrame.width - defaultWidth) / 2.0)
        let defaultY = screenFrame.origin.y + floor((screenFrame.height - defaultHeight) / 2.0)

        let contentRect = NSRect(x: defaultX, y: defaultY, width: defaultWidth, height: defaultHeight)

        // Create the window with computed default frame and allow resizing/zooming
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = NSHomeDirectory()
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor

        // Integrate toolbar into title bar like Finder
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        // Set minimum size; do not set a strict maximum to allow maximize/fullscreen
        window.minSize = NSSize(width: 600, height: 400)
        window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // Allow the standard macOS zoom (green) button behavior
        window.tabbingMode = .disallowed

        // Explicitly ensure window is resizable
        window.styleMask.insert(.resizable)

        super.init(window: window)

        // Apply custom traffic light appearance per user setting
        WindowTrafficLightManager.shared.applyToAllWindows()
        NotificationCenter.default.addObserver(forName: Notification.Name("didChangeWindowControlAppearance"), object: nil, queue: .main) { _ in
            WindowTrafficLightManager.shared.applyToAllWindows()
        }
        // Setup Split View Controller
        let newSplitViewController = SplitViewController()
        newSplitViewController.delegate = self // Set delegate
        splitViewController = newSplitViewController

        if let splitVC = splitViewController?.splitViewItems.first?.viewController as? SplitPaneViewController {
            splitVC.delegate = self
        }

        // IMPORTANT: Set as contentViewController instead of manually adding as subview
        // This ensures proper window resizing behavior
        window.contentViewController = newSplitViewController

        // Set the window frame AFTER setting contentViewController
        // This ensures the calculated frame (half screen width) is applied
        window.setFrame(contentRect, display: false)

        // Disable autosave for now to prevent any saved frame interference
        // TODO: Re-enable after confirming resize works
        // window.setFrameAutosaveName("MainWindow")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // Show window after everything is loaded
        window?.makeKeyAndOrderFront(nil)
    }



    // MARK: - Public Methods

    func addNewTab() {
        splitViewController?.addNewTab()
    }

    func addSettingsTab() {
        splitViewController?.addSettingsTab()
    }

    func closeCurrentTab() {
        splitViewController?.closeCurrentTab()
    }

    func toggleTerminal() {
        splitViewController?.toggleTerminal()
    }

    func cutSelection() {
        splitViewController?.cutSelection()
    }

    func copySelection() {
        splitViewController?.copySelection()
    }

    func pasteSelection() {
        splitViewController?.pasteSelection()
    }

    func setViewMode(_ viewMode: ViewMode) {
        splitViewController?.setViewMode(viewMode)
    }
    
    func toggleHiddenFiles() {
        splitViewController?.toggleHiddenFiles()
    }

    func togglePreviewPane() {
        splitViewController?.togglePreviewPane()
    }

    func splitVertically() {
        splitViewController?.splitVertically()
    }

    func splitHorizontally() {
        splitViewController?.splitHorizontally()
    }

    func openStorageAnalyzerTab() {
        splitViewController?.openStorageAnalyzerTab()
    }

    func goBack() {
        splitViewController?.goBack()
    }

    func goForward() {
        splitViewController?.goForward()
    }

    func navigateToURL(_ url: URL) {
        splitViewController?.navigateToURL(url)
    }

    func isShowingHiddenFiles() -> Bool {
        return splitViewController?.isShowingHiddenFiles() ?? false
    }

    // MARK: - SplitViewControllerDelegate

    func splitViewController(_ splitViewController: SplitViewController, didUpdateSelection selectedCount: Int, totalSize: Int64) {
        // Status bar is now managed by each FileBrowserViewController
    }

    func splitViewController(_ splitViewController: SplitViewController, didUpdateDiskSpace diskSpace: String?) {
        // Status bar is now managed by each FileBrowserViewController
    }

    // MARK: - SplitPaneViewControllerDelegate

    func splitPaneDirectoryDidChange(to path: String) {
        window?.title = path
    }

    func splitPaneOpenInNewTab(url: URL) {
        splitViewController?.addNewTab()
    }

    func splitPane(_ splitPane: SplitPaneViewController, didUpdateSelection selectedCount: Int, totalSize: Int64) {
        // Status bar is now managed by each FileBrowserViewController
    }

    func splitPane(_ splitPane: SplitPaneViewController, didUpdateDiskSpace diskSpace: String?) {
        // Status bar is now managed by each FileBrowserViewController
    }

    func splitPaneDidRequestAddToFavorites(item: FileItem) {
        splitViewController?.sidebarViewController?.addFavorite(item: item)
    }
}
