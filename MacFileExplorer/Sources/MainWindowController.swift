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
        window.title = "Mac File Explorer"
        window.setFrameAutosaveName("MainWindow")
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor

        super.init(window: window)

        setupSplitView()

        // Force the window to display
        window.makeKeyAndOrderFront(nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    private func setupSplitView() {
        splitViewController = SplitViewController()
        contentViewController = splitViewController
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
