import Cocoa

protocol TabBarControllerDelegate: AnyObject {
    func tabBarController(_ tabBarController: TabBarController, didUpdateSelection selectedCount: Int, totalSize: Int64)
    func tabBarController(_ tabBarController: TabBarController, didUpdateDiskSpace diskSpace: String?)
}

class TabBarController: NSViewController, SplitPaneDelegate {

    weak var delegate: TabBarControllerDelegate?

    private var tabView: NSTabView!
    private var tabs: [SplitPaneViewController] = []
    private var currentTabIndex = 0
    private var tabBarContainer: NSView!
    private var tabButtonsStackView: NSStackView!
    private var tabButtons: [NSButton] = []

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        setupUI()
    }

    private func setupUI() {
        // Create tab bar container at the top
        tabBarContainer = NSView()
        tabBarContainer.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainer.wantsLayer = true
        tabBarContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // Add bottom border for visual separation
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainer.addSubview(separator)

        view.addSubview(tabBarContainer)

        // Create stack view for tab buttons
        tabButtonsStackView = NSStackView()
        tabButtonsStackView.translatesAutoresizingMaskIntoConstraints = false
        tabButtonsStackView.orientation = .horizontal
        tabButtonsStackView.spacing = 0
        tabButtonsStackView.alignment = .centerY
        tabBarContainer.addSubview(tabButtonsStackView)

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
            tabBarContainer.heightAnchor.constraint(equalToConstant: 28),

            tabButtonsStackView.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor, constant: 4),
            tabButtonsStackView.trailingAnchor.constraint(lessThanOrEqualTo: tabBarContainer.trailingAnchor, constant: -4),
            tabButtonsStackView.topAnchor.constraint(equalTo: tabBarContainer.topAnchor),
            tabButtonsStackView.bottomAnchor.constraint(equalTo: tabBarContainer.bottomAnchor, constant: -1),

            separator.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: tabBarContainer.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])

        // Constrain tab view below tab bar
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: tabBarContainer.bottomAnchor),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func createTabButton(title: String, index: Int) -> NSButton {
        let button = NSButton()
        button.title = title
        button.bezelStyle = .shadowlessSquare
        button.isBordered = false
        button.setButtonType(.momentaryChange)
        button.target = self
        button.action = #selector(tabButtonClicked(_:))
        button.tag = index
        button.font = NSFont.systemFont(ofSize: 13)
        button.alignment = .center

        // Set minimum width for tabs
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true

        // Full height tabs with distinct appearance
        button.wantsLayer = true
        button.layer?.cornerRadius = 0 // No rounding for full height effect

        if index == currentTabIndex {
            // Active tab - distinct darker background with full height
            if #available(macOS 10.14, *) {
                button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            } else {
                button.layer?.backgroundColor = NSColor.selectedControlColor.withAlphaComponent(0.15).cgColor
            }
            button.contentTintColor = NSColor.labelColor
            button.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        } else {
            // Inactive tab - transparent with subtle text
            button.layer?.backgroundColor = NSColor.clear.cgColor
            button.contentTintColor = NSColor.secondaryLabelColor
            button.font = NSFont.systemFont(ofSize: 13)
        }

        return button
    }

    private func updateTabButtons() {
        // Ensure view is loaded
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
        }

        // Force visual update
        tabButtonsStackView.layoutSubtreeIfNeeded()
        tabBarContainer.layoutSubtreeIfNeeded()
    }

    @objc private func tabButtonClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index < tabs.count else { return }

        currentTabIndex = index
        tabView.selectTabViewItem(at: index)
        updateTabButtons()

        // Update terminal to the new tab's directory
                    _ = tabs[index].currentPath
                    if let splitVC = parent as? SplitViewController {
                        splitVC.updateTerminalDirectory()
                    }    }

    // MARK: - Public Methods

    func addNewTab() {
        let splitPane = SplitPaneViewController()
        splitPane.delegate = self
        tabs.append(splitPane)

        // Force the view to load
        _ = splitPane.view

        let tabItem = NSTabViewItem(viewController: splitPane)
        tabItem.label = URL(fileURLWithPath: splitPane.currentPath).lastPathComponent // Will be updated when directory loads
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

    func cutSelection() {
        guard currentTabIndex < tabs.count else { return }
        tabs[currentTabIndex].cutSelection()
    }

    func copySelection() {
        guard currentTabIndex < tabs.count else { return }
        tabs[currentTabIndex].copySelection()
    }

    func pasteSelection() {
        guard currentTabIndex < tabs.count else { return }
        tabs[currentTabIndex].pasteSelection()
    }
    
    func changeFolderColor() {
        guard currentTabIndex < tabs.count else { return }
        tabs[currentTabIndex].changeFolderColor()
    }
    
    func setViewMode(_ viewMode: ViewMode) {
        guard currentTabIndex < tabs.count else { return }
        tabs[currentTabIndex].setViewMode(viewMode)
    }
    
    func toggleHiddenFiles() {
        guard currentTabIndex < tabs.count else { return }
        tabs[currentTabIndex].toggleHiddenFiles()
    }
    
    func splitVertically() {
        guard currentTabIndex < tabs.count else { return }
        tabs[currentTabIndex].splitVertically()
    }
    
    func splitHorizontally() {
        guard currentTabIndex < tabs.count else { return }
        tabs[currentTabIndex].splitHorizontally()
    }

    func navigateToLocation(_ url: URL) {
        print("TabBarController: navigateToLocation - Received URL: \(url.path)")
        guard currentTabIndex < tabs.count else { return }
        tabs[currentTabIndex].navigateToURL(url)
    }

    func updateZoomLevel(to level: Double) {
        // Forward zoom level to the current tab/pane
        guard currentTabIndex < tabs.count else { return }
        tabs[currentTabIndex].updateZoomLevel(to: level)
    }

    public func openInNewTab(url: URL) {
        print("TabBarController: openInNewTab - Received URL: \(url.path)")
        // Create a new tab with a SplitPaneViewController
        let splitPane = SplitPaneViewController()
        splitPane.delegate = self
        tabs.append(splitPane)

        let tabItem = NSTabViewItem(viewController: splitPane)
        tabItem.label = url.lastPathComponent
        tabView.addTabViewItem(tabItem)

        // Switch to the new tab
        tabView.selectTabViewItem(at: tabs.count - 1)
        currentTabIndex = tabs.count - 1

        updateTabButtons()

        // Ensure the view is loaded before navigating
        _ = splitPane.view
        
        // Navigate to the URL in the new tab
        splitPane.navigateToURL(url)
    }
}

// MARK: - SplitPaneDelegate

extension TabBarController {
    func splitPaneDirectoryDidChange(to path: String) {
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

        // Update window title to show current directory path
        view.window?.title = path

        // Notify parent to update terminal
        if let splitVC = parent as? SplitViewController {
            splitVC.updateTerminalDirectory()
        }
    }

    func splitPaneOpenInNewTab(url: URL) {
        print("TabBarController: splitPaneOpenInNewTab - Received URL: \(url.path)")
        // Delegate to parent TabBarController to handle opening in new tab
        openInNewTab(url: url)
    }

    func splitPane(_ splitPane: SplitPaneViewController, didUpdateSelection selectedCount: Int, totalSize: Int64) {
        delegate?.tabBarController(self, didUpdateSelection: selectedCount, totalSize: totalSize)
    }
    
    func splitPane(_ splitPane: SplitPaneViewController, didUpdateDiskSpace diskSpace: String?) {
        delegate?.tabBarController(self, didUpdateDiskSpace: diskSpace)
    }

    func toolbarDidRequestSplitVertically() {
        guard currentTabIndex < tabs.count else { return }
        tabs[currentTabIndex].splitVertically()
    }

    func toolbarDidRequestSplitHorizontally() {
        guard currentTabIndex < tabs.count else { return }
        tabs[currentTabIndex].splitHorizontally()
    }
}