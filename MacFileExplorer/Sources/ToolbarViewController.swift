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

class ToolbarViewController: NSViewController, NSSearchFieldDelegate {

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
    private var searchButton: NSButton!
    private var isSearchFieldVisible = false
    private var leftButtonsStackView: NSStackView!
    private var overflowButton: NSButton!
    private var overflowMenu: NSMenu!
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
        // Increased height to accommodate two rows: buttons (40) + breadcrumb bar (30) + extra padding
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 84))
        setupUI()
        // Observe preview pane visibility changes to update toggle button state
        NotificationCenter.default.addObserver(self, selector: #selector(handlePreviewPaneToggled(_:)), name: .previewPaneToggled, object: nil)
        // Observe toolbar settings changes so visibility toggles update live
        NotificationCenter.default.addObserver(self, selector: #selector(handleToolbarSettingsChanged(_:)), name: .toolbarSettingsDidChangeNotification, object: nil)
        // Observe accent color changes
        NotificationCenter.default.addObserver(self, selector: #selector(accentColorDidChange), name: .accentColorDidChangeNotification, object: nil)
        // Initial state update based on persisted preference
        let initiallyShowingPreview = UserDefaults.standard.bool(forKey: UserDefaults.Keys.showPreviewPane.rawValue)
        updatePreviewPaneDisplay(showing: initiallyShowingPreview)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .previewPaneToggled, object: nil)
        NotificationCenter.default.removeObserver(self, name: .accentColorDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .toolbarSettingsDidChangeNotification, object: nil)
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
        backButton.toolTip = L10n.text("Back (⌘[)")
        backButton.setAccessibilityRole(.button)
        backButton.setAccessibilityLabel(L10n.text("Back"))
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
        forwardButton.toolTip = L10n.text("Forward (⌘])")
        forwardButton.setAccessibilityRole(.button)
        forwardButton.setAccessibilityLabel(L10n.text("Forward"))
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
        listModeButton.toolTip = L10n.text("List View (⌘1)")
        listModeButton.setAccessibilityRole(.button)
        listModeButton.setAccessibilityLabel(L10n.text("List View"))
        listModeButton.isHidden = !showViewMode
        listModeButton.wantsLayer = true
        view.addSubview(listModeButton)

        iconsModeButton = NSButton()
        iconsModeButton.translatesAutoresizingMaskIntoConstraints = false
        iconsModeButton.bezelStyle = .texturedRounded
        iconsModeButton.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Icons View")
        iconsModeButton.target = self
        iconsModeButton.action = #selector(iconsViewModeClicked(_:))
        iconsModeButton.toolTip = L10n.text("Icons View (⌘2)")
        iconsModeButton.setAccessibilityRole(.button)
        iconsModeButton.setAccessibilityLabel(L10n.text("Icons View"))
        iconsModeButton.isHidden = !showViewMode
        iconsModeButton.wantsLayer = true
        view.addSubview(iconsModeButton)

        columnsModeButton = NSButton()
        columnsModeButton.translatesAutoresizingMaskIntoConstraints = false
        columnsModeButton.bezelStyle = .texturedRounded
        columnsModeButton.image = NSImage(systemSymbolName: "sidebar.leading", accessibilityDescription: "Columns View")
        columnsModeButton.target = self
        columnsModeButton.action = #selector(columnsViewModeClicked(_:))
        columnsModeButton.toolTip = L10n.text("Columns View (⌘3)")
        columnsModeButton.setAccessibilityRole(.button)
        columnsModeButton.setAccessibilityLabel(L10n.text("Columns View"))
        columnsModeButton.isHidden = !showViewMode
        columnsModeButton.wantsLayer = true
        view.addSubview(columnsModeButton)

        windowsListModeButton = NSButton()
        windowsListModeButton.translatesAutoresizingMaskIntoConstraints = false
        windowsListModeButton.bezelStyle = .texturedRounded
        windowsListModeButton.image = NSImage(systemSymbolName: "list.bullet.rectangle", accessibilityDescription: "Windows List View")
        windowsListModeButton.target = self
        windowsListModeButton.action = #selector(windowsListViewModeClicked(_:))
        windowsListModeButton.toolTip = L10n.text("Windows List View (⌘4)")
        windowsListModeButton.setAccessibilityRole(.button)
        windowsListModeButton.setAccessibilityLabel(L10n.text("Windows List View"))
        windowsListModeButton.isHidden = !showViewMode
        windowsListModeButton.wantsLayer = true
        view.addSubview(windowsListModeButton)
        
        // Hidden Files toggle button
        hiddenFilesButton = NSButton()
        hiddenFilesButton.translatesAutoresizingMaskIntoConstraints = false
        hiddenFilesButton.bezelStyle = .texturedRounded
        hiddenFilesButton.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "Show Hidden Files")
        hiddenFilesButton.target = self
        hiddenFilesButton.action = #selector(toggleHiddenFiles(_:))
        hiddenFilesButton.toolTip = L10n.text("Show Hidden Files (⇧⌘.)")
        hiddenFilesButton.setAccessibilityRole(.button)
        hiddenFilesButton.setAccessibilityLabel(L10n.text("Toggle hidden files"))
        hiddenFilesButton.isHidden = !showHiddenFiles
        view.addSubview(hiddenFilesButton)
        
        // Split Vertical button
        splitVerticalButton = NSButton()
        splitVerticalButton.translatesAutoresizingMaskIntoConstraints = false
        splitVerticalButton.bezelStyle = .texturedRounded
        splitVerticalButton.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Split Vertically")
        splitVerticalButton.target = self
        splitVerticalButton.action = #selector(splitVerticallyClicked(_:))
        splitVerticalButton.toolTip = L10n.text("Split View Vertically")
        splitVerticalButton.setAccessibilityRole(.button)
        splitVerticalButton.setAccessibilityLabel(L10n.text("Split view vertically"))
        splitVerticalButton.isHidden = !showSplit
        view.addSubview(splitVerticalButton)
        
        // Split Horizontal button
        splitHorizontalButton = NSButton()
        splitHorizontalButton.translatesAutoresizingMaskIntoConstraints = false
        splitHorizontalButton.bezelStyle = .texturedRounded
        splitHorizontalButton.image = NSImage(systemSymbolName: "rectangle.split.1x2", accessibilityDescription: "Split Horizontally")
        splitHorizontalButton.target = self
        splitHorizontalButton.action = #selector(splitHorizontallyClicked(_:))
        splitHorizontalButton.toolTip = L10n.text("Split View Horizontally")
        splitHorizontalButton.setAccessibilityRole(.button)
        splitHorizontalButton.setAccessibilityLabel(L10n.text("Split view horizontally"))
        splitHorizontalButton.isHidden = !showSplit
        view.addSubview(splitHorizontalButton)

        // Preview Pane button
        previewPaneButton = NSButton()
        previewPaneButton.translatesAutoresizingMaskIntoConstraints = false
        previewPaneButton.bezelStyle = .texturedRounded
        previewPaneButton.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: "Toggle Preview Pane")
        previewPaneButton.target = self
        previewPaneButton.action = #selector(togglePreviewPaneClicked(_:))
        previewPaneButton.toolTip = L10n.text("Show Preview Pane")
        previewPaneButton.setAccessibilityRole(.button)
        previewPaneButton.setAccessibilityLabel(L10n.text("Toggle preview pane"))
        previewPaneButton.isHidden = !showPreviewPane
        view.addSubview(previewPaneButton)

        // Storage Analyzer button
        storageAnalyzerButton = NSButton()
        storageAnalyzerButton.translatesAutoresizingMaskIntoConstraints = false
        storageAnalyzerButton.bezelStyle = .texturedRounded
        storageAnalyzerButton.image = NSImage(systemSymbolName: "chart.pie", accessibilityDescription: "Storage Analyzer")
        storageAnalyzerButton.target = self
        storageAnalyzerButton.action = #selector(storageAnalyzerButtonClicked(_:))
        storageAnalyzerButton.toolTip = L10n.text("Storage Analyzer")
        storageAnalyzerButton.setAccessibilityRole(.button)
        storageAnalyzerButton.setAccessibilityLabel(L10n.text("Open Storage Analyzer"))
        storageAnalyzerButton.isHidden = !showStorageAnalyzer
        view.addSubview(storageAnalyzerButton)

        // Open in Terminal button
        openTerminalButton = NSButton()
        openTerminalButton.translatesAutoresizingMaskIntoConstraints = false
        openTerminalButton.bezelStyle = .texturedRounded
        openTerminalButton.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Open in Terminal")
        openTerminalButton.target = self
        openTerminalButton.action = #selector(openTerminalButtonClicked(_:))
        openTerminalButton.toolTip = L10n.text("Open in Terminal")
        openTerminalButton.setAccessibilityRole(.button)
        openTerminalButton.setAccessibilityLabel(L10n.text("Open in Terminal"))
        openTerminalButton.isHidden = !showOpenTerminal
        view.addSubview(openTerminalButton)

        // Left buttons stack - will contain many of the action buttons so we can hide them responsively
        leftButtonsStackView = NSStackView()
        leftButtonsStackView.translatesAutoresizingMaskIntoConstraints = false
        leftButtonsStackView.orientation = .horizontal
        leftButtonsStackView.alignment = .centerY
        leftButtonsStackView.spacing = 6
        leftButtonsStackView.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        view.addSubview(leftButtonsStackView)

        // New Folder button
        newFolderButton = NSButton()
        newFolderButton.translatesAutoresizingMaskIntoConstraints = false
        newFolderButton.bezelStyle = .texturedRounded
        newFolderButton.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: "New Folder")
        newFolderButton.target = self
        newFolderButton.action = #selector(newFolderButtonClicked(_:))
        newFolderButton.toolTip = L10n.text("New Folder (⇧⌘N)")
        newFolderButton.setAccessibilityRole(.button)
        newFolderButton.setAccessibilityLabel(L10n.text("New Folder"))
        newFolderButton.isHidden = !showNewFolder

        // Add primary left buttons into stack in desired order
        leftButtonsStackView.addArrangedSubview(listModeButton)
        leftButtonsStackView.addArrangedSubview(iconsModeButton)
        leftButtonsStackView.addArrangedSubview(columnsModeButton)
        leftButtonsStackView.addArrangedSubview(windowsListModeButton)
        leftButtonsStackView.addArrangedSubview(hiddenFilesButton)
        leftButtonsStackView.addArrangedSubview(splitVerticalButton)
        leftButtonsStackView.addArrangedSubview(splitHorizontalButton)
        leftButtonsStackView.addArrangedSubview(previewPaneButton)
        leftButtonsStackView.addArrangedSubview(newFolderButton)
        leftButtonsStackView.addArrangedSubview(storageAnalyzerButton)
        leftButtonsStackView.addArrangedSubview(openTerminalButton)


        // Create overflow button (hidden by default)
        overflowButton = NSButton()
        overflowButton.translatesAutoresizingMaskIntoConstraints = false
        overflowButton.bezelStyle = .texturedRounded
        overflowButton.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "More")
        overflowButton.isBordered = false
        overflowButton.target = self
        overflowButton.action = #selector(overflowButtonClicked(_:))
        overflowButton.toolTip = L10n.text("More")
        overflowButton.setAccessibilityRole(.button)
        overflowButton.setAccessibilityLabel(L10n.text("More options"))
        overflowButton.isHidden = true
        leftButtonsStackView.addArrangedSubview(overflowButton)

        // Overflow menu
        overflowMenu = NSMenu()

        // Sort button
        sortButton = AccentPopUpButton()
        sortButton.translatesAutoresizingMaskIntoConstraints = false
        sortButton.bezelStyle = .texturedRounded
        sortButton.pullsDown = true
        sortButton.addItem(withTitle: L10n.text("Sort"))
        (sortButton.item(at: 0) as NSMenuItem?)?.image = NSImage(systemSymbolName: "arrow.up.arrow.down", accessibilityDescription: "Sort")

        sortButton.menu?.addItem(withTitle: L10n.text("Name ↑"), action: #selector(sortByNameAscending(_:)), keyEquivalent: "")
        sortButton.menu?.addItem(withTitle: L10n.text("Name ↓"), action: #selector(sortByNameDescending(_:)), keyEquivalent: "")
        sortButton.menu?.addItem(NSMenuItem.separator())
        sortButton.menu?.addItem(withTitle: L10n.text("Date Modified ↑"), action: #selector(sortByDateAscending(_:)), keyEquivalent: "")
        sortButton.menu?.addItem(withTitle: L10n.text("Date Modified ↓"), action: #selector(sortByDateDescending(_:)), keyEquivalent: "")
        sortButton.menu?.addItem(NSMenuItem.separator())
        sortButton.menu?.addItem(withTitle: L10n.text("Size ↑"), action: #selector(sortBySizeAscending(_:)), keyEquivalent: "")
        sortButton.menu?.addItem(withTitle: L10n.text("Size ↓"), action: #selector(sortBySizeDescending(_:)), keyEquivalent: "")
        sortButton.menu?.addItem(NSMenuItem.separator())
        sortButton.menu?.addItem(withTitle: L10n.text("Type ↑"), action: #selector(sortByTypeAscending(_:)), keyEquivalent: "")
        sortButton.menu?.addItem(withTitle: L10n.text("Type ↓"), action: #selector(sortByTypeDescending(_:)), keyEquivalent: "")

        sortButton.menu?.items.forEach { $0.target = self }
        sortButton.toolTip = L10n.text("Sort Options")
        sortButton.setAccessibilityRole(.popUpButton)
        sortButton.setAccessibilityLabel(L10n.text("Sort Options"))
        sortButton.isHidden = !showSort
        view.addSubview(sortButton)

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

        // Search Button
        searchButton = NSButton()
        searchButton.translatesAutoresizingMaskIntoConstraints = false
        searchButton.bezelStyle = .texturedRounded
        searchButton.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        searchButton.target = self
        searchButton.action = #selector(searchButtonClicked(_:))
        searchButton.toolTip = L10n.text("Search (⌘F)")
        searchButton.setAccessibilityRole(.button)
        searchButton.setAccessibilityLabel(L10n.text("Search"))
        view.addSubview(searchButton)
        
        // Search Field
        searchField = NSSearchField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = L10n.text("Search")
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.sendsWholeSearchString = false
        searchField.sendsSearchStringImmediately = true
        searchField.toolTip = L10n.text("Search (⌘F)")
        searchField.isHidden = true // Hidden by default
        searchField.delegate = self
        searchField.setAccessibilityLabel(L10n.text("Search files"))
        searchField.setAccessibilityRole(.textField)
        view.addSubview(searchField)
        
        // Filter button
        filterButton = NSButton()
        filterButton.translatesAutoresizingMaskIntoConstraints = false
        filterButton.bezelStyle = .texturedRounded
        filterButton.image = NSImage(systemSymbolName: "line.3.horizontal.decrease.circle", accessibilityDescription: "Filter")
        filterButton.target = self
        filterButton.action = #selector(filterButtonClicked(_:))
        filterButton.toolTip = L10n.text("Filter Files")
        filterButton.setAccessibilityRole(.button)
        filterButton.setAccessibilityLabel(L10n.text("Filter Files"))
        view.addSubview(filterButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Bottom border
            bottomBorder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBorder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBorder.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBorder.heightAnchor.constraint(equalToConstant: 1),


            // Top row: left buttons stack
            leftButtonsStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            leftButtonsStackView.trailingAnchor.constraint(lessThanOrEqualTo: sortButton.leadingAnchor, constant: -8),
            leftButtonsStackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            leftButtonsStackView.heightAnchor.constraint(equalToConstant: 26),

            // Ensure each standard button keeps its intrinsic size
            listModeButton.widthAnchor.constraint(equalToConstant: 30),
            listModeButton.heightAnchor.constraint(equalToConstant: 26),
            iconsModeButton.widthAnchor.constraint(equalToConstant: 30),
            iconsModeButton.heightAnchor.constraint(equalToConstant: 26),
            columnsModeButton.widthAnchor.constraint(equalToConstant: 30),
            columnsModeButton.heightAnchor.constraint(equalToConstant: 26),
            windowsListModeButton.widthAnchor.constraint(equalToConstant: 30),
            windowsListModeButton.heightAnchor.constraint(equalToConstant: 26),
            hiddenFilesButton.widthAnchor.constraint(equalToConstant: 30),
            hiddenFilesButton.heightAnchor.constraint(equalToConstant: 26),
            splitVerticalButton.widthAnchor.constraint(equalToConstant: 30),
            splitVerticalButton.heightAnchor.constraint(equalToConstant: 26),
            splitHorizontalButton.widthAnchor.constraint(equalToConstant: 30),
            splitHorizontalButton.heightAnchor.constraint(equalToConstant: 26),
            previewPaneButton.widthAnchor.constraint(equalToConstant: 30),
            previewPaneButton.heightAnchor.constraint(equalToConstant: 26),
            newFolderButton.widthAnchor.constraint(equalToConstant: 30),
            newFolderButton.heightAnchor.constraint(equalToConstant: 26),
            storageAnalyzerButton.widthAnchor.constraint(equalToConstant: 30),
            storageAnalyzerButton.heightAnchor.constraint(equalToConstant: 26),
            openTerminalButton.widthAnchor.constraint(equalToConstant: 30),
            openTerminalButton.heightAnchor.constraint(equalToConstant: 26),
            overflowButton.widthAnchor.constraint(equalToConstant: 26),
            overflowButton.heightAnchor.constraint(equalToConstant: 26),

            // Keep sort/search area at the right side as before
            sortButton.trailingAnchor.constraint(equalTo: searchButton.leadingAnchor, constant: -8),
            sortButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            sortButton.widthAnchor.constraint(equalToConstant: 44),
            sortButton.heightAnchor.constraint(equalToConstant: 26),

            searchButton.trailingAnchor.constraint(equalTo: filterButton.leadingAnchor, constant: -8),
            searchButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            searchButton.widthAnchor.constraint(equalToConstant: 30),
            searchButton.heightAnchor.constraint(equalToConstant: 26),

            searchField.leadingAnchor.constraint(equalTo: sortButton.trailingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: filterButton.leadingAnchor, constant: -8),
            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: 9),
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
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
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

        // Ensure the primary action buttons keep their intrinsic size before breadcrumb compresses
        for viewItem in leftButtonsStackView.arrangedSubviews {
            if let btn = viewItem as? NSButton {
                btn.setContentHuggingPriority(.required, for: .horizontal)
                btn.setContentCompressionResistancePriority(.required, for: .horizontal)
            }
        }
    }

    @objc private func handleToolbarSettingsChanged(_ notification: Notification) {
        // Re-read visibility preferences and apply to UI elements
        let showBackForward = UserDefaults.standard.object(forKey: UserDefaults.Keys.showBackForwardButtons.rawValue) as? Bool ?? true
        let showViewMode = UserDefaults.standard.object(forKey: UserDefaults.Keys.showViewModeButton.rawValue) as? Bool ?? true
        let showHiddenFiles = UserDefaults.standard.object(forKey: UserDefaults.Keys.showHiddenFilesButton.rawValue) as? Bool ?? true
        let showSplit = UserDefaults.standard.object(forKey: UserDefaults.Keys.showSplitButtons.rawValue) as? Bool ?? true
        let showPreviewPane = UserDefaults.standard.object(forKey: UserDefaults.Keys.showPreviewPaneButton.rawValue) as? Bool ?? true
        let showNewFolder = UserDefaults.standard.object(forKey: UserDefaults.Keys.showNewFolderButton.rawValue) as? Bool ?? true
        let showSort = UserDefaults.standard.object(forKey: UserDefaults.Keys.showSortButton.rawValue) as? Bool ?? true
        let showStorageAnalyzer = UserDefaults.standard.object(forKey: "showStorageAnalyzerButton") as? Bool ?? true
        let showOpenTerminal = UserDefaults.standard.object(forKey: UserDefaults.Keys.showOpenTerminalButton.rawValue) as? Bool ?? true

        backButton.isHidden = !showBackForward
        forwardButton.isHidden = !showBackForward

        listModeButton.isHidden = !showViewMode
        iconsModeButton.isHidden = !showViewMode
        columnsModeButton.isHidden = !showViewMode
        windowsListModeButton.isHidden = !showViewMode

        hiddenFilesButton.isHidden = !showHiddenFiles
        splitVerticalButton.isHidden = !showSplit
        splitHorizontalButton.isHidden = !showSplit
        previewPaneButton.isHidden = !showPreviewPane
        newFolderButton.isHidden = !showNewFolder
        sortButton.isHidden = !showSort
        storageAnalyzerButton.isHidden = !showStorageAnalyzer
        openTerminalButton.isHidden = !showOpenTerminal

        // Force layout update to account for hidden/shown controls
        view.needsLayout = true
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

        // Add stronger visual differentiation for active button
        let accentColor = NSColor.customAccentColor
        let inactiveTint = NSColor.tertiaryLabelColor
        let buttons = [listModeButton, iconsModeButton, columnsModeButton, windowsListModeButton]

        for button in buttons {
            guard let button else { continue }
            button.wantsLayer = true
            if button.state == .on {
                button.contentTintColor = .labelColor
                button.layer?.backgroundColor = accentColor.withAlphaComponent(0.22).cgColor
                button.layer?.borderColor = accentColor.cgColor
                button.layer?.borderWidth = 1.0
                button.layer?.cornerRadius = 6
                button.alphaValue = 1.0
            } else {
                button.contentTintColor = inactiveTint
                button.layer?.backgroundColor = NSColor.clear.cgColor
                button.layer?.borderWidth = 0
                button.alphaValue = 0.85
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
    
    override func viewDidLayout() {
        super.viewDidLayout()
        adjustOverflowIfNeeded()
    }

    private func adjustOverflowIfNeeded() {
        // Determine available horizontal space for left buttons
        let leftInset: CGFloat = 12
        
        var rightHandControlsMinX: CGFloat = view.bounds.width - 8 // Start with trailing padding
        if !closePaneButton.isHidden { rightHandControlsMinX = min(rightHandControlsMinX, closePaneButton.frame.minX) }
        if !filterButton.isHidden { rightHandControlsMinX = min(rightHandControlsMinX, filterButton.frame.minX) }
        if isSearchFieldVisible, !searchField.isHidden {
             rightHandControlsMinX = min(rightHandControlsMinX, searchField.frame.minX)
        } else if !searchButton.isHidden {
             rightHandControlsMinX = min(rightHandControlsMinX, searchButton.frame.minX)
        }
        if !sortButton.isHidden { rightHandControlsMinX = min(rightHandControlsMinX, sortButton.frame.minX) }

        let rightEdge = rightHandControlsMinX - 8 // 8px padding

        var usedX: CGFloat = leftInset

        // Decide which buttons fit; move extras into overflow
        var overflowItems: [NSButton] = []
        let allButtons: [NSButton?] = [listModeButton, iconsModeButton, columnsModeButton, windowsListModeButton, hiddenFilesButton, splitVerticalButton, splitHorizontalButton, previewPaneButton, newFolderButton, storageAnalyzerButton, openTerminalButton]

        for btn in allButtons {
            guard let b = btn else { continue }
            
            let key = buttonToPreferenceKey(b)
            let userWantsVisible = key == nil || (UserDefaults.standard.object(forKey: key!) as? Bool ?? true)

            if !userWantsVisible {
                if !b.isHidden { b.isHidden = true }
                continue
            }

            let w = b.frame.width
            if usedX + w > rightEdge {
                // hide and move to overflow
                b.isHidden = true
                overflowItems.append(b)
            } else {
                b.isHidden = false
                usedX += w + leftButtonsStackView.spacing
            }
        }

        // Show or hide overflow button depending on items
        if overflowItems.isEmpty {
            overflowButton.isHidden = true
            overflowMenu.removeAllItems()
        } else {
            overflowButton.isHidden = false
            overflowMenu.removeAllItems()
            for b in overflowItems {
                let item = NSMenuItem(title: b.toolTip ?? b.title, action: b.action, keyEquivalent: "")
                item.target = b.target
                overflowMenu.addItem(item)
            }
        }
    }

    private func buttonToPreferenceKey(_ button: NSButton) -> String? {
        switch button {
        case backButton, forwardButton:
            return UserDefaults.Keys.showBackForwardButtons.rawValue
        case listModeButton, iconsModeButton, columnsModeButton, windowsListModeButton:
            return UserDefaults.Keys.showViewModeButton.rawValue
        case hiddenFilesButton:
            return UserDefaults.Keys.showHiddenFilesButton.rawValue
        case splitVerticalButton, splitHorizontalButton:
            return UserDefaults.Keys.showSplitButtons.rawValue
        case previewPaneButton:
            return UserDefaults.Keys.showPreviewPaneButton.rawValue
        case newFolderButton:
            return UserDefaults.Keys.showNewFolderButton.rawValue
        case sortButton:
            return UserDefaults.Keys.showSortButton.rawValue
        case storageAnalyzerButton:
            return "showStorageAnalyzerButton"
        case openTerminalButton:
            return UserDefaults.Keys.showOpenTerminalButton.rawValue
        default:
            return nil
        }
    }

    @objc private func overflowButtonClicked(_ sender: NSButton) {
        let location = NSPoint(x: 0, y: sender.bounds.height)
        overflowMenu.popUp(positioning: nil, at: location, in: sender)
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
            guard var currentPathURL = breadcrumbURLs.last else { return }
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

    @objc private func searchButtonClicked(_ sender: NSButton) {
        isSearchFieldVisible = true
        searchButton.isHidden = true
        searchButton.isEnabled = false
        searchButton.alphaValue = 0
        // Keep sort button visible; instead expand search into available space without covering neighbors.
        searchField.isHidden = false
        view.window?.makeFirstResponder(searchField)
        view.layoutSubtreeIfNeeded()
        adjustOverflowIfNeeded()
    }

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
        debugLog("ToolbarViewController: openTerminalButtonClicked")
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

// MARK: - NSSearchFieldDelegate
extension ToolbarViewController {
    func controlTextDidEndEditing(_ obj: Notification) {
        // This is called when the search field loses focus
        if isSearchFieldVisible {
            isSearchFieldVisible = false
            searchButton.isHidden = false
            searchButton.isEnabled = true
            searchButton.alphaValue = 1
            searchField.isHidden = true
            if searchField.stringValue != "" {
                searchField.stringValue = ""
                delegate?.toolbarDidSearchTextChange("")
            }
            adjustOverflowIfNeeded()
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            // This is the Escape key
            if isSearchFieldVisible {
                // End editing, which will trigger controlTextDidEndEditing
                view.window?.makeFirstResponder(nil)
                searchField.stringValue = ""
                delegate?.toolbarDidSearchTextChange("")
                adjustOverflowIfNeeded()
                return true
            }
        }
        return false // Let the system handle other commands
    }
}
