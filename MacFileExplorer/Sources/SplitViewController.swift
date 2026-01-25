import Cocoa

protocol SplitViewControllerDelegate: AnyObject {
    func splitViewController(_ splitViewController: SplitViewController, didUpdateSelection selectedCount: Int, totalSize: Int64)
    func splitViewController(_ splitViewController: SplitViewController, didUpdateDiskSpace diskSpace: String?)
}

class SplitViewController: NSSplitViewController, SidebarDelegate, TabBarControllerDelegate, TerminalViewControllerDelegate, TerminalVisibilityDelegate, SettingsStoreDelegate {

    weak var delegate: SplitViewControllerDelegate?

    var sidebarViewController: SidebarViewController?
    private var contentSplitViewController: NSSplitViewController?
    private var tabBarController: TabBarController?
    var terminalViewController: TerminalViewController?
    private var terminalSplitItem: NSSplitViewItem?
    private let terminalCoordinator = TerminalVisibilityCoordinator()
    private var hasInitializedTabs = false
    private let minimumContentWidth: CGFloat = 320 // keep room for file panes
    private let sidebarMinWidth: CGFloat = 140
    private let sidebarMaxWidth: CGFloat = 260
    private let settingsStore: SettingsStoreProtocol = SettingsStore.shared

    // Single Source of Truth for terminal visibility
    var isTerminalVisible: Bool {
        get { terminalCoordinator.isVisible }
        set { terminalCoordinator.isVisible = newValue }
    }

    private var shouldAnimateTerminalTransition = true

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
        sidebarViewController = SidebarViewController(settings: settingsStore)
        sidebarViewController?.delegate = self
        let sidebarItem = NSSplitViewItem(viewController: sidebarViewController!)
        // Determine fixed width (load saved or default)
        let savedWidth = settingsStore.sidebarFixedWidth
        // Clamp to a compact range so the sidebar never forces a wide window
        let clampedWidth: CGFloat
        if savedWidth > 0 {
            clampedWidth = CGFloat(min(max(savedWidth, sidebarMinWidth), sidebarMaxWidth))
        } else {
            clampedWidth = 200
        }
        let initialWidth: CGFloat = clampedWidth
        sidebarItem.minimumThickness = sidebarMinWidth // allow narrowing
        sidebarItem.maximumThickness = sidebarMaxWidth // cap width to avoid locking the window but leave room for content
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
        terminalCoordinator.delegate = self
        terminalSplitItem = NSSplitViewItem(viewController: terminalViewController!)
        terminalSplitItem?.minimumThickness = 150
        terminalSplitItem?.maximumThickness = 500
        terminalSplitItem?.canCollapse = true
        terminalSplitItem?.isCollapsed = true
        contentSplitViewController!.addSplitViewItem(terminalSplitItem!)

        // Add content split view to main split view
        let contentItem = NSSplitViewItem(viewController: contentSplitViewController!)
        contentItem.canCollapse = false
        contentItem.minimumThickness = minimumContentWidth
        addSplitViewItem(contentItem)

        // Apply initial divider position to honor fixed width
        Task { @MainActor [weak self] in
            guard let self else { return }
            let safeWidth = self.adjustedSidebarWidth(proposed: initialWidth)
            self.splitView.setPosition(safeWidth, ofDividerAt: 0)
        }
        // Register for settings changes
        settingsStore.addDelegate(self)
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

            // Restore terminal visibility state from coordinator
            if terminalCoordinator.isVisible {
                Task { @MainActor [weak self] in
                    self?.shouldAnimateTerminalTransition = false
                    self?.applyTerminalVisibility(true, animated: false)
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
        debugLog("SplitViewController: toggleTerminal called - Current State: \(isTerminalVisible)")
        shouldAnimateTerminalTransition = true
        terminalCoordinator.toggleTerminal()
    }

    func showTerminal(at path: String? = nil) {
        let url = path.map { URL(fileURLWithPath: $0) }
        shouldAnimateTerminalTransition = true
        terminalCoordinator.setVisibility(true, at: url)
    }

    private func applyTerminalVisibility(_ visible: Bool, animated: Bool) {
        guard let terminalSplitItem = terminalSplitItem else { return }
        
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                terminalSplitItem.animator().isCollapsed = !visible
            }, completionHandler: { [weak self] in
                self?.handleTerminalVisibilityTransitionComplete(visible)
            })
        } else {
            terminalSplitItem.isCollapsed = !visible
            handleTerminalVisibilityTransitionComplete(visible)
        }
    }

    private func handleTerminalVisibilityTransitionComplete(_ visible: Bool) {
        if visible {
            if let targetURL = terminalCoordinator.currentDirectory {
                debugLog("  Terminal Visible - Setting directory to \(targetURL.path)")
                terminalViewController?.changeDirectory(to: targetURL.path)
            } else if let currentPath = tabBarController?.getCurrentPath() {
                 debugLog("  Terminal Visible - Setting directory to current tab path \(currentPath)")
                 terminalViewController?.changeDirectory(to: currentPath)
            }
            
            // Ensure focus
            terminalViewController?.focusInput()
        } else {
            debugLog("  Terminal Hidden - Restoring focus")
            view.window?.makeFirstResponder(tabBarController?.view)
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
        guard let firstItem = splitViewItems.safe(at: 0) else { return }
        let currentWidth = firstItem.viewController.view.frame.width

        // Persist width for next launch
        if currentWidth > 120 {
            let clampedWidth = max(sidebarMinWidth, min(currentWidth, sidebarMaxWidth))
            settingsStore.sidebarFixedWidth = Double(clampedWidth)
        }
    }

    private func adjustedSidebarWidth(proposed: CGFloat) -> CGFloat {
        // Ensure the content side retains a minimum width
        let totalWidth = splitView.frame.width
        let maxAllowed = max(sidebarMinWidth, min(sidebarMaxWidth, totalWidth - minimumContentWidth))
        let minAllowed: CGFloat = sidebarMinWidth
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

// MARK: - TerminalVisibilityObserver

extension SplitViewController {
    func terminalVisibilityDidChange(isVisible: Bool) {
        debugLog("SplitViewController: Terminal visibility SSOT changed to \(isVisible)")
        applyTerminalVisibility(isVisible, animated: shouldAnimateTerminalTransition)
    }

    // MARK: - SettingsStoreDelegate
    
    func settingsStore(_ settingsStore: SettingsStoreProtocol, terminalVisibilityDidChange isVisible: Bool) {
        // If the change came from SettingsStore (not our coordinator), update coordinator
        // The coordinator will then notify us via terminalVisibilityDidChange
        if terminalCoordinator.isVisible != isVisible {
            shouldAnimateTerminalTransition = true
            terminalCoordinator.setVisibility(isVisible)
        }
    }
}
