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
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 600))
        setupUI()
        loadSidebarItems()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Create the top-level split view
        let mainSplitView = NSSplitView()
        mainSplitView.isVertical = false
        mainSplitView.dividerStyle = .thin
        mainSplitView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainSplitView)

        NSLayoutConstraint.activate([
            mainSplitView.topAnchor.constraint(equalTo: view.topAnchor),
            mainSplitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainSplitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainSplitView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Create the nested split view for the bottom sections
        let bottomSplitView = NSSplitView()
        bottomSplitView.isVertical = false
        bottomSplitView.dividerStyle = .thin

        // Favorites section
        let favoritesContainer = NSView()
        setupFavoritesSection()
        guard let favoritesScrollView = favoritesTableView.enclosingScrollView else {
            print("Error: favoritesTableView has no enclosing scroll view")
            return
        }
        let favoritesStack = NSStackView(views: [favoritesHeaderView, favoritesScrollView])
        favoritesStack.orientation = .vertical
        favoritesStack.spacing = 0
        favoritesStack.translatesAutoresizingMaskIntoConstraints = false
        favoritesContainer.addSubview(favoritesStack)
        NSLayoutConstraint.activate([
            favoritesStack.topAnchor.constraint(equalTo: favoritesContainer.topAnchor),
            favoritesStack.leadingAnchor.constraint(equalTo: favoritesContainer.leadingAnchor),
            favoritesStack.trailingAnchor.constraint(equalTo: favoritesContainer.trailingAnchor),
            favoritesStack.bottomAnchor.constraint(equalTo: favoritesContainer.bottomAnchor),
        ])
        mainSplitView.addArrangedSubview(favoritesContainer)

        // Locations section
        let locationsContainer = NSView()
        setupLocationsSection()
        guard let drivesScrollView = drivesTableView.enclosingScrollView else {
            print("Error: drivesTableView has no enclosing scroll view")
            return
        }
        let locationsStack = NSStackView(views: [drivesHeaderView, drivesScrollView])
        locationsStack.orientation = .vertical
        locationsStack.spacing = 0
        locationsStack.translatesAutoresizingMaskIntoConstraints = false
        locationsContainer.addSubview(locationsStack)
        NSLayoutConstraint.activate([
            locationsStack.topAnchor.constraint(equalTo: locationsContainer.topAnchor),
            locationsStack.leadingAnchor.constraint(equalTo: locationsContainer.leadingAnchor),
            locationsStack.trailingAnchor.constraint(equalTo: locationsContainer.trailingAnchor),
            locationsStack.bottomAnchor.constraint(equalTo: locationsContainer.bottomAnchor),
        ])
        bottomSplitView.addArrangedSubview(locationsContainer)

        // Folder Explorer section
        let folderExplorerContainer = NSView()
        setupFolderExplorerSection()
        guard let folderScrollView = folderExplorerOutlineView.enclosingScrollView else {
            print("Error: folderExplorerOutlineView has no enclosing scroll view")
            return
        }
        let folderExplorerStack = NSStackView(views: [folderExplorerHeaderView, folderScrollView])
        folderExplorerStack.orientation = .vertical
        folderExplorerStack.spacing = 0
        folderExplorerStack.translatesAutoresizingMaskIntoConstraints = false
        folderExplorerContainer.addSubview(folderExplorerStack)
        NSLayoutConstraint.activate([
            folderExplorerStack.topAnchor.constraint(equalTo: folderExplorerContainer.topAnchor),
            folderExplorerStack.leadingAnchor.constraint(equalTo: folderExplorerContainer.leadingAnchor),
            folderExplorerStack.trailingAnchor.constraint(equalTo: folderExplorerContainer.trailingAnchor),
            folderExplorerStack.bottomAnchor.constraint(equalTo: folderExplorerContainer.bottomAnchor),
        ])
        bottomSplitView.addArrangedSubview(folderExplorerContainer)

        mainSplitView.addArrangedSubview(bottomSplitView)
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
        
        // Enable drag and drop for reordering
        favoritesTableView.registerForDraggedTypes([.string])
        favoritesTableView.setDraggingSourceOperationMask(.move, forLocal: true)

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

    @objc private func contextMenuEject(_ sender: Any) {
        guard let menuItem = sender as? NSMenuItem,
              let menu = menuItem.menu,
              let item = getClickedItem(from: menu) else { return }

        // Attempt to unmount the volume
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: item.url)
            // Refresh the drives list after successful ejection
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.loadSidebarItems()
            }
        } catch {
            // Show error alert
            let alert = NSAlert()
            alert.messageText = "Eject Failed"
            alert.informativeText = "Could not eject '\(item.name)': \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
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
    
    // MARK: - Auto-expand Folder Explorer
    
    func expandToCurrentDirectory(url: URL) {
        guard UserDefaults.standard.bool(forKey: UserDefaults.Keys.expandSidebarToCurrentDirectory.rawValue) else { return }
        
        // Find the path components from the root to the target URL
        var pathComponents: [URL] = []
        var currentURL = url
        while currentURL.path != "/" && currentURL.path != folderExplorerRootItem.url.path {
            pathComponents.insert(currentURL, at: 0)
            currentURL = currentURL.deletingLastPathComponent()
        }
        
        // Start expanding from the root
        var currentItem: FileItem? = folderExplorerRootItem
        for componentURL in pathComponents {
            if let children = currentItem?.children {
                for child in children {
                    if child.url == componentURL {
                        folderExplorerOutlineView.expandItem(currentItem)
                        currentItem = child
                        break
                    }
                }
            }
        }
        
        // Select the final item
        if let finalItem = currentItem {
            let row = folderExplorerOutlineView.row(forItem: finalItem)
            if row >= 0 {
                folderExplorerOutlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                folderExplorerOutlineView.scrollRowToVisible(row)
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
        if let ejectItem = menu.item(withTitle: "Eject") {
            menu.removeItem(ejectItem)
        }

        // Check if item is in favorites and add the correct menu item
        let isInFavorites = favoriteItems.contains(where: { $0.url == selectedItem.url })
        if isInFavorites {
            menu.addItem(withTitle: "Remove from Favorites", action: #selector(contextMenuRemoveFromFavorites(_:)), keyEquivalent: "")
        } else {
            menu.addItem(withTitle: "Add to Favorites", action: #selector(contextMenuAddToFavorites(_:)), keyEquivalent: "")
        }

        // Add eject option for volumes in the Locations section
        if tv == drivesTableView {
            // Check if the volume is ejectable
            do {
                let resourceValues = try selectedItem.url.resourceValues(forKeys: [.volumeIsEjectableKey, .volumeIsRemovableKey])
                if let isEjectable = resourceValues.volumeIsEjectable, isEjectable {
                    menu.addItem(NSMenuItem.separator())
                    menu.addItem(withTitle: "Eject", action: #selector(contextMenuEject(_:)), keyEquivalent: "")
                }
            } catch {
                // If we can't determine if it's ejectable, don't show the eject option
                print("Error checking if volume is ejectable: \(error)")
            }
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
    
    // MARK: - Drag and Drop
    
    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        if tableView == favoritesTableView {
            let data = try? NSKeyedArchiver.archivedData(withRootObject: rowIndexes, requiringSecureCoding: false)
            pboard.declareTypes([.string], owner: self)
            pboard.setData(data, forType: .string)
            return true
        }
        return false
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if tableView == favoritesTableView && dropOperation == .above {
            return .move
        }
        return []
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        if tableView == favoritesTableView, dropOperation == .above {
            guard let data = info.draggingPasteboard.data(forType: .string),
                  let rowIndexes = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSIndexSet.self], from: data) as? IndexSet else {
                return false
            }
            
            let draggedRow = rowIndexes.first!
            
            // Perform the reordering
            let item = favoriteItems[draggedRow]
            favoriteItems.remove(at: draggedRow)
            
            var insertionRow = row
            if draggedRow < insertionRow {
                insertionRow -= 1
            }
            favoriteItems.insert(item, at: insertionRow)
            
            tableView.reloadData()
            saveFavorites() // Persist the new order
            return true
        }
        return false
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
