import Cocoa

enum SplitOrientation {
    case vertical
    case horizontal
}

protocol FileBrowserDelegate: AnyObject {
    func directoryDidChange(to path: String)
    func openInNewTab(url: URL)
    func fileBrowserDidRequestSplit(_ fileBrowser: FileBrowserViewController, orientation: SplitOrientation)
    func fileBrowser(_ fileBrowser: FileBrowserViewController, didSelectFile file: FileItem?)
    func fileBrowserDidRequestClosePane(_ fileBrowser: FileBrowserViewController)
    func fileBrowser(_ fileBrowser: FileBrowserViewController, didUpdateSelection selectedCount: Int, totalSize: Int64)
    func fileBrowser(_ fileBrowser: FileBrowserViewController, didUpdateDiskSpace diskSpace: String?)
    func fileBrowserDidRequestAddToFavorites(_ fileBrowser: FileBrowserViewController, item: FileItem)
}

protocol SplitPaneViewControllerDelegate: AnyObject {
    func splitPaneDirectoryDidChange(to path: String)
    func splitPaneOpenInNewTab(url: URL)
    func splitPane(_ splitPane: SplitPaneViewController, didUpdateSelection selectedCount: Int, totalSize: Int64)
    func splitPane(_ splitPane: SplitPaneViewController, didUpdateDiskSpace diskSpace: String?)
    func splitPaneDidRequestAddToFavorites(item: FileItem)
}

class SplitPaneViewController: NSSplitViewController, FileBrowserDelegate {

    weak var delegate: SplitPaneViewControllerDelegate?

    private var panes: [FileBrowserViewController] = []
    private var activePaneIndex: Int = 0
    private var previewViewController: PreviewPaneViewController?
    private var previewSplitItem: NSSplitViewItem?
    private var isPreviewPaneVisible: Bool = false

    var currentPath: String {
        guard activePaneIndex < panes.count else { return "/" }
        return panes[activePaneIndex].currentPath
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        NotificationCenter.default.addObserver(self, selector: #selector(handlePreviewPaneCloseRequested), name: .previewPaneCloseRequested, object: nil)
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
        activePaneIndex = panes.count - 1

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
        print("SplitPaneViewController: navigateToURL - Received URL: \(url.path)")
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

    // MARK: - FileBrowserDelegate

    func directoryDidChange(to path: String) {
        // Find which pane changed
        for (index, pane) in panes.enumerated() {
            if pane.currentPath == path {
                activePaneIndex = index
                break
            }
        }

        delegate?.splitPaneDirectoryDidChange(to: path)
    }

    func openInNewTab(url: URL) {
        // Delegate to parent TabBarController to handle opening in new tab
        delegate?.splitPaneOpenInNewTab(url: url)
    }

    func fileBrowserDidRequestSplit(_ fileBrowser: FileBrowserViewController, orientation: SplitOrientation) {
        // Determine which pane requested the split
        guard let paneIndex = panes.firstIndex(of: fileBrowser) else { return }
        
        // Change split view orientation if needed
        let isVertical = orientation == .vertical
        if splitView.isVertical != isVertical {
            splitView.isVertical = isVertical
        }
        
        // Add a new pane next to the requesting pane with the same directory
        // Use the currentPath property to get the directory URL
        let currentPath = fileBrowser.currentPath
        let currentURL = URL(fileURLWithPath: currentPath)
        addPane(url: currentURL)
    }
    
    func fileBrowser(_ fileBrowser: FileBrowserViewController, didSelectFile file: FileItem?) {
        // Update preview pane if visible
        if isPreviewPaneVisible, let preview = previewViewController {
            preview.previewFile(file)
        }
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
                let currentActivePane = panes[activePaneIndex]
                // This is a bit tricky as we don't have direct access to its selection.
                // For now, we'll clear the preview. A more robust solution would involve
                // the active pane re-reporting its selection.
                // previewViewController.fileItem = nil 
            }

            // Notify delegate of new active path
            if activePaneIndex < panes.count {
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

    // MARK: - Additional Public Methods

    func togglePreviewPane() {
        if isPreviewPaneVisible {
            // Hide preview pane
            if let previewSplitItem = previewSplitItem {
                removeSplitViewItem(previewSplitItem)
                previewViewController?.removeFromParent()
                previewViewController = nil
                self.previewSplitItem = nil
                isPreviewPaneVisible = false
                
                // Save state and notify
                UserDefaults.standard.set(false, forKey: UserDefaults.Keys.showPreviewPane.rawValue)
                NotificationCenter.default.post(name: Notification.Name("previewPaneToggled"), object: nil)
            }
        } else {
            // Show preview pane
            let preview = PreviewPaneViewController()
            preview.position = .right
            previewViewController = preview

            addChild(preview)
            let splitItem = NSSplitViewItem(viewController: preview)
            splitItem.canCollapse = true
            splitItem.minimumThickness = 250
            splitItem.maximumThickness = 600

            // Prevent the preview pane from pushing/resizing the window
            splitItem.holdingPriority = NSLayoutConstraint.Priority(rawValue: 249)
            addSplitViewItem(splitItem)

            // Set width constraints to keep preview pane stable
            preview.view.translatesAutoresizingMaskIntoConstraints = false
            preview.view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            preview.view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            previewSplitItem = splitItem
            isPreviewPaneVisible = true
            
            // Update preview with current selection
            if activePaneIndex < panes.count {
                let selectedItems = panes[activePaneIndex].getSelectedItems()
                if let firstItem = selectedItems.first {
                    preview.previewFile(firstItem)
                }
            }
            
            // Save state and notify
            UserDefaults.standard.set(true, forKey: UserDefaults.Keys.showPreviewPane.rawValue)
            NotificationCenter.default.post(name: Notification.Name("previewPaneToggled"), object: nil)
        }
    }

    @objc private func handlePreviewPaneCloseRequested() {
        if isPreviewPaneVisible {
            togglePreviewPane()
        }
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
