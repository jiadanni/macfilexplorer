import Cocoa

protocol SplitPaneDelegate: AnyObject {
    func splitPaneDirectoryDidChange(to path: String)
}

class SplitPaneViewController: NSViewController {

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
        fileBrowser.delegate = self
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
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].navigateToURL(url)
    }

    func showBulkColorPicker() {
        guard activePaneIndex < panes.count else { return }
        panes[activePaneIndex].showBulkColorPicker()
    }
}

// MARK: - FileBrowserDelegate

extension SplitPaneViewController: FileBrowserDelegate {
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
        // This should be handled by the parent TabBarController
        // For now, just navigate in the active pane
        navigateToURL(url)
    }
}
