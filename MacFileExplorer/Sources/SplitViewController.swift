import Cocoa

class SplitViewController: NSSplitViewController, SidebarDelegate {

    private var sidebarViewController: SidebarViewController?
    private var contentSplitViewController: NSSplitViewController?
    private var tabBarController: TabBarController?
    private var terminalViewController: TerminalViewController?
    private var terminalSplitItem: NSSplitViewItem?
    private var isTerminalVisible = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
    }

    private func setupUI() {
        // Main split view is vertical (left-right)
        splitView.isVertical = true
        splitView.dividerStyle = .thin

        // Create sidebar
        sidebarViewController = SidebarViewController()
        sidebarViewController?.delegate = self
        let sidebarItem = NSSplitViewItem(viewController: sidebarViewController!)
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 300
        sidebarItem.canCollapse = false
        addSplitViewItem(sidebarItem)

        // Create content split view (vertical split for tab bar + terminal)
        contentSplitViewController = NSSplitViewController()
        contentSplitViewController!.splitView.isVertical = false
        contentSplitViewController!.splitView.dividerStyle = .thin

        // Create tab bar controller for file browsing
        tabBarController = TabBarController()
        let tabBarItem = NSSplitViewItem(viewController: tabBarController!)
        tabBarItem.minimumThickness = 300
        // Don't set maximumThickness - let it grow automatically
        tabBarItem.canCollapse = false
        contentSplitViewController!.addSplitViewItem(tabBarItem)

        // Create terminal view controller (initially hidden)
        terminalViewController = TerminalViewController()
        terminalSplitItem = NSSplitViewItem(viewController: terminalViewController!)
        terminalSplitItem?.minimumThickness = 150
        terminalSplitItem?.maximumThickness = 500
        terminalSplitItem?.canCollapse = true
        terminalSplitItem?.isCollapsed = true
        contentSplitViewController!.addSplitViewItem(terminalSplitItem!)

        // Add content split view to main split view
        let contentItem = NSSplitViewItem(viewController: contentSplitViewController!)
        contentItem.canCollapse = false
        addSplitViewItem(contentItem)

        // Force view hierarchy to load before adding initial tab
        _ = tabBarController?.view

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

    func openLocationInNewTab(_ url: URL) {
        // Ensure view is loaded
        _ = tabBarController?.view

        // Add a new tab first
        addNewTab()

        // Ensure the new tab is ready, then navigate to the location
        DispatchQueue.main.async { [weak self] in
            self?.tabBarController?.navigateToLocation(url)
        }
    }

    // MARK: - SidebarDelegate

    func sidebarDidSelectLocation(_ url: URL) {
        tabBarController?.navigateToLocation(url)
    }
}
