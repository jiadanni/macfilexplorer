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
    private var accentColorObserver: NSObjectProtocol?
    private var zoomObserver: NSObjectProtocol?
    
    private func owningSplitViewController() -> SplitViewController? {
        var controller: NSViewController? = parent
        while let current = controller {
            if let splitVC = current as? SplitViewController {
                return splitVC
            }
            controller = current.parent
        }
        return nil
    }

    override func loadView() {
        view = NSView()
        setupUI()
        
        // Listen for accent color changes
        accentColorObserver = NotificationCenter.default.addObserver(forName: .accentColorDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updateTabButtons()
        }
        
        zoomObserver = NotificationCenter.default.addObserver(forName: .zoomDidChangeNotification, object: nil, queue: .main) { [weak self] notification in
            if let zoomValue = notification.object as? Double {
                self?.updateZoomLevel(to: zoomValue)
            }
        }
    }
    
    deinit {
        if let accentColorObserver {
            NotificationCenter.default.removeObserver(accentColorObserver)
        }
        if let zoomObserver {
            NotificationCenter.default.removeObserver(zoomObserver)
        }
    }

    static let stripHeight: CGFloat = 32
    private static let tabHeight: CGFloat = 26

    private func setupUI() {
        // Tab strip: one step darker than the content; the selected tab is
        // raised in the content color so it reads as attached to the pane below.
        let strip = ChromeSurfaceView(fillColor: AppDesignSystem.Chrome.tabStripBackground)
        strip.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainer = strip

        let separator = HairlineView()
        tabBarContainer.addSubview(separator)

        view.addSubview(tabBarContainer)

        tabButtonsStackView = NSStackView()
        tabButtonsStackView.translatesAutoresizingMaskIntoConstraints = false
        tabButtonsStackView.orientation = .horizontal
        tabButtonsStackView.spacing = 2
        tabButtonsStackView.alignment = .bottom
        tabBarContainer.addSubview(tabButtonsStackView)

        let newTabButton = ToolbarIconButton(symbolName: "plus", accessibilityDescription: L10n.text("New Tab"))
        newTabButton.toolTip = L10n.text("New Tab")
        newTabButton.target = self
        newTabButton.action = #selector(newTabButtonClicked(_:))
        tabBarContainer.addSubview(newTabButton)

        tabView = NSTabView()
        tabView.tabViewType = .noTabsNoBorder
        tabView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabView)

        NSLayoutConstraint.activate([
            tabBarContainer.topAnchor.constraint(equalTo: view.topAnchor),
            tabBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBarContainer.heightAnchor.constraint(equalToConstant: Self.stripHeight),

            tabButtonsStackView.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor, constant: 8),
            tabButtonsStackView.bottomAnchor.constraint(equalTo: tabBarContainer.bottomAnchor),
            tabButtonsStackView.heightAnchor.constraint(equalToConstant: Self.tabHeight),

            newTabButton.leadingAnchor.constraint(equalTo: tabButtonsStackView.trailingAnchor, constant: 2),
            newTabButton.trailingAnchor.constraint(lessThanOrEqualTo: tabBarContainer.trailingAnchor, constant: -8),
            newTabButton.bottomAnchor.constraint(equalTo: tabBarContainer.bottomAnchor, constant: -1),
            newTabButton.widthAnchor.constraint(equalToConstant: 26),
            newTabButton.heightAnchor.constraint(equalToConstant: 24),

            separator.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: tabBarContainer.bottomAnchor),

            tabView.topAnchor.constraint(equalTo: tabBarContainer.bottomAnchor),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        // Keep the "+" button beside the last tab, but let tabs squeeze first when crowded.
        tabButtonsStackView.setClippingResistancePriority(.defaultLow, for: .horizontal)
    }

    /// Updates a tab title in place, keeping the selected/unselected styling.
    private func setTitle(_ title: String, forTabButtonAt index: Int) {
        guard let button = tabButtons.safe(at: index) else { return }
        let isSelected = index == currentTabIndex
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: isSelected ? .medium : .regular),
            .foregroundColor: isSelected ? NSColor.labelColor : NSColor.secondaryLabelColor
        ])
        button.setAccessibilityLabel("\(title) tab")
    }

    @objc private func newTabButtonClicked(_ sender: Any) {
        addNewTab()
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
        button.setAccessibilityRole(.button)
        button.setAccessibilityLabel("\(title) tab")
        button.target = self
        button.action = #selector(tabButtonClicked(_:))
        button.tag = index
        button.alignment = .left
        button.lineBreakMode = .byTruncatingTail
        button.translatesAutoresizingMaskIntoConstraints = false
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: isSelected ? .medium : .regular),
            .foregroundColor: isSelected ? NSColor.labelColor : NSColor.secondaryLabelColor
        ])
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        container.addSubview(button)

        // Make the entire container clickable, not just the title.
        let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(tabContainerClicked(_:)))
        clickRecognizer.buttonMask = 0x1 // left mouse button
        container.addGestureRecognizer(clickRecognizer)

        var constraints: [NSLayoutConstraint] = [
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: Self.tabHeight),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),
            container.widthAnchor.constraint(lessThanOrEqualToConstant: 220)
        ]

        if showClose {
            let closeButton = ToolbarIconButton(symbolName: "xmark", accessibilityDescription: "Close \(title) tab")
            closeButton.target = self
            closeButton.action = #selector(closeTabButtonClicked(_:))
            closeButton.tag = index
            closeButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
            container.addSubview(closeButton)
            tabCloseButtons.append(closeButton)
            constraints += [
                closeButton.leadingAnchor.constraint(equalTo: button.trailingAnchor, constant: 8),
                closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
                closeButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                closeButton.widthAnchor.constraint(equalToConstant: 18),
                closeButton.heightAnchor.constraint(equalToConstant: 18)
            ]
        } else {
            constraints.append(button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14))
        }
        NSLayoutConstraint.activate(constraints)

        tabButtons.append(button)
        // Tag the container with the index for hit-testing in the click handler
        container.identifier = NSUserInterfaceItemIdentifier("\(index)")
        return container
    }

    @objc private func tabContainerClicked(_ recognizer: NSClickGestureRecognizer) {
        guard let container = recognizer.view else { return }
        if let id = container.identifier?.rawValue, let index = Int(id) {
            if let button = tabButtons.safe(at: index) {
                tabButtonClicked(button)
            }
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
        guard let currentTabVC = tabs.safe(at: currentTabIndex) else { return }
        NotificationCenter.default.post(name: .tabDidChangeNotification, object: currentTabVC)
    }

    @objc private func tabButtonClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index < tabs.count else { return }

        currentTabIndex = index
        tabView.selectTabViewItem(at: index)
        updateTabButtons()

        // Update terminal to the new tab's directory
        if let splitVC = owningSplitViewController() {
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
        guard let currentTab = tabs.safe(at: currentTabIndex) else { return }
        if currentTab is StartViewController {
            return
        }
        closeTab(at: currentTabIndex)
    }

    private func closeTab(at index: Int) {
        guard index >= 0, index < tabs.count, tabs.count > 1 else { return }
        // Don't allow closing the Start tab
        guard let tab = tabs.safe(at: index) else { return }
        if tab is StartViewController {
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
        debugLog("TabBarController: navigateToLocation - Received URL: \(url.path)")
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
        debugLog("TabBarController: openInNewTab - Received URL: \(url.path)")
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
                setTitle("Settings", forTabButtonAt: currentTabIndex)
            }
        } else if currentTabIndex < tabs.count, tabs[currentTabIndex] is StorageAnalyzerTabViewController {
            if currentTabIndex < tabView.numberOfTabViewItems {
                let tabItem = tabView.tabViewItem(at: currentTabIndex)
                if tabItem.label != "Storage Analyzer" { tabItem.label = "Storage Analyzer" }
            }
            if currentTabIndex < tabButtons.count, tabButtons[currentTabIndex].title != "Storage Analyzer" {
                setTitle("Storage Analyzer", forTabButtonAt: currentTabIndex)
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
                setTitle(directoryName, forTabButtonAt: currentTabIndex)
            }
        }

        // Update window title to show current directory path
        view.window?.title = path

        // Notify parent to update terminal
        if let splitVC = owningSplitViewController() {
            splitVC.updateTerminalDirectory()
            // Also update the sidebar folder explorer to follow the active directory (respects user setting).
            let url = URL(fileURLWithPath: path)
            splitVC.updateSidebarSelection(url: url)
        }
    }

    func splitPaneOpenInNewTab(url: URL) {
        debugLog("TabBarController: splitPaneOpenInNewTab - Received URL: \(url.path)")
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
        // Forward to sidebar to add item to favorites
        if let splitVC = owningSplitViewController() {
            splitVC.sidebarViewController?.addFavorite(item: item)
        }
    }
    
    func splitPaneDidRequestOpenTerminal(at path: String) {
        if let splitVC = owningSplitViewController() {
            splitVC.showTerminal(at: path)
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
