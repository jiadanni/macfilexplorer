import Cocoa

class MainWindowController: NSWindowController, SplitViewControllerDelegate, SplitPaneViewControllerDelegate {

    private var splitViewController: SplitViewController?

    init() {
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.title = NSHomeDirectory() // Show home directory initially
        window.setFrameAutosaveName("MainWindow")
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor

        // Disable native window tabs - we have our own custom tab implementation
        window.tabbingMode = .disallowed

        super.init(window: window)

        // Setup Split View Controller
        let newSplitViewController = SplitViewController()
        newSplitViewController.delegate = self // Set delegate
        // Force the view to load now
        _ = newSplitViewController.view
        splitViewController = newSplitViewController

        if let splitVC = splitViewController?.splitViewItems.first?.viewController as? SplitPaneViewController {
            splitVC.delegate = self
        }

        // Add split view to the window's content view
        if let contentView = window.contentView,
           let splitView = splitViewController?.view {
            contentView.addSubview(splitView)

            // Set up constraints
            splitView.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                splitView.topAnchor.constraint(equalTo: contentView.topAnchor),
                splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                splitView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
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
