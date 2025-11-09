import Cocoa

class MainWindowController: NSWindowController {

    private var splitViewController: SplitViewController!

    init() {
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.title = ""  // Hide title since tabs will show in title bar
        window.setFrameAutosaveName("MainWindow")
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor

        // Configure title bar for integrated tabs
        window.titleVisibility = .hidden

        super.init(window: window)

        setupSplitView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // Show window after everything is loaded
        window?.makeKeyAndOrderFront(nil)
    }

    private func setupSplitView() {
        splitViewController = SplitViewController()

        // Force the view to load now
        _ = splitViewController.view

        contentViewController = splitViewController

        // Ensure window displays
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
}
