import Cocoa

/// Manages context menu creation and handling for the file browser.
///
/// Extracted from FileBrowserViewController to reduce complexity.
/// Responsible for:
/// - Building the context menu structure
/// - Handling menu item actions
/// - Managing column visibility menu
protocol FileBrowserContextMenuDelegate: AnyObject {
    func contextMenuDidSelectOpen()
    func contextMenuDidSelectOpenInNewTab()
    func contextMenuDidSelectOpenWith()
    func contextMenuDidSelectGetInfo()
    func contextMenuDidSelectCopy()
    func contextMenuDidSelectCopyTo()
    func contextMenuDidSelectCut()
    func contextMenuDidSelectMoveTo()
    func contextMenuDidSelectPaste()
    func contextMenuDidSelectRename()
    func contextMenuDidSelectDelete()
    func contextMenuDidSelectNewFolder()
    func contextMenuDidSelectNewFile()
    func contextMenuDidSelectAddToFavorites()
    func contextMenuDidSelectShowInFinder()
    func contextMenuDidSelectOpenInTerminal()
    func contextMenuDidSelectClosePane()
}

class FileBrowserContextMenuProvider: NSObject, NSMenuDelegate {
    weak var delegate: FileBrowserContextMenuDelegate?
    private let settings: SettingsStoreProtocol
    
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
            if identifier == "NameColumn" { item.isEnabled = false }
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        let resetItem = NSMenuItem(title: "Reset to Defaults", action: #selector(handleResetColumns(_:)), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)
        
        return menu
    }
    
    // MARK: - Menu Item Actions
    
    @objc private func handleOpen(_ sender: Any) {
        delegate?.contextMenuDidSelectOpen()
    }
    
    @objc private func handleOpenInNewTab(_ sender: Any) {
        delegate?.contextMenuDidSelectOpenInNewTab()
    }
    
    @objc private func handleOpenWith(_ sender: Any) {
        delegate?.contextMenuDidSelectOpenWith()
    }
    
    @objc private func handleGetInfo(_ sender: Any) {
        delegate?.contextMenuDidSelectGetInfo()
    }
    
    @objc private func handleCopy(_ sender: Any) {
        delegate?.contextMenuDidSelectCopy()
    }
    
    @objc private func handleCopyTo(_ sender: Any) {
        delegate?.contextMenuDidSelectCopyTo()
    }
    
    @objc private func handleCut(_ sender: Any) {
        delegate?.contextMenuDidSelectCut()
    }
    
    @objc private func handleMoveTo(_ sender: Any) {
        delegate?.contextMenuDidSelectMoveTo()
    }
    
    @objc private func handlePaste(_ sender: Any) {
        delegate?.contextMenuDidSelectPaste()
    }
    
    @objc private func handleRename(_ sender: Any) {
        delegate?.contextMenuDidSelectRename()
    }
    
    @objc private func handleDelete(_ sender: Any) {
        delegate?.contextMenuDidSelectDelete()
    }
    
    @objc private func handleNewFolder(_ sender: Any) {
        delegate?.contextMenuDidSelectNewFolder()
    }
    
    @objc private func handleNewFile(_ sender: Any) {
        delegate?.contextMenuDidSelectNewFile()
    }
    
    @objc private func handleAddToFavorites(_ sender: Any) {
        delegate?.contextMenuDidSelectAddToFavorites()
    }
    
    @objc private func handleShowInFinder(_ sender: Any) {
        delegate?.contextMenuDidSelectShowInFinder()
    }
    
    @objc private func handleOpenInTerminal(_ sender: Any) {
        delegate?.contextMenuDidSelectOpenInTerminal()
    }
    
    @objc private func handleClosePane(_ sender: Any) {
        delegate?.contextMenuDidSelectClosePane()
    }
    
    @objc private func handleToggleColumn(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String, identifier != "NameColumn" else { return }
        var visibility = settings.columnVisibility
        let current = visibility[identifier] ?? true
        visibility[identifier] = !current
        settings.columnVisibility = visibility
    }
    
    @objc private func handleResetColumns(_ sender: NSMenuItem) {
        let defaults: [String: Bool] = [
            "NameColumn": true,
            "DateModifiedColumn": true,
            "TypeColumn": true,
            "SizeColumn": true,
            "DateCreatedColumn": false,
            "TagsColumn": false
        ]
        settings.columnVisibility = defaults
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
        // Remove trailing separator
        if let last = cleaned.last, last.isSeparatorItem { cleaned.removeLast() }
        menu.removeAllItems()
        cleaned.forEach { menu.addItem($0) }
    }
}
