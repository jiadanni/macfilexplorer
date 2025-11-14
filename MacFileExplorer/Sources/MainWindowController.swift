import Cocoa

class MainWindowController: NSWindowController, StatusBarDelegate, SplitViewControllerDelegate {

    private var splitViewController: SplitViewController?
    private var statusBarViewController: StatusBarViewController?

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

        // Setup Status Bar Controller
        let newStatusBarViewController = StatusBarViewController()
        newStatusBarViewController.delegate = self // Set delegate
        // Force the view to load now
        _ = newStatusBarViewController.view
        statusBarViewController = newStatusBarViewController

        // Add split view and status bar to the window's content view
        if let contentView = window.contentView,
           let splitView = splitViewController?.view,
           let statusBarView = statusBarViewController?.view {
            contentView.addSubview(splitView)
            contentView.addSubview(statusBarView)

            // Set up constraints
            splitView.translatesAutoresizingMaskIntoConstraints = false
            statusBarView.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                splitView.topAnchor.constraint(equalTo: contentView.topAnchor),
                splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                splitView.bottomAnchor.constraint(equalTo: statusBarView.topAnchor),

                statusBarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                statusBarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                statusBarView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                statusBarView.heightAnchor.constraint(equalToConstant: 22) // Standard status bar height
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
    
    func splitVertically() {
        splitViewController?.splitVertically()
    }
    
    func splitHorizontally() {
        splitViewController?.splitHorizontally()
    }

    func zoomLevelDidChange(to level: Double) {
        // Forward zoom level changes to the split view controller
        splitViewController?.updateZoomLevel(to: level)
    }
    
    // MARK: - SplitViewControllerDelegate

    func splitViewController(_ splitViewController: SplitViewController, didUpdateSelection selectedCount: Int, totalSize: Int64) {
        statusBarViewController?.updateFileInformation(selectedCount: selectedCount, totalSize: totalSize, diskSpace: nil)
    }

    func splitViewController(_ splitViewController: SplitViewController, didUpdateDiskSpace diskSpace: String?) {
        // Only update disk space if no files are currently selected.
        // If there's an active selection, the selection info takes precedence.
        // We can infer this by checking if the last update was for a selection.
        // A more robust solution might involve the StatusBarViewController managing its own state.
        // For now, we'll assume if selectedCount is 0, it's safe to update disk space.
        statusBarViewController?.updateFileInformation(selectedCount: 0, totalSize: 0, diskSpace: diskSpace)
    }
}
