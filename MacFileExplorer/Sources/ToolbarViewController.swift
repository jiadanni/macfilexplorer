import Cocoa

protocol ToolbarDelegate: AnyObject {
    func toolbarDidRequestBack()
    func toolbarDidRequestForward()
    func toolbarDidRequestNavigate(to url: URL)
    func toolbarDidChangeSortColumn(_ column: String, ascending: Bool)
}

class ToolbarViewController: NSViewController {

    weak var delegate: ToolbarDelegate?

    private var backButton: NSButton!
    private var forwardButton: NSButton!
    private var breadcrumbStackView: NSStackView!
    private var breadcrumbScrollView: NSScrollView!
    private var sortButton: NSPopUpButton!

    private var currentURL: URL?
    private var canGoBack: Bool = false
    private var canGoForward: Bool = false

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
        view.addSubview(backButton)

        // Forward button
        forwardButton = NSButton()
        forwardButton.translatesAutoresizingMaskIntoConstraints = false
        forwardButton.bezelStyle = .texturedRounded
        forwardButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward")
        forwardButton.target = self
        forwardButton.action = #selector(forwardButtonClicked(_:))
        forwardButton.isEnabled = false
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
            breadcrumbScrollView.trailingAnchor.constraint(equalTo: sortButton.leadingAnchor, constant: -8),
            breadcrumbScrollView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            breadcrumbScrollView.heightAnchor.constraint(equalToConstant: 26),

            breadcrumbStackView.leadingAnchor.constraint(equalTo: breadcrumbScrollView.leadingAnchor),
            breadcrumbStackView.topAnchor.constraint(equalTo: breadcrumbScrollView.topAnchor),
            breadcrumbStackView.bottomAnchor.constraint(equalTo: breadcrumbScrollView.bottomAnchor),

            sortButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            sortButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            sortButton.widthAnchor.constraint(equalToConstant: 44),
            sortButton.heightAnchor.constraint(equalToConstant: 26)
        ])
    }

    // MARK: - Public Methods

    func updatePath(_ url: URL, canGoBack: Bool, canGoForward: Bool) {
        self.currentURL = url
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward

        backButton.isEnabled = canGoBack
        forwardButton.isEnabled = canGoForward

        updateBreadcrumbs(for: url)
    }

    private func updateBreadcrumbs(for url: URL) {
        // Clear existing breadcrumbs
        breadcrumbStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Build path components
        var components: [String] = []
        var currentPath = url

        // Handle root specially
        if url.path == "/" {
            components = ["/"]
        } else {
            while !currentPath.path.isEmpty && currentPath.path != "/" {
                components.insert(currentPath.lastPathComponent, at: 0)
                currentPath = currentPath.deletingLastPathComponent()
            }
            // Add root if not already there
            if !components.isEmpty {
                components.insert("/", at: 0)
            }
        }

        // Create breadcrumb buttons
        for (index, component) in components.enumerated() {
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
            button.tag = index

            // Store the URL for this component
            var urlForComponent = URL(fileURLWithPath: "/")
            for i in 1...index {
                if i < components.count && components[i] != "/" {
                    urlForComponent.appendPathComponent(components[i])
                }
            }
            button.identifier = NSUserInterfaceItemIdentifier(urlForComponent.path)

            breadcrumbStackView.addArrangedSubview(button)
        }
    }

    // MARK: - Actions

    @objc private func backButtonClicked(_ sender: Any) {
        delegate?.toolbarDidRequestBack()
    }

    @objc private func forwardButtonClicked(_ sender: Any) {
        delegate?.toolbarDidRequestForward()
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
}
