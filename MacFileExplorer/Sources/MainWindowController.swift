import Cocoa

class MainWindowController: NSWindowController, StatusBarDelegate {

    private var splitViewController: SplitViewController!
    private var statusBarViewController: StatusBarViewController!

    init() {
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.title = "Mac File Explorer"
        window.setFrameAutosaveName("MainWindow")
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor

        // Disable native window tabs - we have our own custom tab implementation
        window.tabbingMode = .disallowed

        super.init(window: window)

        // Setup Split View Controller
        splitViewController = SplitViewController()
        // Force the view to load now
        _ = splitViewController.view
        
        // Setup Status Bar Controller
        statusBarViewController = StatusBarViewController()
        statusBarViewController.delegate = self // Set delegate
        // Force the view to load now
        _ = statusBarViewController.view

        // Add split view and status bar to the window's content view
        if let contentView = window.contentView {
            contentView.addSubview(splitViewController.view)
            contentView.addSubview(statusBarViewController.view)

            // Set up constraints
            splitViewController.view.translatesAutoresizingMaskIntoConstraints = false
            statusBarViewController.view.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                splitViewController.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                splitViewController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                splitViewController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                splitViewController.view.bottomAnchor.constraint(equalTo: statusBarViewController.view.topAnchor),

                statusBarViewController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                statusBarViewController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                statusBarViewController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                statusBarViewController.view.heightAnchor.constraint(equalToConstant: 22) // Standard status bar height
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

    func showBulkColorPicker() {
        splitViewController?.showBulkColorPicker()
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

    func zoomLevelDidChange(to level: Double) {
        // Forward zoom level changes to the active file browser if needed
        // For now, this can be a no-op or forward to splitViewController
    }
}
