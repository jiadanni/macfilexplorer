import Cocoa

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

class ToolbarViewController: NSViewController, NSSearchFieldDelegate, SettingsStoreDelegate {

    weak var delegate: ToolbarDelegate?
    
    private let settings: SettingsStoreProtocol

    private var backButton: NSButton!
    private var forwardButton: NSButton!
    private var breadcrumbStackView: NSStackView!
    private var breadcrumbScrollView: NSScrollView!
    private var sortButton: NSPopUpButton!
    // View mode segmented control (Finder-style)
    private var viewModeSegmentedControl: NSSegmentedControl!
    // Legacy individual buttons kept for settings compatibility
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
    private var searchFieldWidthConstraint: NSLayoutConstraint!
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

    init(settings: SettingsStoreProtocol = SettingsStore.shared) {
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.settings = SettingsStore.shared
        super.init(coder: coder)
    }

    override func loadView() {
        // Increased height to accommodate two rows: buttons (40) + breadcrumb bar (30) + extra padding
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 84))
        setupUI()
        // Set as delegate for settings changes
        settings.addDelegate(self)
        // Observe toolbar settings changes so visibility toggles update live
        NotificationCenter.default.addObserver(self, selector: #selector(handleToolbarSettingsChanged(_:)), name: .toolbarSettingsDidChangeNotification, object: nil)
        // Observe accent color changes
        NotificationCenter.default.addObserver(self, selector: #selector(accentColorDidChange), name: .accentColorDidChangeNotification, object: nil)
        // Initial state update based on persisted preference
        let initiallyShowingPreview = settings.previewPaneVisible
        updatePreviewPaneDisplay(showing: initiallyShowingPreview)
    }

    deinit {
        settings.removeDelegate(self)
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

        // Load toolbar visibility settings from SettingsStore
        let showBackForward = settings.showBackForwardButtons
        let showViewMode = settings.showViewModeButton
        let showHiddenFiles = settings.showHiddenFilesButton
        let showSplit = settings.showSplitButtons
        let showPreviewPane = settings.showPreviewPaneButton
        let showNewFolder = settings.showNewFolderButton
        let showSort = settings.showSortButton
        let showStorageAnalyzer = settings.showStorageAnalyzerButton
        let showOpenTerminal = settings.showOpenTerminalButton

        // Back button
        backButton = NSButton()
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.bezelStyle = .texturedRounded
        backButton.image = NSImage.mfeSymbol(named: "chevron.left", accessibilityDescription: "Back")
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
        forwardButton.image = NSImage.mfeSymbol(named: "chevron.right", accessibilityDescription: "Forward")
        forwardButton.target = self
        forwardButton.action = #selector(forwardButtonClicked(_:))
        forwardButton.isEnabled = false
        forwardButton.sendAction(on: [.leftMouseDown, .rightMouseDown])
        forwardButton.toolTip = L10n.text("Forward (⌘])")
        forwardButton.setAccessibilityRole(.button)
        forwardButton.setAccessibilityLabel(L10n.text("Forward"))
        forwardButton.isHidden = !showBackForward
        view.addSubview(forwardButton)

        // Breadcrumb scroll view (for address bar) - styled for Finder-like clean appearance
        breadcrumbScrollView = NSScrollView()
        breadcrumbScrollView.translatesAutoresizingMaskIntoConstraints = false
        breadcrumbScrollView.hasHorizontalScroller = false
        breadcrumbScrollView.hasVerticalScroller = false
        breadcrumbScrollView.borderType = .noBorder
        breadcrumbScrollView.drawsBackground = true
        breadcrumbScrollView.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.08)
        breadcrumbScrollView.wantsLayer = true
        breadcrumbScrollView.layer?.cornerRadius = 5
        breadcrumbScrollView.layer?.masksToBounds = true
        view.addSubview(breadcrumbScrollView)

        // Breadcrumb stack view
        breadcrumbStackView = NSStackView()
        breadcrumbStackView.orientation = .horizontal
        breadcrumbStackView.spacing = 0
        breadcrumbStackView.alignment = .centerY
        breadcrumbStackView.translatesAutoresizingMaskIntoConstraints = false
        breadcrumbScrollView.documentView = breadcrumbStackView

        // View Mode segmented control (Finder-style grouped buttons)
        viewModeSegmentedControl = NSSegmentedControl()
        viewModeSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        viewModeSegmentedControl.segmentCount = 4
        viewModeSegmentedControl.trackingMode = .selectOne
        viewModeSegmentedControl.segmentStyle = .separated

        // Set images for each segment
        viewModeSegmentedControl.setImage(NSImage.mfeSymbol(named: "list.bullet", accessibilityDescription: "List View"), forSegment: 0)
        viewModeSegmentedControl.setImage(NSImage.mfeSymbol(named: "square.grid.2x2", accessibilityDescription: "Icons View"), forSegment: 1)
        viewModeSegmentedControl.setImage(NSImage.mfeSymbol(named: "sidebar.leading", accessibilityDescription: "Columns View"), forSegment: 2)
        viewModeSegmentedControl.setImage(NSImage.mfeSymbol(named: "list.bullet.rectangle", accessibilityDescription: "Windows List View"), forSegment: 3)

        // Set fixed width for each segment for uniform appearance
        for i in 0..<4 {
            viewModeSegmentedControl.setWidth(28, forSegment: i)
        }

        // Set tooltips using NSSegmentedCell
        if let cell = viewModeSegmentedControl.cell as? NSSegmentedCell {
            cell.setToolTip(L10n.text("List View (⌘1)"), forSegment: 0)
            cell.setToolTip(L10n.text("Icons View (⌘2)"), forSegment: 1)
            cell.setToolTip(L10n.text("Columns View (⌘3)"), forSegment: 2)
            cell.setToolTip(L10n.text("Windows List View (⌘4)"), forSegment: 3)
        }

        viewModeSegmentedControl.target = self
        viewModeSegmentedControl.action = #selector(viewModeSegmentChanged(_:))
        viewModeSegmentedControl.selectedSegment = 0
        viewModeSegmentedControl.isHidden = !showViewMode
        viewModeSegmentedControl.setAccessibilityLabel(L10n.text("View Mode"))
        view.addSubview(viewModeSegmentedControl)

        // Create hidden placeholder buttons for settings compatibility (not added to view)
        listModeButton = NSButton()
        listModeButton.isHidden = true
        iconsModeButton = NSButton()
        iconsModeButton.isHidden = true
        columnsModeButton = NSButton()
        columnsModeButton.isHidden = true
        windowsListModeButton = NSButton()
        windowsListModeButton.isHidden = true
        
        // Hidden Files toggle button
        hiddenFilesButton = NSButton()
        hiddenFilesButton.translatesAutoresizingMaskIntoConstraints = false
        hiddenFilesButton.bezelStyle = .texturedRounded
        hiddenFilesButton.image = NSImage.mfeSymbol(named: "eye.slash", accessibilityDescription: "Show Hidden Files")
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
        splitVerticalButton.image = NSImage.mfeSymbol(named: "rectangle.split.2x1", accessibilityDescription: "Split Vertically")
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
        splitHorizontalButton.image = NSImage.mfeSymbol(named: "rectangle.split.1x2", accessibilityDescription: "Split Horizontally")
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
        previewPaneButton.image = NSImage.mfeSymbol(named: "sidebar.right", accessibilityDescription: "Toggle Preview Pane")
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
        storageAnalyzerButton.image = NSImage.mfeSymbol(named: "chart.pie", accessibilityDescription: "Storage Analyzer")
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
        openTerminalButton.image = NSImage.mfeSymbol(named: "terminal", accessibilityDescription: "Open in Terminal")
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
        leftButtonsStackView.spacing = 4  // Tighter spacing like Finder
        leftButtonsStackView.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        view.addSubview(leftButtonsStackView)

        // New Folder button
        newFolderButton = NSButton()
        newFolderButton.translatesAutoresizingMaskIntoConstraints = false
        newFolderButton.bezelStyle = .texturedRounded
        newFolderButton.image = NSImage.mfeSymbol(named: "folder.badge.plus", accessibilityDescription: "New Folder")
        newFolderButton.target = self
        newFolderButton.action = #selector(newFolderButtonClicked(_:))
        newFolderButton.toolTip = L10n.text("New Folder (⇧⌘N)")
        newFolderButton.setAccessibilityRole(.button)
        newFolderButton.setAccessibilityLabel(L10n.text("New Folder"))
        newFolderButton.isHidden = !showNewFolder

        // Add primary left buttons into stack in desired order with visual separators
        // Group 0: Navigation
        leftButtonsStackView.addArrangedSubview(backButton)
        leftButtonsStackView.addArrangedSubview(forwardButton)

        // Separator after navigation
        leftButtonsStackView.addArrangedSubview(createToolbarSeparator())

        // Group 1: View modes
        leftButtonsStackView.addArrangedSubview(viewModeSegmentedControl)

        // Separator after view modes
        leftButtonsStackView.addArrangedSubview(createToolbarSeparator())

        // Group 2: Visibility toggles (hidden files, preview pane)
        leftButtonsStackView.addArrangedSubview(hiddenFilesButton)
        leftButtonsStackView.addArrangedSubview(previewPaneButton)

        // Separator
        leftButtonsStackView.addArrangedSubview(createToolbarSeparator())

        // Group 3: Layout controls (split views)
        leftButtonsStackView.addArrangedSubview(splitVerticalButton)
        leftButtonsStackView.addArrangedSubview(splitHorizontalButton)

        // Separator
        leftButtonsStackView.addArrangedSubview(createToolbarSeparator())

        // Group 4: Actions (new folder, storage, terminal)
        leftButtonsStackView.addArrangedSubview(newFolderButton)
        leftButtonsStackView.addArrangedSubview(storageAnalyzerButton)
        leftButtonsStackView.addArrangedSubview(openTerminalButton)


        // Create overflow button (hidden by default)
        overflowButton = NSButton()
        overflowButton.translatesAutoresizingMaskIntoConstraints = false
        overflowButton.bezelStyle = .texturedRounded
        overflowButton.image = NSImage.mfeSymbol(named: "ellipsis", accessibilityDescription: "More")
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
        (sortButton.item(at: 0) as NSMenuItem?)?.image = NSImage.mfeSymbol(named: "arrow.up.arrow.down", accessibilityDescription: "Sort")

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
        closePaneButton.image = NSImage.mfeSymbol(named: "xmark", accessibilityDescription: "Close Pane")
        closePaneButton.target = self
        closePaneButton.action = #selector(closePaneButtonClicked(_:))
        closePaneButton.toolTip = "Close Pane (⌘W)"
        closePaneButton.isHidden = true // Hidden by default, shown when there are multiple panes
        view.addSubview(closePaneButton)

        // Search Button
        searchButton = NSButton()
        searchButton.translatesAutoresizingMaskIntoConstraints = false
        searchButton.bezelStyle = .texturedRounded
        searchButton.image = NSImage.mfeSymbol(named: "magnifyingglass", accessibilityDescription: "Search")
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

        searchFieldWidthConstraint = searchField.widthAnchor.constraint(equalToConstant: 30)
        
        // Filter button
        filterButton = NSButton()
        filterButton.translatesAutoresizingMaskIntoConstraints = false
        filterButton.bezelStyle = .texturedRounded
        filterButton.image = NSImage.mfeSymbol(named: "line.3.horizontal.decrease.circle", accessibilityDescription: "Filter")
        filterButton.imagePosition = .imageOnly
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

            // Segmented control for view modes (Finder-style)
            viewModeSegmentedControl.heightAnchor.constraint(equalToConstant: 24),

            // Ensure each standard button keeps its intrinsic size
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
            backButton.widthAnchor.constraint(equalToConstant: 30),
            backButton.heightAnchor.constraint(equalToConstant: 26),
            forwardButton.widthAnchor.constraint(equalToConstant: 30),
            forwardButton.heightAnchor.constraint(equalToConstant: 26),
            overflowButton.widthAnchor.constraint(equalToConstant: 26),
            overflowButton.heightAnchor.constraint(equalToConstant: 26),

            // Keep sort/search area at the right side as before
            sortButton.trailingAnchor.constraint(equalTo: searchField.leadingAnchor, constant: -8),
            sortButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            sortButton.widthAnchor.constraint(equalToConstant: 44),
            sortButton.heightAnchor.constraint(equalToConstant: 26),

            searchButton.trailingAnchor.constraint(equalTo: filterButton.leadingAnchor, constant: -8),
            searchButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            searchButton.widthAnchor.constraint(equalToConstant: 30),
            searchButton.heightAnchor.constraint(equalToConstant: 26),

            searchFieldWidthConstraint,
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

            // Bottom row: breadcrumb/URL bar
            breadcrumbScrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            breadcrumbScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            breadcrumbScrollView.topAnchor.constraint(equalTo: leftButtonsStackView.bottomAnchor, constant: 6),
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
        let showBackForward = settings.showBackForwardButtons
        let showViewMode = settings.showViewModeButton
        let showHiddenFiles = settings.showHiddenFilesButton
        let showSplit = settings.showSplitButtons
        let showPreviewPane = settings.showPreviewPaneButton
        let showNewFolder = settings.showNewFolderButton
        let showSort = settings.showSortButton
        let showStorageAnalyzer = settings.showStorageAnalyzerButton
        let showOpenTerminal = settings.showOpenTerminalButton

        backButton.isHidden = !showBackForward
        forwardButton.isHidden = !showBackForward

        viewModeSegmentedControl.isHidden = !showViewMode

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
        // Update segmented control selection
        switch viewMode {
        case .list:
            viewModeSegmentedControl.selectedSegment = 0
        case .icons:
            viewModeSegmentedControl.selectedSegment = 1
        case .columns:
            viewModeSegmentedControl.selectedSegment = 2
        case .windowsList:
            viewModeSegmentedControl.selectedSegment = 3
        }
    }
    
    func updateHiddenFilesDisplay(showing: Bool) {
        showingHiddenFiles = showing
        if showing {
            hiddenFilesButton.image = NSImage.mfeSymbol(named: "eye", accessibilityDescription: "Hide Hidden Files")
            hiddenFilesButton.toolTip = "Hide Hidden Files (⇧⌘.)"
        } else {
            hiddenFilesButton.image = NSImage.mfeSymbol(named: "eye.slash", accessibilityDescription: "Show Hidden Files")
            hiddenFilesButton.toolTip = "Show Hidden Files (⇧⌘.)"
        }
    }

    func updateSortDisplay(column: String, ascending: Bool) {
        var title = ""
        var image: NSImage?

        switch column {
        case AppConfig.ColumnID.name:
            title = "Name"
        case AppConfig.ColumnID.dateModified:
            title = "Date Modified"
        case AppConfig.ColumnID.size:
            title = "Size"
        case AppConfig.ColumnID.type:
            title = "Type"
        case AppConfig.ColumnID.dateCreated:
            title = "Date Created"
        default:
            title = "Sort"
        }

        if ascending {
            title += " ↑"
            image = NSImage.mfeSymbol(named: "arrow.up", accessibilityDescription: "Ascending")
        } else {
            title += " ↓"
            image = NSImage.mfeSymbol(named: "arrow.down", accessibilityDescription: "Descending")
        }

        sortButton.title = title
        sortButton.image = image
    }

    func updateSplitButtonsState(canAddMore: Bool) {
        splitVerticalButton.isEnabled = canAddMore
        splitHorizontalButton.isEnabled = canAddMore

        if !canAddMore {
            let limit = settings.maximumPanes
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
                previewPaneButton.image = NSImage.mfeSymbol(named: "sidebar.right", accessibilityDescription: "Hide Preview Pane")
                previewPaneButton.contentTintColor = NSColor.customAccentColor
                previewPaneButton.toolTip = "Hide Preview Pane"
            } else {
                previewPaneButton.image = NSImage.mfeSymbol(named: "sidebar.right", accessibilityDescription: "Show Preview Pane")
                previewPaneButton.contentTintColor = nil
                previewPaneButton.toolTip = "Show Preview Pane"
            }
        }
    }

    // MARK: - Testing

    var testingHiddenFilesButtonState: NSControl.StateValue {
        hiddenFilesButton.state
    }

    var testingPreviewPaneButtonToolTip: String? {
        previewPaneButton.toolTip
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        adjustOverflowIfNeeded()
    }

    private func adjustOverflowIfNeeded() {
        // Determine available horizontal space for left-hand buttons
        let leftInset: CGFloat = 12
        let spacing = leftButtonsStackView.spacing
        
        // Calculate the leftmost boundary of the right-hand controls
        var rightHandControlsMinX: CGFloat = view.bounds.width - 8
        if !closePaneButton.isHidden { rightHandControlsMinX = min(rightHandControlsMinX, closePaneButton.frame.minX) }
        if !filterButton.isHidden { rightHandControlsMinX = min(rightHandControlsMinX, filterButton.frame.minX) }
        
        if isSearchFieldVisible && !searchField.isHidden {
             rightHandControlsMinX = min(rightHandControlsMinX, searchField.frame.minX)
        } else if !searchButton.isHidden {
             rightHandControlsMinX = min(rightHandControlsMinX, searchButton.frame.minX)
        }
        
        if !sortButton.isHidden { rightHandControlsMinX = min(rightHandControlsMinX, sortButton.frame.minX) }

        let rightEdge = rightHandControlsMinX - 8 // 8px padding before right-hand controls
        var usedX: CGFloat = leftInset

        // Process subviews in the leftButtonsStackView in order
        var overflowItems: [NSButton] = []
        
        // We iterate through all views in the stack and decide visibility based on available space
        // Some items (like back/forward buttons) are prioritized.
        for subview in leftButtonsStackView.arrangedSubviews {
            if subview == overflowButton { continue }
            
            // Skip views that are hidden by user preference or logic (other than overflow)
            let userWantsVisible: Bool
            if let btn = subview as? NSButton {
                userWantsVisible = isButtonVisible(btn)
            } else if subview === viewModeSegmentedControl {
                userWantsVisible = settings.showViewModeButton
            } else {
                // Separators or other views
                userWantsVisible = true // We'll hide separators if their neighbor is hidden
            }
            
            if !userWantsVisible {
                subview.isHidden = true
                continue
            }
            
            let width = subview.intrinsicContentSize.width
            
            // Always keep back/forward buttons if possible
            let isEssential = (subview === backButton || subview === forwardButton)
            
            if !isEssential && usedX + width > rightEdge {
                // Doesn't fit, hide it
                subview.isHidden = true
                if let btn = subview as? NSButton {
                    overflowItems.append(btn)
                }
            } else {
                // Fits, show it
                subview.isHidden = false
                usedX += width + spacing
            }
        }
        
        // Final pass to hide separators that have no visible neighbor to their right or are redundant
        // (Simplified: just hiding them if they were marked hidden by the overlap logic)
        
        // Update overflow button
        if overflowItems.isEmpty {
            overflowButton.isHidden = true
            overflowMenu.removeAllItems()
        } else {
            overflowButton.isHidden = false
            overflowMenu.removeAllItems()
            for b in overflowItems {
                let title = b.toolTip ?? b.title
                if title.isEmpty { continue }
                let item = NSMenuItem(title: title, action: b.action, keyEquivalent: "")
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
    
    /// Creates a subtle vertical separator for toolbar button groups (Finder-style)
    private func createToolbarSeparator() -> NSView {
        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
        separator.heightAnchor.constraint(equalToConstant: 16).isActive = true
        return separator
    }

    private func isButtonVisible(_ button: NSButton) -> Bool {
        switch button {
        case backButton, forwardButton:
            return settings.showBackForwardButtons
        case listModeButton, iconsModeButton, columnsModeButton, windowsListModeButton:
            return settings.showViewModeButton
        case hiddenFilesButton:
            return settings.showHiddenFilesButton
        case splitVerticalButton, splitHorizontalButton:
            return settings.showSplitButtons
        case previewPaneButton:
            return settings.showPreviewPaneButton
        case newFolderButton:
            return settings.showNewFolderButton
        case sortButton:
            return settings.showSortButton
        case storageAnalyzerButton:
            return settings.showStorageAnalyzerButton
        case openTerminalButton:
            return settings.showOpenTerminalButton
        default:
            return true
        }
    }

    @objc private func overflowButtonClicked(_ sender: NSButton) {
        let location = NSPoint(x: 0, y: sender.bounds.height)
        overflowMenu.popUp(positioning: nil, at: location, in: sender)
    }

    @objc private func accentColorDidChange() {
        // Update preview pane button color if it's active
        let isShowingPreview = settings.previewPaneVisible
        if isShowingPreview {
            previewPaneButton.contentTintColor = NSColor.customAccentColor
        }
    }

    private func updateBreadcrumbs(for url: URL) {
        // Clear existing breadcrumbs
        breadcrumbStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // 1. Build full list of button components and separators
        var components: [NSView] = []
        let pathComponents = url.pathComponents
        var breadcrumbURLs: [URL] = []

        if pathComponents.isEmpty { return }

        // Generate URL for each component
        var currentURL = URL(fileURLWithPath: "/")
        breadcrumbURLs.append(currentURL)
        for i in 1..<pathComponents.count {
            currentURL.appendPathComponent(pathComponents[i])
            breadcrumbURLs.append(currentURL)
        }

        for (index, component) in pathComponents.enumerated() {
            if index > 0 {
                // Use SF Symbol chevron for cleaner Finder-like separator
                let separatorView = NSImageView()
                separatorView.image = NSImage.mfeSymbol(named: "chevron.right", accessibilityDescription: nil)
                separatorView.contentTintColor = .tertiaryLabelColor
                separatorView.imageScaling = .scaleProportionallyDown
                separatorView.setContentHuggingPriority(.required, for: .horizontal)
                separatorView.translatesAutoresizingMaskIntoConstraints = false
                separatorView.widthAnchor.constraint(equalToConstant: 8).isActive = true
                separatorView.heightAnchor.constraint(equalToConstant: 10).isActive = true
                components.append(separatorView)
            }

            let button = NSButton()
            // Show macOS icon for root, otherwise show folder name
            if component == "/" {
                button.image = NSImage(named: NSImage.computerName)
                button.imageScaling = .scaleProportionallyDown
                button.imagePosition = .imageOnly
            } else {
                button.title = component
            }
            button.bezelStyle = .roundRect
            button.isBordered = false
            button.font = NSFont.systemFont(ofSize: 12, weight: .regular)
            button.contentTintColor = .labelColor
            button.target = self
            button.action = #selector(breadcrumbClicked(_:))
            button.toolTip = url.pathComponents[0...index].joined(separator: "/").dropFirst().description
            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            button.lineBreakMode = .byTruncatingMiddle

            if let url = breadcrumbURLs.safe(at: index) {
                button.identifier = NSUserInterfaceItemIdentifier(url.path)
            }
            components.append(button)
        }

        // 2. Measure total width and available width
        let totalWidth = components.reduce(0) { $0 + $1.intrinsicContentSize.width }
        let availableWidth = breadcrumbScrollView.bounds.width - 12 // 6pt padding on each side

        // 3. If oversized, replace middle components with an ellipsis
        if totalWidth > availableWidth {
            var finalComponents: [NSView] = []
            var currentWidth: CGFloat = 0

            // Ellipsis indicator
            let ellipsis = NSTextField(labelWithString: "…")
            ellipsis.textColor = .tertiaryLabelColor
            ellipsis.font = NSFont.systemFont(ofSize: 12)
            ellipsis.alignment = .center
            let ellipsisWidth = ellipsis.intrinsicContentSize.width + 8

            // Add first component (root)
            if let first = components.first {
                finalComponents.append(first)
                currentWidth += first.intrinsicContentSize.width
            }

            // Add components from the end until space runs out
            var tail: [NSView] = []
            for i in stride(from: components.count - 1, to: 0, by: -1) {
                let component = components[i]
                let componentWidth = component.intrinsicContentSize.width
                if currentWidth + ellipsisWidth + componentWidth > availableWidth {
                    break
                }
                tail.insert(component, at: 0)
                currentWidth += componentWidth
            }

            // Add ellipsis if there's a gap
            finalComponents.append(ellipsis)
            finalComponents.append(contentsOf: tail)
            
            components = finalComponents
        }
        
        // 4. Add final components to stack view
        components.forEach(breadcrumbStackView.addArrangedSubview)

        // 5. Scroll to the end to show the most recent path component
        breadcrumbScrollView.documentView?.enclosingScrollView?.contentView.scroll(to: NSPoint(x: breadcrumbStackView.bounds.width, y: 0))
    }

    // MARK: - Actions

    @objc private func searchButtonClicked(_ sender: NSButton) {
        isSearchFieldVisible = true
        searchButton.isHidden = true
        searchButton.isEnabled = false
        searchButton.alphaValue = 0
        
        // Expand search field width and layout
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            searchFieldWidthConstraint.animator().constant = 250
            searchField.isHidden = false
            view.layoutSubtreeIfNeeded()
        } completionHandler: {
            self.view.window?.makeFirstResponder(self.searchField)
            self.adjustOverflowIfNeeded()
        }
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
            menuItem.image = NSImage.mfeSymbol(named: "folder", accessibilityDescription: nil)
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
            menuItem.image = NSImage.mfeSymbol(named: "folder", accessibilityDescription: nil)
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
        delegate?.toolbarDidChangeSortColumn(AppConfig.ColumnID.name, ascending: true)
    }

    @objc private func sortByNameDescending(_ sender: Any) {
        delegate?.toolbarDidChangeSortColumn(AppConfig.ColumnID.name, ascending: false)
    }

    @objc private func sortByDateAscending(_ sender: Any) {
        delegate?.toolbarDidChangeSortColumn(AppConfig.ColumnID.dateModified, ascending: true)
    }

    @objc private func sortByDateDescending(_ sender: Any) {
        delegate?.toolbarDidChangeSortColumn(AppConfig.ColumnID.dateModified, ascending: false)
    }

    @objc private func sortBySizeAscending(_ sender: Any) {
        delegate?.toolbarDidChangeSortColumn(AppConfig.ColumnID.size, ascending: true)
    }

    @objc private func sortBySizeDescending(_ sender: Any) {
        delegate?.toolbarDidChangeSortColumn(AppConfig.ColumnID.size, ascending: false)
    }

    @objc private func sortByTypeAscending(_ sender: Any) {
        delegate?.toolbarDidChangeSortColumn(AppConfig.ColumnID.type, ascending: true)
    }

    @objc private func sortByTypeDescending(_ sender: Any) {
        delegate?.toolbarDidChangeSortColumn(AppConfig.ColumnID.type, ascending: false)
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

    @objc private func viewModeSegmentChanged(_ sender: NSSegmentedControl) {
        let viewModes: [ViewMode] = [.list, .icons, .columns, .windowsList]
        guard sender.selectedSegment >= 0 && sender.selectedSegment < viewModes.count else { return }
        delegate?.toolbarDidChangeViewMode(viewModes[sender.selectedSegment])
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
    
    @objc func filterButtonClicked(_ sender: Any) {
        debugLog("ToolbarViewController: filterButtonClicked")
        delegate?.toolbarDidRequestShowFilter()
    }
}

// MARK: - SettingsStoreDelegate
extension ToolbarViewController {
    func settingsStore(_ settingsStore: SettingsStoreProtocol, previewPaneVisibilityDidChange isVisible: Bool) {
        updatePreviewPaneDisplay(showing: isVisible)
    }
    
    func settingsStore(_ settingsStore: SettingsStoreProtocol, hiddenFilesStateDidChange isVisible: Bool) {
        // Update hidden files button state if it exists
        if let button = hiddenFilesButton {
            button.state = isVisible ? .on : .off
        }
    }
}

// MARK: - NSSearchFieldDelegate
extension ToolbarViewController {
    func controlTextDidEndEditing(_ obj: Notification) {
        // This is called when the search field loses focus
        if isSearchFieldVisible {
            isSearchFieldVisible = false
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                searchFieldWidthConstraint.animator().constant = 30
                searchField.isHidden = true
                searchButton.isHidden = false
                searchButton.isEnabled = true
                searchButton.alphaValue = 1
                view.layoutSubtreeIfNeeded()
            } completionHandler: {
                if self.searchField.stringValue != "" {
                    self.searchField.stringValue = ""
                    self.delegate?.toolbarDidSearchTextChange("")
                }
                self.adjustOverflowIfNeeded()
            }
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
