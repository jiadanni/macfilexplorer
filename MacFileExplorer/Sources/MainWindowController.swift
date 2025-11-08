import Cocoa

class MainWindowController: NSWindowController {

    private var splitViewController: SplitViewController?

    convenience init() {
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

        self.init(window: window)

        setupSplitView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // Ensure window is visible
        window?.makeKeyAndOrderFront(nil)
    }

    private func setupSplitView() {
        splitViewController = SplitViewController()
        window?.contentViewController = splitViewController
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
