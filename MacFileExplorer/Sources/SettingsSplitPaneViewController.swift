import Cocoa

// A specialized SplitPaneViewController that hosts the SettingsViewController inside a tab.
class SettingsSplitPaneViewController: SplitPaneViewController {
    private var settingsVC: SettingsViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Remove any file browser panes added by base implementation
        for item in splitViewItems { removeSplitViewItem(item) }
        for child in children { child.removeFromParent() }

        let svc = SettingsViewController()
        settingsVC = svc
        let item = NSSplitViewItem(viewController: svc)
        item.canCollapse = false
        addSplitViewItem(item)
    }

    // MARK: - Overrides to neutralize file operations
    override func navigateToURL(_ url: URL) { /* No-op in settings tab */ }
    override func cutSelection() { }
    override func copySelection() { }
    override func pasteSelection() { }
    override func setViewMode(_ viewMode: ViewMode) { }
    override func toggleHiddenFiles() { }
    override func isShowingHiddenFiles() -> Bool { return false }
    override func updateZoomLevel(to level: Double) { }
    override func goBack() { }
    override func goForward() { }
}
