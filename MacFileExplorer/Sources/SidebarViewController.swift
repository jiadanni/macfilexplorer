import Cocoa

protocol SidebarDelegate: AnyObject {
    func sidebarDidSelectLocation(_ url: URL)
}

class SidebarViewController: NSViewController {

    weak var delegate: SidebarDelegate?

    private var scrollView: NSScrollView!
    private var stackView: NSStackView!

    // Favorites
    private var favoritesHeaderView: NSView!
    private var favoritesTableView: NSTableView!
    private var favoriteItems: [SidebarItem] = []

    // Drives
    private var drivesHeaderView: NSView!
    private var drivesTableView: NSTableView!
    private var driveItems: [SidebarItem] = []

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 600))
        setupUI()
        loadSidebarItems()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Create main scroll view
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        view.addSubview(scrollView)

        // Create stack view to hold sections
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.edgeInsets = NSEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = stackView

        // Favorites section
        setupFavoritesSection()

        // Drives section
        setupDrivesSection()

        // Set up constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor)
        ])
    }

    private func setupFavoritesSection() {
        // Header
        favoritesHeaderView = createSectionHeader(title: "FAVORITES")
        stackView.addArrangedSubview(favoritesHeaderView)

        // Table view
        favoritesTableView = NSTableView()
        favoritesTableView.headerView = nil
        favoritesTableView.rowSizeStyle = .small
        favoritesTableView.selectionHighlightStyle = .sourceList
        favoritesTableView.backgroundColor = .clear
        favoritesTableView.intercellSpacing = NSSize(width: 0, height: 0)
        favoritesTableView.style = .sourceList
        favoritesTableView.delegate = self
        favoritesTableView.dataSource = self
        favoritesTableView.target = self
        favoritesTableView.action = #selector(tableViewClicked(_:))

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FavoritesColumn"))
        column.width = 180
        favoritesTableView.addTableColumn(column)

        let favoritesContainer = NSView()
        favoritesContainer.translatesAutoresizingMaskIntoConstraints = false
        favoritesContainer.addSubview(favoritesTableView)
        favoritesTableView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            favoritesTableView.topAnchor.constraint(equalTo: favoritesContainer.topAnchor),
            favoritesTableView.leadingAnchor.constraint(equalTo: favoritesContainer.leadingAnchor),
            favoritesTableView.trailingAnchor.constraint(equalTo: favoritesContainer.trailingAnchor),
            favoritesTableView.bottomAnchor.constraint(equalTo: favoritesContainer.bottomAnchor),
            favoritesContainer.heightAnchor.constraint(equalToConstant: 200)
        ])

        stackView.addArrangedSubview(favoritesContainer)

        NSLayoutConstraint.activate([
            favoritesContainer.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            favoritesContainer.trailingAnchor.constraint(equalTo: stackView.trailingAnchor)
        ])
    }

    private func setupDrivesSection() {
        // Header
        drivesHeaderView = createSectionHeader(title: "LOCATIONS")
        stackView.addArrangedSubview(drivesHeaderView)

        // Table view
        drivesTableView = NSTableView()
        drivesTableView.headerView = nil
        drivesTableView.rowSizeStyle = .small
        drivesTableView.selectionHighlightStyle = .sourceList
        drivesTableView.backgroundColor = .clear
        drivesTableView.intercellSpacing = NSSize(width: 0, height: 0)
        drivesTableView.style = .sourceList
        drivesTableView.delegate = self
        drivesTableView.dataSource = self
        drivesTableView.target = self
        drivesTableView.action = #selector(tableViewClicked(_:))

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("DrivesColumn"))
        column.width = 180
        drivesTableView.addTableColumn(column)

        let drivesContainer = NSView()
        drivesContainer.translatesAutoresizingMaskIntoConstraints = false
        drivesContainer.addSubview(drivesTableView)
        drivesTableView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            drivesTableView.topAnchor.constraint(equalTo: drivesContainer.topAnchor),
            drivesTableView.leadingAnchor.constraint(equalTo: drivesContainer.leadingAnchor),
            drivesTableView.trailingAnchor.constraint(equalTo: drivesContainer.trailingAnchor),
            drivesTableView.bottomAnchor.constraint(equalTo: drivesContainer.bottomAnchor),
            drivesContainer.heightAnchor.constraint(equalToConstant: 150)
        ])

        stackView.addArrangedSubview(drivesContainer)

        NSLayoutConstraint.activate([
            drivesContainer.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            drivesContainer.trailingAnchor.constraint(equalTo: stackView.trailingAnchor)
        ])
    }

    private func createSectionHeader(title: String) -> NSView {
        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 20),
            headerView.widthAnchor.constraint(equalToConstant: 180)
        ])

        return headerView
    }

    private func loadSidebarItems() {
        let fileManager = FileManager.default
        let workspace = NSWorkspace.shared

        // Favorites - use SF Symbols or system icons to avoid triggering permissions
        let desktopURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let documentsURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        let downloadsURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let applicationsURL = URL(fileURLWithPath: "/Applications")
        let homeURL = fileManager.homeDirectoryForCurrentUser

        // Use system icons that don't require file access
        let folderIcon = NSImage(systemSymbolName: "folder", accessibilityDescription: nil) ?? NSWorkspace.shared.icon(forFileType: "public.folder")
        let desktopIcon = NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: nil) ?? folderIcon
        let documentIcon = NSImage(systemSymbolName: "doc", accessibilityDescription: nil) ?? folderIcon
        let downloadIcon = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil) ?? folderIcon
        let homeIcon = NSImage(systemSymbolName: "house", accessibilityDescription: nil) ?? folderIcon

        favoriteItems = [
            SidebarItem(name: "Desktop", url: desktopURL, icon: desktopIcon),
            SidebarItem(name: "Documents", url: documentsURL, icon: documentIcon),
            SidebarItem(name: "Downloads", url: downloadsURL, icon: downloadIcon),
            SidebarItem(name: "Applications", url: applicationsURL, icon: workspace.icon(forFile: applicationsURL.path)),
            SidebarItem(name: "Home", url: homeURL, icon: homeIcon)
        ]

        // Drives - get all mounted volumes
        driveItems = []
        if let volumeURLs = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey], options: [.skipHiddenVolumes]) {
            for volumeURL in volumeURLs {
                do {
                    let resourceValues = try volumeURL.resourceValues(forKeys: [.volumeNameKey])
                    let volumeName = resourceValues.volumeName ?? volumeURL.lastPathComponent

                    // Use workspace icon for all volumes (it provides the correct icon automatically)
                    let icon = workspace.icon(forFile: volumeURL.path)

                    driveItems.append(SidebarItem(name: volumeName, url: volumeURL, icon: icon))
                } catch {
                    print("Error reading volume info: \(error)")
                }
            }
        }

        favoritesTableView.reloadData()
        drivesTableView.reloadData()
    }

    @objc private func tableViewClicked(_ sender: NSTableView) {
        let row = sender.clickedRow
        guard row >= 0 else { return }

        var item: SidebarItem?
        if sender == favoritesTableView {
            item = favoriteItems[row]
        } else if sender == drivesTableView {
            item = driveItems[row]
        }

        if let item = item {
            delegate?.sidebarDidSelectLocation(item.url)
        }
    }
}

// MARK: - NSTableViewDataSource

extension SidebarViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == favoritesTableView {
            return favoriteItems.count
        } else if tableView == drivesTableView {
            return driveItems.count
        }
        return 0
    }
}

// MARK: - NSTableViewDelegate

extension SidebarViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellView = NSTableCellView()

        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyDown
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let textField = NSTextField()
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.isEditable = false
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false

        cellView.addSubview(imageView)
        cellView.addSubview(textField)

        var item: SidebarItem?
        if tableView == favoritesTableView {
            item = favoriteItems[row]
        } else if tableView == drivesTableView {
            item = driveItems[row]
        }

        if let item = item {
            imageView.image = item.icon
            textField.stringValue = item.name
        }

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
            imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16),

            textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4)
        ])

        cellView.imageView = imageView
        cellView.textField = textField

        return cellView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 22
    }
}

// MARK: - SidebarItem

struct SidebarItem {
    let name: String
    let url: URL
    let icon: NSImage?
}
