import Cocoa

class TabBarController: NSViewController {

    private var tabView: NSTabView!
    private var tabs: [FileBrowserViewController] = []
    private var currentTabIndex = 0
    private var tabButtonsStackView: NSStackView!
    private var tabButtons: [NSButton] = []
    private var titlebarAccessory: NSTitlebarAccessoryViewController?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        setupUI()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        setupTitlebarTabs()

        // Force an immediate update to ensure tabs are visible
        if tabButtonsStackView != nil && !tabs.isEmpty {
            updateTabButtons()
        }
    }

    private func setupUI() {
        // Create tab view without custom tab bar
        tabView = NSTabView()
        tabView.tabViewType = .noTabsNoBorder
        tabView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabView)

        // Constrain tab view to fill entire view
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: view.topAnchor),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupTitlebarTabs() {
        guard let window = view.window, titlebarAccessory == nil else { return }

        // Create stack view for tab buttons
        tabButtonsStackView = NSStackView()
        tabButtonsStackView.orientation = .horizontal
        tabButtonsStackView.spacing = 8  // More spacing between tabs
        tabButtonsStackView.alignment = .centerY
        tabButtonsStackView.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)

        // Create titlebar accessory view controller
        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = tabButtonsStackView
        accessory.layoutAttribute = .leading

        window.addTitlebarAccessoryViewController(accessory)
        titlebarAccessory = accessory

        updateTabButtons()
    }

    private func createTabButton(title: String, index: Int) -> NSButton {
        let button = NSButton()
        button.title = title
        button.bezelStyle = .rounded
        button.setButtonType(.pushOnPushOff)
        button.target = self
        button.action = #selector(tabButtonClicked(_:))
        button.tag = index
        button.font = NSFont.systemFont(ofSize: 12)

        // Set minimum width for tabs
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true

        // Style the button with custom appearance
        button.wantsLayer = true

        if index == currentTabIndex {
            // Active tab - bright with border
            button.state = .on
            button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
            button.layer?.borderColor = NSColor.controlAccentColor.cgColor
            button.layer?.borderWidth = 2
            button.layer?.cornerRadius = 6
            button.contentTintColor = NSColor.controlAccentColor
        } else {
            // Inactive tab - subtle appearance
            button.state = .off
            button.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
            button.layer?.borderColor = NSColor.separatorColor.cgColor
            button.layer?.borderWidth = 1
            button.layer?.cornerRadius = 6
            button.contentTintColor = NSColor.secondaryLabelColor
        }

        return button
    }

    private func updateTabButtons() {
        // Guard against nil stack view (before viewDidAppear is called)
        guard tabButtonsStackView != nil else { return }

        // Remove all existing buttons
        tabButtonsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tabButtons.removeAll()

        // Create new buttons for all tabs
        for (index, _) in tabs.enumerated() {
            let tabItem = tabView.tabViewItem(at: index)
            let button = createTabButton(title: tabItem.label, index: index)
            tabButtonsStackView.addArrangedSubview(button)
            tabButtons.append(button)

            // Highlight current tab
            if index == currentTabIndex {
                button.state = .on
            }
        }
    }

    @objc private func tabButtonClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index < tabs.count else { return }

        currentTabIndex = index
        tabView.selectTabViewItem(at: index)
        updateTabButtons()
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

        updateTabButtons()
    }

    func closeCurrentTab() {
        guard tabs.count > 1 else { return }

        tabs.remove(at: currentTabIndex)
        tabView.removeTabViewItem(tabView.tabViewItem(at: currentTabIndex))

        if currentTabIndex >= tabs.count {
            currentTabIndex = tabs.count - 1
        }
        tabView.selectTabViewItem(at: currentTabIndex)

        updateTabButtons()
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

            // Update the button label too
            if currentTabIndex < tabButtons.count {
                tabButtons[currentTabIndex].title = directoryName
            }
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

        updateTabButtons()

        // Navigate to the URL in the new tab
        fileBrowser.navigateToURL(url)
    }
}

// MARK: - FileBrowserDelegate Protocol

protocol FileBrowserDelegate: AnyObject {
    func directoryDidChange(to path: String)
    func openInNewTab(url: URL)
}
