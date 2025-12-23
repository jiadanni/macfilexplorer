//
//  StorageAnalyzerWindowController.swift
//  MacFileExplorer
//
//  Main window controller for Storage Analyzer
//

import Cocoa

class StorageAnalyzerWindowController: NSWindowController {
    // MARK: - Properties

    private var splitViewController: NSSplitViewController!
    private var listViewController: StorageListViewController!
    private var summaryViewController: StorageSummaryViewController!

    private var toolbar: NSToolbar!
    private var searchField: NSSearchField!

    private var engine: StorageAnalyzerEngine!
    private var rootURL: URL?
    private var rootItem: StorageItem?

    private var progressViewController: StorageProgressViewController?
    private var progressSheet: NSWindow?
    private var scopeSheet: NSWindow?

    // MARK: - Initialization

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Storage Analyzer"
        window.minSize = NSSize(width: 700, height: 500)

        self.init(window: window)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        guard let window = window else { return }

        // Create engine
        engine = StorageAnalyzerEngine()

        // Create view controllers
        listViewController = StorageListViewController()
        listViewController.delegate = self

        summaryViewController = StorageSummaryViewController()

        // Create split view
        splitViewController = NSSplitViewController()
        splitViewController.splitView.isVertical = true
        splitViewController.splitView.dividerStyle = .thin

        let listItem = NSSplitViewItem(viewController: listViewController)
        listItem.canCollapse = false
        listItem.minimumThickness = 400

        let summaryItem = NSSplitViewItem(sidebarWithViewController: summaryViewController)
        summaryItem.canCollapse = false
        summaryItem.minimumThickness = 250
        summaryItem.maximumThickness = 350

        splitViewController.addSplitViewItem(listItem)
        splitViewController.addSplitViewItem(summaryItem)

        window.contentViewController = splitViewController

        // Setup toolbar
        setupToolbar()

        // Show scope selection dialog
        showScopeSelectionDialog()
    }

    private func setupToolbar() {
        toolbar = NSToolbar(identifier: "StorageAnalyzerToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        window?.toolbar = toolbar
    }

    // MARK: - Scope Selection

    private func showScopeSelectionDialog() {
        let scopeVC = StorageScopeSelectionViewController()
        scopeVC.completionHandler = { [weak self] url, options in
            // Dismiss the scope selection sheet first
            if let sheet = self?.scopeSheet {
                self?.window?.endSheet(sheet)
                self?.scopeSheet = nil
            }
            // Then start the scan
            self?.startScan(url: url, options: options)
        }

        scopeVC.cancelHandler = { [weak self] in
            // User cancelled - dismiss sheet and close the Storage Analyzer window
            if let sheet = self?.scopeSheet {
                self?.window?.endSheet(sheet)
                self?.scopeSheet = nil
            }
            self?.window?.close()
        }

        let sheet = NSWindow(contentViewController: scopeVC)
        sheet.styleMask = [.titled, .closable]
        sheet.title = "Select Scan Scope"
        sheet.delegate = self
        scopeSheet = sheet
        window?.beginSheet(sheet)
    }

    // MARK: - Scanning

    private func startScan(url: URL, options: StorageAnalyzerEngine.ScanOptions) {
        rootURL = url

        // Check Full Disk Access permission if scanning root
        if url.path == "/" {
            let status = PermissionsManager.shared.checkPermissionStatus(for: .fullDiskAccess)
            if status != .granted {
                showFullDiskAccessAlert()
                return
            }
        }

        // Show progress sheet
        showProgressSheet()

        // Start scan
        engine.startScan(url: url, options: options, delegate: self)
    }

    private func showProgressSheet() {
        let progressVC = StorageProgressViewController()
        progressVC.cancelHandler = { [weak self] in
            self?.engine.cancel()
        }

        self.progressViewController = progressVC

        let sheet = NSWindow(contentViewController: progressVC)
        sheet.styleMask = [.titled, .closable]
        sheet.title = "Scanning..."

        progressSheet = sheet

        window?.beginSheet(sheet)
    }

    private func hideProgressSheet() {
        guard let sheet = progressSheet else { return }
        window?.endSheet(sheet)
        progressSheet = nil
        progressViewController = nil
    }

    private func showFullDiskAccessAlert() {
        let alert = NSAlert()
        alert.messageText = "Full Disk Access Required"
        alert.informativeText = "To scan the entire system, MacFileExplorer needs Full Disk Access. Would you like to grant this permission in System Preferences?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Choose Different Folder")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: window!) { response in
            if response == .alertFirstButtonReturn {
                PermissionsManager.shared.openSystemPreferences(for: .fullDiskAccess)
            } else if response == .alertSecondButtonReturn {
                self.showScopeSelectionDialog()
            }
        }
    }

    // MARK: - Actions

    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        listViewController.setSearchText(sender.stringValue)
    }

    @objc private func rescanAction(_ sender: Any) {
        guard let url = rootURL else { return }
        startScan(url: url, options: .default)
    }

    @objc private func newScanAction(_ sender: Any) {
        showScopeSelectionDialog()
    }

    @objc private func exportAction(_ sender: Any) {
        // TODO: Implement export functionality
        let alert = NSAlert()
        alert.messageText = "Export"
        alert.informativeText = "Export functionality coming soon!"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window!)
    }
}

// MARK: - StorageAnalyzerDelegate
extension StorageAnalyzerWindowController: StorageAnalyzerDelegate {
    func analyzerDidStart(totalItems: Int) {
        // Progress sheet already shown
    }

    func analyzerDidProgress(currentPath: String, itemsScanned: Int, totalSize: Int64) {
        progressViewController?.updateProgress(
            currentPath: currentPath,
            itemsScanned: itemsScanned,
            totalSize: totalSize
        )
    }

    func analyzerDidComplete(rootItem: StorageItem, duration: TimeInterval) {
        Task { @MainActor [weak self] in
            self?.rootItem = rootItem
            self?.listViewController.setRootItem(rootItem)
            self?.summaryViewController.setRootItem(rootItem)

            // Update window title
            if let url = self?.rootURL {
                self?.window?.title = "Storage Analyzer - \(url.path)"
            }

            // Hide progress sheet
            self?.hideProgressSheet()

            // Show completion message
            let alert = NSAlert()
            alert.messageText = "Scan Complete"
            alert.informativeText = "Scanned \(rootItem.fileCount) files in \(String(format: "%.1f", duration)) seconds.\nTotal size: \(rootItem.formattedSize)"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            if let window = self?.window {
                alert.beginSheetModal(for: window)
            }
        }
    }

    func analyzerDidFail(error: String) {
        Task { @MainActor [weak self] in
            self?.progressViewController?.setScanFailed(error: error)

            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self?.hideProgressSheet()
        }
    }

    func analyzerWasCancelled() {
        Task { @MainActor [weak self] in
            self?.hideProgressSheet()
        }
    }
}

// MARK: - StorageListViewDelegate
extension StorageAnalyzerWindowController: StorageListViewDelegate {
    func listViewDidSelectItem(_ item: StorageItem) {
        summaryViewController.setSelectedItem(item)
    }

    func listViewDidDoubleClickItem(_ item: StorageItem) {
        // Already handled by list view (drill down)
    }

    func listViewDidRequestAction(_ action: StorageAction, items: [StorageItem]) {
        switch action {
        case .open:
            for item in items {
                NSWorkspace.shared.open(item.url)
            }

        case .quickLook:
            if let first = items.first {
                NSWorkspace.shared.activateFileViewerSelecting([first.url])
            }

        case .showInMainViewer:
            // TODO: Integration with main file browser
            let alert = NSAlert()
            alert.messageText = "Show in Main Viewer"
            alert.informativeText = "This feature will be integrated with the main file browser."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            if let window = window {
                alert.beginSheetModal(for: window)
            }

        case .moveToTrash:
            moveItemsToTrash(items)

        case .revealInFinder:
            for item in items {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }

        case .copyPath:
            let paths = items.map { $0.url.path }.joined(separator: "\n")
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(paths, forType: .string)
        }
    }

    private func moveItemsToTrash(_ items: [StorageItem]) {
        let alert = NSAlert()
        alert.messageText = "Move to Trash"
        alert.informativeText = "Are you sure you want to move \(items.count) item(s) to the Trash?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: window!) { response in
            if response == .alertFirstButtonReturn {
                for item in items {
                    do {
                        try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                    } catch {
                        debugLog("Failed to trash item: \(error)")
                    }
                }

                // Rescan after deletion
                if let url = self.rootURL {
                    StorageAnalyzerEngine.invalidateCache(for: url)
                    self.startScan(url: url, options: .default)
                }
            }
        }
    }
}

// MARK: - NSWindowDelegate
extension StorageAnalyzerWindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // If this is the scope sheet being closed
        if sender == scopeSheet {
            window?.endSheet(sender)
            scopeSheet = nil
            // Also close the main window since user cancelled scope selection
            window?.close()
            return false // We handle the closing ourselves
        }
        return true
    }
}

// MARK: - NSToolbarDelegate
extension StorageAnalyzerWindowController: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier.rawValue {
        case "search":
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Search"

            searchField = NSSearchField(frame: NSRect(x: 0, y: 0, width: 200, height: 22))
            searchField.placeholderString = "Search..."
            searchField.target = self
            searchField.action = #selector(searchFieldChanged(_:))

            item.view = searchField
            return item

        case "rescan":
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Rescan"
            item.paletteLabel = "Rescan"
            item.toolTip = "Rescan current location"
            item.image = NSImage.mfeSymbol(named: "arrow.clockwise", accessibilityDescription: "Rescan")
            item.target = self
            item.action = #selector(rescanAction(_:))
            return item

        case "newScan":
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "New Scan"
            item.paletteLabel = "New Scan"
            item.toolTip = "Start a new scan"
            item.image = NSImage.mfeSymbol(named: "doc.badge.plus", accessibilityDescription: "New Scan")
            item.target = self
            item.action = #selector(newScanAction(_:))
            return item

        case "export":
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Export"
            item.paletteLabel = "Export"
            item.toolTip = "Export results"
            item.image = NSImage.mfeSymbol(named: "square.and.arrow.up", accessibilityDescription: "Export")
            item.target = self
            item.action = #selector(exportAction(_:))
            return item

        default:
            return nil
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            NSToolbarItem.Identifier("newScan"),
            NSToolbarItem.Identifier("rescan"),
            .flexibleSpace,
            NSToolbarItem.Identifier("search"),
            .flexibleSpace,
            NSToolbarItem.Identifier("export")
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            NSToolbarItem.Identifier("newScan"),
            NSToolbarItem.Identifier("rescan"),
            NSToolbarItem.Identifier("search"),
            NSToolbarItem.Identifier("export"),
            .flexibleSpace,
            .space
        ]
    }
}
