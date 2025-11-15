import Cocoa

protocol SplitViewControllerDelegate: AnyObject {
    func splitViewController(_ splitViewController: SplitViewController, didUpdateSelection selectedCount: Int, totalSize: Int64)
    func splitViewController(_ splitViewController: SplitViewController, didUpdateDiskSpace diskSpace: String?)
}

class SplitViewController: NSSplitViewController, SidebarDelegate, TabBarControllerDelegate, TerminalViewControllerDelegate {

    weak var delegate: SplitViewControllerDelegate?

    var sidebarViewController: SidebarViewController?
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
        sidebarItem.canCollapse = false
        addSplitViewItem(sidebarItem)

        // Create content split view (vertical split for tab bar + terminal)
        contentSplitViewController = NSSplitViewController()
        contentSplitViewController!.splitView.isVertical = false
        contentSplitViewController!.splitView.dividerStyle = .thin

        // Create tab bar controller for file browsing
        tabBarController = TabBarController()
        tabBarController?.delegate = self // Set self as the delegate
        let tabBarItem = NSSplitViewItem(viewController: tabBarController!)
        tabBarItem.minimumThickness = 300
        // Don't set maximumThickness - let it grow automatically
        tabBarItem.canCollapse = false
        contentSplitViewController!.addSplitViewItem(tabBarItem)

        // Create terminal view controller (initially hidden)
        terminalViewController = TerminalViewController()
        terminalViewController?.delegate = self
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

    func isShowingHiddenFiles() -> Bool {
        return tabBarController?.isShowingHiddenFiles() ?? false
    }

    func togglePreviewPane() {
        tabBarController?.togglePreviewPane()
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
    
    func updateSidebarSelection(url: URL) {
        // Update sidebar folder explorer to expand and select the current directory
        sidebarViewController?.expandToCurrentDirectory(url: url)
    }

    func openLocationInNewTab(_ url: URL) {
        // Use the TabBarController's openInNewTab method which handles everything properly
        (tabBarController as TabBarController?)?.openInNewTab(url: url)
    }

    func updateZoomLevel(to level: Double) {
        tabBarController?.updateZoomLevel(to: level)
    }

    func goBack() {
        tabBarController?.goBack()
    }

    func goForward() {
        tabBarController?.goForward()
    }

    // MARK: - SidebarDelegate

    func sidebarDidSelectLocation(_ url: URL) {
        print("SplitViewController: sidebarDidSelectLocation - Received URL: \(url.path)")
        tabBarController?.navigateToLocation(url)
        sidebarViewController?.expandToCurrentDirectory(url: url)
    }
    
    // MARK: - TabBarControllerDelegate
    
    func tabBarController(_ tabBarController: TabBarController, didUpdateSelection selectedCount: Int, totalSize: Int64) {
        delegate?.splitViewController(self, didUpdateSelection: selectedCount, totalSize: totalSize)
    }
    
    func tabBarController(_ tabBarController: TabBarController, didUpdateDiskSpace diskSpace: String?) {
        delegate?.splitViewController(self, didUpdateDiskSpace: diskSpace)
    }

    // MARK: - TerminalViewControllerDelegate

    func terminalViewControllerDidRequestClose(_ controller: TerminalViewController) {
        toggleTerminal()
    }
}
