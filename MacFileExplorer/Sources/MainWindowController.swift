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

        // Disable native window tabs - we have our own custom tab implementation
        window.tabbingMode = .disallowed

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

    func cutSelection() {
        splitViewController?.cutSelection()
    }

    func copySelection() {
        splitViewController?.copySelection()
    }

    func pasteSelection() {
        splitViewController?.pasteSelection()
    }
}
