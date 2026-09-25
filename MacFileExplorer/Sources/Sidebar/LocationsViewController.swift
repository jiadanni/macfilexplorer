import Cocoa

class LocationsViewController: NSViewController {
    
    weak var delegate: SidebarDelegate?
    var driveItems: [SidebarItem] = []
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
    
    override func loadView() {
        view = NSView()
        setupUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadDrives()
        
        let workspace = NSWorkspace.shared
        NotificationCenter.default.addObserver(self, selector: #selector(volumeDidMount(_:)), name: NSWorkspace.didMountNotification, object: workspace)
        NotificationCenter.default.addObserver(self, selector: #selector(volumeDidUnmount(_:)), name: NSWorkspace.didUnmountNotification, object: workspace)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        settings.removeDelegate(self)
    }
    
    var contentHeight: CGFloat {
        let rowHeight: CGFloat = 22
        let rowCount = CGFloat(driveItems.count)
        return rowCount * rowHeight
    }
    
    @objc private func volumeDidMount(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.loadDrives()
        }
    }

    @objc private func volumeDidUnmount(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.loadDrives()
        }
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
        tableView.menu?.delegate = self
        
        tableView.registerForDraggedTypes([.fileURL])
        tableView.setAccessibilityIdentifier("LocationsTable")
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("DrivesColumn"))
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
    
    func loadDrives() {
        let fileManager = FileManager.default
        let workspace = NSWorkspace.shared
        
        driveItems = []
        
        // Load mounted volumes
        if let volumeURLs = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey], options: [.skipHiddenVolumes]) {
            for volumeURL in volumeURLs {
                do {
                    let resourceValues = try volumeURL.resourceValues(forKeys: [.volumeNameKey])
                    let volumeName = resourceValues.volumeName ?? volumeURL.lastPathComponent
                    let icon = workspace.icon(forFile: volumeURL.path)
                    driveItems.append(SidebarItem(name: volumeName, url: volumeURL, icon: icon))
                } catch {
                    debugLog("Error reading volume info: \(error)")
                }
            }
        }
        
        // Add Google Drive if it exists in home directory (modern default)
        // This ensures Google Drive appears in sidebar even if not mounted as a volume
        if let googleDrivePath = AppConfig.GoogleDrive.homeDirectoryPath {
            if fileManager.fileExists(atPath: googleDrivePath.path) {
                // Check if Google Drive is already in the list
                let alreadyListed = driveItems.contains { 
                    $0.url.path == googleDrivePath.path || 
                    $0.name.localizedCaseInsensitiveContains("Google Drive")
                }
                
                if !alreadyListed {
                    let icon = workspace.icon(forFile: googleDrivePath.path)
                    driveItems.append(SidebarItem(name: "Google Drive", url: googleDrivePath, icon: icon))
                    debugLog("✅ Added Google Drive to locations: \(googleDrivePath.path)")
                }
            }
        }
        
        // Sort items: mounted volumes first, then Google Drive
        driveItems.sort { item1, item2 in
            let isGD1 = item1.name.localizedCaseInsensitiveContains("Google Drive")
            let isGD2 = item2.name.localizedCaseInsensitiveContains("Google Drive")
            if isGD1 != isGD2 {
                return !isGD1 // Non-Google Drive items first
            }
            return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
        }
        
        tableView.reloadData()
    }
    
    @objc private func tableViewClicked(_ sender: NSTableView) {
        let row = sender.clickedRow
        guard row >= 0, row < driveItems.count else { return }
        let item = driveItems[row]
        
        if let event = NSApp.currentEvent, event.modifierFlags.contains(.command) {
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
         
         // Eject will be added dynamically in menuNeedsUpdate or handled here
         menu.addItem(NSMenuItem.separator())
         menu.addItem(withTitle: "Eject", action: #selector(contextMenuEject(_:)), keyEquivalent: "")
        return menu
    }
    
    @objc private func contextMenuOpen(_ sender: Any) {
         let row = tableView.clickedRow
         guard row >= 0, row < driveItems.count else { return }
         delegate?.sidebarDidSelectLocation(driveItems[row].url)
    }

    @objc private func contextMenuOpenInNewTab(_ sender: Any) {
         let row = tableView.clickedRow
         guard row >= 0, row < driveItems.count else { return }
         if let splitVC = view.window?.contentViewController as? SplitViewController {
             splitVC.openLocationInNewTab(driveItems[row].url)
         }
    }

    @objc private func contextMenuShowInFinder(_ sender: Any) {
         let row = tableView.clickedRow
         guard row >= 0, row < driveItems.count else { return }
         NSWorkspace.shared.activateFileViewerSelecting([driveItems[row].url])
    }
    
    @objc private func contextMenuEject(_ sender: Any) {
        let row = tableView.clickedRow
        guard row >= 0, row < driveItems.count else { return }
        let item = driveItems[row]
        ejectDrive(item: item)
    }
    
    // Eject helper
    func ejectDrive(item: SidebarItem) {
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: item.url)
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 500_000_000)
                self?.loadDrives()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Eject Failed"
            alert.informativeText = "Could not eject '\(item.name)': \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    @objc private func ejectButtonAction(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0, row < driveItems.count else { return }
        ejectDrive(item: driveItems[row])
    }
    
    private func isRemovableDrive(url: URL) -> Bool {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.volumeIsEjectableKey, .volumeIsRemovableKey])
            return resourceValues.volumeIsEjectable == true || resourceValues.volumeIsRemovable == true
        } catch {
            return false
        }
    }
}

extension LocationsViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return driveItems.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = driveItems[row]
        let cellView = NSTableCellView()
        
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = item.icon
        
        let textField = NSTextField()
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.isEditable = false
        textField.font = AppDesignSystem.Typography.sidebarRow
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.stringValue = item.name
        
        cellView.addSubview(imageView)
        cellView.addSubview(textField)
        
        var constraints: [NSLayoutConstraint] = []
        
        if isRemovableDrive(url: item.url) {
            let ejectButton = HoverButton()
            ejectButton.translatesAutoresizingMaskIntoConstraints = false
            ejectButton.bezelStyle = .texturedRounded
            ejectButton.image = NSImage.mfeSymbol(named: "eject", accessibilityDescription: "Eject")
            ejectButton.isBordered = false
            ejectButton.target = self
            ejectButton.action = #selector(ejectButtonAction(_:))
            ejectButton.tag = row
            cellView.addSubview(ejectButton)
            
            constraints = [
                imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),
                
                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                textField.trailingAnchor.constraint(equalTo: ejectButton.leadingAnchor, constant: -4),
                
                ejectButton.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                ejectButton.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                ejectButton.widthAnchor.constraint(equalToConstant: 16),
                ejectButton.heightAnchor.constraint(equalToConstant: 16)
            ]
        } else {
             constraints = [
                imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),
                
                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4)
            ]
        }
        
        NSLayoutConstraint.activate(constraints)
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 22
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if info.draggingPasteboard.types?.contains(.fileURL) == true {
             if dropOperation == .on && row >= 0 { return .copy }
        }
        return []
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
         if dropOperation == .on, let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
              guard row < driveItems.count else { return false }
              let destination = driveItems[row].url
              
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

extension LocationsViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
         let row = tableView.clickedRow
         let hasSelection = row >= 0 && row < driveItems.count
         
         menu.item(withTitle: "Open")?.isEnabled = hasSelection
         menu.item(withTitle: "Open in New Tab")?.isEnabled = hasSelection
         menu.item(withTitle: "Show in Finder")?.isEnabled = hasSelection
         
         if hasSelection {
             let item = driveItems[row]
             // Check ejectable
             let isEjectable = isRemovableDrive(url: item.url)
             menu.item(withTitle: "Eject")?.isHidden = !isEjectable
             menu.item(withTitle: "Eject")?.isEnabled = isEjectable
         } else {
             menu.item(withTitle: "Eject")?.isEnabled = false
         }
    }
}

// MARK: - SettingsStoreDelegate
extension LocationsViewController: SettingsStoreDelegate {
    func settingsStoreDidUpdateAccentColor(_ settingsStore: SettingsStoreProtocol) {
        tableView.reloadData()
    }
    
    func settingsStore(_ settingsStore: SettingsStoreProtocol, hiddenFilesStateDidChange isVisible: Bool) {}
    func settingsStore(_ settingsStore: SettingsStoreProtocol, previewPaneVisibilityDidChange isVisible: Bool) {}
    func settingsStore(_ settingsStore: SettingsStoreProtocol, showFileExtensionsDidChange show: Bool) {}
    func settingsStore(_ settingsStore: SettingsStoreProtocol, easySelectDidChange enabled: Bool) {}
}
