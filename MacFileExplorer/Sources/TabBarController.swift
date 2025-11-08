import Cocoa

class TabBarController: NSViewController {

    private var tabView: NSTabView!
    private var tabs: [FileBrowserViewController] = []
    private var currentTabIndex = 0

    override func loadView() {
        view = NSView()
        setupUI()
    }

    private func setupUI() {
        // Create tab view
        tabView = NSTabView()
        tabView.tabViewType = .noTabsNoBorder
        tabView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabView)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: view.topAnchor),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Create tab bar (custom implementation using stack view)
        setupTabBar()
    }

    private func setupTabBar() {
        let tabBarContainer = NSView()
        tabBarContainer.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainer.wantsLayer = true
        tabBarContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.addSubview(tabBarContainer)

        NSLayoutConstraint.activate([
            tabBarContainer.topAnchor.constraint(equalTo: view.topAnchor),
            tabBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBarContainer.heightAnchor.constraint(equalToConstant: 30)
        ])

        // Update tab view constraints
        tabView.topAnchor.constraint(equalTo: tabBarContainer.bottomAnchor).isActive = true
    }

    // MARK: - Public Methods

    func addNewTab() {
        let fileBrowser = FileBrowserViewController()
        fileBrowser.delegate = self
        tabs.append(fileBrowser)

        let tabItem = NSTabViewItem(viewController: fileBrowser)
        tabItem.label = "Home"
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
}

// MARK: - FileBrowserDelegate

extension TabBarController: FileBrowserDelegate {
    func directoryDidChange(to path: String) {
        // Notify parent to update terminal
        if let splitVC = parent as? SplitViewController {
            splitVC.updateTerminalDirectory(path)
        }
    }
}

// MARK: - FileBrowserDelegate Protocol

protocol FileBrowserDelegate: AnyObject {
    func directoryDidChange(to path: String)
}
