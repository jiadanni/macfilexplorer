import Cocoa

extension FileBrowserViewController {
    // MARK: - Context Menu

    func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        let showHotkeys = settings.showContextMenuHotkeys

        menu.addItem(withTitle: "Open", action: #selector(contextMenuOpen(_:)), keyEquivalent: showHotkeys ? "\r" : "")
        menu.addItem(withTitle: "Open in New Tab", action: #selector(contextMenuOpenInNewTab(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Open With...", action: #selector(contextMenuOpenWith(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())

        let getInfoItem = NSMenuItem(title: "Get Info", action: #selector(contextMenuGetInfo(_:)), keyEquivalent: showHotkeys ? "i" : "")
        if showHotkeys {
            getInfoItem.keyEquivalentModifierMask = .command
        }
        menu.addItem(getInfoItem)
        menu.addItem(NSMenuItem.separator())

        let copyItem = NSMenuItem(title: "Copy", action: #selector(contextMenuCopy(_:)), keyEquivalent: showHotkeys ? "c" : "")
        if showHotkeys {
            copyItem.keyEquivalentModifierMask = .command
        }
        menu.addItem(copyItem)
        menu.addItem(withTitle: "Copy To...", action: #selector(contextMenuCopyTo(_:)), keyEquivalent: "")

        let cutItem = NSMenuItem(title: "Cut", action: #selector(contextMenuCut(_:)), keyEquivalent: showHotkeys ? "x" : "")
        if showHotkeys {
            cutItem.keyEquivalentModifierMask = .command
        }
        menu.addItem(cutItem)
        menu.addItem(withTitle: "Move To...", action: #selector(contextMenuMoveTo(_:)), keyEquivalent: "")

        let pasteItem = NSMenuItem(title: "Paste", action: #selector(contextMenuPaste(_:)), keyEquivalent: showHotkeys ? "v" : "")
        if showHotkeys {
            pasteItem.keyEquivalentModifierMask = .command
        }
        menu.addItem(pasteItem)
        menu.addItem(NSMenuItem.separator())

        let renameItem = NSMenuItem(title: "Rename", action: #selector(contextMenuRename(_:)), keyEquivalent: "")
        menu.addItem(renameItem)

        let deleteItem = NSMenuItem(title: "Move to Trash", action: #selector(contextMenuDelete(_:)), keyEquivalent: showHotkeys ? String(UnicodeScalar(NSDeleteCharacter)!) : "")
        if showHotkeys {
            deleteItem.keyEquivalentModifierMask = .command
        }
        menu.addItem(deleteItem)
        menu.addItem(NSMenuItem.separator())

        let newFolderItem = NSMenuItem(title: "New Folder", action: #selector(contextMenuNewFolder(_:)), keyEquivalent: showHotkeys ? "n" : "")
        if showHotkeys {
            newFolderItem.keyEquivalentModifierMask = .command
        }
        menu.addItem(newFolderItem)
        menu.addItem(withTitle: "New File", action: #selector(contextMenuNewFile(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Add to Favorites", action: #selector(contextMenuAddToFavorites(_:)), keyEquivalent: "")
        if let last = menu.items.last, let prev = menu.items.dropLast().last, last.isSeparatorItem, prev.isSeparatorItem {
            menu.removeItem(last)
        }
        let tagsMenuItem = NSMenuItem(title: "Tags", action: nil, keyEquivalent: "")
        let tagsMenu = NSMenu()
        tagsMenuItem.submenu = tagsMenu
        menu.addItem(tagsMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Show in Finder", action: #selector(contextMenuShowInFinder(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Open in Terminal", action: #selector(contextMenuOpenInTerminal(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Close Pane", action: #selector(contextMenuClosePane(_:)), keyEquivalent: "")

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

        menu.delegate = self
        return menu
    }

    // MARK: - Column Visibility

    func createHeaderColumnsMenu() -> NSMenu {
        let menu = NSMenu(title: "Columns")
        let visibility = settings.columnVisibility
        for column in outlineView.tableColumns {
            let identifier = column.identifier.rawValue
            let title = column.title
            let item = NSMenuItem(title: title, action: #selector(toggleColumnVisibility(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = identifier
            let isVisible = visibility[identifier] ?? true
            item.state = isVisible ? .on : .off
            if identifier == AppConfig.ColumnID.name { item.isEnabled = false }
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
        let resetItem = NSMenuItem(title: "Reset to Defaults", action: #selector(resetColumnVisibility(_:)), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)
        return menu
    }

    @objc private func toggleColumnVisibility(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String, identifier != AppConfig.ColumnID.name else { return }
        var visibility = settings.columnVisibility
        let current = visibility[identifier] ?? true
        visibility[identifier] = !current
        settings.columnVisibility = visibility
        applyColumnVisibility(visibility)
        outlineView.headerView?.menu = createHeaderColumnsMenu()
    }

    @objc private func resetColumnVisibility(_ sender: NSMenuItem) {
        let defaults: [String: Bool] = [
            AppConfig.ColumnID.name: true,
            AppConfig.ColumnID.dateModified: true,
            AppConfig.ColumnID.type: true,
            AppConfig.ColumnID.size: true,
            AppConfig.ColumnID.dateCreated: false,
            "TagsColumn": false
        ]
        settings.columnVisibility = defaults
        applyColumnVisibility(defaults)
        outlineView.headerView?.menu = createHeaderColumnsMenu()
    }

    func applyColumnVisibility(_ visibility: [String: Bool]) {
        for column in outlineView.tableColumns {
            let id = column.identifier.rawValue
            if id == AppConfig.ColumnID.name {
                column.isHidden = false
                continue
            }
            let shouldShow = visibility[id] ?? true
            column.isHidden = !shouldShow
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let selectedItems = getSelectedItems()

        if let openWithItem = menu.items.first(where: { $0.title == "Open With..." }) {
            let shouldHideOpenWith = settings.hideOpenWith ||
                selectedItems.isEmpty ||
                selectedItems.count > 1 ||
                selectedItems.first?.isDirectory == true
            openWithItem.isHidden = shouldHideOpenWith
        }

        if let getInfoItem = menu.items.first(where: { $0.title == "Get Info" }) {
            getInfoItem.isHidden = settings.hideGetInfo
        }

        if let copyItem = menu.items.first(where: { $0.title == "Copy" }) {
            copyItem.isHidden = settings.hideCopy
        }

        if let cutItem = menu.items.first(where: { $0.title == "Cut" }) {
            cutItem.isHidden = settings.hideCut
        }

        if let pasteItem = menu.items.first(where: { $0.title == "Paste" }) {
            pasteItem.isHidden = settings.hidePaste
        }

        if let renameItem = menu.items.first(where: { $0.title == "Rename" }) {
            renameItem.isHidden = settings.hideRename
        }

        if let deleteItem = menu.items.first(where: { $0.title == "Move to Trash" }) {
            deleteItem.isHidden = settings.hideMoveToTrash
        }

        if let showInFinderItem = menu.items.first(where: { $0.title == "Show in Finder" }) {
            showInFinderItem.isHidden = settings.hideShowInFinder
        }

        if let changeFolderColorItem = menu.items.first(where: { $0.title == "Change Folder Color..." }) {
            menu.removeItem(changeFolderColorItem)
        }

        if let newFolderItem = menu.items.first(where: { $0.title == "New Folder" }) {
            newFolderItem.isHidden = settings.hideNewFolder
        }

        if let tagsMenuItem = menu.items.first(where: { $0.title == "Tags" }) {
            let items = getSelectedItems()
            if items.isEmpty {
                tagsMenuItem.isHidden = true
            } else {
                tagsMenuItem.isHidden = false
                let tagsMenu = tagsMenuItem.submenu!
                tagsMenu.removeAllItems()

                let allTags = getAllTags()
                for tag in allTags {
                    let menuItem = NSMenuItem(title: tag, action: #selector(toggleTag(_:)), keyEquivalent: "")
                    menuItem.target = self
                    menuItem.state = items.allSatisfy({ $0.tags.contains(tag) }) ? .on : .off
                    tagsMenu.addItem(menuItem)
                }

                tagsMenu.addItem(NSMenuItem.separator())
                tagsMenu.addItem(withTitle: "Add New Tag...", action: #selector(addNewTag(_:)), keyEquivalent: "")
            }
        }
    }

    func getSelectedItems() -> [FileItem] {
        selectionCoordinator.selectedItems()
    }

    private func getAllTags() -> [String] {
        let items = getSelectedItems()
        var allTags = Set<String>()
        for item in items {
            allTags.formUnion(item.tags)
        }
        return allTags.sorted()
    }

    @objc private func toggleTag(_ sender: NSMenuItem) {
        let items = getSelectedItems()
        let tag = sender.title
        let add = sender.state == .off

        for item in items {
            var tags = item.tags
            if add {
                if !tags.contains(tag) {
                    tags.append(tag)
                }
            } else {
                tags.removeAll { $0 == tag }
            }

            do {
                try (item.url as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
            } catch {
                showError("Failed to update tags for \(item.name): \(error.localizedDescription)")
            }
        }
        refreshCurrentDirectory()
    }

    @objc private func addNewTag(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }

        guard let newTag = FileBrowserDialogHelper.showTextInputDialog(
            title: "Add New Tag",
            message: "Enter the name for the selected items:"
        ), !newTag.isEmpty else { return }

        for item in items {
            var tags = item.tags
            if !tags.contains(newTag) {
                tags.append(newTag)
            }

            do {
                try (item.url as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
            } catch {
                showError("Failed to update tags for \(item.name): \(error.localizedDescription)")
            }
        }
        refreshCurrentDirectory()
    }

    private func getSelectedFileURLs() -> [URL] {
        return getSelectedItems().map { $0.url }
    }

    @objc func contextMenuOpen(_ sender: Any) {
        let items = getSelectedItems()
        if items.count == 1 {
            let item = items[0]
            if item.isDirectory {
                navigationCoordinator.loadDirectory(item.url)
            } else {
                FileBrowserActionHelper.openFile(item.url)
            }
        } else if items.count > 1 {
            for url in items.map({ $0.url }) {
                FileBrowserActionHelper.openFile(url)
            }
        }
    }

    @objc func contextMenuOpenInNewTab(_ sender: Any) {
        let items = getSelectedItems()
        if items.count == 1 {
            let item = items[0]
            if item.isDirectory {
                delegate?.openInNewTab(url: item.url)
            }
        }
    }

    @objc func contextMenuOpenWith(_ sender: Any) {
        let items = getSelectedItems()
        guard let item = items.first, items.count == 1, !item.isDirectory else { return }

        let openWithMenu = NSMenu()
        let url = item.url as CFURL
        let defaultAppURL = LSCopyDefaultApplicationURLForURL(url, .all, nil)?.takeRetainedValue() as? URL
        let appURLs = LSCopyApplicationURLsForURL(url, .all)?.takeRetainedValue() as? [URL] ?? []

        for appURL in appURLs {
            let appName = appURL.deletingPathExtension().lastPathComponent
            let menuItem = NSMenuItem(title: appName, action: #selector(openWithApp(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = appURL
            menuItem.image = NSWorkspace.shared.icon(forFile: appURL.path)
            if appURL == defaultAppURL {
                menuItem.state = .on
            }
            openWithMenu.addItem(menuItem)
        }

        openWithMenu.addItem(NSMenuItem.separator())
        openWithMenu.addItem(withTitle: "Other...", action: #selector(openWithOther(_:)), keyEquivalent: "")

        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(openWithMenu, with: event, for: view)
        }
    }

    @objc func openWithApp(_ sender: NSMenuItem) {
        guard let appURL = sender.representedObject as? URL else { return }
        let items = getSelectedItems()
        guard let item = items.first, items.count == 1 else { return }

        FileBrowserActionHelper.openFile(item.url, withApplication: appURL)
    }

    @objc func openWithOther(_ sender: Any) {
        let items = getSelectedItems()
        guard let item = items.first, items.count == 1 else { return }

        let openPanel = NSOpenPanel()
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        openPanel.allowedContentTypes = [.application]
        openPanel.allowsMultipleSelection = false

        if openPanel.runModal() == .OK, let appURL = openPanel.url {
            FileBrowserActionHelper.openFile(item.url, withApplication: appURL)
        }
    }

    @objc func contextMenuGetInfo(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }
    }

    @objc func contextMenuCopy(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items.map { $0.url as NSURL })
    }

    @objc private func contextMenuCopyTo(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }

        let openPanel = NSOpenPanel()
        openPanel.title = "Copy To..."
        openPanel.prompt = "Copy"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true

        openPanel.begin { [weak self] response in
            guard let self = self else {
                debugLog("Warning: FileBrowserViewController deallocated before copy-to dialog completion")
                return
            }
            guard response == .OK, let destinationURL = openPanel.url else { return }
            self.performFileOperation(.copy, items: items.map { $0.url }, destination: destinationURL)
        }
    }

    @objc func contextMenuCut(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let customCutMarkerType = NSPasteboard.PasteboardType(AppConfig.Pasteboard.cutMarkerType)
        pasteboard.declareTypes([.fileURL, customCutMarkerType], owner: nil)

        let fileURLs = items.map { $0.url as NSURL }
        pasteboard.writeObjects(fileURLs)

        pasteboard.setString("cut", forType: customCutMarkerType)
    }

    @objc private func contextMenuMoveTo(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }

        let openPanel = NSOpenPanel()
        openPanel.title = "Move To..."
        openPanel.prompt = "Move"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true

        openPanel.begin { [weak self] response in
            guard let self = self else {
                debugLog("Warning: FileBrowserViewController deallocated before move-to dialog completion")
                return
            }
            guard response == .OK, let destinationURL = openPanel.url else { return }
            self.performFileOperation(.move, items: items.map { $0.url }, destination: destinationURL)
        }
    }

    @objc func contextMenuPaste(_ sender: Any) {
        let pasteboard = NSPasteboard.general
        guard let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !fileURLs.isEmpty else { return }

        let customCutMarkerType = NSPasteboard.PasteboardType(AppConfig.Pasteboard.cutMarkerType)
        let isCut = pasteboard.string(forType: customCutMarkerType) == "cut"
        let operation: FileOperationType = isCut ? .move : .copy

        performFileOperation(operation, items: fileURLs, destination: currentDirectory)

        if isCut {
            pasteboard.clearContents()
        }
    }

    @objc func contextMenuRename(_ sender: Any) {
        let selectedItems = getSelectedItems()
        guard let item = selectedItems.first, selectedItems.count == 1 else { return }

        if let outlineView = self.outlineView, currentViewMode == .list, let row = outlineView.item(atRow: outlineView.selectedRow) as? FileItem, row == item {
            let rowView = outlineView.rowView(atRow: outlineView.selectedRow, makeIfNecessary: false)
            if let cell = rowView?.view(atColumn: 0) as? NSTableCellView, let textField = cell.textField {
                textField.isEditable = true
                view.window?.makeFirstResponder(textField)
            }
        }
    }

    @objc func contextMenuDelete(_ sender: Any) {
        let items = getSelectedItems()
        guard !items.isEmpty else { return }

        let confirmed = FileBrowserDialogHelper.showConfirmationDialog(
            title: "Delete \(items.count) item(s)?",
            message: "Are you sure you want to move \(items.count) item(s) to the Trash?"
        )

        if confirmed {
            performFileOperation(.delete, items: items.map { $0.url }, destination: nil)
        }
    }

    @objc func contextMenuNewFolder(_ sender: Any) {
        guard let folderName = FileBrowserDialogHelper.showNewFolderDialog() else { return }

        let newFolderURL = currentDirectory.appendingPathComponent(folderName)

        do {
            try FileManager.default.createDirectory(at: newFolderURL, withIntermediateDirectories: false, attributes: nil)
            refreshCurrentDirectory()
        } catch {
            showError("Failed to create folder: \(error.localizedDescription)")
        }
    }

    @objc func contextMenuNewFile(_ sender: Any) {
        guard let newFileName = FileBrowserDialogHelper.showNewFileDialog() else { return }

        let newFileURL = currentDirectory.appendingPathComponent(newFileName)
        if !FileManager.default.fileExists(atPath: newFileURL.path) {
            FileManager.default.createFile(atPath: newFileURL.path, contents: nil, attributes: nil)
            refreshCurrentDirectory()
        } else {
            showError("A file with this name already exists.")
        }
    }

    @objc private func contextMenuAdvancedCopyTo(_ sender: Any) {
    }

    @objc private func contextMenuAdvancedMoveTo(_ sender: Any) {
    }

    @objc func contextMenuShowInFinder(_ sender: Any) {
        let items = getSelectedItems()
        if items.isEmpty {
            FileBrowserActionHelper.revealInFinder(currentDirectory)
        } else {
            for item in items {
                FileBrowserActionHelper.revealInFinder(item.url)
            }
        }
    }

    @objc func contextMenuOpenInTerminal(_ sender: Any) {
        delegate?.toolbarDidRequestOpenInTerminal(from: self)
    }

    @objc func contextMenuClosePane(_ sender: Any) {
        delegate?.fileBrowserDidRequestClosePane(self)
    }

    @objc func contextMenuAddToFavorites(_ sender: Any) {
        let items = getSelectedItems()
        guard let item = items.first, items.count == 1 else { return }
        delegate?.fileBrowserDidRequestAddToFavorites(self, item: item)
    }
}
