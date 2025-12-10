import Cocoa

enum SplitOrientation {
    case vertical
    case horizontal
}

protocol FileBrowserDelegate: AnyObject {
    func directoryDidChange(_ fileBrowser: FileBrowserViewController, to path: String)
    func fileBrowserDidBecomeActive(_ fileBrowser: FileBrowserViewController)
    func openInNewTab(url: URL)
    func fileBrowserDidRequestSplit(_ fileBrowser: FileBrowserViewController, orientation: SplitOrientation)
    func fileBrowser(_ fileBrowser: FileBrowserViewController, didSelectFile file: FileItem?)
    func fileBrowserDidRequestClosePane(_ fileBrowser: FileBrowserViewController)
    func fileBrowser(_ fileBrowser: FileBrowserViewController, didUpdateSelection selectedCount: Int, totalSize: Int64)
    func fileBrowser(_ fileBrowser: FileBrowserViewController, didUpdateDiskSpace diskSpace: String?)
    func fileBrowserDidRequestAddToFavorites(_ fileBrowser: FileBrowserViewController, item: FileItem)
    func toolbarDidRequestOpenInTerminal(from fileBrowser: FileBrowserViewController)
}

protocol SplitPaneViewControllerDelegate: AnyObject {
    func splitPaneDirectoryDidChange(to path: String)
    func splitPaneOpenInNewTab(url: URL)
    func splitPane(_ splitPane: SplitPaneViewController, didUpdateSelection selectedCount: Int, totalSize: Int64)
    func splitPane(_ splitPane: SplitPaneViewController, didUpdateDiskSpace diskSpace: String?)
    func splitPaneDidRequestAddToFavorites(item: FileItem)
    func splitPaneDidRequestOpenTerminal(at path: String)
}

class SplitPaneViewController: NSSplitViewController, FileBrowserDelegate {

    weak var delegate: SplitPaneViewControllerDelegate?

    private var panes: [FileBrowserViewController] = []
    private var activePaneIndex: Int = 0
    // Per-pane preview now managed inside each FileBrowserViewController

    var currentPath: String {
        guard activePaneIndex < panes.count else { return "/" }
        return panes[activePaneIndex].currentPath
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        NotificationCenter.default.addObserver(self, selector: #selector(handlePreviewPaneCloseRequested), name: .previewPaneCloseRequested, object: nil)
        // Per-pane preview visibility restored when each pane is created
    }

    private func setupUI() {
        // Configure the split view itself
        splitView.isVertical = true // Main split is vertical (panes side-by-side)
        splitView.dividerStyle = .thin

        // Add initial file browser pane
        addPane()
    }

    // MARK: - Public Methods

    func addPane(url: URL? = nil) {
        // Check if we've reached the maximum panes limit
        let maxPanes = UserDefaults.standard.integer(forKey: UserDefaults.Keys.maximumPanes.rawValue)
        let limit = maxPanes > 0 ? maxPanes : 2 // Default to 2 if not set

        if panes.count >= limit {
            // Show alert that maximum panes reached
            let alert = NSAlert()
            alert.messageText = "Maximum Panes Reached"
            alert.informativeText = "You have reached the maximum of \(limit) panes. Close a pane or increase the limit in Settings > Advanced."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        let fileBrowser = FileBrowserViewController()
        fileBrowser.delegate = self // SplitPaneViewController is now the FileBrowserDelegate
        panes.append(fileBrowser)

        addChild(fileBrowser)
        let splitItem = NSSplitViewItem(viewController: fileBrowser)
        splitItem.canCollapse = false
        addSplitViewItem(splitItem) // Add the pane

        // Navigate to URL if provided
        if let url = url {
            fileBrowser.navigateToURL(url)
        }

        // Update active pane
        setActivePane(index: panes.count - 1)

        // Update close button visibility for all panes
        updateClosePaneButtonVisibility()
    }

    func removeActivePane() {
        guard panes.count > 1, activePaneIndex < panes.count else { return }

        let paneToRemove = panes[activePaneIndex]
        panes.remove(at: activePaneIndex)

        removeSplitViewItem(splitViewItems[activePaneIndex]) // Remove the split view item

        paneToRemove.removeFromParent()

        // Update active pane index
        if activePaneIndex >= panes.count {
            activePaneIndex = panes.count - 1
        }
        updateActivePaneUI()

        // Notify delegate of new active path
        if activePaneIndex < panes.count {
            delegate?.splitPaneDirectoryDidChange(to: panes[activePaneIndex].currentPath)
        }

        // Update close button visibility for all remaining panes
        updateClosePaneButtonVisibility()
    }

    func canAddMorePanes() -> Bool {
        let maxPanes = UserDefaults.standard.integer(forKey: UserDefaults.Keys.maximumPanes.rawValue)
        let limit = maxPanes > 0 ? maxPanes : 2 // Default to 2 if not set
        return panes.count < limit
    }

    func splitVertically() {
        // Check if we can add more panes
        guard canAddMorePanes() else {
            let maxPanes = UserDefaults.standard.integer(forKey: UserDefaults.Keys.maximumPanes.rawValue)
            let limit = maxPanes > 0 ? maxPanes : 2
            let alert = NSAlert()
            alert.messageText = "Maximum Panes Reached"
            alert.informativeText = "You have reached the maximum of \(limit) panes. Close a pane or increase the limit in Settings > Advanced."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        // Get current directory from active pane
        let currentURL = URL(fileURLWithPath: currentPath)

        // Ensure the split view is vertical
        splitView.isVertical = true

        // Add new pane with same directory
        addPane(url: currentURL)
    }

    func splitHorizontally() {
        // Check if we can add more panes
        guard canAddMorePanes() else {
            let maxPanes = UserDefaults.standard.integer(forKey: UserDefaults.Keys.maximumPanes.rawValue)
            let limit = maxPanes > 0 ? maxPanes : 2
            let alert = NSAlert()
            alert.messageText = "Maximum Panes Reached"
            alert.informativeText = "You have reached the maximum of \(limit) panes. Close a pane or increase the limit in Settings > Advanced."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        // Ensure the split view is horizontal
        splitView.isVertical = false

        // Get current directory from active pane
        let currentURL = URL(fileURLWithPath: currentPath)

        // Add new pane with same directory
        addPane(url: currentURL)
    }

    func navigateToURL(_ url: URL) {
        debugLog("SplitPaneViewController: navigateToURL - Received URL: \(url.path)")
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].navigateToURL(url)
    }

    func cutSelection() {
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].cutSelection()
    }

    func copySelection() {
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].copySelection()
    }

    func pasteSelection() {
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].pasteSelection()
    }
    
    // func changeFolderColor() {
    //     guard activePaneIndex < panes.count else { return }
    //     panes[activePaneIndex].changeFolderColor()
    // }
    
    func setViewMode(_ viewMode: ViewMode) {
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].toolbarDidChangeViewMode(viewMode)
    }
    
    func toggleHiddenFiles() {
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].toggleHiddenFilesState()
    }
    
    func updateZoomLevel(to level: Double) {
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].setZoomLevel(level)
    }

    // MARK: - Private Methods

    private func updateClosePaneButtonVisibility() {
        // Show close button only when there are multiple panes
        let shouldShowCloseButton = panes.count > 1
        for pane in panes {
            pane.setClosePaneButtonVisible(shouldShowCloseButton)
            // Also update split button states
            pane.updateSplitButtonsState(canAddMorePanes())
        }
    }
    
    private func setActivePane(index: Int) {
        guard index >= 0, index < panes.count else { return }
        activePaneIndex = index
        updateActivePaneUI()
    }
    
    private func setActivePane(for fileBrowser: FileBrowserViewController) {
        if let index = panes.firstIndex(where: { $0 === fileBrowser }) {
            setActivePane(index: index)
        }
    }
    
    private func updateActivePaneUI() {
        for (index, pane) in panes.enumerated() {
            let isActivePane = (index == activePaneIndex)
            pane.setZoomControlsVisible(isActivePane)
        }
    }

    // MARK: - FileBrowserDelegate

    func directoryDidChange(_ fileBrowser: FileBrowserViewController, to path: String) {
        setActivePane(for: fileBrowser)
        delegate?.splitPaneDirectoryDidChange(to: path)
    }
    
    func fileBrowserDidBecomeActive(_ fileBrowser: FileBrowserViewController) {
        setActivePane(for: fileBrowser)
        guard activePaneIndex < panes.count else { return }
        let path = panes[activePaneIndex].currentPath
        delegate?.splitPaneDirectoryDidChange(to: path)
    }

    func openInNewTab(url: URL) {
        // Delegate to parent TabBarController to handle opening in new tab
        delegate?.splitPaneOpenInNewTab(url: url)
    }

    func fileBrowserDidRequestSplit(_ fileBrowser: FileBrowserViewController, orientation: SplitOrientation) {
        // Verify pane exists
        guard panes.contains(fileBrowser) else { return }
        let isVertical = orientation == .vertical
        if splitView.isVertical != isVertical {
            splitView.isVertical = isVertical
        }
        let currentPath = fileBrowser.currentPath
        let currentURL = URL(fileURLWithPath: currentPath)
        addPane(url: currentURL)
    }
    
    func fileBrowser(_ fileBrowser: FileBrowserViewController, didSelectFile file: FileItem?) {
        // Selection handled per pane for its own preview; nothing needed here.
    }

    func fileBrowserDidRequestClosePane(_ fileBrowser: FileBrowserViewController) {
        // Ensure there's more than one file browser pane before attempting to close
        guard panes.count > 1 else {
            // Optionally, show an alert that the last pane cannot be closed
            let alert = NSAlert()
            alert.messageText = "Cannot Close Last Pane"
            alert.informativeText = "At least one file browser pane must remain open."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        if let index = panes.firstIndex(of: fileBrowser) {
            let paneToRemove = panes[index]
            panes.remove(at: index)

            // Remove the corresponding split view item
            // The splitViewItems array includes the previewViewController, so adjust index
            let splitViewItemIndex = index
            if splitViewItemIndex < splitViewItems.count {
                removeSplitViewItem(splitViewItems[splitViewItemIndex])
            }
            
            paneToRemove.removeFromParent()

            // Adjust activePaneIndex if the removed pane was active or before the active one
            if activePaneIndex == index {
                activePaneIndex = min(index, panes.count - 1)
            } else if activePaneIndex > index {
                activePaneIndex -= 1
            }
            
            // If no file browser panes remain (should not happen due to guard), clear preview
            if panes.isEmpty {
                // previewViewController.fileItem = nil
            } else {
                // Update preview with the new active pane's selection, or clear if no selection
                // Active pane may refresh its own preview automatically; nothing needed here.
            }

            // Notify delegate of new active path
            if activePaneIndex < panes.count {
                updateActivePaneUI()
                delegate?.splitPaneDirectoryDidChange(to: panes[activePaneIndex].currentPath)
            } else {
                // If all panes are closed (should be prevented by guard), report empty path
                delegate?.splitPaneDirectoryDidChange(to: "/")
            }

            // Update close button visibility for all remaining panes
            updateClosePaneButtonVisibility()
        }
    }

// MARK: - FileBrowserDelegate (continued)
    func fileBrowser(_ fileBrowser: FileBrowserViewController, didUpdateSelection selectedCount: Int, totalSize: Int64) {
        delegate?.splitPane(self, didUpdateSelection: selectedCount, totalSize: totalSize)
    }
    
    func fileBrowser(_ fileBrowser: FileBrowserViewController, didUpdateDiskSpace diskSpace: String?) {
        delegate?.splitPane(self, didUpdateDiskSpace: diskSpace)
    }

    func fileBrowserDidRequestAddToFavorites(_ fileBrowser: FileBrowserViewController, item: FileItem) {
        delegate?.splitPaneDidRequestAddToFavorites(item: item)
    }

    func toolbarDidRequestOpenInTerminal(from fileBrowser: FileBrowserViewController) {
        setActivePane(for: fileBrowser)
        guard activePaneIndex < panes.count else { return }
        let path = panes[activePaneIndex].currentPath
        delegate?.splitPaneDidRequestOpenTerminal(at: path)
    }

    // MARK: - Additional Public Methods

    func togglePreviewPane() {
        // Delegate toggle to active pane's internal preview implementation
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].toolbarDidTogglePreviewPane()
        NotificationCenter.default.post(name: Notification.Name("previewPaneToggled"), object: nil)
    }

    @objc private func handlePreviewPaneCloseRequested() {
        togglePreviewPane()
    }


    func isShowingHiddenFiles() -> Bool {
        guard activePaneIndex < panes.count else { return false }
        return panes[activePaneIndex].isShowingHiddenFiles()
    }

    func goBack() {
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].goBack()
    }

    func goForward() {
        // Note: goForward(to:) requires a URL parameter, which we don't have here
        // This is a stub for now - the old architecture may not have supported forward navigation
        guard activePaneIndex < panes.count else { return }
        // panes[activePaneIndex].goForward(to: ???)
    }
}
