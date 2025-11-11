import Cocoa

enum SplitOrientation {
    case vertical
    case horizontal
}

protocol FileBrowserDelegate: AnyObject {
    func directoryDidChange(to path: String)
    func openInNewTab(url: URL)
    func fileBrowserDidRequestSplit(_ fileBrowser: FileBrowserViewController, orientation: SplitOrientation)
}

protocol SplitPaneDelegate: AnyObject {
    func splitPaneDirectoryDidChange(to path: String)
    func splitPaneOpenInNewTab(url: URL)
}

class SplitPaneViewController: NSViewController, FileBrowserDelegate {

    weak var delegate: SplitPaneDelegate?

    private var splitView: NSSplitView!
    private var panes: [FileBrowserViewController] = []
    private var activePaneIndex: Int = 0

    var currentPath: String {
        guard activePaneIndex < panes.count else { return "/" }
        return panes[activePaneIndex].currentPath
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        setupUI()
    }

    private func setupUI() {
        // Create split view
        splitView = NSSplitView()
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        view.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: view.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Add initial pane
        addPane()
    }

    // MARK: - Public Methods

    func addPane(url: URL? = nil) {
        let fileBrowser = FileBrowserViewController()
        fileBrowser.delegate = self // SplitPaneViewController is now the FileBrowserDelegate
        panes.append(fileBrowser)

        addChild(fileBrowser)
        let splitItem = NSSplitViewItem(viewController: fileBrowser)
        splitItem.canCollapse = false
        splitView.addArrangedSubview(fileBrowser.view)

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

        paneToRemove.view.removeFromSuperview()
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

        // Add new pane with same directory
        addPane(url: currentURL)
    }

    func splitHorizontally() {
        // Change split view orientation
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

    func showBulkColorPicker() {
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].showBulkColorPicker()
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
        let isVertical = (orientation == .vertical)
        if splitView.isVertical != isVertical {
            splitView.isVertical = isVertical
        }
        
        // Add a new pane next to the requesting pane with the same directory
        // Use the currentPath property to get the directory URL
        let currentPath = fileBrowser.currentPath
        if let currentURL = URL(string: "file://\(currentPath)") {
            addPane(url: currentURL)
        } else {
            // Fallback to home directory if path is unavailable
            addPane(url: FileManager.default.homeDirectoryForCurrentUser)
        }
    }
}
