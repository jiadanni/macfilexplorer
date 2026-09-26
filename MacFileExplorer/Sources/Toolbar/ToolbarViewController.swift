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

/// Single-row pane toolbar:
/// `[‹ ›] Title / breadcrumb ········ [view pill] [tools…] [sort] [filter] [search ⌘F] [×]`
class ToolbarViewController: NSViewController, NSSearchFieldDelegate, SettingsStoreDelegate {

    static let height: CGFloat = 52

    weak var delegate: ToolbarDelegate?

    private let settings: SettingsStoreProtocol

    // Navigation + location
    private var navigationStack: NSStackView!
    private var backButton: ToolbarIconButton!
    private var forwardButton: ToolbarIconButton!
    private var titleLabel: NSTextField!
    private var breadcrumbStackView: NSStackView!

    // Right-hand controls
    private var rightStack: NSStackView!
    private var viewModeControl: PillSegmentedControl!
    private var toolsStack: NSStackView!
    private var hiddenFilesButton: ToolbarIconButton!
    private var splitVerticalButton: ToolbarIconButton!
    private var splitHorizontalButton: ToolbarIconButton!
    private var previewPaneButton: ToolbarIconButton!
    private var openTerminalButton: ToolbarIconButton!
    private var storageAnalyzerButton: ToolbarIconButton!
    private var newFolderButton: ToolbarIconButton!
    private var overflowButton: ToolbarIconButton!
    private let overflowMenu = NSMenu()
    private var sortButton: ToolbarIconButton!
    private let sortMenu = NSMenu()
    private var filterButton: ToolbarIconButton!
    private var searchField: NSSearchField!
    private var searchShortcutLabel: NSTextField!
    private var closePaneButton: ToolbarIconButton!

    private static let viewModes: [ViewMode] = [.list, .icons, .columns, .windowsList]
    private static let searchFieldWidth: CGFloat = 180
    private static let minimumTitleWidth: CGFloat = 120

    private var navigationHistory: [URL] = []
    private var currentHistoryIndex: Int = -1
    private var showingHiddenFiles: Bool = false
    private var sortColumn: String = AppConfig.ColumnID.name
    private var sortAscending = true
    private var accentColorObserver: NSObjectProtocol?

    init(settings: SettingsStoreProtocol = SettingsStore.shared) {
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.settings = SettingsStore.shared
        super.init(coder: coder)
    }

    override func loadView() {
        view = ChromeSurfaceView(fillColor: AppDesignSystem.Chrome.barBackground)
        view.frame = NSRect(x: 0, y: 0, width: 800, height: Self.height)
        setupUI()
        settings.addDelegate(self)
        NotificationCenter.default.addObserver(self, selector: #selector(handleToolbarSettingsChanged(_:)), name: .toolbarSettingsDidChangeNotification, object: nil)
        accentColorObserver = NotificationCenter.default.addObserver(forName: .accentColorDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.allIconButtons.forEach { $0.refreshAccent() }
        }
        updatePreviewPaneDisplay(showing: settings.previewPaneVisible)
        updateTerminalDisplay(showing: settings.terminalIsVisible)
        applyVisibilityPreferences()
    }

    deinit {
        settings.removeDelegate(self)
        NotificationCenter.default.removeObserver(self, name: .toolbarSettingsDidChangeNotification, object: nil)
        if let accentColorObserver {
            NotificationCenter.default.removeObserver(accentColorObserver)
        }
    }

    // MARK: - Setup

    private func setupUI() {
        let bottomBorder = HairlineView(color: AppDesignSystem.Chrome.barBorder)
        view.addSubview(bottomBorder)

        // Navigation
        backButton = makeButton("chevron.left", label: L10n.text("Back"), toolTip: L10n.text("Back (⌘[)"), action: #selector(backButtonClicked(_:)))
        backButton.sendAction(on: [.leftMouseDown, .rightMouseDown])
        backButton.isEnabled = false
        forwardButton = makeButton("chevron.right", label: L10n.text("Forward"), toolTip: L10n.text("Forward (⌘])"), action: #selector(forwardButtonClicked(_:)))
        forwardButton.sendAction(on: [.leftMouseDown, .rightMouseDown])
        forwardButton.isEnabled = false

        navigationStack = NSStackView(views: [backButton, forwardButton])
        navigationStack.orientation = .horizontal
        navigationStack.spacing = 2
        navigationStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navigationStack)

        // Title + breadcrumb subtitle
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = AppDesignSystem.Typography.toolbarTitle
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setAccessibilityIdentifier("ToolbarTitle")

        breadcrumbStackView = NSStackView()
        breadcrumbStackView.orientation = .horizontal
        breadcrumbStackView.spacing = 2
        breadcrumbStackView.alignment = .centerY
        breadcrumbStackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        breadcrumbStackView.setClippingResistancePriority(.defaultLow, for: .horizontal)
        breadcrumbStackView.setAccessibilityLabel(L10n.text("Path"))

        let titleStack = NSStackView(views: [titleLabel, breadcrumbStackView])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 0
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        titleStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleStack.setClippingResistancePriority(.defaultLow, for: .horizontal)
        view.addSubview(titleStack)

        // View mode pill
        viewModeControl = PillSegmentedControl(segments: [
            .init(symbolName: "list.bullet", label: L10n.text("List View"), toolTip: L10n.text("List View (⌘1)")),
            .init(symbolName: "square.grid.2x2", label: L10n.text("Icons View"), toolTip: L10n.text("Icons View (⌘2)")),
            .init(symbolName: "rectangle.split.3x1", label: L10n.text("Columns View"), toolTip: L10n.text("Columns View (⌘3)")),
            .init(symbolName: "list.bullet.rectangle", label: L10n.text("Windows List View"), toolTip: L10n.text("Windows List View (⌘4)"))
        ])
        viewModeControl.setAccessibilityLabel(L10n.text("View Mode"))
        viewModeControl.onSelectionChange = { [weak self] index in
            guard let mode = Self.viewModes.safe(at: index) else { return }
            self?.delegate?.toolbarDidChangeViewMode(mode)
        }

        // Tool toggles, in the order shown by the design
        hiddenFilesButton = makeButton("eye", label: L10n.text("Toggle hidden files"), toolTip: L10n.text("Show Hidden Files (⇧⌘.)"), action: #selector(toggleHiddenFiles(_:)))
        hiddenFilesButton.isToggle = true
        splitVerticalButton = makeButton("rectangle.split.2x1", label: L10n.text("Split view vertically"), toolTip: L10n.text("Split View Vertically"), action: #selector(splitVerticallyClicked(_:)))
        splitHorizontalButton = makeButton("rectangle.split.1x2", label: L10n.text("Split view horizontally"), toolTip: L10n.text("Split View Horizontally"), action: #selector(splitHorizontallyClicked(_:)))
        previewPaneButton = makeButton("sidebar.right", label: L10n.text("Toggle preview pane"), toolTip: L10n.text("Show Preview Pane"), action: #selector(togglePreviewPaneClicked(_:)))
        previewPaneButton.isToggle = true
        openTerminalButton = makeButton("terminal", label: L10n.text("Toggle terminal"), toolTip: L10n.text("Show Terminal"), action: #selector(openTerminalButtonClicked(_:)))
        openTerminalButton.isToggle = true
        storageAnalyzerButton = makeButton("chart.pie", label: L10n.text("Open Storage Analyzer"), toolTip: L10n.text("Storage Analyzer"), action: #selector(storageAnalyzerButtonClicked(_:)))
        newFolderButton = makeButton("folder.badge.plus", label: L10n.text("New Folder"), toolTip: L10n.text("New Folder (⇧⌘N)"), action: #selector(newFolderButtonClicked(_:)))

        toolsStack = NSStackView(views: [hiddenFilesButton, splitVerticalButton, splitHorizontalButton, previewPaneButton, openTerminalButton, storageAnalyzerButton, newFolderButton])
        toolsStack.orientation = .horizontal
        toolsStack.spacing = 2

        overflowButton = makeButton("ellipsis", label: L10n.text("More options"), toolTip: L10n.text("More"), action: #selector(overflowButtonClicked(_:)))
        overflowButton.isHidden = true

        // Sort: icon button + menu (checkmark marks the active sort)
        sortButton = makeButton("arrow.up.arrow.down", label: L10n.text("Sort Options"), toolTip: L10n.text("Sort Options"), action: #selector(sortButtonClicked(_:)))
        buildSortMenu()

        filterButton = makeButton("line.3.horizontal.decrease.circle", label: L10n.text("Filter Files"), toolTip: L10n.text("Filter Files"), action: #selector(filterButtonClicked(_:)))

        // Always-visible search field with a ⌘F hint
        searchField = NSSearchField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = L10n.text("Search")
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.sendsWholeSearchString = false
        searchField.sendsSearchStringImmediately = true
        searchField.toolTip = L10n.text("Search (⌘F)")
        searchField.delegate = self
        searchField.setAccessibilityLabel(L10n.text("Search files"))

        searchShortcutLabel = NSTextField(labelWithString: "⌘F")
        searchShortcutLabel.font = AppDesignSystem.Typography.caption
        searchShortcutLabel.textColor = .tertiaryLabelColor
        searchShortcutLabel.translatesAutoresizingMaskIntoConstraints = false
        searchShortcutLabel.setAccessibilityElement(false)
        searchField.addSubview(searchShortcutLabel)

        closePaneButton = makeButton("xmark", label: L10n.text("Close Pane"), toolTip: L10n.text("Close Pane (⌘W)"), action: #selector(closePaneButtonClicked(_:)))
        closePaneButton.isHidden = true // Shown when there are multiple panes

        rightStack = NSStackView(views: [viewModeControl, toolsStack, overflowButton, sortButton, filterButton, searchField, closePaneButton])
        rightStack.orientation = .horizontal
        rightStack.alignment = .centerY
        rightStack.spacing = 8
        rightStack.setCustomSpacing(2, after: toolsStack)
        rightStack.setCustomSpacing(2, after: overflowButton)
        rightStack.setCustomSpacing(2, after: sortButton)
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rightStack)

        NSLayoutConstraint.activate([
            bottomBorder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBorder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBorder.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            navigationStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            navigationStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            titleStack.leadingAnchor.constraint(equalTo: navigationStack.trailingAnchor, constant: 10),
            titleStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            titleStack.trailingAnchor.constraint(lessThanOrEqualTo: rightStack.leadingAnchor, constant: -12),

            rightStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            rightStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            searchField.widthAnchor.constraint(equalToConstant: Self.searchFieldWidth),
            searchShortcutLabel.trailingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: -8),
            searchShortcutLabel.centerYAnchor.constraint(equalTo: searchField.centerYAnchor)
        ])
    }

    private var allIconButtons: [ToolbarIconButton] {
        [backButton, forwardButton, hiddenFilesButton, splitVerticalButton, splitHorizontalButton, previewPaneButton,
         openTerminalButton, storageAnalyzerButton, newFolderButton, overflowButton, sortButton, filterButton, closePaneButton]
    }

    private func makeButton(_ symbol: String, label: String, toolTip: String, action: Selector) -> ToolbarIconButton {
        let button = ToolbarIconButton(symbolName: symbol, accessibilityDescription: label)
        button.toolTip = toolTip
        button.target = self
        button.action = action
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }

    private func buildSortMenu() {
        let entries: [(title: String, column: String, ascending: Bool)] = [
            (L10n.text("Name ↑"), AppConfig.ColumnID.name, true),
            (L10n.text("Name ↓"), AppConfig.ColumnID.name, false),
            (L10n.text("Date Modified ↑"), AppConfig.ColumnID.dateModified, true),
            (L10n.text("Date Modified ↓"), AppConfig.ColumnID.dateModified, false),
            (L10n.text("Size ↑"), AppConfig.ColumnID.size, true),
            (L10n.text("Size ↓"), AppConfig.ColumnID.size, false),
            (L10n.text("Kind ↑"), AppConfig.ColumnID.type, true),
            (L10n.text("Kind ↓"), AppConfig.ColumnID.type, false)
        ]
        sortMenu.removeAllItems()
        for (index, entry) in entries.enumerated() {
            if index > 0 && index % 2 == 0 { sortMenu.addItem(.separator()) }
            let item = NSMenuItem(title: entry.title, action: #selector(sortMenuItemSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = SortChoice(column: entry.column, ascending: entry.ascending)
            sortMenu.addItem(item)
        }
        refreshSortMenuState()
    }

    private final class SortChoice: NSObject {
        let column: String
        let ascending: Bool
        init(column: String, ascending: Bool) {
            self.column = column
            self.ascending = ascending
        }
    }

    // MARK: - Visibility Preferences

    @objc private func handleToolbarSettingsChanged(_ notification: Notification) {
        applyVisibilityPreferences()
    }

    private func applyVisibilityPreferences() {
        navigationStack.isHidden = !settings.showBackForwardButtons
        viewModeControl.isHidden = !settings.showViewModeButton
        sortButton.isHidden = !settings.showSortButton
        view.needsLayout = true
    }

    private func isButtonVisible(_ button: NSButton) -> Bool {
        switch button {
        case hiddenFilesButton: return settings.showHiddenFilesButton
        case splitVerticalButton, splitHorizontalButton: return settings.showSplitButtons
        case previewPaneButton: return settings.showPreviewPaneButton
        case newFolderButton: return settings.showNewFolderButton
        case storageAnalyzerButton: return settings.showStorageAnalyzerButton
        case openTerminalButton: return settings.showOpenTerminalButton
        default: return true
        }
    }

    // MARK: - Public Methods

    func updatePath(_ url: URL, canGoBack: Bool, canGoForward: Bool, history: [URL] = [], currentIndex: Int = -1) {
        navigationHistory = history
        currentHistoryIndex = currentIndex

        backButton.isEnabled = canGoBack
        forwardButton.isEnabled = canGoForward

        titleLabel.stringValue = FileManager.default.displayName(atPath: url.path)
        updateBreadcrumbs(for: url)
    }

    func updateViewModeDisplay(for viewMode: ViewMode) {
        if let index = Self.viewModes.firstIndex(of: viewMode) {
            viewModeControl.selectSegment(index)
        }
    }

    func updateHiddenFilesDisplay(showing: Bool) {
        showingHiddenFiles = showing
        hiddenFilesButton.state = showing ? .on : .off
        hiddenFilesButton.toolTip = showing ? "Hide Hidden Files (⇧⌘.)" : "Show Hidden Files (⇧⌘.)"
    }

    func updateSortDisplay(column: String, ascending: Bool) {
        sortColumn = column
        sortAscending = ascending
        refreshSortMenuState()

        let columnName: String
        switch column {
        case AppConfig.ColumnID.name: columnName = "Name"
        case AppConfig.ColumnID.dateModified: columnName = "Date Modified"
        case AppConfig.ColumnID.size: columnName = "Size"
        case AppConfig.ColumnID.type: columnName = "Kind"
        case AppConfig.ColumnID.dateCreated: columnName = "Date Created"
        default: columnName = "Sort"
        }
        sortButton.toolTip = "Sorted by \(columnName) \(ascending ? "↑" : "↓")"
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
        view.needsLayout = true
    }

    func updatePreviewPaneDisplay(showing: Bool) {
        previewPaneButton.state = showing ? .on : .off
        previewPaneButton.toolTip = showing ? "Hide Preview Pane" : "Show Preview Pane"
    }

    func updateTerminalDisplay(showing: Bool) {
        openTerminalButton.state = showing ? .on : .off
        openTerminalButton.toolTip = showing ? "Hide Terminal" : "Show Terminal"
    }

    func focusSearchField() {
        view.window?.makeFirstResponder(searchField)
    }

    // MARK: - Testing

    var testingHiddenFilesButtonState: NSControl.StateValue {
        hiddenFilesButton.state
    }

    var testingPreviewPaneButtonToolTip: String? {
        previewPaneButton.toolTip
    }

    // MARK: - Layout

    override func viewDidLayout() {
        super.viewDidLayout()
        adjustOverflowIfNeeded()
    }

    /// Moves tool buttons that don't fit into the "…" overflow menu. Widths come
    /// from intrinsic sizes rather than current frames so the pass is stable
    /// even though it toggles `isHidden` during layout.
    private func adjustOverflowIfNeeded() {
        let navigationWidth = navigationStack.isHidden ? 0 : navigationStack.fittingSize.width + 10
        let available = view.bounds.width - 12 - navigationWidth - Self.minimumTitleWidth - 12 - 12

        // Controls on the right that never overflow
        let fixedViews: [NSView] = [viewModeControl, sortButton, filterButton, searchField, closePaneButton].filter { !$0.isHidden }
        let fixedWidth = fixedViews.reduce(CGFloat(0)) { total, subview in
            let width = subview === searchField ? Self.searchFieldWidth : subview.intrinsicContentSize.width
            return total + width + rightStack.spacing
        }

        let buttonWidth: CGFloat = 30 + toolsStack.spacing
        let candidateCount = toolsStack.arrangedSubviews.filter { ($0 as? NSButton).map(isButtonVisible) ?? false }.count
        var remaining = available - fixedWidth
        if CGFloat(candidateCount) * buttonWidth > remaining {
            remaining -= buttonWidth // reserve room for the "…" button
        }

        var overflowItems: [ToolbarIconButton] = []
        var used: CGFloat = 0
        for subview in toolsStack.arrangedSubviews {
            guard let button = subview as? ToolbarIconButton else { continue }
            let shouldShow: Bool
            if !isButtonVisible(button) {
                shouldShow = false
            } else if used + buttonWidth <= remaining {
                shouldShow = true
                used += buttonWidth
            } else {
                shouldShow = false
                overflowItems.append(button)
            }
            if button.isHidden == shouldShow { button.isHidden = !shouldShow }
        }

        let overflowHidden = overflowItems.isEmpty
        if overflowButton.isHidden != overflowHidden { overflowButton.isHidden = overflowHidden }
        overflowMenu.removeAllItems()
        for button in overflowItems {
            let item = NSMenuItem(title: button.toolTip ?? "", action: button.action, keyEquivalent: "")
            item.target = button.target
            item.image = button.image
            item.state = button.isToggle ? button.state : .off
            item.isEnabled = button.isEnabled
            overflowMenu.addItem(item)
        }
    }

    // MARK: - Breadcrumbs

    /// Renders the path under the title as small clickable segments, e.g.
    /// `Users › daniel › Desktop`. Deep paths keep the last few segments and
    /// collapse the rest into "…".
    private func updateBreadcrumbs(for url: URL) {
        breadcrumbStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        var segments: [(title: String, url: URL)] = []
        var partial = URL(fileURLWithPath: "/")
        for component in url.pathComponents where component != "/" {
            partial.appendPathComponent(component)
            segments.append((component, partial))
        }
        if segments.isEmpty {
            segments.append((FileManager.default.displayName(atPath: "/"), partial))
        }

        let maxSegments = 4
        let collapsed = segments.count > maxSegments
        let visibleSegments = collapsed ? Array(segments.suffix(maxSegments)) : segments

        if collapsed {
            breadcrumbStackView.addArrangedSubview(makeBreadcrumbSeparator("… ›"))
        }
        for (index, segment) in visibleSegments.enumerated() {
            if index > 0 {
                breadcrumbStackView.addArrangedSubview(makeBreadcrumbSeparator("›"))
            }
            let button = NSButton(title: segment.title, target: self, action: #selector(breadcrumbClicked(_:)))
            button.isBordered = false
            button.attributedTitle = NSAttributedString(string: segment.title, attributes: [
                .font: AppDesignSystem.Typography.toolbarSubtitle,
                .foregroundColor: NSColor.secondaryLabelColor
            ])
            button.lineBreakMode = .byTruncatingMiddle
            button.identifier = NSUserInterfaceItemIdentifier(segment.url.path)
            button.toolTip = segment.url.path
            button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            breadcrumbStackView.addArrangedSubview(button)
        }
    }

    private func makeBreadcrumbSeparator(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = AppDesignSystem.Typography.toolbarSubtitle
        label.textColor = .tertiaryLabelColor
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    // MARK: - Actions

    @objc private func backButtonClicked(_ sender: NSButton) {
        if NSApp.currentEvent?.type == .rightMouseDown {
            showHistoryMenu(for: sender, indices: Array(stride(from: currentHistoryIndex - 1, through: 0, by: -1)))
        } else {
            delegate?.toolbarDidRequestBack()
        }
    }

    @objc private func forwardButtonClicked(_ sender: NSButton) {
        if NSApp.currentEvent?.type == .rightMouseDown {
            let start = currentHistoryIndex + 1
            guard start < navigationHistory.count else { return }
            showHistoryMenu(for: sender, indices: Array(start..<navigationHistory.count))
        } else {
            delegate?.toolbarDidRequestForward()
        }
    }

    private func showHistoryMenu(for button: NSButton, indices: [Int]) {
        guard !indices.isEmpty else { return }
        let menu = NSMenu()
        for i in indices {
            guard let url = navigationHistory.safe(at: i) else { continue }
            let displayName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
            let menuItem = NSMenuItem(title: displayName, action: #selector(historyItemClicked(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.tag = i
            menuItem.image = NSImage.mfeSymbol(named: "folder", accessibilityDescription: nil)
            menu.addItem(menuItem)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    @objc private func historyItemClicked(_ sender: NSMenuItem) {
        delegate?.toolbarDidRequestNavigateToHistoryIndex(sender.tag)
    }

    @objc private func breadcrumbClicked(_ sender: NSButton) {
        guard let pathString = sender.identifier?.rawValue else { return }
        delegate?.toolbarDidRequestNavigate(to: URL(fileURLWithPath: pathString))
    }

    @objc private func sortButtonClicked(_ sender: NSButton) {
        refreshSortMenuState()
        sortMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @objc private func sortMenuItemSelected(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? SortChoice else { return }
        delegate?.toolbarDidChangeSortColumn(choice.column, ascending: choice.ascending)
    }

    private func refreshSortMenuState() {
        for item in sortMenu.items {
            guard let choice = item.representedObject as? SortChoice else { continue }
            item.state = (choice.column == sortColumn && choice.ascending == sortAscending) ? .on : .off
        }
    }

    @objc private func overflowButtonClicked(_ sender: NSButton) {
        overflowMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @objc private func newFolderButtonClicked(_ sender: Any) {
        delegate?.toolbarDidRequestNewFolder()
    }

    @objc private func toggleHiddenFiles(_ sender: Any) {
        let show = !showingHiddenFiles
        updateHiddenFilesDisplay(showing: show)
        delegate?.toolbarDidToggleHiddenFiles(show: show)
    }

    @objc private func splitVerticallyClicked(_ sender: Any) {
        delegate?.toolbarDidRequestSplitVertically()
    }

    @objc private func splitHorizontallyClicked(_ sender: Any) {
        delegate?.toolbarDidRequestSplitHorizontally()
    }

    @objc private func togglePreviewPaneClicked(_ sender: Any) {
        // State is re-synced from the preview coordinator via updatePreviewPaneDisplay
        delegate?.toolbarDidTogglePreviewPane()
    }

    @objc private func closePaneButtonClicked(_ sender: Any) {
        delegate?.toolbarDidRequestClosePane()
    }

    @objc private func storageAnalyzerButtonClicked(_ sender: Any) {
        // Walk up to the TabBarController and open Storage Analyzer in a tab
        var controller: NSViewController? = parent
        while let current = controller {
            if let tabBarController = current as? TabBarController {
                tabBarController.openStorageAnalyzerTab()
                return
            }
            controller = current.parent
        }
    }

    @objc private func openTerminalButtonClicked(_ sender: Any) {
        // Hide via the settings store (SplitViewController observes it and routes
        // through TerminalVisibilityCoordinator); show at this pane's directory.
        if settings.terminalIsVisible {
            settings.terminalIsVisible = false
        } else {
            delegate?.toolbarDidRequestOpenInTerminal()
        }
        updateTerminalDisplay(showing: settings.terminalIsVisible)
    }

    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        searchShortcutLabel.isHidden = !sender.stringValue.isEmpty
        delegate?.toolbarDidSearchTextChange(sender.stringValue)
    }

    @objc func filterButtonClicked(_ sender: Any) {
        delegate?.toolbarDidRequestShowFilter()
    }
}

// MARK: - SettingsStoreDelegate
extension ToolbarViewController {
    func settingsStore(_ settingsStore: SettingsStoreProtocol, previewPaneVisibilityDidChange isVisible: Bool) {
        updatePreviewPaneDisplay(showing: isVisible)
    }

    func settingsStore(_ settingsStore: SettingsStoreProtocol, hiddenFilesStateDidChange isVisible: Bool) {
        updateHiddenFilesDisplay(showing: isVisible)
    }

    func settingsStore(_ settingsStore: SettingsStoreProtocol, terminalVisibilityDidChange isVisible: Bool) {
        updateTerminalDisplay(showing: isVisible)
    }
}

// MARK: - NSSearchFieldDelegate
extension ToolbarViewController {
    func controlTextDidChange(_ obj: Notification) {
        searchShortcutLabel.isHidden = !searchField.stringValue.isEmpty
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            // Escape clears the search and gives up focus
            searchField.stringValue = ""
            searchShortcutLabel.isHidden = false
            delegate?.toolbarDidSearchTextChange("")
            view.window?.makeFirstResponder(nil)
            return true
        }
        return false
    }
}
