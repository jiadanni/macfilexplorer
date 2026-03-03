import Cocoa

class FavoritesViewController: NSViewController {
    
    weak var delegate: SidebarDelegate?
    var favoriteItems: [SidebarItem] = []
    var tableView: NSTableView!
    private let settings: SettingsStoreProtocol

    init(settings: SettingsStoreProtocol = SettingsStore.shared) {
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
        settings.addDelegate(self)
    }

    required init?(coder: NSCoder) {
        self.settings = SettingsStore.shared
        super.init(coder: coder)
        settings.addDelegate(self)
    }
    
    deinit {
        settings.removeDelegate(self)
    }

    var contentHeight: CGFloat {
        let rowHeight: CGFloat = 22
        let rowCount = CGFloat(favoriteItems.count)
        return rowCount * rowHeight
    }

    override func loadView() {
        view = NSView()
        setupUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadFavorites()
    }
    
    // Public method to reload if needed
    func reloadData() {
        tableView.reloadData()
    }
    
    private func setupUI() {
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowSizeStyle = .small
        tableView.style = .sourceList
        tableView.backgroundColor = .clear
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.action = #selector(tableViewClicked(_:))
        tableView.menu = createContextMenu()
        tableView.menu?.delegate = self // Set menu delegate
        
        tableView.registerForDraggedTypes([.string, .fileURL])
        tableView.setDraggingSourceOperationMask(.move, forLocal: true)
        tableView.setAccessibilityIdentifier("FavoritesTable")
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FavoritesColumn"))
        column.width = 180
        tableView.addTableColumn(column)
        
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = tableView
        
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func loadFavorites() {
        let fileManager = FileManager.default
        let workspace = NSWorkspace.shared
        
        // Default Favorites
        let homeURL = fileManager.homeDirectoryForCurrentUser
        let desktopURL = homeURL.appendingPathComponent("Desktop")
        let documentsURL = homeURL.appendingPathComponent("Documents")
        let downloadsURL = homeURL.appendingPathComponent("Downloads")
        let applicationsURL = URL(fileURLWithPath: "/Applications")
        
        // Use system icons
        let folderIcon = NSImage.mfeSymbol(named: "folder", accessibilityDescription: nil) ?? NSWorkspace.shared.icon(for: .folder)
        let desktopIcon = NSImage.mfeSymbol(named: "desktopcomputer", accessibilityDescription: nil) ?? folderIcon
        let documentIcon = NSImage.mfeSymbol(named: "doc", accessibilityDescription: nil) ?? folderIcon
        let downloadIcon = NSImage.mfeSymbol(named: "arrow.down.circle", accessibilityDescription: nil) ?? folderIcon
        let homeIcon = NSImage.mfeSymbol(named: "house", accessibilityDescription: nil) ?? folderIcon
        
        favoriteItems = [
            SidebarItem(name: "Desktop", url: desktopURL, icon: desktopIcon),
            SidebarItem(name: "Documents", url: documentsURL, icon: documentIcon),
            SidebarItem(name: "Downloads", url: downloadsURL, icon: downloadIcon),
            SidebarItem(name: "Applications", url: applicationsURL, icon: workspace.icon(forFile: applicationsURL.path)),
            SidebarItem(name: "Home", url: homeURL, icon: homeIcon)
        ]
        
        loadFavoritesFromDefaults()
        
        tableView.reloadData()
    }
    
    private func loadFavoritesFromDefaults() {
        // Use injected settings
        let savedPaths = settings.sidebarFavorites
        let workspace = NSWorkspace.shared
        for path in savedPaths {
            let url = URL(fileURLWithPath: path)
            let icon = workspace.icon(forFile: path)
            let name = url.lastPathComponent
            if !favoriteItems.contains(where: { $0.url == url }) {
                favoriteItems.append(SidebarItem(name: name, url: url, icon: icon))
            }
        }
    }
    
    func saveFavorites() {
        let favoritePaths = favoriteItems.map { $0.url.path }
        // Update settings directly (already references the same object)
        settings.sidebarFavorites = favoritePaths
    }

             func addFavorite(item: FileItem) {
        let sidebarItem = SidebarItem(name: item.name, url: item.url, icon: item.icon(useGrayscale: SettingsStore.shared.useGrayscaleIcons))
        if !favoriteItems.contains(where: { $0.url == sidebarItem.url }) {
            favoriteItems.append(sidebarItem)
            tableView.reloadData()
            saveFavorites()
        }
    }
    
    @objc private func tableViewClicked(_ sender: NSTableView) {
        let row = sender.clickedRow
        guard row >= 0, row < favoriteItems.count else { return }
        
        let item = favoriteItems[row]
        
        if let event = NSApp.currentEvent, event.modifierFlags.contains(.command) {
            // Ideally delegate this up to split view controller logic if possible
            // But since parent might be SidebarViewController, we might need a delegate method for opening in new tab
            // For now, let's keep it simple and assume standard selection or try to find parent split view
             if let splitVC = view.window?.contentViewController as? SplitViewController {
                 splitVC.openLocationInNewTab(item.url)
             } else {
                 delegate?.sidebarDidSelectLocation(item.url)
             }
        } else {
            delegate?.sidebarDidSelectLocation(item.url)
        }
    }
    
    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open", action: #selector(contextMenuOpen(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Open in New Tab", action: #selector(contextMenuOpenInNewTab(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Show in Finder", action: #selector(contextMenuShowInFinder(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Remove from Favorites", action: #selector(contextMenuRemoveFromFavorites(_:)), keyEquivalent: "")
        return menu
    }
    
    @objc private func contextMenuOpen(_ sender: Any) {
         let row = tableView.clickedRow
         guard row >= 0, row < favoriteItems.count else { return }
         delegate?.sidebarDidSelectLocation(favoriteItems[row].url)
    }

    @objc private func contextMenuOpenInNewTab(_ sender: Any) {
         let row = tableView.clickedRow
         guard row >= 0, row < favoriteItems.count else { return }
         if let splitVC = view.window?.contentViewController as? SplitViewController {
             splitVC.openLocationInNewTab(favoriteItems[row].url)
         }
    }

    @objc private func contextMenuShowInFinder(_ sender: Any) {
         let row = tableView.clickedRow
         guard row >= 0, row < favoriteItems.count else { return }
         NSWorkspace.shared.activateFileViewerSelecting([favoriteItems[row].url])
    }

    @objc private func contextMenuRemoveFromFavorites(_ sender: Any) {
         let row = tableView.clickedRow
         guard row >= 0, row < favoriteItems.count else { return }
         favoriteItems.remove(at: row)
         tableView.reloadData()
         saveFavorites()
    }
}

extension FavoritesViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return favoriteItems.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = favoriteItems[row]
        let cellView = NSTableCellView()
        
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = item.icon
        
        let textField = NSTextField()
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.isEditable = false
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.stringValue = item.name
        
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
        
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 22
    }
    
    // Drag & Drop
    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        let data = try? NSKeyedArchiver.archivedData(withRootObject: rowIndexes, requiringSecureCoding: false)
        pboard.declareTypes([.string], owner: self)
        pboard.setData(data, forType: .string)
        return true
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if info.draggingPasteboard.types?.contains(.fileURL) == true {
             if dropOperation == .on && row >= 0 { return .copy }
        }
        if dropOperation == .above { return .move }
        return []
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
         // Reordering
         if dropOperation == .above {
             guard let data = info.draggingPasteboard.data(forType: .string),
                   let rowIndexes = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSIndexSet.self], from: data) as? IndexSet,
                   let draggedRow = rowIndexes.first else { return false }
             
             let item = favoriteItems[draggedRow]
             favoriteItems.remove(at: draggedRow)
             var insertionRow = row
             if draggedRow < insertionRow { insertionRow -= 1 }
             favoriteItems.insert(item, at: insertionRow)
             tableView.reloadData()
             saveFavorites()
             return true
         }
         
         // File drop
         if dropOperation == .on, let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
              guard row < favoriteItems.count else { return false }
              let destinationInfo = favoriteItems[row]
              let destination = destinationInfo.url
              
             let fileManager = FileManager.default
             var allSucceeded = true
             
             for sourceURL in urls {
                 let fileName = sourceURL.lastPathComponent
                 let targetURL = destination.appendingPathComponent(fileName)
                 if sourceURL == targetURL { continue }
                 do {
                     try fileManager.moveItem(at: sourceURL, to: targetURL)
                 } catch {
                     debugLog("Failed to move \(sourceURL) to \(targetURL): \(error)")
                     allSucceeded = false
                 }
             }
             return allSucceeded
         }
         
         return false
    }
}

extension FavoritesViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Enforce validations if needed
         let row = tableView.clickedRow
         let hasSelection = row >= 0 && row < favoriteItems.count
         
         menu.item(withTitle: "Open")?.isEnabled = hasSelection
         menu.item(withTitle: "Open in New Tab")?.isEnabled = hasSelection
         menu.item(withTitle: "Show in Finder")?.isEnabled = hasSelection
         menu.item(withTitle: "Remove from Favorites")?.isEnabled = hasSelection
    }
}

// MARK: - SettingsStoreDelegate
extension FavoritesViewController: SettingsStoreDelegate {
    func settingsStoreDidUpdateAccentColor(_ settingsStore: SettingsStoreProtocol) {
        tableView.reloadData()
    }
    
    func settingsStore(_ settingsStore: SettingsStoreProtocol, hiddenFilesStateDidChange isVisible: Bool) {}
    func settingsStore(_ settingsStore: SettingsStoreProtocol, previewPaneVisibilityDidChange isVisible: Bool) {}
    func settingsStore(_ settingsStore: SettingsStoreProtocol, showFileExtensionsDidChange show: Bool) {}
    func settingsStore(_ settingsStore: SettingsStoreProtocol, easySelectDidChange enabled: Bool) {}
}
