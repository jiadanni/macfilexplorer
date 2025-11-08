import Cocoa

class SplitViewController: NSSplitViewController {

    private var tabBarController: TabBarController?
    private var terminalViewController: TerminalViewController?
    private var terminalSplitItem: NSSplitViewItem?
    private var isTerminalVisible = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
    }

    private func setupUI() {
        // Create tab bar controller for file browsing
        tabBarController = TabBarController()
        let tabBarItem = NSSplitViewItem(viewController: tabBarController!)
        tabBarItem.minimumThickness = 300
        tabBarItem.maximumThickness = .infinity
        tabBarItem.canCollapse = false
        addSplitViewItem(tabBarItem)

        // Create terminal view controller (initially hidden)
        terminalViewController = TerminalViewController()
        terminalSplitItem = NSSplitViewItem(viewController: terminalViewController!)
        terminalSplitItem?.minimumThickness = 150
        terminalSplitItem?.maximumThickness = 500
        terminalSplitItem?.canCollapse = true
        terminalSplitItem?.isCollapsed = true
        addSplitViewItem(terminalSplitItem!)

        // Set split view orientation
        splitView.isVertical = false
        splitView.dividerStyle = .thin

        // Add initial tab
        addNewTab()
    }

    // MARK: - Public Methods

    func addNewTab() {
        tabBarController?.addNewTab()
    }

    func closeCurrentTab() {
        tabBarController?.closeCurrentTab()
    }

    func toggleTerminal() {
        guard let terminalSplitItem = terminalSplitItem else { return }

        isTerminalVisible.toggle()
        terminalSplitItem.animator().isCollapsed = !isTerminalVisible

        if isTerminalVisible {
            // Update terminal to current directory
            if let currentPath = tabBarController?.getCurrentPath() {
                terminalViewController?.changeDirectory(to: currentPath)
            }
        }
    }

    func showBulkColorPicker() {
        tabBarController?.showBulkColorPicker()
    }

    func updateTerminalDirectory(_ path: String) {
        if isTerminalVisible {
            terminalViewController?.changeDirectory(to: path)
        }
    }
}
