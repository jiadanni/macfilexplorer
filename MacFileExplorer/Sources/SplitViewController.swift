import Cocoa

class SplitViewController: NSSplitViewController, SidebarDelegate {

    private var sidebarViewController: SidebarViewController?
    private var contentSplitViewController: NSSplitViewController?
    private var tabBarController: TabBarController?
    private var terminalViewController: TerminalViewController?
    private var terminalSplitItem: NSSplitViewItem?
    private var isTerminalVisible = false
    private var hasInitializedTabs = false

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
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        // Create initial tab after view hierarchy is fully loaded (only once)
        if !hasInitializedTabs {
            hasInitializedTabs = true
            addNewTab()
        }
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
            // Update terminal to current directory when opening
            if let currentPath = tabBarController?.getCurrentPath() {
                terminalViewController?.changeDirectory(to: currentPath)
            }

            // Focus the input field
            terminalViewController?.focusInput()
        }
    }

    func showBulkColorPicker() {
        tabBarController?.showBulkColorPicker()
    }

    func cutSelection() {
        tabBarController?.cutSelection()
    }

    func copySelection() {
        tabBarController?.copySelection()
    }

    func pasteSelection() {
        tabBarController?.pasteSelection()
    }
    
    func setViewMode(_ viewMode: ViewMode) {
        tabBarController?.setViewMode(viewMode)
    }
    
    func toggleHiddenFiles() {
        tabBarController?.toggleHiddenFiles()
    }
    
    func splitVertically() {
        tabBarController?.splitVertically()
    }
    
    func splitHorizontally() {
        tabBarController?.splitHorizontally()
    }

    func updateTerminalDirectory() {
        // Always update terminal directory, regardless of visibility
        // This ensures it shows the correct directory when toggled open
        if let currentPath = tabBarController?.getCurrentPath() {
            terminalViewController?.changeDirectory(to: currentPath)
        }
    }

    func openLocationInNewTab(_ url: URL) {
        // Use the TabBarController's openInNewTab method which handles everything properly
        (tabBarController as TabBarController?)?.openInNewTab(url: url)
    }

    func updateZoomLevel(to level: Double) {
        tabBarController?.updateZoomLevel(to: level)
    }

    // MARK: - SidebarDelegate

    func sidebarDidSelectLocation(_ url: URL) {
        print("SplitViewController: sidebarDidSelectLocation - Received URL: \(url.path)")
        tabBarController?.navigateToLocation(url)
    }
}
