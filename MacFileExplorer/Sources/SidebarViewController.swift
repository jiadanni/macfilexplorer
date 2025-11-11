import Cocoa

protocol SidebarDelegate: AnyObject {
    func sidebarDidSelectLocation(_ url: URL)
}

class SidebarViewController: NSViewController {

    weak var delegate: SidebarDelegate?

    // Favorites
    private var favoritesHeaderView: NSView!
    private var favoritesTableView: NSTableView!
    private var favoriteItems: [SidebarItem] = []

    // Locations (formerly Drives)
    private var drivesHeaderView: NSView!
    private var drivesTableView: NSTableView!
    private var driveItems: [SidebarItem] = []

    // Folder Explorer
    private var folderExplorerHeaderView: NSView!
    private var folderExplorerOutlineView: NSOutlineView!
    private var folderExplorerRootItem: FileItem!
    private var folderExplorerScrollView: NSScrollView!

    // Main stack view to hold sections
    private var stackView: NSStackView!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 600))
        setupUI()
        loadSidebarItems()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Use a main stack view to arrange sections vertically
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading // Align items to the leading edge
        stackView.spacing = 0 // No spacing between sections, separators will provide it
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: view.widthAnchor) // Ensure stack view fills width
        ])

        // Favorites section
        setupFavoritesSection()
        stackView.addArrangedSubview(favoritesHeaderView)
        stackView.addArrangedSubview(favoritesTableView.enclosingScrollView!) // Add the scroll view

        // Separator
        let separator1 = NSBox()
        separator1.boxType = .separator
        separator1.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(separator1)
        separator1.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // Locations section (formerly Drives)
        setupLocationsSection() // Renamed method
        stackView.addArrangedSubview(drivesHeaderView)
        stackView.addArrangedSubview(drivesTableView.enclosingScrollView!) // Add the scroll view

        // Separator
        let separator2 = NSBox()
        separator2.boxType = .separator
        separator2.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(separator2)
        separator2.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // Folder Explorer section
        setupFolderExplorerSection()
        stackView.addArrangedSubview(folderExplorerHeaderView)
        stackView.addArrangedSubview(folderExplorerOutlineView.enclosingScrollView!) // Add the scroll view
    }

    private func setupFavoritesSection() {
        // Header
        favoritesHeaderView = createSectionHeader(title: "FAVORITES")

        // Table view
        favoritesTableView = NSTableView()
        favoritesTableView.headerView = nil
        favoritesTableView.rowSizeStyle = .small
        favoritesTableView.style = .sourceList
        favoritesTableView.backgroundColor = .clear
        favoritesTableView.intercellSpacing = NSSize(width: 0, height: 0)
        favoritesTableView.delegate = self
        favoritesTableView.dataSource = self
        favoritesTableView.target = self
        favoritesTableView.action = #selector(tableViewClicked(_:))
        favoritesTableView.menu = createContextMenu()
        favoritesTableView.menu?.delegate = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FavoritesColumn"))
        column.width = 180
        favoritesTableView.addTableColumn(column)

        // Create scroll view for favoritesTableView
        let favoritesScrollView = NSScrollView()
        favoritesScrollView.translatesAutoresizingMaskIntoConstraints = false
        favoritesScrollView.hasVerticalScroller = true
        favoritesScrollView.autohidesScrollers = true
        favoritesScrollView.borderType = .noBorder
        favoritesScrollView.documentView = favoritesTableView

        // Set minimum height for favorites section
        favoritesScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        favoritesScrollView.widthAnchor.constraint(equalToConstant: 200).isActive = true // Match sidebar width
    }

    private func setupLocationsSection() { // Renamed from setupDrivesSection
        // Header
        drivesHeaderView = createSectionHeader(title: "LOCATIONS")

        // Table view
        drivesTableView = NSTableView()
        drivesTableView.headerView = nil
        drivesTableView.rowSizeStyle = .small
        drivesTableView.style = .sourceList
        drivesTableView.backgroundColor = .clear
        drivesTableView.intercellSpacing = NSSize(width: 0, height: 0)
        drivesTableView.delegate = self
        drivesTableView.dataSource = self
        drivesTableView.target = self
        drivesTableView.action = #selector(tableViewClicked(_:))
        drivesTableView.menu = createContextMenu()
        drivesTableView.menu?.delegate = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("DrivesColumn"))
        column.width = 180
        drivesTableView.addTableColumn(column)

        // Create scroll view for drivesTableView
        let drivesScrollView = NSScrollView()
        drivesScrollView.translatesAutoresizingMaskIntoConstraints = false
        drivesScrollView.hasVerticalScroller = true
        drivesScrollView.autohidesScrollers = true
        drivesScrollView.borderType = .noBorder
        drivesScrollView.documentView = drivesTableView

        // Set minimum height for drives section
        drivesScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        drivesScrollView.widthAnchor.constraint(equalToConstant: 200).isActive = true // Match sidebar width
    }

    private func setupFolderExplorerSection() {
        // Header
        folderExplorerHeaderView = createSectionHeader(title: "FOLDER EXPLORER")

        // Outline view
        folderExplorerOutlineView = NSOutlineView()
        folderExplorerOutlineView.headerView = nil
        folderExplorerOutlineView.rowSizeStyle = .small
        folderExplorerOutlineView.style = .sourceList
        folderExplorerOutlineView.backgroundColor = .clear
        folderExplorerOutlineView.intercellSpacing = NSSize(width: 0, height: 0)
        folderExplorerOutlineView.delegate = self
        folderExplorerOutlineView.dataSource = self
        folderExplorerOutlineView.target = self
        folderExplorerOutlineView.doubleAction = #selector(outlineViewDoubleClicked(_:))
        folderExplorerOutlineView.menu = createContextMenu() // Reuse context menu
        folderExplorerOutlineView.menu?.delegate = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FolderExplorerColumn"))
        column.width = 180
        folderExplorerOutlineView.addTableColumn(column)
        folderExplorerOutlineView.outlineTableColumn = column // Set the outline column

        // Create scroll view for folderExplorerOutlineView
        folderExplorerScrollView = NSScrollView()
        folderExplorerScrollView.translatesAutoresizingMaskIntoConstraints = false
        folderExplorerScrollView.hasVerticalScroller = true
        folderExplorerScrollView.autohidesScrollers = true
        folderExplorerScrollView.borderType = .noBorder
        folderExplorerScrollView.documentView = folderExplorerOutlineView

        // Set minimum height for folder explorer section
        folderExplorerScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        folderExplorerScrollView.widthAnchor.constraint(equalToConstant: 200).isActive = true // Match sidebar width
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
        let folderIcon = NSImage(systemSymbolName: "folder", accessibilityDescription: nil) ?? NSWorkspace.shared.icon(for: .folder)
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

        // Load additional favorites from UserDefaults
        loadFavoritesFromDefaults()

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

        // Folder Explorer - initialize with root
        folderExplorerRootItem = FileItem(url: URL(fileURLWithPath: "/"))
        folderExplorerRootItem.loadChildren(showsHiddenFiles: false) // Load children for the root

        favoritesTableView.reloadData()
        drivesTableView.reloadData()
        folderExplorerOutlineView.reloadData()
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

    @objc private func outlineViewDoubleClicked(_ sender: NSOutlineView) {
        let row = sender.clickedRow
        guard row >= 0 else { return }

        if let fileItem = sender.item(atRow: row) as? FileItem {
            delegate?.sidebarDidSelectLocation(fileItem.url)
        }
    }

    // MARK: - Context Menu

    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(withTitle: "Open", action: #selector(contextMenuOpen(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Open in New Tab", action: #selector(contextMenuOpenInNewTab(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Show in Finder", action: #selector(contextMenuShowInFinder(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())

        return menu
    }

    private func getClickedItem(from menu: NSMenu) -> SidebarItem? {
        // Determine which table view was right-clicked
        var tableView: NSTableView?
        if favoritesTableView.menu == menu {
            tableView = favoritesTableView
        } else if drivesTableView.menu == menu {
            tableView = drivesTableView
        }

        guard let tv = tableView else { return nil }
        let row = tv.clickedRow
        guard row >= 0 else { return nil }

        if tv == favoritesTableView {
            return favoriteItems[row]
        } else if tv == drivesTableView {
            return driveItems[row]
        }

        return nil
    }

    @objc private func contextMenuOpen(_ sender: Any) {
        guard let menuItem = sender as? NSMenuItem,
              let menu = menuItem.menu,
              let item = getClickedItem(from: menu) else { return }

        delegate?.sidebarDidSelectLocation(item.url)
    }

    @objc private func contextMenuOpenInNewTab(_ sender: Any) {
        guard let menuItem = sender as? NSMenuItem,
              let menu = menuItem.menu else { return }

        var urlToOpen: URL?

        // Check which view the context menu was opened from
        if menu == favoritesTableView.menu || menu == drivesTableView.menu {
            if let item = getClickedItem(from: menu) {
                urlToOpen = item.url
            }
        } else if menu == folderExplorerOutlineView.menu {
            let row = folderExplorerOutlineView.clickedRow
            if row >= 0, let item = folderExplorerOutlineView.item(atRow: row) as? FileItem {
                if item.isDirectory {
                    urlToOpen = item.url
                }
            }
        }

        guard let url = urlToOpen else { return }

        // Notify delegate to open in new tab
        if let splitVC = parent as? SplitViewController {
            splitVC.openLocationInNewTab(url)
        }
    }

    @objc private func contextMenuShowInFinder(_ sender: Any) {
        guard let menuItem = sender as? NSMenuItem,
              let menu = menuItem.menu,
              let item = getClickedItem(from: menu) else { return }

        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    @objc private func contextMenuAddToFavorites(_ sender: Any) {
        guard let menuItem = sender as? NSMenuItem,
              let menu = menuItem.menu,
              let item = getClickedItem(from: menu) else { return }

        // Check if already in favorites
        if !favoriteItems.contains(where: { $0.url == item.url }) {
            favoriteItems.append(item)
            favoritesTableView.reloadData()

            // Save to UserDefaults
            saveFavorites()
        }
    }

    @objc private func contextMenuRemoveFromFavorites(_ sender: Any) {
        guard let menuItem = sender as? NSMenuItem,
              let menu = menuItem.menu,
              let item = getClickedItem(from: menu) else { return }

        // Remove from favorites
        if let index = favoriteItems.firstIndex(where: { $0.url == item.url }) {
            favoriteItems.remove(at: index)
            favoritesTableView.reloadData()

            // Save to UserDefaults
            saveFavorites()
        }
    }

    private func saveFavorites() {
        let favoritePaths = favoriteItems.map { $0.url.path }
        UserDefaults.standard.set(favoritePaths, forKey: "SidebarFavorites")
    }

    private func loadFavoritesFromDefaults() {
        guard let savedPaths = UserDefaults.standard.array(forKey: "SidebarFavorites") as? [String] else { return }

        let workspace = NSWorkspace.shared
        _ = NSImage(systemSymbolName: "folder", accessibilityDescription: nil) ?? NSWorkspace.shared.icon(for: .folder)

        for path in savedPaths {
            let url = URL(fileURLWithPath: path)
            let icon = workspace.icon(forFile: path)
            let name = url.lastPathComponent

            // Only add if not already in favorites
            if !favoriteItems.contains(where: { $0.url == url }) {
                favoriteItems.append(SidebarItem(name: name, url: url, icon: icon))
            }
        }
    }
}

// MARK: - NSMenuDelegate

extension SidebarViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Determine which table view was right-clicked
        var tableView: NSTableView?
        if favoritesTableView.menu == menu {
            tableView = favoritesTableView
        } else if drivesTableView.menu == menu {
            tableView = drivesTableView
        } else if folderExplorerOutlineView.menu == menu { // Handle folder explorer context menu
            // For folder explorer, we need to get the FileItem from the outline view
            let row = folderExplorerOutlineView.clickedRow
            guard row >= 0, let fileItem = folderExplorerOutlineView.item(atRow: row) as? FileItem else {
                menu.items.forEach { $0.isEnabled = false }
                return
            }

            // Enable appropriate menu items
            menu.item(withTitle: "Open")?.isEnabled = true
            menu.item(withTitle: "Open in New Tab")?.isEnabled = true
            menu.item(withTitle: "Show in Finder")?.isEnabled = true

            // Remove existing favorite items to avoid duplicates
            if let addItem = menu.item(withTitle: "Add to Favorites") {
                menu.removeItem(addItem)
            }
            if let removeItem = menu.item(withTitle: "Remove from Favorites") {
                menu.removeItem(removeItem)
            }

            // Check if item is in favorites and add the correct menu item
            let isInFavorites = favoriteItems.contains(where: { $0.url == fileItem.url })
            if isInFavorites {
                menu.addItem(withTitle: "Remove from Favorites", action: #selector(contextMenuRemoveFromFavorites(_:)), keyEquivalent: "")
            } else {
                menu.addItem(withTitle: "Add to Favorites", action: #selector(contextMenuAddToFavorites(_:)), keyEquivalent: "")
            }
            return
        }

        guard let tv = tableView else {
            menu.items.forEach { $0.isEnabled = false }
            return
        }

        let row = tv.clickedRow
        guard row >= 0 else {
            menu.items.forEach { $0.isEnabled = false }
            return
        }

        var item: SidebarItem?
        if tv == favoritesTableView {
            item = favoriteItems[row]
        } else if tv == drivesTableView {
            item = driveItems[row]
        }

        guard let selectedItem = item else {
            menu.items.forEach { $0.isEnabled = false }
            return
        }

        // Enable appropriate menu items
        menu.item(withTitle: "Open")?.isEnabled = true
        menu.item(withTitle: "Open in New Tab")?.isEnabled = true
        menu.item(withTitle: "Show in Finder")?.isEnabled = true

        // Remove existing favorite items to avoid duplicates
        if let addItem = menu.item(withTitle: "Add to Favorites") {
            menu.removeItem(addItem)
        }
        if let removeItem = menu.item(withTitle: "Remove from Favorites") {
            menu.removeItem(removeItem)
        }

        // Check if item is in favorites and add the correct menu item
        let isInFavorites = favoriteItems.contains(where: { $0.url == selectedItem.url })
        if isInFavorites {
            menu.addItem(withTitle: "Remove from Favorites", action: #selector(contextMenuRemoveFromFavorites(_:)), keyEquivalent: "")
        } else {
            menu.addItem(withTitle: "Add to Favorites", action: #selector(contextMenuAddToFavorites(_:)), keyEquivalent: "")
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

// MARK: - NSOutlineViewDataSource

extension SidebarViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { // Root item
            return folderExplorerRootItem?.children?.count ?? 0
        }
        guard let fileItem = item as? FileItem else { return 0 }
        return fileItem.children?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil { // Root item
            return folderExplorerRootItem?.children?[index] as Any
        }
        guard let fileItem = item as? FileItem else {
            fatalError("Invalid item for outline view")
        }
        return fileItem.children?[index] as Any
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let fileItem = item as? FileItem else { return false }
        return fileItem.isDirectory
    }
}

// MARK: - NSOutlineViewDelegate

extension SidebarViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let fileItem = item as? FileItem else { return nil }

        let cellView = NSTableCellView()

        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = fileItem.icon

        let textField = NSTextField()
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.isEditable = false
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.stringValue = fileItem.name

        cellView.addSubview(imageView)
        cellView.addSubview(textField)

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

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView else { return }
        let selectedRow = outlineView.selectedRow
        guard selectedRow >= 0 else { return }

        if let fileItem = outlineView.item(atRow: selectedRow) as? FileItem {
            print("SidebarViewController: outlineViewSelectionDidChange - Selected URL: \(fileItem.url.path)")
            delegate?.sidebarDidSelectLocation(fileItem.url)
        }
    }

    func outlineViewItemWillExpand(_ notification: Notification) {
        guard let expandedItem = notification.userInfo?["NSObject"] as? FileItem else { return }
        print("SidebarViewController: outlineViewItemWillExpand - Expanding URL: \(expandedItem.url.path)")
        print("SidebarViewController: Children before loadChildren: \(expandedItem.children?.count ?? 0)")
        expandedItem.loadChildren(showsHiddenFiles: false) // Load children when item is about to expand
        print("SidebarViewController: Children after loadChildren: \(expandedItem.children?.count ?? 0)")
    }
}
