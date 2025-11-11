import Cocoa

enum ViewMode: String, CaseIterable {
    case list = "List"
    case details = "Details"
    case icons = "Icons"
    case columns = "Columns"
    case windowsList = "Windows List" // This will be more complex to implement
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
}

class ToolbarViewController: NSViewController {

    weak var delegate: ToolbarDelegate?

    private var backButton: NSButton!
    private var forwardButton: NSButton!
    private var breadcrumbStackView: NSStackView!
    private var breadcrumbScrollView: NSScrollView!
    private var sortButton: NSPopUpButton!
    private var viewButton: NSPopUpButton!
    private var newFolderButton: NSButton!

    private var currentURL: URL?
    private var canGoBack: Bool = false
    private var canGoForward: Bool = false
    private var navigationHistory: [URL] = []
    private var currentHistoryIndex: Int = -1

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 40))
        setupUI()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Back button
        backButton = NSButton()
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.bezelStyle = .texturedRounded
        backButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")
        backButton.target = self
        backButton.action = #selector(backButtonClicked(_:))
        backButton.isEnabled = false
        backButton.sendAction(on: [.leftMouseDown, .rightMouseDown])
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

        // View button
        viewButton = NSPopUpButton()
        viewButton.translatesAutoresizingMaskIntoConstraints = false
        viewButton.bezelStyle = .texturedRounded
        viewButton.pullsDown = false // Change to false so the selected item is displayed
        // No initial "View" item, the selected item will be displayed as the title


        viewButton.menu?.addItem(withTitle: "Show Hidden Files", action: #selector(showHiddenFiles(_:)), keyEquivalent: "")
        viewButton.menu?.addItem(withTitle: "Hide Hidden Files", action: #selector(hideHiddenFiles(_:)), keyEquivalent: "")
        viewButton.menu?.addItem(NSMenuItem.separator())

        // Add view mode options
        for mode in ViewMode.allCases {
            let menuItem = NSMenuItem(title: mode.rawValue, action: #selector(changeViewMode(_:)), keyEquivalent: "")
            menuItem.representedObject = mode.rawValue // Use rawValue as a stable identifier
            viewButton.menu?.addItem(menuItem)
        }
        viewButton.menu?.addItem(NSMenuItem.separator())
        viewButton.menu?.addItem(withTitle: "Split Vertically", action: #selector(splitVerticallyClicked(_:)), keyEquivalent: "")
        viewButton.menu?.addItem(withTitle: "Split Horizontally", action: #selector(splitHorizontallyClicked(_:)), keyEquivalent: "")
        viewButton.menu?.items.forEach { $0.target = self }
        view.addSubview(viewButton)

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
        view.addSubview(sortButton)

        // New Folder button
        newFolderButton = NSButton()
        newFolderButton.translatesAutoresizingMaskIntoConstraints = false
        newFolderButton.bezelStyle = .texturedRounded
        newFolderButton.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: "New Folder")
        newFolderButton.target = self
        newFolderButton.action = #selector(newFolderButtonClicked(_:))
        view.addSubview(newFolderButton)

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
            breadcrumbScrollView.trailingAnchor.constraint(equalTo: viewButton.leadingAnchor, constant: -8),
            breadcrumbScrollView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            breadcrumbScrollView.heightAnchor.constraint(equalToConstant: 26),

            breadcrumbStackView.leadingAnchor.constraint(equalTo: breadcrumbScrollView.leadingAnchor),
            breadcrumbStackView.topAnchor.constraint(equalTo: breadcrumbScrollView.topAnchor),
            breadcrumbStackView.bottomAnchor.constraint(equalTo: breadcrumbScrollView.bottomAnchor),

            viewButton.trailingAnchor.constraint(equalTo: newFolderButton.leadingAnchor, constant: -8),
            viewButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            viewButton.widthAnchor.constraint(equalToConstant: 44),
            viewButton.heightAnchor.constraint(equalToConstant: 26),

            newFolderButton.trailingAnchor.constraint(equalTo: sortButton.leadingAnchor, constant: -8),
            newFolderButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            newFolderButton.widthAnchor.constraint(equalToConstant: 30),
            newFolderButton.heightAnchor.constraint(equalToConstant: 26),

            sortButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            sortButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            sortButton.widthAnchor.constraint(equalToConstant: 44),
            sortButton.heightAnchor.constraint(equalToConstant: 26)
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
        viewButton.title = viewMode.rawValue
        // Optionally update image based on viewMode
        switch viewMode {
        case .list:
            viewButton.image = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "List View")
        case .details:
            viewButton.image = NSImage(systemSymbolName: "tablecells", accessibilityDescription: "Details View")
        case .icons:
            viewButton.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Icons View")
        case .columns:
            viewButton.image = NSImage(systemSymbolName: "sidebar.leading", accessibilityDescription: "Columns View")
        case .windowsList:
            viewButton.image = NSImage(systemSymbolName: "list.bullet.rectangle.portrait", accessibilityDescription: "Windows List View")
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

    private func updateBreadcrumbs(for url: URL) {
        // Clear existing breadcrumbs
        breadcrumbStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let pathComponents = url.pathComponents
        var currentPathURL = URL(fileURLWithPath: "/")

        for (index, component) in pathComponents.enumerated() {
            // Skip the first empty component if path is "/"
            if component.isEmpty && index == 0 && pathComponents.count > 1 {
                continue
            }

            // Add separator (except before first actual component)
            if index > 0 && !(component.isEmpty && index == 0) {
                let separator = NSTextField(labelWithString: " ▸ ")
                separator.textColor = .secondaryLabelColor
                separator.font = NSFont.systemFont(ofSize: 12)
                breadcrumbStackView.addArrangedSubview(separator)
            }

            // Create breadcrumb button
            let button = NSButton()
            button.bezelStyle = .roundRect
            button.isBordered = false
            button.font = NSFont.systemFont(ofSize: 12)
            button.target = self
            button.action = #selector(breadcrumbClicked(_:))

            if component == "/" && index == 0 {
                button.title = "/"
                currentPathURL = URL(fileURLWithPath: "/")
            } else {
                button.title = component
                currentPathURL.appendPathComponent(component)
            }
            button.identifier = NSUserInterfaceItemIdentifier(currentPathURL.path)

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

    @objc private func showHiddenFiles(_ sender: Any) {
        delegate?.toolbarDidToggleHiddenFiles(show: true)
    }

    @objc private func hideHiddenFiles(_ sender: Any) {
        delegate?.toolbarDidToggleHiddenFiles(show: false)
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
}
