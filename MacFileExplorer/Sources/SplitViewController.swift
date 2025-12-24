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
    var terminalViewController: TerminalViewController?
    private var terminalSplitItem: NSSplitViewItem?
    var isTerminalVisible = false
    private var hasInitializedTabs = false
    private let minimumContentWidth: CGFloat = 320 // keep room for file panes
    private var isAdjustingSplitPosition = false // prevent recursive position updates
    private let settingsStore: SettingsStoreProtocol = SettingsStore.shared

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
    }

    private func setupUI() {
        // Main split view is vertical (left-right)
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self

        // Create sidebar
        sidebarViewController = SidebarViewController()
        sidebarViewController?.delegate = self
        let sidebarItem = NSSplitViewItem(viewController: sidebarViewController!)
        // Determine fixed width (load saved or default)
        let savedWidth = settingsStore.sidebarFixedWidth
        // Clamp to a compact range so the sidebar never forces a wide window
        let clampedWidth: CGFloat
        if savedWidth > 0 {
            clampedWidth = CGFloat(min(max(savedWidth, 160), 240))
        } else {
            clampedWidth = 200
        }
        let initialWidth: CGFloat = clampedWidth
        sidebarItem.minimumThickness = 140 // allow narrowing
        sidebarItem.maximumThickness = 260 // cap width to avoid locking the window but leave room for content
        sidebarItem.holdingPriority = .defaultLow // prefer shrinking the sidebar first
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

        // Apply initial divider position to honor fixed width
        Task { @MainActor [weak self] in
            guard let self else { return }
            let safeWidth = self.adjustedSidebarWidth(proposed: initialWidth)
            self.splitView.setPosition(safeWidth, ofDividerAt: 0)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        // Create initial tab after view hierarchy is fully loaded (only once)
        if !hasInitializedTabs {
            hasInitializedTabs = true

            // Check if we should show Start tab
            // Default to Start Page if no startup folder is explicitly set
            let hasLaunchedBefore = settingsStore.hasLaunchedBefore
            let showStartOnLaunch = settingsStore.showStartOnLaunch
            let hasStartupFolder = settingsStore.startupFolder != nil

            // Show Start Page if: first launch, preference is set, OR no startup folder configured
            if !hasLaunchedBefore || showStartOnLaunch || !hasStartupFolder {
                tabBarController?.addStartTab()
            } else {
                addNewTab()
            }

            // Restore terminal visibility state
            let wasVisible = settingsStore.terminalIsVisible
            if wasVisible {
                // Restore state without animation to avoid crashes during initial setup
                Task { @MainActor [weak self] in
                    self?.setTerminalVisibility(true, animated: false)
                }
            }
        }
    }

    // MARK: - Public Methods

    func addNewTab() {
        tabBarController?.addNewTab()
    }

    func addSettingsTab() {
        tabBarController?.openSettingsTab()
    }

    func closeCurrentTab() {
        tabBarController?.closeCurrentTab()
    }

    func toggleTerminal() {
        debugLog("SplitViewController: toggleTerminal called - currentState=\(isTerminalVisible)")
        setTerminalVisibility(!isTerminalVisible, animated: true)
    }

    func showTerminal(at path: String? = nil) {
        setTerminalVisibility(true, path: path, animated: true)
    }

    private func setTerminalVisibility(_ visible: Bool, path: String? = nil, animated: Bool = true) {
        guard let terminalSplitItem = terminalSplitItem else { return }

        // Only act if state changes
        guard isTerminalVisible != visible else {
            if visible {
                terminalViewController?.focusInput()
            }
            return
        }

        isTerminalVisible = visible
        if animated {
            terminalSplitItem.animator().isCollapsed = !visible
        } else {
            terminalSplitItem.isCollapsed = !visible
        }

        if visible {
            let targetPath = path ?? tabBarController?.getCurrentPath()
            if let targetPath {
                debugLog("  Opening terminal - setting directory to \(targetPath)")
                terminalViewController?.changeDirectory(to: targetPath)
            }

            // Defer focus when not animated to ensure view is fully laid out
            if animated {
                terminalViewController?.focusInput()
            } else {
                // Use a short main-queue async delay instead of Task.sleep to avoid
                // depending on suspension/timing and to be more robust across systems.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.terminalViewController?.focusInput()
                }
            }
        } else {
            debugLog("  Closing terminal - restoring focus to tabBarController.view")
            view.window?.makeFirstResponder(tabBarController?.view)
        }

        settingsStore.terminalIsVisible = visible
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

    func openStorageAnalyzerTab() {
        tabBarController?.openStorageAnalyzerTab()
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

    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)
        // Persist sidebar width only when the main split view (sidebar + content) resizes.
        guard notification.object as? NSSplitView === splitView else { return }
        guard splitViewItems.count > 0 else { return }
        guard !isAdjustingSplitPosition else { return } // prevent recursive calls
        
        guard let firstItem = splitViewItems.safe(at: 0) else { return }
        let currentWidth = firstItem.viewController.view.frame.width
        let adjustedWidth = adjustedSidebarWidth(proposed: currentWidth)
        
        // Only adjust if the difference is significant and would improve layout
        if abs(currentWidth - adjustedWidth) > 1.0 {
            isAdjustingSplitPosition = true
            // Defer to avoid constraint conflicts during active layout
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.splitView.setPosition(adjustedWidth, ofDividerAt: 0)
                self.isAdjustingSplitPosition = false
            }
        }
        
        // Persist width for next launch
        if currentWidth > 120 {
            let clampedWidth = max(140.0, min(currentWidth, 240.0))
            settingsStore.sidebarFixedWidth = Double(clampedWidth)
        }
    }

    private func adjustedSidebarWidth(proposed: CGFloat) -> CGFloat {
        // Ensure the content side retains a minimum width
        let totalWidth = splitView.frame.width
        let maxAllowed = max(140.0, min(260.0, totalWidth - minimumContentWidth))
        let minAllowed: CGFloat = 140.0
        let clamped = min(max(proposed, minAllowed), maxAllowed.isFinite ? maxAllowed : proposed)
        return clamped
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

    func navigateToURL(_ url: URL) {
        tabBarController?.navigateToLocation(url)
    }

    // MARK: - SidebarDelegate

    func sidebarDidSelectLocation(_ url: URL) {
        debugLog("SplitViewController: sidebarDidSelectLocation - Received URL: \(url.path)")
        
        // Check if we're currently on the Start page
        // If so, open in new tab. Otherwise, navigate in current tab.
        guard let tabBarController = tabBarController else {
            return
        }
        
        if tabBarController.isCurrentTabStartPage() {
            // On Start page - open in new tab
            debugLog("  → Opening in new tab (currently on Start page)")
            tabBarController.openInNewTab(url: url)
        } else {
            // On a regular tab - navigate in current tab
            debugLog("  → Navigating in current tab")
            tabBarController.navigateToLocation(url)
        }
        
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
