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
}

protocol SplitPaneDelegate: AnyObject {
    func splitPaneDirectoryDidChange(to path: String)
    func splitPaneOpenInNewTab(url: URL)
    func splitPane(_ splitPane: SplitPaneViewController, didUpdateSelection selectedCount: Int, totalSize: Int64)
    func splitPane(_ splitPane: SplitPaneViewController, didUpdateDiskSpace diskSpace: String?)
}

class SplitPaneViewController: NSSplitViewController, FileBrowserDelegate {

    weak var delegate: SplitPaneDelegate?

    private var panes: [FileBrowserViewController] = []
    private var activePaneIndex: Int = 0
    // private var previewViewController: PreviewViewController!

    var currentPath: String {
        guard activePaneIndex < panes.count else { return "/" }
        return panes[activePaneIndex].currentPath
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        // Configure the split view itself
        splitView.isVertical = true // Main split is vertical (panes side-by-side)
        splitView.dividerStyle = .thin

        // Add initial file browser pane
        addPane()

        // Add preview pane
        // previewViewController = PreviewViewController()
        // addChild(previewViewController)
        // addSplitViewItem(NSSplitViewItem(viewController: previewViewController))
    }

    // MARK: - Public Methods

    func addPane(url: URL? = nil) {
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
    }

    func splitVertically() {
        // Get current directory from active pane
        let currentURL = URL(fileURLWithPath: currentPath)

        // Ensure the split view is vertical
        splitView.isVertical = true

        // Add new pane with same directory
        addPane(url: currentURL)
    }

    func splitHorizontally() {
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
        // previewViewController.fileItem = file
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
            }
        }
    }

// MARK: - FileBrowserDelegate
extension SplitPaneViewController {
    func fileBrowser(_ fileBrowser: FileBrowserViewController, didUpdateSelection selectedCount: Int, totalSize: Int64) {
        delegate?.splitPane(self, didUpdateSelection: selectedCount, totalSize: totalSize)
    }
    
    func fileBrowser(_ fileBrowser: FileBrowserViewController, didUpdateDiskSpace diskSpace: String?) {
        delegate?.splitPane(self, didUpdateDiskSpace: diskSpace)
    }
}
