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
        
        NotificationCenter.default.addObserver(forName: .zoomDidChangeNotification, object: nil, queue: .main) { [weak self] notification in
            if let zoomValue = notification.object as? Double {
                self?.updateZoomLevel(to: zoomValue)
            }
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
        tabButtonsStackView.spacing = -1
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
        let container = TabButtonContainerView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let isSelected = index == currentTabIndex
        container.isSelected = isSelected

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

        // Make the entire container clickable by adding a click gesture recognizer.
        // This ensures the hit area isn't limited to the centered title button.
        let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(tabContainerClicked(_:)))
        clickRecognizer.buttonMask = 0x1 // left mouse button
        container.addGestureRecognizer(clickRecognizer)

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

        // Core constraints: center the title, vertically stretch, and set container size
        let centerConstraint = button.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        let topConstraint = button.topAnchor.constraint(equalTo: container.topAnchor)
        let bottomConstraint = button.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -1)
        let heightConstraint = container.heightAnchor.constraint(equalToConstant: 28)
        button.lineBreakMode = .byTruncatingTail
        let widthConstraint = container.widthAnchor.constraint(greaterThanOrEqualToConstant: 130)
        let maxWidthConstraint = container.widthAnchor.constraint(lessThanOrEqualToConstant: 250)

        var edgeConstraints: [NSLayoutConstraint] = []
        if let cb = closeButton {
            // Prefer centering; but ensure the title doesn't run into the close button or left edge.
            let trailingToClose = button.trailingAnchor.constraint(lessThanOrEqualTo: cb.leadingAnchor, constant: -4)
            let leadingToEdge = button.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 8)
            trailingToClose.priority = .defaultHigh
            leadingToEdge.priority = .defaultHigh
            edgeConstraints.append(contentsOf: [trailingToClose, leadingToEdge])
        } else {
            let leadingToEdge = button.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 8)
            let trailingToEdge = button.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8)
            leadingToEdge.priority = .defaultHigh
            trailingToEdge.priority = .defaultHigh
            edgeConstraints.append(contentsOf: [leadingToEdge, trailingToEdge])
        }

        // Activate with center constraints required and edge constraints lower priority so centering wins
        NSLayoutConstraint.activate([centerConstraint, topConstraint, bottomConstraint, heightConstraint, widthConstraint, maxWidthConstraint] + edgeConstraints)

        // Track for updates
        tabButtons.append(button)
        if let cb = closeButton { tabCloseButtons.append(cb) }
        // Tag the container with the index for hit-testing in the click handler
        container.identifier = NSUserInterfaceItemIdentifier("\(index)")
        return container
    }

    @objc private func tabContainerClicked(_ recognizer: NSClickGestureRecognizer) {
        guard let container = recognizer.view else { return }
        if let id = container.identifier?.rawValue, let index = Int(id) {
            tabButtonClicked(tabButtons[index])
        } else {
            // Fallback: try to find the button inside the container
            if let btn = container.subviews.compactMap({ $0 as? NSButton }).first, btn.tag < tabs.count {
                tabButtonClicked(btn)
            }
        }
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

    private func postTabChangeNotification() {
        guard currentTabIndex < tabs.count else { return }
        let currentTabVC = tabs[currentTabIndex]
        NotificationCenter.default.post(name: .tabDidChangeNotification, object: currentTabVC)
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
        postTabChangeNotification()
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
        postTabChangeNotification()
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
        postTabChangeNotification()
    }

    func showStartTab() {
        // Check if Start tab already exists
        for (index, tab) in tabs.enumerated() {
            if tab is StartViewController {
                tabView.selectTabViewItem(at: index)
                currentTabIndex = index
                postTabChangeNotification()
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
        postTabChangeNotification()
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
            postTabChangeNotification()
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
        postTabChangeNotification()
    }

    // MARK: - Storage Analyzer Tab

    func openStorageAnalyzerTab() {
        // If storage analyzer tab already exists, select it
        if let existingIndex = tabs.firstIndex(where: { $0 is StorageAnalyzerTabViewController }) {
            tabView.selectTabViewItem(at: existingIndex)
            currentTabIndex = existingIndex
            updateTabButtons()
            postTabChangeNotification()
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
        postTabChangeNotification()
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
        postTabChangeNotification()
    }

    func startViewDidRequestOpenSettings() {
        // Open settings tab
        openSettingsTab()
    }
}