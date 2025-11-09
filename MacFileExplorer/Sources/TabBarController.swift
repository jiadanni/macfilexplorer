import Cocoa

class TabBarController: NSViewController {

    private var tabView: NSTabView!
    private var tabs: [FileBrowserViewController] = []
    private var currentTabIndex = 0

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        setupUI()
    }

    private func setupUI() {
        // Create tab bar container first
        let tabBarContainer = NSView()
        tabBarContainer.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainer.wantsLayer = true
        tabBarContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.addSubview(tabBarContainer)

        // Create tab view
        tabView = NSTabView()
        tabView.tabViewType = .noTabsNoBorder
        tabView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabView)

        // Constrain tab bar to top
        NSLayoutConstraint.activate([
            tabBarContainer.topAnchor.constraint(equalTo: view.topAnchor),
            tabBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBarContainer.heightAnchor.constraint(equalToConstant: 30)
        ])

        // Constrain tab view below tab bar
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: tabBarContainer.bottomAnchor),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Public Methods

    func addNewTab() {
        let fileBrowser = FileBrowserViewController()
        fileBrowser.delegate = self
        tabs.append(fileBrowser)

        let tabItem = NSTabViewItem(viewController: fileBrowser)
        tabItem.label = "Applications"  // Will be updated when directory loads
        tabView.addTabViewItem(tabItem)
        tabView.selectTabViewItem(at: tabs.count - 1)
        currentTabIndex = tabs.count - 1
    }

    func closeCurrentTab() {
        guard tabs.count > 1 else { return }

        tabs.remove(at: currentTabIndex)
        tabView.removeTabViewItem(tabView.tabViewItem(at: currentTabIndex))

        if currentTabIndex >= tabs.count {
            currentTabIndex = tabs.count - 1
        }
        tabView.selectTabViewItem(at: currentTabIndex)
    }

    func getCurrentPath() -> String? {
        guard currentTabIndex < tabs.count else { return nil }
        return tabs[currentTabIndex].currentPath
    }

    func showBulkColorPicker() {
        guard currentTabIndex < tabs.count else { return }
        tabs[currentTabIndex].showBulkColorPicker()
    }

    func navigateToLocation(_ url: URL) {
        guard currentTabIndex < tabs.count else { return }
        tabs[currentTabIndex].navigateToURL(url)
    }
}

// MARK: - FileBrowserDelegate

extension TabBarController: FileBrowserDelegate {
    func directoryDidChange(to path: String) {
        // Update tab label with current directory name
        let url = URL(fileURLWithPath: path)
        let directoryName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent

        // Find the tab that corresponds to the current directory change
        if currentTabIndex < tabView.numberOfTabViewItems {
            let tabItem = tabView.tabViewItem(at: currentTabIndex)
            tabItem.label = directoryName
        }

        // Notify parent to update terminal
        if let splitVC = parent as? SplitViewController {
            splitVC.updateTerminalDirectory(path)
        }
    }

    func openInNewTab(url: URL) {
        // Create a new tab
        let fileBrowser = FileBrowserViewController()
        fileBrowser.delegate = self
        tabs.append(fileBrowser)

        let tabItem = NSTabViewItem(viewController: fileBrowser)
        tabItem.label = url.lastPathComponent
        tabView.addTabViewItem(tabItem)

        // Switch to the new tab
        tabView.selectTabViewItem(at: tabs.count - 1)
        currentTabIndex = tabs.count - 1

        // Navigate to the URL in the new tab
        fileBrowser.navigateToURL(url)
    }
}

// MARK: - FileBrowserDelegate Protocol

protocol FileBrowserDelegate: AnyObject {
    func directoryDidChange(to path: String)
    func openInNewTab(url: URL)
}
