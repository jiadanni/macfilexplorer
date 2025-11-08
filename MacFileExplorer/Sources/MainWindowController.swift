import Cocoa

class MainWindowController: NSWindowController {

    private var splitViewController: SplitViewController?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.title = "Mac File Explorer"
        window.titlebarAppearsTransparent = true
        window.toolbar = NSToolbar(identifier: "MainToolbar")
        window.toolbar?.displayMode = .iconOnly
        window.toolbar?.delegate = nil

        self.init(window: window)

        setupSplitView()
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
