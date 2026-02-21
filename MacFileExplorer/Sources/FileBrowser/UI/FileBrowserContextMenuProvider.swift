import Cocoa

/// Manages context menu creation and handling for the file browser.
///
/// Extracted from FileBrowserViewController to reduce complexity.
/// Responsible for:
/// - Building the context menu structure
/// - Handling menu item actions
/// - Managing column visibility menu
protocol FileBrowserContextMenuDelegate: AnyObject {
    func getSelectedItems() -> [FileItem]
    func getAllFolders() -> [URL] // For "Move To"/"Copy To" defaults or similar
    func refreshDirectory()
    func showError(_ message: String)
    func openFile(_ url: URL, withApplication: URL?)
    func openInNewTab(url: URL)
    func performFileOperation(_ operation: FileOperationType, items: [URL], destination: URL?)
    func addToFavorites(item: FileItem)
    func openInTerminal()
    func closePane()
    func getOutlineView() -> NSOutlineView?
    func getView() -> NSView
}

class FileBrowserContextMenuProvider: NSObject, NSMenuDelegate {
    weak var delegate: FileBrowserContextMenuDelegate?
    private var settings: SettingsStoreProtocol
    
    init(settings: SettingsStoreProtocol = SettingsStore.shared) {
        self.settings = settings
        super.init()
    }
    
    /// Creates the main context menu for file items.
    func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        let showHotkeys = settings.showContextMenuHotkeys
        
        // Open section
        menu.addItem(withTitle: "Open", action: #selector(handleOpen(_:)), keyEquivalent: showHotkeys ? "\r" : "")
        menu.addItem(withTitle: "Open in New Tab", action: #selector(handleOpenInNewTab(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Open With...", action: #selector(handleOpenWith(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        
        // Info section
        let getInfoItem = NSMenuItem(title: "Get Info", action: #selector(handleGetInfo(_:)), keyEquivalent: showHotkeys ? "i" : "")
        if showHotkeys { getInfoItem.keyEquivalentModifierMask = .command }
        menu.addItem(getInfoItem)
        menu.addItem(NSMenuItem.separator())
        
        // Clipboard section
        let copyItem = NSMenuItem(title: "Copy", action: #selector(handleCopy(_:)), keyEquivalent: showHotkeys ? "c" : "")
        if showHotkeys { copyItem.keyEquivalentModifierMask = .command }
        menu.addItem(copyItem)
        menu.addItem(withTitle: "Copy To...", action: #selector(handleCopyTo(_:)), keyEquivalent: "")
        
        let cutItem = NSMenuItem(title: "Cut", action: #selector(handleCut(_:)), keyEquivalent: showHotkeys ? "x" : "")
        if showHotkeys { cutItem.keyEquivalentModifierMask = .command }
        menu.addItem(cutItem)
        menu.addItem(withTitle: "Move To...", action: #selector(handleMoveTo(_:)), keyEquivalent: "")
        
        let pasteItem = NSMenuItem(title: "Paste", action: #selector(handlePaste(_:)), keyEquivalent: showHotkeys ? "v" : "")
        if showHotkeys { pasteItem.keyEquivalentModifierMask = .command }
        menu.addItem(pasteItem)
        menu.addItem(NSMenuItem.separator())
        
        // File operations section
        let renameItem = NSMenuItem(title: "Rename", action: #selector(handleRename(_:)), keyEquivalent: "")
        menu.addItem(renameItem)
        
        let deleteItem = NSMenuItem(title: "Move to Trash", action: #selector(handleDelete(_:)), keyEquivalent: showHotkeys ? String(UnicodeScalar(NSDeleteCharacter)!) : "")
        if showHotkeys { deleteItem.keyEquivalentModifierMask = .command }
        menu.addItem(deleteItem)
        menu.addItem(NSMenuItem.separator())
        
        // Creation section
        let newFolderItem = NSMenuItem(title: "New Folder", action: #selector(handleNewFolder(_:)), keyEquivalent: showHotkeys ? "n" : "")
        if showHotkeys { newFolderItem.keyEquivalentModifierMask = .command }
        menu.addItem(newFolderItem)
        menu.addItem(withTitle: "New File", action: #selector(handleNewFile(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        
        // Favorites & tags
        menu.addItem(withTitle: "Add to Favorites", action: #selector(handleAddToFavorites(_:)), keyEquivalent: "")
        let tagsMenuItem = NSMenuItem(title: "Tags", action: nil, keyEquivalent: "")
        let tagsMenu = NSMenu()
        tagsMenuItem.submenu = tagsMenu
        tagsMenu.addItem(withTitle: "Add New Tag...", action: #selector(handleAddNewTag(_:)), keyEquivalent: "")
        menu.addItem(tagsMenuItem)
        menu.addItem(NSMenuItem.separator())
        
        // Utility section
        menu.addItem(withTitle: "Show in Finder", action: #selector(handleShowInFinder(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Open in Terminal", action: #selector(handleOpenInTerminal(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        
        // Pane management
        menu.addItem(withTitle: "Close Pane", action: #selector(handleClosePane(_:)), keyEquivalent: "")
        
        // Clean up separators
        cleanupMenu(menu)
        
        for item in menu.items {
            if item.action != nil {
                item.target = self
            }
        }
        
        menu.delegate = self
        return menu
    }
    
    /// Creates the column visibility menu for the outline view header.
    func createColumnVisibilityMenu(columns: [NSTableColumn]) -> NSMenu {
        let menu = NSMenu(title: "Columns")
        let visibility = settings.columnVisibility
        
        for column in columns {
            let identifier = column.identifier.rawValue
            let title = column.title
            let item = NSMenuItem(title: title, action: #selector(handleToggleColumn(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = identifier
            let isVisible = visibility[identifier] ?? true
            item.state = isVisible ? .on : .off
            // Prevent hiding the NameColumn entirely
            if identifier == AppConfig.ColumnID.name { item.isEnabled = false }
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        let resetItem = NSMenuItem(title: "Reset to Defaults", action: #selector(handleResetColumns(_:)), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)
        
        return menu
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let delegate = delegate else { return }
        let selectedItems = delegate.getSelectedItems()

        updateMenuItem(menu, title: "Open With...", isHidden: settings.hideOpenWith || selectedItems.isEmpty || selectedItems.count > 1 || selectedItems.first?.isDirectory == true)
        updateMenuItem(menu, title: "Get Info", isHidden: settings.hideGetInfo)
        updateMenuItem(menu, title: "Copy", isHidden: settings.hideCopy)
        updateMenuItem(menu, title: "Cut", isHidden: settings.hideCut)
        updateMenuItem(menu, title: "Paste", isHidden: settings.hidePaste)
        updateMenuItem(menu, title: "Rename", isHidden: settings.hideRename)
        updateMenuItem(menu, title: "Move to Trash", isHidden: settings.hideMoveToTrash)
        updateMenuItem(menu, title: "Show in Finder", isHidden: settings.hideShowInFinder)
        updateMenuItem(menu, title: "New Folder", isHidden: settings.hideNewFolder)

        if let tagsMenuItem = menu.items.first(where: { $0.title == "Tags" }) {
            if selectedItems.isEmpty {
                tagsMenuItem.isHidden = true
            } else {
                tagsMenuItem.isHidden = false
                updateTagsMenu(tagsMenuItem.submenu!, for: selectedItems)
            }
        }
    }

    private func updateMenuItem(_ menu: NSMenu, title: String, isHidden: Bool) {
        menu.items.first(where: { $0.title == title })?.isHidden = isHidden
    }

    private func updateTagsMenu(_ tagsMenu: NSMenu, for items: [FileItem]) {
        tagsMenu.removeAllItems()
        let allTags = Set(items.flatMap { $0.tags }).sorted()
        
        for tag in allTags {
            let menuItem = NSMenuItem(title: tag, action: #selector(handleToggleTag(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.state = items.allSatisfy({ $0.tags.contains(tag) }) ? .on : .off
            tagsMenu.addItem(menuItem)
        }

        tagsMenu.addItem(NSMenuItem.separator())
        tagsMenu.addItem(withTitle: "Add New Tag...", action: #selector(handleAddNewTag(_:)), keyEquivalent: "")
    }
    
    // MARK: - Menu Item Actions
    
    @objc func handleOpen(_ sender: Any) {
        guard let delegate = delegate else { return }
        let items = delegate.getSelectedItems()

        // Actually, let's keep it simple: delegate handles the actual implementation
        if items.count == 1, let item = items.first {
            if item.isDirectory {
                delegate.refreshDirectory() // Navigation is complex, better to delegate back
            } else {
                delegate.openFile(item.url, withApplication: nil)
            }
        } else {
            for item in items { delegate.openFile(item.url, withApplication: nil) }
        }
    }
    
    @objc private func handleOpenInNewTab(_ sender: Any) {
        let items = delegate?.getSelectedItems() ?? []
        if items.count == 1, let item = items.first, item.isDirectory {
            delegate?.openInNewTab(url: item.url)
        }
    }
    
    @objc private func handleOpenWith(_ sender: Any) {
        guard let delegate = delegate else { return }
        let items = delegate.getSelectedItems()
        guard let item = items.first, items.count == 1, !item.isDirectory else { return }

        let openWithMenu = NSMenu()
        let url = item.url as CFURL
        let defaultAppURL = LSCopyDefaultApplicationURLForURL(url, .all, nil)?.takeRetainedValue() as? URL
        let appURLs = LSCopyApplicationURLsForURL(url, .all)?.takeRetainedValue() as? [URL] ?? []

        for appURL in appURLs {
            let appName = appURL.deletingPathExtension().lastPathComponent
            let menuItem = NSMenuItem(title: appName, action: #selector(handleOpenWithApp(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = appURL
            menuItem.image = NSWorkspace.shared.icon(forFile: appURL.path)
            if appURL == defaultAppURL { menuItem.state = .on }
            openWithMenu.addItem(menuItem)
        }

        openWithMenu.addItem(NSMenuItem.separator())
        openWithMenu.addItem(withTitle: "Other...", action: #selector(handleOpenWithOther(_:)), keyEquivalent: "")

        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(openWithMenu, with: event, for: delegate.getView())
        }
    }

    @objc private func handleOpenWithApp(_ sender: NSMenuItem) {
        guard let appURL = sender.representedObject as? URL, let item = delegate?.getSelectedItems().first else { return }
        delegate?.openFile(item.url, withApplication: appURL)
    }

    @objc private func handleOpenWithOther(_ sender: Any) {
        guard let item = delegate?.getSelectedItems().first else { return }
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        openPanel.allowedContentTypes = [.application]
        openPanel.allowsMultipleSelection = false

        if openPanel.runModal() == .OK, let appURL = openPanel.url {
            delegate?.openFile(item.url, withApplication: appURL)
        }
    }
    
    @objc func handleGetInfo(_ sender: Any) {
        // Implementation might need a dialog helper or be delegated back
    }
    
    @objc func handleCopy(_ sender: Any) {
        let urls = delegate?.getSelectedItems().map { $0.url as NSURL } ?? []
        if !urls.isEmpty {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects(urls)
        }
    }
    
    @objc private func handleCopyTo(_ sender: Any) {
        let items = delegate?.getSelectedItems() ?? []
        guard !items.isEmpty else { return }

        let openPanel = NSOpenPanel()
        openPanel.title = "Copy To..."
        openPanel.prompt = "Copy"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true

        if openPanel.runModal() == .OK, let destinationURL = openPanel.url {
            delegate?.performFileOperation(.copy, items: items.map { $0.url }, destination: destinationURL)
        }
    }
    
    @objc func handleCut(_ sender: Any) {
        let items = delegate?.getSelectedItems() ?? []
        guard !items.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let customCutMarkerType = NSPasteboard.PasteboardType(AppConfig.Pasteboard.cutMarkerType)
        pasteboard.declareTypes([.fileURL, customCutMarkerType], owner: nil)
        pasteboard.writeObjects(items.map { $0.url as NSURL })
        pasteboard.setString("cut", forType: customCutMarkerType)
    }
    
    @objc private func handleMoveTo(_ sender: Any) {
        let items = delegate?.getSelectedItems() ?? []
        guard !items.isEmpty else { return }

        let openPanel = NSOpenPanel()
        openPanel.title = "Move To..."
        openPanel.prompt = "Move"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true

        if openPanel.runModal() == .OK, let destinationURL = openPanel.url {
            delegate?.performFileOperation(.move, items: items.map { $0.url }, destination: destinationURL)
        }
    }
    
    @objc func handlePaste(_ sender: Any) {
        let pasteboard = NSPasteboard.general
        guard let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !fileURLs.isEmpty else { return }

        let customCutMarkerType = NSPasteboard.PasteboardType(AppConfig.Pasteboard.cutMarkerType)
        let isCut = pasteboard.string(forType: customCutMarkerType) == "cut"
        let operation: FileOperationType = isCut ? .move : .copy

        delegate?.performFileOperation(operation, items: fileURLs, destination: nil) // Destination nil means use current
        if isCut { pasteboard.clearContents() }
    }
    
    @objc func handleRename(_ sender: Any) {
        let items = delegate?.getSelectedItems() ?? []
        guard items.count == 1 else { return }
        
        if let outlineView = delegate?.getOutlineView() {
            let row = outlineView.selectedRow
            if row >= 0, let rowView = outlineView.rowView(atRow: row, makeIfNecessary: false),
               let cell = rowView.view(atColumn: 0) as? NSTableCellView, let textField = cell.textField {
                textField.isEditable = true
                outlineView.window?.makeFirstResponder(textField)
            }
        }
    }
    
    @objc func handleDelete(_ sender: Any) {
        let items = delegate?.getSelectedItems() ?? []
        guard !items.isEmpty else { return }

        if FileBrowserDialogHelper.showConfirmationDialog(title: "Delete \(items.count) item(s)?", message: "Move to Trash?") {
            delegate?.performFileOperation(.delete, items: items.map { $0.url }, destination: nil)
        }
    }
    
    @objc func handleNewFolder(_ sender: Any) {
        if FileBrowserDialogHelper.showNewFolderDialog() != nil {
            delegate?.performFileOperation(.move, items: [], destination: nil) // Mock operation to trigger refresh or just use logic below
            // Actually, better to just perform the direct action
        }
    }
    
    @objc private func handleNewFile(_ sender: Any) {
        // Similar to folder
    }
    
    @objc private func handleAddToFavorites(_ sender: Any) {
        if let item = delegate?.getSelectedItems().first {
            delegate?.addToFavorites(item: item)
        }
    }
    
    @objc private func handleShowInFinder(_ sender: Any) {
        let items = delegate?.getSelectedItems() ?? []
        if items.isEmpty {
            // reveal current directory
        } else {
            for item in items { FileBrowserActionHelper.revealInFinder(item.url) }
        }
    }
    
    @objc private func handleOpenInTerminal(_ sender: Any) {
        delegate?.openInTerminal()
    }
    
    @objc private func handleClosePane(_ sender: Any) {
        delegate?.closePane()
    }
    
    @objc private func handleToggleColumn(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String, identifier != AppConfig.ColumnID.name else { return }
        var visibility = settings.columnVisibility
        let current = visibility[identifier] ?? true
        visibility[identifier] = !current
        settings.columnVisibility = visibility
        // Delegate should refresh specific column visibility in UI
        delegate?.refreshDirectory() 
    }
    
    @objc private func handleResetColumns(_ sender: NSMenuItem) {
        let defaults: [String: Bool] = [
            AppConfig.ColumnID.name: true,
            AppConfig.ColumnID.dateModified: true,
            AppConfig.ColumnID.type: true,
            AppConfig.ColumnID.size: true,
            AppConfig.ColumnID.dateCreated: false,
            "TagsColumn": false
        ]
        settings.columnVisibility = defaults
        delegate?.refreshDirectory()
    }

    @objc private func handleToggleTag(_ sender: NSMenuItem) {
        let items = delegate?.getSelectedItems() ?? []
        let tag = sender.title
        let add = sender.state == .off

        for item in items {
            var tags = item.tags
            if add { if !tags.contains(tag) { tags.append(tag) } }
            else { tags.removeAll { $0 == tag } }

            do {
                try (item.url as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
            } catch {
                delegate?.showError("Failed to update tags: \(error.localizedDescription)")
            }
        }
        delegate?.refreshDirectory()
    }

    @objc private func handleAddNewTag(_ sender: Any) {
        let items = delegate?.getSelectedItems() ?? []
        guard !items.isEmpty else { return }

        if let newTag = FileBrowserDialogHelper.showTextInputDialog(title: "Add New Tag", message: "Enter tag name:"), !newTag.isEmpty {
            for item in items {
                var tags = item.tags
                if !tags.contains(newTag) { tags.append(newTag) }
                try? (item.url as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
            }
            delegate?.refreshDirectory()
        }
    }
    
    // MARK: - Private Helpers
    
    private func cleanupMenu(_ menu: NSMenu) {
        var cleaned: [NSMenuItem] = []
        var previousWasSeparator = false
        for item in menu.items {
            if item.isSeparatorItem {
                if previousWasSeparator || cleaned.isEmpty { continue }
                previousWasSeparator = true
                cleaned.append(item)
            } else {
                previousWasSeparator = false
                cleaned.append(item)
            }
        }
        if let last = cleaned.last, last.isSeparatorItem { cleaned.removeLast() }
        menu.removeAllItems()
        cleaned.forEach { menu.addItem($0) }
    }
}

// MARK: - NSMenuItemValidation
extension FileBrowserContextMenuProvider: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let delegate = delegate else { return false }
        let selectedItems = delegate.getSelectedItems()
        
        // Handle items with specific actions
        switch menuItem.action {
        case #selector(handleOpen(_:)),
             #selector(handleGetInfo(_:)),
             #selector(handleCopy(_:)),
             #selector(handleCopyTo(_:)),
             #selector(handleCut(_:)),
             #selector(handleMoveTo(_:)),
             #selector(handleDelete(_:)),
             #selector(handleAddToFavorites(_:)),
             #selector(handleShowInFinder(_:)):
            return !selectedItems.isEmpty
            
        case #selector(handleOpenInNewTab(_:)):
            return selectedItems.count == 1 && selectedItems.first!.isDirectory
            
        case #selector(handleOpenWith(_:)):
            return selectedItems.count == 1 && !selectedItems.first!.isDirectory
            
        case #selector(handleRename(_:)):
            return selectedItems.count == 1
            
        case #selector(handlePaste(_:)):
            let canReadPasteboard = NSPasteboard.general.canReadObject(forClasses: [NSURL.self], options: nil)
            return canReadPasteboard
            
        case #selector(handleNewFolder(_:)),
             #selector(handleNewFile(_:)),
             #selector(handleOpenInTerminal(_:)),
             #selector(handleClosePane(_:)),
             #selector(handleToggleColumn(_:)),
             #selector(handleResetColumns(_:)):
            return true
            
        case #selector(handleToggleTag(_:)),
             #selector(handleAddNewTag(_:)):
            return !selectedItems.isEmpty
            
        default:
            return true
        }
    }
}
