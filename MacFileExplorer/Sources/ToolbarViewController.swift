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
    func toolbarDidRequestShowFilter()
    func toolbarDidRequestOpenInTerminal()
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
    private var filterButton: NSButton!
    private var previewPaneButton: NSButton!
    private var storageAnalyzerButton: NSButton!
    private var openTerminalButton: NSButton!

    private var currentURL: URL?
    private var canGoBack: Bool = false
    private var canGoForward: Bool = false
    private var navigationHistory: [URL] = []
    private var currentHistoryIndex: Int = -1
    private var showingHiddenFiles: Bool = false

    override func loadView() {
        // Increased height to accommodate two rows: buttons (40) + breadcrumb bar (30)
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 70))
        setupUI()
        // Observe preview pane visibility changes to update toggle button state
        NotificationCenter.default.addObserver(self, selector: #selector(handlePreviewPaneToggled(_:)), name: .previewPaneToggled, object: nil)
        // Observe accent color changes
        NotificationCenter.default.addObserver(self, selector: #selector(accentColorDidChange), name: .accentColorDidChangeNotification, object: nil)
        // Initial state update based on persisted preference
        let initiallyShowingPreview = UserDefaults.standard.bool(forKey: UserDefaults.Keys.showPreviewPane.rawValue)
        updatePreviewPaneDisplay(showing: initiallyShowingPreview)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .previewPaneToggled, object: nil)
        NotificationCenter.default.removeObserver(self, name: .accentColorDidChangeNotification, object: nil)
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Add subtle bottom border for visual separation
        let bottomBorder = NSView()
        bottomBorder.wantsLayer = true
        bottomBorder.layer?.backgroundColor = NSColor.separatorColor.cgColor
        bottomBorder.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBorder)

        // Load toolbar visibility settings from UserDefaults
        let showBackForward = UserDefaults.standard.object(forKey: UserDefaults.Keys.showBackForwardButtons.rawValue) as? Bool ?? true
        let showViewMode = UserDefaults.standard.object(forKey: UserDefaults.Keys.showViewModeButton.rawValue) as? Bool ?? true
        let showHiddenFiles = UserDefaults.standard.object(forKey: UserDefaults.Keys.showHiddenFilesButton.rawValue) as? Bool ?? true
        let showSplit = UserDefaults.standard.object(forKey: UserDefaults.Keys.showSplitButtons.rawValue) as? Bool ?? true
        let showPreviewPane = UserDefaults.standard.object(forKey: UserDefaults.Keys.showPreviewPaneButton.rawValue) as? Bool ?? true
        let showNewFolder = UserDefaults.standard.object(forKey: UserDefaults.Keys.showNewFolderButton.rawValue) as? Bool ?? true
        let showSort = UserDefaults.standard.object(forKey: UserDefaults.Keys.showSortButton.rawValue) as? Bool ?? true
        let showStorageAnalyzer = UserDefaults.standard.object(forKey: "showStorageAnalyzerButton") as? Bool ?? true
        let showOpenTerminal = UserDefaults.standard.object(forKey: UserDefaults.Keys.showOpenTerminalButton.rawValue) as? Bool ?? true

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

        // Breadcrumb scroll view (for address bar) - styled for Finder-like appearance
        breadcrumbScrollView = NSScrollView()
        breadcrumbScrollView.translatesAutoresizingMaskIntoConstraints = false
        breadcrumbScrollView.hasHorizontalScroller = false
        breadcrumbScrollView.hasVerticalScroller = false
        breadcrumbScrollView.borderType = .lineBorder
        breadcrumbScrollView.drawsBackground = true
        breadcrumbScrollView.backgroundColor = NSColor.controlBackgroundColor
        breadcrumbScrollView.wantsLayer = true
        breadcrumbScrollView.layer?.cornerRadius = 6
        breadcrumbScrollView.layer?.borderWidth = 0.5
        breadcrumbScrollView.layer?.borderColor = NSColor.separatorColor.cgColor
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

        // Storage Analyzer button
        storageAnalyzerButton = NSButton()
        storageAnalyzerButton.translatesAutoresizingMaskIntoConstraints = false
        storageAnalyzerButton.bezelStyle = .texturedRounded
        storageAnalyzerButton.image = NSImage(systemSymbolName: "chart.pie", accessibilityDescription: "Storage Analyzer")
        storageAnalyzerButton.target = self
        storageAnalyzerButton.action = #selector(storageAnalyzerButtonClicked(_:))
        storageAnalyzerButton.toolTip = "Storage Analyzer"
        storageAnalyzerButton.isHidden = !showStorageAnalyzer
        view.addSubview(storageAnalyzerButton)

        // Open in Terminal button
        openTerminalButton = NSButton()
        openTerminalButton.translatesAutoresizingMaskIntoConstraints = false
        openTerminalButton.bezelStyle = .texturedRounded
        openTerminalButton.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Open in Terminal")
        openTerminalButton.target = self
        openTerminalButton.action = #selector(openTerminalButtonClicked(_:))
        openTerminalButton.toolTip = "Open in Terminal"
        openTerminalButton.isHidden = !showOpenTerminal
        view.addSubview(openTerminalButton)

        // Sort button
        sortButton = AccentPopUpButton()
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
        
        // Filter button
        filterButton = NSButton()
        filterButton.translatesAutoresizingMaskIntoConstraints = false
        filterButton.bezelStyle = .texturedRounded
        filterButton.image = NSImage(systemSymbolName: "line.3.horizontal.decrease.circle", accessibilityDescription: "Filter")
        filterButton.target = self
        filterButton.action = #selector(filterButtonClicked(_:))
        filterButton.toolTip = "Filter Files"
        view.addSubview(filterButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Bottom border
            bottomBorder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBorder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBorder.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBorder.heightAnchor.constraint(equalToConstant: 1),

            // Top row: view mode and action buttons
            listModeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            listModeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            listModeButton.widthAnchor.constraint(equalToConstant: 30),
            listModeButton.heightAnchor.constraint(equalToConstant: 26),

            iconsModeButton.leadingAnchor.constraint(equalTo: listModeButton.trailingAnchor, constant: 4),
            iconsModeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            iconsModeButton.widthAnchor.constraint(equalToConstant: 30),
            iconsModeButton.heightAnchor.constraint(equalToConstant: 26),

            columnsModeButton.leadingAnchor.constraint(equalTo: iconsModeButton.trailingAnchor, constant: 4),
            columnsModeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            columnsModeButton.widthAnchor.constraint(equalToConstant: 30),
            columnsModeButton.heightAnchor.constraint(equalToConstant: 26),

            windowsListModeButton.leadingAnchor.constraint(equalTo: columnsModeButton.trailingAnchor, constant: 4),
            windowsListModeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            windowsListModeButton.widthAnchor.constraint(equalToConstant: 30),
            windowsListModeButton.heightAnchor.constraint(equalToConstant: 26),

            hiddenFilesButton.leadingAnchor.constraint(equalTo: windowsListModeButton.trailingAnchor, constant: 8),
            hiddenFilesButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            hiddenFilesButton.widthAnchor.constraint(equalToConstant: 30),
            hiddenFilesButton.heightAnchor.constraint(equalToConstant: 26),

            splitVerticalButton.leadingAnchor.constraint(equalTo: hiddenFilesButton.trailingAnchor, constant: 4),
            splitVerticalButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            splitVerticalButton.widthAnchor.constraint(equalToConstant: 30),
            splitVerticalButton.heightAnchor.constraint(equalToConstant: 26),

            splitHorizontalButton.leadingAnchor.constraint(equalTo: splitVerticalButton.trailingAnchor, constant: 4),
            splitHorizontalButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            splitHorizontalButton.widthAnchor.constraint(equalToConstant: 30),
            splitHorizontalButton.heightAnchor.constraint(equalToConstant: 26),

            previewPaneButton.leadingAnchor.constraint(equalTo: splitHorizontalButton.trailingAnchor, constant: 4),
            previewPaneButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            previewPaneButton.widthAnchor.constraint(equalToConstant: 30),
            previewPaneButton.heightAnchor.constraint(equalToConstant: 26),

            newFolderButton.leadingAnchor.constraint(equalTo: previewPaneButton.trailingAnchor, constant: 8),
            newFolderButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            newFolderButton.widthAnchor.constraint(equalToConstant: 30),
            newFolderButton.heightAnchor.constraint(equalToConstant: 26),

            storageAnalyzerButton.leadingAnchor.constraint(equalTo: newFolderButton.trailingAnchor, constant: 8),
            storageAnalyzerButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            storageAnalyzerButton.widthAnchor.constraint(equalToConstant: 30),
            storageAnalyzerButton.heightAnchor.constraint(equalToConstant: 26),

            openTerminalButton.leadingAnchor.constraint(equalTo: storageAnalyzerButton.trailingAnchor, constant: 8),
            openTerminalButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            openTerminalButton.widthAnchor.constraint(equalToConstant: 30),
            openTerminalButton.heightAnchor.constraint(equalToConstant: 26),

            sortButton.trailingAnchor.constraint(equalTo: searchField.leadingAnchor, constant: -8),
            sortButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            sortButton.widthAnchor.constraint(equalToConstant: 44),
            sortButton.heightAnchor.constraint(equalToConstant: 26),

            searchField.trailingAnchor.constraint(equalTo: filterButton.leadingAnchor, constant: -8),
            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: 9),
            searchField.widthAnchor.constraint(equalToConstant: 150),
            searchField.heightAnchor.constraint(equalToConstant: 22),

            filterButton.trailingAnchor.constraint(equalTo: closePaneButton.leadingAnchor, constant: -4),
            filterButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            filterButton.widthAnchor.constraint(equalToConstant: 30),
            filterButton.heightAnchor.constraint(equalToConstant: 26),

            closePaneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            closePaneButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            closePaneButton.widthAnchor.constraint(equalToConstant: 30),
            closePaneButton.heightAnchor.constraint(equalToConstant: 26),

            // Bottom row: back/forward buttons + breadcrumb/URL bar
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            backButton.topAnchor.constraint(equalTo: listModeButton.bottomAnchor, constant: 6),
            backButton.widthAnchor.constraint(equalToConstant: 30),
            backButton.heightAnchor.constraint(equalToConstant: 26),

            forwardButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 4),
            forwardButton.topAnchor.constraint(equalTo: listModeButton.bottomAnchor, constant: 6),
            forwardButton.widthAnchor.constraint(equalToConstant: 30),
            forwardButton.heightAnchor.constraint(equalToConstant: 26),

            breadcrumbScrollView.leadingAnchor.constraint(equalTo: forwardButton.trailingAnchor, constant: 8),
            breadcrumbScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            breadcrumbScrollView.topAnchor.constraint(equalTo: listModeButton.bottomAnchor, constant: 6),
            breadcrumbScrollView.heightAnchor.constraint(equalToConstant: 26),

            breadcrumbStackView.leadingAnchor.constraint(equalTo: breadcrumbScrollView.leadingAnchor),
            breadcrumbStackView.topAnchor.constraint(equalTo: breadcrumbScrollView.topAnchor),
            breadcrumbStackView.bottomAnchor.constraint(equalTo: breadcrumbScrollView.bottomAnchor)
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
        // Update button states
        listModeButton.state = (viewMode == .list) ? .on : .off
        iconsModeButton.state = (viewMode == .icons) ? .on : .off
        columnsModeButton.state = (viewMode == .columns) ? .on : .off
        windowsListModeButton.state = (viewMode == .windowsList) ? .on : .off

        // Add visual highlighting for active button using accent color
        let accentColor = NSColor.customAccentColor
        let buttons = [listModeButton, iconsModeButton, columnsModeButton, windowsListModeButton]

        for button in buttons {
            if button?.state == .on {
                // Active button: use accent color tint
                button?.contentTintColor = accentColor
                button?.layer?.backgroundColor = accentColor.withAlphaComponent(0.15).cgColor
                button?.layer?.cornerRadius = 4
                button?.wantsLayer = true
            } else {
                // Inactive button: default appearance
                button?.contentTintColor = nil
                button?.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
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

    func updatePreviewPaneDisplay(showing: Bool) {
        NSAnimationContext.runAnimationGroup { _ in
            NSAnimationContext.current.duration = 0.15
            if showing {
                previewPaneButton.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: "Hide Preview Pane")
                previewPaneButton.contentTintColor = NSColor.customAccentColor
                previewPaneButton.toolTip = "Hide Preview Pane"
            } else {
                previewPaneButton.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: "Show Preview Pane")
                previewPaneButton.contentTintColor = nil
                previewPaneButton.toolTip = "Show Preview Pane"
            }
        }
    }

    @objc private func accentColorDidChange() {
        // Update preview pane button color if it's active
        let isShowingPreview = UserDefaults.standard.bool(forKey: UserDefaults.Keys.showPreviewPane.rawValue)
        if isShowingPreview {
            previewPaneButton.contentTintColor = NSColor.customAccentColor
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

    @objc private func storageAnalyzerButtonClicked(_ sender: Any) {
        // Navigate up to find the TabBarController and open Storage Analyzer in a tab
        if let splitViewController = parent as? FileBrowserViewController,
           let splitPaneVC = splitViewController.parent as? SplitPaneViewController,
           let tabBarController = splitPaneVC.parent as? TabBarController {
            tabBarController.openStorageAnalyzerTab()
        }
    }

    @objc private func openTerminalButtonClicked(_ sender: Any) {
        delegate?.toolbarDidRequestOpenInTerminal()
    }

    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        delegate?.toolbarDidSearchTextChange(sender.stringValue)
    }
    
    @objc private func filterButtonClicked(_ sender: Any) {
        delegate?.toolbarDidRequestShowFilter()
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
