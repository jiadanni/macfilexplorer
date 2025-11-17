import Cocoa

enum ViewMode: String, CaseIterable {
    case list = "List"
    case icons = "Icons"
    case columns = "Columns"
    case windowsList = "List (Win)"
}

protocol ToolbarDelegate: AnyObject {
    func toolbarDidRequestBack()
    func toolbarDidRequestForward()
    func toolbarDidRequestNavigate(to url: URL)
    func toolbarDidChangeSortColumn(_ column: String, ascending: Bool)
    func toolbarDidRequestNavigateToHistoryIndex(_ index: Int)
    func toolbarDidRequestNewFolder()
    func toolbarDidToggleHiddenFiles(show: Bool)
    func toolbarDidChangeViewMode(_ viewMode: ViewMode)
    func toolbarDidRequestSplitVertically()
    func toolbarDidRequestSplitHorizontally()
    func toolbarDidRequestClosePane()
    func toolbarDidSearchTextChange(_ searchText: String)
    func toolbarDidTogglePreviewPane()
}

class ToolbarViewController: NSViewController {

    weak var delegate: ToolbarDelegate?

    private var backButton: NSButton!
    private var forwardButton: NSButton!
    private var breadcrumbStackView: NSStackView!
    private var breadcrumbScrollView: NSScrollView!
    private var sortButton: NSPopUpButton!
    private var listModeButton: NSButton!
    private var iconsModeButton: NSButton!
    private var columnsModeButton: NSButton!
    private var windowsListModeButton: NSButton!
    private var hiddenFilesButton: NSButton!
    private var splitVerticalButton: NSButton!
    private var splitHorizontalButton: NSButton!
    private var newFolderButton: NSButton!
    private var closePaneButton: NSButton!
    private var searchField: NSSearchField!
    private var previewPaneButton: NSButton!

    private var currentURL: URL?
    private var canGoBack: Bool = false
    private var canGoForward: Bool = false
    private var navigationHistory: [URL] = []
    private var currentHistoryIndex: Int = -1
    private var showingHiddenFiles: Bool = false

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 40))
        setupUI()
        // Observe preview pane visibility changes to update toggle button state
        NotificationCenter.default.addObserver(self, selector: #selector(handlePreviewPaneToggled(_:)), name: .previewPaneToggled, object: nil)
        // Initial state update based on persisted preference
        let initiallyShowingPreview = UserDefaults.standard.bool(forKey: UserDefaults.Keys.showPreviewPane.rawValue)
        updatePreviewPaneDisplay(showing: initiallyShowingPreview)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .previewPaneToggled, object: nil)
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Load toolbar visibility settings from UserDefaults
        let showBackForward = UserDefaults.standard.object(forKey: UserDefaults.Keys.showBackForwardButtons.rawValue) as? Bool ?? true
        let showViewMode = UserDefaults.standard.object(forKey: UserDefaults.Keys.showViewModeButton.rawValue) as? Bool ?? true
        let showHiddenFiles = UserDefaults.standard.object(forKey: UserDefaults.Keys.showHiddenFilesButton.rawValue) as? Bool ?? true
        let showSplit = UserDefaults.standard.object(forKey: UserDefaults.Keys.showSplitButtons.rawValue) as? Bool ?? true
        let showPreviewPane = UserDefaults.standard.object(forKey: UserDefaults.Keys.showPreviewPaneButton.rawValue) as? Bool ?? true
        let showNewFolder = UserDefaults.standard.object(forKey: UserDefaults.Keys.showNewFolderButton.rawValue) as? Bool ?? true
        let showSort = UserDefaults.standard.object(forKey: UserDefaults.Keys.showSortButton.rawValue) as? Bool ?? true

        // Back button
        backButton = NSButton()
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.bezelStyle = .texturedRounded
        backButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")
        backButton.target = self
        backButton.action = #selector(backButtonClicked(_:))
        backButton.isEnabled = false
        backButton.sendAction(on: [.leftMouseDown, .rightMouseDown])
        backButton.toolTip = "Back (⌘[)"
        backButton.isHidden = !showBackForward
        view.addSubview(backButton)

        // Forward button
        forwardButton = NSButton()
        forwardButton.translatesAutoresizingMaskIntoConstraints = false
        forwardButton.bezelStyle = .texturedRounded
        forwardButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward")
        forwardButton.target = self
        forwardButton.action = #selector(forwardButtonClicked(_:))
        forwardButton.isEnabled = false
        forwardButton.sendAction(on: [.leftMouseDown, .rightMouseDown])
        forwardButton.toolTip = "Forward (⌘])"
        forwardButton.isHidden = !showBackForward
        view.addSubview(forwardButton)

        // Breadcrumb scroll view (for address bar)
        breadcrumbScrollView = NSScrollView()
        breadcrumbScrollView.translatesAutoresizingMaskIntoConstraints = false
        breadcrumbScrollView.hasHorizontalScroller = false
        breadcrumbScrollView.hasVerticalScroller = false
        breadcrumbScrollView.borderType = .bezelBorder
        breadcrumbScrollView.drawsBackground = true
        breadcrumbScrollView.backgroundColor = NSColor.textBackgroundColor
        view.addSubview(breadcrumbScrollView)

        // Breadcrumb stack view
        breadcrumbStackView = NSStackView()
        breadcrumbStackView.orientation = .horizontal
        breadcrumbStackView.spacing = 0
        breadcrumbStackView.alignment = .centerY
        breadcrumbStackView.translatesAutoresizingMaskIntoConstraints = false
        breadcrumbScrollView.documentView = breadcrumbStackView

        // View Mode buttons
        listModeButton = NSButton()
        listModeButton.translatesAutoresizingMaskIntoConstraints = false
        listModeButton.bezelStyle = .texturedRounded
        listModeButton.image = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "List View")
        listModeButton.target = self
        listModeButton.action = #selector(listViewModeClicked(_:))
        listModeButton.toolTip = "List View (⌘1)"
        listModeButton.isHidden = !showViewMode
        view.addSubview(listModeButton)

        iconsModeButton = NSButton()
        iconsModeButton.translatesAutoresizingMaskIntoConstraints = false
        iconsModeButton.bezelStyle = .texturedRounded
        iconsModeButton.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Icons View")
        iconsModeButton.target = self
        iconsModeButton.action = #selector(iconsViewModeClicked(_:))
        iconsModeButton.toolTip = "Icons View (⌘2)"
        iconsModeButton.isHidden = !showViewMode
        view.addSubview(iconsModeButton)

        columnsModeButton = NSButton()
        columnsModeButton.translatesAutoresizingMaskIntoConstraints = false
        columnsModeButton.bezelStyle = .texturedRounded
        columnsModeButton.image = NSImage(systemSymbolName: "sidebar.leading", accessibilityDescription: "Columns View")
        columnsModeButton.target = self
        columnsModeButton.action = #selector(columnsViewModeClicked(_:))
        columnsModeButton.toolTip = "Columns View (⌘3)"
        columnsModeButton.isHidden = !showViewMode
        view.addSubview(columnsModeButton)

        windowsListModeButton = NSButton()
        windowsListModeButton.translatesAutoresizingMaskIntoConstraints = false
        windowsListModeButton.bezelStyle = .texturedRounded
        windowsListModeButton.image = NSImage(systemSymbolName: "list.bullet.rectangle", accessibilityDescription: "Windows List View")
        windowsListModeButton.target = self
        windowsListModeButton.action = #selector(windowsListViewModeClicked(_:))
        windowsListModeButton.toolTip = "Windows List View (⌘4)"
        windowsListModeButton.isHidden = !showViewMode
        view.addSubview(windowsListModeButton)
        
        // Hidden Files toggle button
        hiddenFilesButton = NSButton()
        hiddenFilesButton.translatesAutoresizingMaskIntoConstraints = false
        hiddenFilesButton.bezelStyle = .texturedRounded
        hiddenFilesButton.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "Show Hidden Files")
        hiddenFilesButton.target = self
        hiddenFilesButton.action = #selector(toggleHiddenFiles(_:))
        hiddenFilesButton.toolTip = "Show Hidden Files (⇧⌘.)"
        hiddenFilesButton.isHidden = !showHiddenFiles
        view.addSubview(hiddenFilesButton)
        
        // Split Vertical button
        splitVerticalButton = NSButton()
        splitVerticalButton.translatesAutoresizingMaskIntoConstraints = false
        splitVerticalButton.bezelStyle = .texturedRounded
        splitVerticalButton.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Split Vertically")
        splitVerticalButton.target = self
        splitVerticalButton.action = #selector(splitVerticallyClicked(_:))
        splitVerticalButton.toolTip = "Split View Vertically"
        splitVerticalButton.isHidden = !showSplit
        view.addSubview(splitVerticalButton)
        
        // Split Horizontal button
        splitHorizontalButton = NSButton()
        splitHorizontalButton.translatesAutoresizingMaskIntoConstraints = false
        splitHorizontalButton.bezelStyle = .texturedRounded
        splitHorizontalButton.image = NSImage(systemSymbolName: "rectangle.split.1x2", accessibilityDescription: "Split Horizontally")
        splitHorizontalButton.target = self
        splitHorizontalButton.action = #selector(splitHorizontallyClicked(_:))
        splitHorizontalButton.toolTip = "Split View Horizontally"
        splitHorizontalButton.isHidden = !showSplit
        view.addSubview(splitHorizontalButton)

        // Preview Pane button
        previewPaneButton = NSButton()
        previewPaneButton.translatesAutoresizingMaskIntoConstraints = false
        previewPaneButton.bezelStyle = .texturedRounded
        previewPaneButton.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: "Toggle Preview Pane")
        previewPaneButton.target = self
        previewPaneButton.action = #selector(togglePreviewPaneClicked(_:))
        previewPaneButton.toolTip = "Show Preview Pane"
        previewPaneButton.isHidden = !showPreviewPane
        view.addSubview(previewPaneButton)

        // Sort button
        sortButton = NSPopUpButton()
        sortButton.translatesAutoresizingMaskIntoConstraints = false
        sortButton.bezelStyle = .texturedRounded
        sortButton.pullsDown = true
        sortButton.addItem(withTitle: "Sort")
        (sortButton.item(at: 0) as NSMenuItem?)?.image = NSImage(systemSymbolName: "arrow.up.arrow.down", accessibilityDescription: "Sort")

        sortButton.menu?.addItem(withTitle: "Name ↑", action: #selector(sortByNameAscending(_:)), keyEquivalent: "")
        sortButton.menu?.addItem(withTitle: "Name ↓", action: #selector(sortByNameDescending(_:)), keyEquivalent: "")
        sortButton.menu?.addItem(NSMenuItem.separator())
        sortButton.menu?.addItem(withTitle: "Date Modified ↑", action: #selector(sortByDateAscending(_:)), keyEquivalent: "")
        sortButton.menu?.addItem(withTitle: "Date Modified ↓", action: #selector(sortByDateDescending(_:)), keyEquivalent: "")
        sortButton.menu?.addItem(NSMenuItem.separator())
        sortButton.menu?.addItem(withTitle: "Size ↑", action: #selector(sortBySizeAscending(_:)), keyEquivalent: "")
        sortButton.menu?.addItem(withTitle: "Size ↓", action: #selector(sortBySizeDescending(_:)), keyEquivalent: "")
        sortButton.menu?.addItem(NSMenuItem.separator())
        sortButton.menu?.addItem(withTitle: "Type ↑", action: #selector(sortByTypeAscending(_:)), keyEquivalent: "")
        sortButton.menu?.addItem(withTitle: "Type ↓", action: #selector(sortByTypeDescending(_:)), keyEquivalent: "")

        sortButton.menu?.items.forEach { $0.target = self }
        sortButton.toolTip = "Sort Options"
        sortButton.isHidden = !showSort
        view.addSubview(sortButton)

        // New Folder button
        newFolderButton = NSButton()
        newFolderButton.translatesAutoresizingMaskIntoConstraints = false
        newFolderButton.bezelStyle = .texturedRounded
        newFolderButton.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: "New Folder")
        newFolderButton.target = self
        newFolderButton.action = #selector(newFolderButtonClicked(_:))
        newFolderButton.toolTip = "New Folder (⇧⌘N)"
        newFolderButton.isHidden = !showNewFolder
        view.addSubview(newFolderButton)

        // Close Pane button
        closePaneButton = NSButton()
        closePaneButton.translatesAutoresizingMaskIntoConstraints = false
        closePaneButton.bezelStyle = .texturedRounded
        closePaneButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close Pane")
        closePaneButton.target = self
        closePaneButton.action = #selector(closePaneButtonClicked(_:))
        closePaneButton.toolTip = "Close Pane (⌘W)"
        closePaneButton.isHidden = true // Hidden by default, shown when there are multiple panes
        view.addSubview(closePaneButton)

        // Search Field
        searchField = NSSearchField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search"
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.sendsWholeSearchString = false
        searchField.sendsSearchStringImmediately = true
        searchField.toolTip = "Search (⌘F)"
        view.addSubview(searchField)

        // Layout constraints
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            backButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 30),
            backButton.heightAnchor.constraint(equalToConstant: 26),

            forwardButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 4),
            forwardButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            forwardButton.widthAnchor.constraint(equalToConstant: 30),
            forwardButton.heightAnchor.constraint(equalToConstant: 26),

            breadcrumbScrollView.leadingAnchor.constraint(equalTo: forwardButton.trailingAnchor, constant: 8),
            breadcrumbScrollView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            breadcrumbScrollView.heightAnchor.constraint(equalToConstant: 26),
            breadcrumbScrollView.widthAnchor.constraint(lessThanOrEqualToConstant: 600),
            breadcrumbScrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            breadcrumbScrollView.trailingAnchor.constraint(lessThanOrEqualTo: listModeButton.leadingAnchor, constant: -8),

            breadcrumbStackView.leadingAnchor.constraint(equalTo: breadcrumbScrollView.leadingAnchor),
            breadcrumbStackView.topAnchor.constraint(equalTo: breadcrumbScrollView.topAnchor),
            breadcrumbStackView.bottomAnchor.constraint(equalTo: breadcrumbScrollView.bottomAnchor),

            listModeButton.trailingAnchor.constraint(equalTo: iconsModeButton.leadingAnchor, constant: -4),
            listModeButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            listModeButton.widthAnchor.constraint(equalToConstant: 30),
            listModeButton.heightAnchor.constraint(equalToConstant: 26),

            iconsModeButton.trailingAnchor.constraint(equalTo: columnsModeButton.leadingAnchor, constant: -4),
            iconsModeButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            iconsModeButton.widthAnchor.constraint(equalToConstant: 30),
            iconsModeButton.heightAnchor.constraint(equalToConstant: 26),

            columnsModeButton.trailingAnchor.constraint(equalTo: windowsListModeButton.leadingAnchor, constant: -4),
            columnsModeButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            columnsModeButton.widthAnchor.constraint(equalToConstant: 30),
            columnsModeButton.heightAnchor.constraint(equalToConstant: 26),

            windowsListModeButton.trailingAnchor.constraint(equalTo: hiddenFilesButton.leadingAnchor, constant: -8),
            windowsListModeButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            windowsListModeButton.widthAnchor.constraint(equalToConstant: 30),
            windowsListModeButton.heightAnchor.constraint(equalToConstant: 26),
            
            hiddenFilesButton.trailingAnchor.constraint(equalTo: splitVerticalButton.leadingAnchor, constant: -4),
            hiddenFilesButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            hiddenFilesButton.widthAnchor.constraint(equalToConstant: 30),
            hiddenFilesButton.heightAnchor.constraint(equalToConstant: 26),
            
            splitVerticalButton.trailingAnchor.constraint(equalTo: splitHorizontalButton.leadingAnchor, constant: -4),
            splitVerticalButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            splitVerticalButton.widthAnchor.constraint(equalToConstant: 30),
            splitVerticalButton.heightAnchor.constraint(equalToConstant: 26),
            
            splitHorizontalButton.trailingAnchor.constraint(equalTo: previewPaneButton.leadingAnchor, constant: -4),
            splitHorizontalButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            splitHorizontalButton.widthAnchor.constraint(equalToConstant: 30),
            splitHorizontalButton.heightAnchor.constraint(equalToConstant: 26),

            previewPaneButton.trailingAnchor.constraint(equalTo: newFolderButton.leadingAnchor, constant: -8),
            previewPaneButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            previewPaneButton.widthAnchor.constraint(equalToConstant: 30),
            previewPaneButton.heightAnchor.constraint(equalToConstant: 26),

            newFolderButton.trailingAnchor.constraint(equalTo: sortButton.leadingAnchor, constant: -8),
            newFolderButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            newFolderButton.widthAnchor.constraint(equalToConstant: 30),
            newFolderButton.heightAnchor.constraint(equalToConstant: 26),

            sortButton.trailingAnchor.constraint(equalTo: searchField.leadingAnchor, constant: -8),
            sortButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            sortButton.widthAnchor.constraint(equalToConstant: 44),
            sortButton.heightAnchor.constraint(equalToConstant: 26),

            searchField.trailingAnchor.constraint(equalTo: closePaneButton.leadingAnchor, constant: -8),
            searchField.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            searchField.widthAnchor.constraint(equalToConstant: 150),
            searchField.heightAnchor.constraint(equalToConstant: 22),

            closePaneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            closePaneButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            closePaneButton.widthAnchor.constraint(equalToConstant: 30),
            closePaneButton.heightAnchor.constraint(equalToConstant: 26)
        ])
    }

    // MARK: - Public Methods

    func updatePath(_ url: URL, canGoBack: Bool, canGoForward: Bool, history: [URL] = [], currentIndex: Int = -1) {
        self.currentURL = url
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.navigationHistory = history
        self.currentHistoryIndex = currentIndex

        backButton.isEnabled = canGoBack
        forwardButton.isEnabled = canGoForward

        updateBreadcrumbs(for: url)
    }

    func updateViewModeDisplay(for viewMode: ViewMode) {
        listModeButton.state = (viewMode == .list) ? .on : .off
        iconsModeButton.state = (viewMode == .icons) ? .on : .off
        columnsModeButton.state = (viewMode == .columns) ? .on : .off
        windowsListModeButton.state = (viewMode == .windowsList) ? .on : .off
    }
    
    func updateHiddenFilesDisplay(showing: Bool) {
        showingHiddenFiles = showing
        if showing {
            hiddenFilesButton.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Hide Hidden Files")
            hiddenFilesButton.toolTip = "Hide Hidden Files (⇧⌘.)"
        } else {
            hiddenFilesButton.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "Show Hidden Files")
            hiddenFilesButton.toolTip = "Show Hidden Files (⇧⌘.)"
        }
    }

    func updateSortDisplay(column: String, ascending: Bool) {
        var title = ""
        var image: NSImage?

        switch column {
        case "NameColumn":
            title = "Name"
        case "DateModifiedColumn":
            title = "Date Modified"
        case "SizeColumn":
            title = "Size"
        case "TypeColumn":
            title = "Type"
        case "DateCreatedColumn":
            title = "Date Created"
        default:
            title = "Sort"
        }

        if ascending {
            title += " ↑"
            image = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: "Ascending")
        } else {
            title += " ↓"
            image = NSImage(systemSymbolName: "arrow.down", accessibilityDescription: "Descending")
        }

        sortButton.title = title
        sortButton.image = image
    }

    func updateSplitButtonsState(canAddMore: Bool) {
        splitVerticalButton.isEnabled = canAddMore
        splitHorizontalButton.isEnabled = canAddMore

        if !canAddMore {
            let maxPanes = UserDefaults.standard.integer(forKey: UserDefaults.Keys.maximumPanes.rawValue)
            let limit = maxPanes > 0 ? maxPanes : 2
            splitVerticalButton.toolTip = "Maximum panes reached (\(limit)). Increase in Settings > Advanced."
            splitHorizontalButton.toolTip = "Maximum panes reached (\(limit)). Increase in Settings > Advanced."
        } else {
            splitVerticalButton.toolTip = "Split View Vertically"
            splitHorizontalButton.toolTip = "Split View Horizontally"
        }
    }

    func setClosePaneButtonVisible(_ visible: Bool) {
        closePaneButton.isHidden = !visible
    }

    private func updatePreviewPaneDisplay(showing: Bool) {
        NSAnimationContext.runAnimationGroup { _ in
            NSAnimationContext.current.duration = 0.15
            if showing {
                previewPaneButton.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: "Hide Preview Pane")
                previewPaneButton.contentTintColor = .systemBlue
                previewPaneButton.toolTip = "Hide Preview Pane"
            } else {
                previewPaneButton.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: "Show Preview Pane")
                previewPaneButton.contentTintColor = nil
                previewPaneButton.toolTip = "Show Preview Pane"
            }
        }
    }

    private func updateBreadcrumbs(for url: URL) {
        // Clear existing breadcrumbs
        breadcrumbStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let pathComponents = url.pathComponents
        var displayComponents: [String] = []
        var breadcrumbURLs: [URL] = []

        if pathComponents.count == 1 && pathComponents[0] == "/" {
            // Handle root path "/"
            displayComponents.append("/")
            breadcrumbURLs.append(URL(fileURLWithPath: "/"))
        } else if pathComponents.count > 1 {
            // Merge "/" with the first directory component
            let firstCombinedComponent = pathComponents[0] + pathComponents[1] // e.g., "/Applications"
            displayComponents.append(firstCombinedComponent)
            breadcrumbURLs.append(URL(fileURLWithPath: pathComponents[0]).appendingPathComponent(pathComponents[1]))

            // Add remaining components
            var currentPathURL = breadcrumbURLs.last!
            for i in 2..<pathComponents.count {
                let component = pathComponents[i]
                displayComponents.append(component)
                currentPathURL.appendPathComponent(component)
                breadcrumbURLs.append(currentPathURL)
            }
        }

        // Create breadcrumb buttons
        for (index, component) in displayComponents.enumerated() {
            // Add separator (except before first item)
            if index > 0 {
                let separator = NSTextField(labelWithString: " ▸ ")
                separator.textColor = .secondaryLabelColor
                separator.font = NSFont.systemFont(ofSize: 12)
                breadcrumbStackView.addArrangedSubview(separator)
            }

            // Create breadcrumb button
            let button = NSButton()
            let originalComponent = component
            // Truncate long path segments for display, keep tooltip full
            var displayTitle = originalComponent
            if originalComponent.count > 22 {
                let prefix = originalComponent.prefix(10)
                let suffix = originalComponent.suffix(8)
                displayTitle = String(prefix) + "…" + String(suffix)
            }
            button.title = displayTitle
            button.bezelStyle = .roundRect
            button.isBordered = false
            button.font = NSFont.systemFont(ofSize: 12)
            button.target = self
            button.action = #selector(breadcrumbClicked(_:))
            button.toolTip = originalComponent
            button.setContentHuggingPriority(.defaultLow, for: .horizontal)
            button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            button.lineBreakMode = .byTruncatingMiddle
            
            // Set the URL for this component
            if index < breadcrumbURLs.count {
                button.identifier = NSUserInterfaceItemIdentifier(breadcrumbURLs[index].path)
            }

            breadcrumbStackView.addArrangedSubview(button)
        }
    }

    // MARK: - Actions

    @objc private func backButtonClicked(_ sender: NSButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseDown {
            showBackHistory(for: sender)
        } else {
            delegate?.toolbarDidRequestBack()
        }
    }

    @objc private func forwardButtonClicked(_ sender: NSButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseDown {
            showForwardHistory(for: sender)
        } else {
            delegate?.toolbarDidRequestForward()
        }
    }

    private func showBackHistory(for button: NSButton) {
        guard currentHistoryIndex > 0 else { return }

        let menu = NSMenu()

        // Show items from current position backwards
        for i in stride(from: currentHistoryIndex - 1, through: 0, by: -1) {
            let url = navigationHistory[i]
            let displayName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
            let menuItem = NSMenuItem(title: displayName, action: #selector(historyItemClicked(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.tag = i
            menuItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
            menu.addItem(menuItem)
        }

        // Show menu below button
        let location = NSPoint(x: 0, y: button.bounds.height)
        menu.popUp(positioning: nil, at: location, in: button)
    }

    private func showForwardHistory(for button: NSButton) {
        guard currentHistoryIndex < navigationHistory.count - 1 else { return }

        let menu = NSMenu()

        // Show items from current position forwards
        for i in (currentHistoryIndex + 1)..<navigationHistory.count {
            let url = navigationHistory[i]
            let displayName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
            let menuItem = NSMenuItem(title: displayName, action: #selector(historyItemClicked(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.tag = i
            menuItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
            menu.addItem(menuItem)
        }

        // Show menu below button
        let location = NSPoint(x: 0, y: button.bounds.height)
        menu.popUp(positioning: nil, at: location, in: button)
    }

    @objc private func historyItemClicked(_ sender: NSMenuItem) {
        let index = sender.tag
        delegate?.toolbarDidRequestNavigateToHistoryIndex(index)
    }

    @objc private func breadcrumbClicked(_ sender: NSButton) {
        guard let pathString = sender.identifier?.rawValue else { return }
        let url = URL(fileURLWithPath: pathString)
        delegate?.toolbarDidRequestNavigate(to: url)
    }

    @objc private func sortByNameAscending(_ sender: Any) {
        delegate?.toolbarDidChangeSortColumn("NameColumn", ascending: true)
    }

    @objc private func sortByNameDescending(_ sender: Any) {
        delegate?.toolbarDidChangeSortColumn("NameColumn", ascending: false)
    }

    @objc private func sortByDateAscending(_ sender: Any) {
        delegate?.toolbarDidChangeSortColumn("DateModifiedColumn", ascending: true)
    }

    @objc private func sortByDateDescending(_ sender: Any) {
        delegate?.toolbarDidChangeSortColumn("DateModifiedColumn", ascending: false)
    }

    @objc private func sortBySizeAscending(_ sender: Any) {
        delegate?.toolbarDidChangeSortColumn("SizeColumn", ascending: true)
    }

    @objc private func sortBySizeDescending(_ sender: Any) {
        delegate?.toolbarDidChangeSortColumn("SizeColumn", ascending: false)
    }

    @objc private func sortByTypeAscending(_ sender: Any) {
        delegate?.toolbarDidChangeSortColumn("TypeColumn", ascending: true)
    }

    @objc private func sortByTypeDescending(_ sender: Any) {
        delegate?.toolbarDidChangeSortColumn("TypeColumn", ascending: false)
    }

    @objc private func newFolderButtonClicked(_ sender: NSButton) {
        delegate?.toolbarDidRequestNewFolder()
    }

    @objc private func toggleHiddenFiles(_ sender: Any) {
        showingHiddenFiles = !showingHiddenFiles
        delegate?.toolbarDidToggleHiddenFiles(show: showingHiddenFiles)
        updateHiddenFilesDisplay(showing: showingHiddenFiles)
    }

    @objc private func listViewModeClicked(_ sender: Any) {
        delegate?.toolbarDidChangeViewMode(.list)
    }

    @objc private func iconsViewModeClicked(_ sender: Any) {
        delegate?.toolbarDidChangeViewMode(.icons)
    }

    @objc private func columnsViewModeClicked(_ sender: Any) {
        delegate?.toolbarDidChangeViewMode(.columns)
    }

    @objc private func windowsListViewModeClicked(_ sender: Any) {
        delegate?.toolbarDidChangeViewMode(.windowsList)
    }

    @objc private func splitVerticallyClicked(_ sender: Any) {
        delegate?.toolbarDidRequestSplitVertically()
    }

    @objc private func splitHorizontallyClicked(_ sender: Any) {
        delegate?.toolbarDidRequestSplitHorizontally()
    }

    @objc private func togglePreviewPaneClicked(_ sender: Any) {
        delegate?.toolbarDidTogglePreviewPane()
    }

    @objc private func closePaneButtonClicked(_ sender: Any) {
        delegate?.toolbarDidRequestClosePane()
    }

    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        delegate?.toolbarDidSearchTextChange(sender.stringValue)
    }
}

// MARK: - Notification Handling
extension ToolbarViewController {
    @objc private func handlePreviewPaneToggled(_ notification: Notification) {
        // Determine current visibility from UserDefaults (since notification carries no userInfo)
        let showing = UserDefaults.standard.bool(forKey: UserDefaults.Keys.showPreviewPane.rawValue)
        updatePreviewPaneDisplay(showing: showing)
    }
}
