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
}

class ToolbarViewController: NSViewController {

    weak var delegate: ToolbarDelegate?

    private var backButton: NSButton!
    private var forwardButton: NSButton!
    private var breadcrumbStackView: NSStackView!
    private var breadcrumbScrollView: NSScrollView!
    private var sortButton: NSPopUpButton!
    private var viewModeButton: NSPopUpButton!
    private var hiddenFilesButton: NSButton!
    private var splitVerticalButton: NSButton!
    private var splitHorizontalButton: NSButton!
    private var newFolderButton: NSButton!
    private var closePaneButton: NSButton!

    private var currentURL: URL?
    private var canGoBack: Bool = false
    private var canGoForward: Bool = false
    private var navigationHistory: [URL] = []
    private var currentHistoryIndex: Int = -1
    private var showingHiddenFiles: Bool = false

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 40))
        setupUI()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Load toolbar visibility settings from UserDefaults
        let showBackForward = UserDefaults.standard.object(forKey: UserDefaults.Keys.showBackForwardButtons.rawValue) as? Bool ?? true
        let showViewMode = UserDefaults.standard.object(forKey: UserDefaults.Keys.showViewModeButton.rawValue) as? Bool ?? true
        let showHiddenFiles = UserDefaults.standard.object(forKey: UserDefaults.Keys.showHiddenFilesButton.rawValue) as? Bool ?? true
        let showSplit = UserDefaults.standard.object(forKey: UserDefaults.Keys.showSplitButtons.rawValue) as? Bool ?? true
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

        // View Mode button
        viewModeButton = NSPopUpButton()
        viewModeButton.translatesAutoresizingMaskIntoConstraints = false
        viewModeButton.bezelStyle = .texturedRounded
        viewModeButton.pullsDown = false
        
        // Add view mode options
        for mode in ViewMode.allCases {
            let menuItem = NSMenuItem(title: mode.rawValue, action: #selector(changeViewMode(_:)), keyEquivalent: "")
            menuItem.representedObject = mode.rawValue
            viewModeButton.menu?.addItem(menuItem)
        }
        viewModeButton.menu?.items.forEach { $0.target = self }
        viewModeButton.isHidden = !showViewMode
        view.addSubview(viewModeButton)
        
        // Hidden Files toggle button
        hiddenFilesButton = NSButton()
        hiddenFilesButton.translatesAutoresizingMaskIntoConstraints = false
        hiddenFilesButton.bezelStyle = .texturedRounded
        hiddenFilesButton.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "Show Hidden Files")
        hiddenFilesButton.target = self
        hiddenFilesButton.action = #selector(toggleHiddenFiles(_:))
        hiddenFilesButton.isHidden = !showHiddenFiles
        view.addSubview(hiddenFilesButton)
        
        // Split Vertical button
        splitVerticalButton = NSButton()
        splitVerticalButton.translatesAutoresizingMaskIntoConstraints = false
        splitVerticalButton.bezelStyle = .texturedRounded
        splitVerticalButton.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Split Vertically")
        splitVerticalButton.target = self
        splitVerticalButton.action = #selector(splitVerticallyClicked(_:))
        splitVerticalButton.isHidden = !showSplit
        view.addSubview(splitVerticalButton)
        
        // Split Horizontal button
        splitHorizontalButton = NSButton()
        splitHorizontalButton.translatesAutoresizingMaskIntoConstraints = false
        splitHorizontalButton.bezelStyle = .texturedRounded
        splitHorizontalButton.image = NSImage(systemSymbolName: "rectangle.split.1x2", accessibilityDescription: "Split Horizontally")
        splitHorizontalButton.target = self
        splitHorizontalButton.action = #selector(splitHorizontallyClicked(_:))
        splitHorizontalButton.isHidden = !showSplit
        view.addSubview(splitHorizontalButton)

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
        sortButton.isHidden = !showSort
        view.addSubview(sortButton)

        // New Folder button
        newFolderButton = NSButton()
        newFolderButton.translatesAutoresizingMaskIntoConstraints = false
        newFolderButton.bezelStyle = .texturedRounded
        newFolderButton.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: "New Folder")
        newFolderButton.target = self
        newFolderButton.action = #selector(newFolderButtonClicked(_:))
        newFolderButton.isHidden = !showNewFolder
        view.addSubview(newFolderButton)

        // Close Pane button
        closePaneButton = NSButton()
        closePaneButton.translatesAutoresizingMaskIntoConstraints = false
        closePaneButton.bezelStyle = .texturedRounded
        closePaneButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close Pane")
        closePaneButton.target = self
        closePaneButton.action = #selector(closePaneButtonClicked(_:))
        closePaneButton.isHidden = true // Hidden by default, shown when there are multiple panes
        view.addSubview(closePaneButton)

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
            breadcrumbScrollView.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
            breadcrumbScrollView.trailingAnchor.constraint(lessThanOrEqualTo: viewModeButton.leadingAnchor, constant: -8),

            breadcrumbStackView.leadingAnchor.constraint(equalTo: breadcrumbScrollView.leadingAnchor),
            breadcrumbStackView.topAnchor.constraint(equalTo: breadcrumbScrollView.topAnchor),
            breadcrumbStackView.bottomAnchor.constraint(equalTo: breadcrumbScrollView.bottomAnchor),

            viewModeButton.trailingAnchor.constraint(equalTo: hiddenFilesButton.leadingAnchor, constant: -4),
            viewModeButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            viewModeButton.widthAnchor.constraint(equalToConstant: 70),
            viewModeButton.heightAnchor.constraint(equalToConstant: 26),
            
            hiddenFilesButton.trailingAnchor.constraint(equalTo: splitVerticalButton.leadingAnchor, constant: -4),
            hiddenFilesButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            hiddenFilesButton.widthAnchor.constraint(equalToConstant: 30),
            hiddenFilesButton.heightAnchor.constraint(equalToConstant: 26),
            
            splitVerticalButton.trailingAnchor.constraint(equalTo: splitHorizontalButton.leadingAnchor, constant: -4),
            splitVerticalButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            splitVerticalButton.widthAnchor.constraint(equalToConstant: 30),
            splitVerticalButton.heightAnchor.constraint(equalToConstant: 26),
            
            splitHorizontalButton.trailingAnchor.constraint(equalTo: newFolderButton.leadingAnchor, constant: -8),
            splitHorizontalButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            splitHorizontalButton.widthAnchor.constraint(equalToConstant: 30),
            splitHorizontalButton.heightAnchor.constraint(equalToConstant: 26),

            newFolderButton.trailingAnchor.constraint(equalTo: sortButton.leadingAnchor, constant: -8),
            newFolderButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            newFolderButton.widthAnchor.constraint(equalToConstant: 30),
            newFolderButton.heightAnchor.constraint(equalToConstant: 26),

            sortButton.trailingAnchor.constraint(equalTo: closePaneButton.leadingAnchor, constant: -8),
            sortButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            sortButton.widthAnchor.constraint(equalToConstant: 44),
            sortButton.heightAnchor.constraint(equalToConstant: 26),

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
        // Select the appropriate menu item in the view mode button
        if let index = ViewMode.allCases.firstIndex(of: viewMode) {
            viewModeButton.selectItem(at: index)
        }
    }
    
    func updateHiddenFilesDisplay(showing: Bool) {
        showingHiddenFiles = showing
        if showing {
            hiddenFilesButton.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Hide Hidden Files")
        } else {
            hiddenFilesButton.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "Show Hidden Files")
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

    func setClosePaneButtonVisible(_ visible: Bool) {
        closePaneButton.isHidden = !visible
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
            button.title = component
            button.bezelStyle = .roundRect
            button.isBordered = false
            button.font = NSFont.systemFont(ofSize: 12)
            button.target = self
            button.action = #selector(breadcrumbClicked(_:))
            
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

    @objc private func changeViewMode(_ sender: NSMenuItem) {
        if let rawValue = sender.representedObject as? String,
           let selectedMode = ViewMode(rawValue: rawValue) {
            delegate?.toolbarDidChangeViewMode(selectedMode)
        }
    }

    @objc private func splitVerticallyClicked(_ sender: Any) {
        delegate?.toolbarDidRequestSplitVertically()
    }

    @objc private func splitHorizontallyClicked(_ sender: Any) {
        delegate?.toolbarDidRequestSplitHorizontally()
    }

    @objc private func closePaneButtonClicked(_ sender: Any) {
        delegate?.toolbarDidRequestClosePane()
    }
}
