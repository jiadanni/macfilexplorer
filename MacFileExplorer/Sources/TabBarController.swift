import Cocoa

protocol TabBarControllerDelegate: AnyObject {
    func tabBarController(_ tabBarController: TabBarController, didUpdateSelection selectedCount: Int, totalSize: Int64)
    func tabBarController(_ tabBarController: TabBarController, didUpdateDiskSpace diskSpace: String?)
}

class TabBarController: NSViewController, SplitPaneViewControllerDelegate {

    weak var delegate: TabBarControllerDelegate?

    private var tabView: NSTabView!
    private var tabs: [NSViewController] = []
    private var currentTabIndex = 0
    private var tabBarContainer: NSView!
    private var tabButtonsStackView: NSStackView!
    private var tabButtons: [NSButton] = []
    private var tabCloseButtons: [NSButton] = []

    override func loadView() {
        view = NSView()
        setupUI()
        
        // Listen for accent color changes
        NotificationCenter.default.addObserver(forName: .accentColorDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updateTabButtons()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .accentColorDidChangeNotification, object: nil)
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

    private func createTabButtonContainer(title: String, index: Int, showClose: Bool) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true

        // Set container background based on selection
        let isSelected = index == currentTabIndex
        if isSelected {
            // Use accent color for active tab with subtle alpha
            container.layer?.backgroundColor = NSColor.customAccentColor.withAlphaComponent(0.15).cgColor
        } else {
            container.layer?.backgroundColor = NSColor.clear.cgColor
        }

        // Add subtle rounded corners at the top for Finder-style tabs
        container.layer?.cornerRadius = 6
        container.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

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
        button.translatesAutoresizingMaskIntoConstraints = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor

        if isSelected {
            button.contentTintColor = NSColor.labelColor
            button.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        } else {
            button.contentTintColor = NSColor.secondaryLabelColor
            button.font = NSFont.systemFont(ofSize: 13)
        }

        container.addSubview(button)

        var closeButton: NSButton?
        if showClose {
            let cb = NSButton()
            cb.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
            cb.bezelStyle = .shadowlessSquare
            cb.isBordered = false
            cb.setButtonType(.momentaryChange)
            cb.imageScaling = .scaleProportionallyDown
            cb.contentTintColor = isSelected ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor
            cb.translatesAutoresizingMaskIntoConstraints = false
            cb.target = self
            cb.action = #selector(closeTabButtonClicked(_:))
            cb.tag = index
            cb.wantsLayer = true
            cb.layer?.cornerRadius = 3

            container.addSubview(cb)
            closeButton = cb
            NSLayoutConstraint.activate([
                cb.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
                cb.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                cb.widthAnchor.constraint(equalToConstant: 16),
                cb.heightAnchor.constraint(equalToConstant: 16)
            ])
        }

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -1),
            (closeButton != nil ? button.trailingAnchor.constraint(lessThanOrEqualTo: closeButton!.leadingAnchor, constant: -4) : button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8)),
            container.heightAnchor.constraint(equalToConstant: 28),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 130)
        ])

        // Track for updates
        tabButtons.append(button)
        if let cb = closeButton { tabCloseButtons.append(cb) }
        return container
    }

    private func updateTabButtons() {
        // Ensure view is loaded
        guard tabButtonsStackView != nil else { return }

        // Remove all existing buttons
        tabButtonsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tabButtons.removeAll()
        tabCloseButtons.removeAll()

        // Create new buttons for all tabs
        for (index, tab) in tabs.enumerated() {
            let tabItem = tabView.tabViewItem(at: index)
            // Start tab should never show close button
            let showClose = tabs.count > 1 && !(tab is StartViewController)
            let container = createTabButtonContainer(title: tabItem.label, index: index, showClose: showClose)
            tabButtonsStackView.addArrangedSubview(container)
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
        if let splitVC = parent as? SplitViewController {
            splitVC.updateTerminalDirectory()
        }
    }

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

    func addStartTab() {
        let startVC = StartViewController()
        startVC.delegate = self
        tabs.append(startVC)

        // Force the view to load
        _ = startVC.view

        let tabItem = NSTabViewItem(viewController: startVC)
        tabItem.label = "Start"
        tabView.addTabViewItem(tabItem)

        tabView.selectTabViewItem(at: tabs.count - 1)

        currentTabIndex = tabs.count - 1

        updateTabButtons()
    }

    func showStartTab() {
        // Check if Start tab already exists
        for (index, tab) in tabs.enumerated() {
            if tab is StartViewController {
                tabView.selectTabViewItem(at: index)
                currentTabIndex = index
                return
            }
        }

        // If not, create it
        addStartTab()
    }

    func closeCurrentTab() {
        guard tabs.count > 1 else { return }
        // Don't allow closing the Start tab
        if tabs[currentTabIndex] is StartViewController {
            return
        }
        closeTab(at: currentTabIndex)
    }

    private func closeTab(at index: Int) {
        guard index >= 0, index < tabs.count, tabs.count > 1 else { return }
        // Don't allow closing the Start tab
        if tabs[index] is StartViewController {
            return
        }
        tabs.remove(at: index)
        tabView.removeTabViewItem(tabView.tabViewItem(at: index))
        if currentTabIndex >= tabs.count { currentTabIndex = tabs.count - 1 }
        tabView.selectTabViewItem(at: currentTabIndex)
        updateTabButtons()
    }

    @objc private func closeTabButtonClicked(_ sender: NSButton) {
        closeTab(at: sender.tag)
    }

    func getCurrentPath() -> String? {
        guard currentTabIndex < tabs.count else { return nil }
        if let splitPane = tabs[currentTabIndex] as? SplitPaneViewController {
            return splitPane.currentPath
        }
        return nil
    }

    func cutSelection() {
        guard currentTabIndex < tabs.count else { return }
        if let splitPane = tabs[currentTabIndex] as? SplitPaneViewController {
            splitPane.cutSelection()
        }
    }

    func copySelection() {
        guard currentTabIndex < tabs.count else { return }
        if let splitPane = tabs[currentTabIndex] as? SplitPaneViewController {
            splitPane.copySelection()
        }
    }

    func pasteSelection() {
        guard currentTabIndex < tabs.count else { return }
        if let splitPane = tabs[currentTabIndex] as? SplitPaneViewController {
            splitPane.pasteSelection()
        }
    }

    // func changeFolderColor() {
    //     guard currentTabIndex < tabs.count else { return }
    //     tabs[currentTabIndex].changeFolderColor()
    // }

    func setViewMode(_ viewMode: ViewMode) {
        guard currentTabIndex < tabs.count else { return }
        if let splitPane = tabs[currentTabIndex] as? SplitPaneViewController {
            splitPane.setViewMode(viewMode)
        }
    }

    func toggleHiddenFiles() {
        guard currentTabIndex < tabs.count else { return }
        if let splitPane = tabs[currentTabIndex] as? SplitPaneViewController {
            splitPane.toggleHiddenFiles()
        }
    }

    func isShowingHiddenFiles() -> Bool {
        guard currentTabIndex < tabs.count else { return false }
        if let splitPane = tabs[currentTabIndex] as? SplitPaneViewController {
            return splitPane.isShowingHiddenFiles()
        }
        return false
    }

    func togglePreviewPane() {
        guard currentTabIndex < tabs.count else { return }
        if let splitPane = tabs[currentTabIndex] as? SplitPaneViewController {
            splitPane.togglePreviewPane()
        }
    }

    func goBack() {
        guard currentTabIndex < tabs.count else { return }
        if let splitPane = tabs[currentTabIndex] as? SplitPaneViewController {
            splitPane.goBack()
        }
    }

    func goForward() {
        guard currentTabIndex < tabs.count else { return }
        if let splitPane = tabs[currentTabIndex] as? SplitPaneViewController {
            splitPane.goForward()
        }
    }

    func splitVertically() {
        guard currentTabIndex < tabs.count else { return }
        if let splitPane = tabs[currentTabIndex] as? SplitPaneViewController {
            splitPane.splitVertically()
        }
    }

    func splitHorizontally() {
        guard currentTabIndex < tabs.count else { return }
        if let splitPane = tabs[currentTabIndex] as? SplitPaneViewController {
            splitPane.splitHorizontally()
        }
    }

    func navigateToLocation(_ url: URL) {
        print("TabBarController: navigateToLocation - Received URL: \(url.path)")
        guard currentTabIndex < tabs.count else { return }
        if let splitPane = tabs[currentTabIndex] as? SplitPaneViewController {
            splitPane.navigateToURL(url)
        }
    }
    
    func isCurrentTabStartPage() -> Bool {
        guard currentTabIndex < tabs.count else { return false }
        return tabs[currentTabIndex] is StartViewController
    }

    func updateZoomLevel(to level: Double) {
        // Forward zoom level to the current tab/pane
        guard currentTabIndex < tabs.count else { return }
        if let splitPane = tabs[currentTabIndex] as? SplitPaneViewController {
            splitPane.updateZoomLevel(to: level)
        }
    }

    // MARK: - Settings Tab

    func openSettingsTab() {
        // If settings tab already exists, select it
        if let existingIndex = tabs.firstIndex(where: { $0 is SettingsSplitPaneViewController }) {
            tabView.selectTabViewItem(at: existingIndex)
            currentTabIndex = existingIndex
            updateTabButtons()
            return
        }
        let settingsPane = SettingsSplitPaneViewController()
        settingsPane.delegate = self
        tabs.append(settingsPane)
        let tabItem = NSTabViewItem(viewController: settingsPane)
        tabItem.label = "Settings"
        tabView.addTabViewItem(tabItem)
        tabView.selectTabViewItem(at: tabs.count - 1)
        currentTabIndex = tabs.count - 1
        updateTabButtons()
    }

    // MARK: - Storage Analyzer Tab

    func openStorageAnalyzerTab() {
        // If storage analyzer tab already exists, select it
        if let existingIndex = tabs.firstIndex(where: { $0 is StorageAnalyzerTabViewController }) {
            tabView.selectTabViewItem(at: existingIndex)
            currentTabIndex = existingIndex
            updateTabButtons()
            return
        }
        let storageAnalyzerVC = StorageAnalyzerTabViewController()
        storageAnalyzerVC.delegate = self
        tabs.append(storageAnalyzerVC)
        let tabItem = NSTabViewItem(viewController: storageAnalyzerVC)
        tabItem.label = "Storage Analyzer"
        tabView.addTabViewItem(tabItem)
        tabView.selectTabViewItem(at: tabs.count - 1)
        currentTabIndex = tabs.count - 1
        updateTabButtons()
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
        // If the active tab is the Settings or Storage Analyzer tab, keep its label fixed.
        if currentTabIndex < tabs.count, tabs[currentTabIndex] is SettingsSplitPaneViewController {
            if currentTabIndex < tabView.numberOfTabViewItems {
                let tabItem = tabView.tabViewItem(at: currentTabIndex)
                if tabItem.label != "Settings" { tabItem.label = "Settings" }
            }
            if currentTabIndex < tabButtons.count, tabButtons[currentTabIndex].title != "Settings" {
                tabButtons[currentTabIndex].title = "Settings"
            }
        } else if currentTabIndex < tabs.count, tabs[currentTabIndex] is StorageAnalyzerTabViewController {
            if currentTabIndex < tabView.numberOfTabViewItems {
                let tabItem = tabView.tabViewItem(at: currentTabIndex)
                if tabItem.label != "Storage Analyzer" { tabItem.label = "Storage Analyzer" }
            }
            if currentTabIndex < tabButtons.count, tabButtons[currentTabIndex].title != "Storage Analyzer" {
                tabButtons[currentTabIndex].title = "Storage Analyzer"
            }
        } else {
            // Update tab label with current directory name
            let url = URL(fileURLWithPath: path)
            let directoryName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
            if currentTabIndex < tabView.numberOfTabViewItems {
                let tabItem = tabView.tabViewItem(at: currentTabIndex)
                tabItem.label = directoryName
            }
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

    func splitPaneDidRequestAddToFavorites(item: FileItem) {
        // Forward to sidebar or handle adding to favorites
        if let splitVC = parent as? SplitViewController {
            splitVC.updateSidebarSelection(url: item.url)
        }
    }

    func toolbarDidRequestSplitVertically() {
        guard currentTabIndex < tabs.count else { return }
        if let splitPane = tabs[currentTabIndex] as? SplitPaneViewController {
            splitPane.splitVertically()
        }
    }

    func toolbarDidRequestSplitHorizontally() {
        guard currentTabIndex < tabs.count else { return }
        if let splitPane = tabs[currentTabIndex] as? SplitPaneViewController {
            splitPane.splitHorizontally()
        }
    }
}

// MARK: - StartViewControllerDelegate
extension TabBarController: StartViewControllerDelegate {
    func startViewDidRequestNavigate(to url: URL) {
        // Close Start tab and open file browser to the requested URL
        if currentTabIndex < tabs.count, tabs[currentTabIndex] is StartViewController {
            // Replace Start tab with file browser
            closeTab(at: currentTabIndex)
        }

        // Add new tab with the requested location
        addNewTab()

        // Navigate to the URL (need to access SplitPaneViewController)
        if let splitPane = tabs[currentTabIndex] as? SplitPaneViewController {
            splitPane.navigateToURL(url)
        }
    }

    func startViewDidRequestOpenSettings() {
        // Open settings tab
        openSettingsTab()
    }
}