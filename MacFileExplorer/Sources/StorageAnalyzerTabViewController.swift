//
//  StorageAnalyzerTabViewController.swift
//  MacFileExplorer
//
//  Wrapper for Storage Analyzer to display in a tab
//

import Cocoa

class StorageAnalyzerTabViewController: NSViewController, SplitPaneViewControllerDelegate {

    weak var delegate: SplitPaneViewControllerDelegate?

    private var splitViewController: NSSplitViewController!
    private var listViewController: StorageListViewController!
    private var summaryViewController: StorageSummaryViewController!
    private var toolbarContainer: NSView!
    private var contentContainer: NSView!

    private var backButton: NSButton!
    private var searchField: NSSearchField!
    private var rescanButton: NSButton!
    private var newScanButton: NSButton!

    private var engine: StorageAnalyzerEngine!
    private var rootURL: URL?
    private var rootItem: StorageItem?

    private var progressViewController: StorageProgressViewController?
    private var progressSheet: NSWindow?
    private var scopeSheet: NSWindow?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // Show scope selection dialog on first appearance if no scan has been performed
        if rootURL == nil {
            // Defer to ensure window is fully set up
            DispatchQueue.main.async { [weak self] in
                self?.showScopeSelectionDialog()
            }
        }
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // Create engine
        engine = StorageAnalyzerEngine()

        // Toolbar container
        toolbarContainer = NSView()
        toolbarContainer.translatesAutoresizingMaskIntoConstraints = false
        toolbarContainer.wantsLayer = true
        toolbarContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.addSubview(toolbarContainer)

        setupToolbar()

        // Content container
        contentContainer = NSView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)

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

        addChild(splitViewController)
        contentContainer.addSubview(splitViewController.view)
        splitViewController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            toolbarContainer.topAnchor.constraint(equalTo: view.topAnchor),
            toolbarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbarContainer.heightAnchor.constraint(equalToConstant: 40),

            contentContainer.topAnchor.constraint(equalTo: toolbarContainer.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            splitViewController.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            splitViewController.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            splitViewController.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            splitViewController.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
    }

    private func setupToolbar() {
        // New Scan button
        newScanButton = NSButton()
        newScanButton.title = "New Scan"
        newScanButton.bezelStyle = .rounded
        newScanButton.target = self
        newScanButton.action = #selector(newScanAction(_:))
        newScanButton.translatesAutoresizingMaskIntoConstraints = false
        toolbarContainer.addSubview(newScanButton)

        // Rescan button
        rescanButton = NSButton()
        rescanButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Rescan")
        rescanButton.bezelStyle = .texturedRounded
        rescanButton.target = self
        rescanButton.action = #selector(rescanAction(_:))
        rescanButton.toolTip = "Rescan current location"
        rescanButton.translatesAutoresizingMaskIntoConstraints = false
        rescanButton.isEnabled = false
        toolbarContainer.addSubview(rescanButton)

        // Search field
        searchField = NSSearchField()
        searchField.placeholderString = "Search..."
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.translatesAutoresizingMaskIntoConstraints = false
        toolbarContainer.addSubview(searchField)

        NSLayoutConstraint.activate([
            newScanButton.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor, constant: 12),
            newScanButton.centerYAnchor.constraint(equalTo: toolbarContainer.centerYAnchor),

            rescanButton.leadingAnchor.constraint(equalTo: newScanButton.trailingAnchor, constant: 8),
            rescanButton.centerYAnchor.constraint(equalTo: toolbarContainer.centerYAnchor),
            rescanButton.widthAnchor.constraint(equalToConstant: 30),
            rescanButton.heightAnchor.constraint(equalToConstant: 26),

            searchField.trailingAnchor.constraint(equalTo: toolbarContainer.trailingAnchor, constant: -12),
            searchField.centerYAnchor.constraint(equalTo: toolbarContainer.centerYAnchor),
            searchField.widthAnchor.constraint(equalToConstant: 200)
        ])
    }

    // MARK: - Scope Selection

    private func showScopeSelectionDialog() {
        guard let window = view.window else {
            print("Warning: Cannot show scope selection - view has no window")
            return
        }
        
        let scopeVC = StorageScopeSelectionViewController()
        scopeVC.completionHandler = { [weak self] url, options in
            // Dismiss the scope selection sheet first
            if let sheet = self?.scopeSheet {
                self?.view.window?.endSheet(sheet)
                self?.scopeSheet = nil
            }
            // Then start the scan
            self?.startScan(url: url, options: options)
        }

        scopeVC.cancelHandler = { [weak self] in
            // User cancelled - dismiss sheet and close this tab
            if let sheet = self?.scopeSheet {
                self?.view.window?.endSheet(sheet)
                self?.scopeSheet = nil
            }
            // Request tab close via parent
            if let tabController = self?.parent?.parent as? TabBarController {
                tabController.closeCurrentTab()
            }
        }

        let sheet = NSWindow(contentViewController: scopeVC)
        sheet.styleMask = [.titled, .closable]
        sheet.title = "Select Scan Scope"
        sheet.delegate = self
        scopeSheet = sheet
        window.beginSheet(sheet)
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

        // Enable rescan button
        rescanButton.isEnabled = true

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

        view.window?.beginSheet(sheet)
    }

    private func hideProgressSheet() {
        guard let sheet = progressSheet else { return }
        view.window?.endSheet(sheet)
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

        if let window = view.window {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    PermissionsManager.shared.openSystemPreferences(for: .fullDiskAccess)
                } else if response == .alertSecondButtonReturn {
                    self.showScopeSelectionDialog()
                }
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

    // MARK: - SplitPaneViewControllerDelegate (stub methods for protocol conformance)

    func splitPaneDirectoryDidChange(to path: String) {
        // Not applicable for Storage Analyzer
    }

    func splitPaneOpenInNewTab(url: URL) {
        delegate?.splitPaneOpenInNewTab(url: url)
    }

    func splitPane(_ splitPane: SplitPaneViewController, didUpdateSelection selectedCount: Int, totalSize: Int64) {
        // Not applicable
    }

    func splitPane(_ splitPane: SplitPaneViewController, didUpdateDiskSpace diskSpace: String?) {
        // Not applicable
    }

    func splitPaneDidRequestAddToFavorites(item: FileItem) {
        // Not applicable
    }
}

// MARK: - StorageAnalyzerDelegate
extension StorageAnalyzerTabViewController: StorageAnalyzerDelegate {
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
        DispatchQueue.main.async { [weak self] in
            self?.rootItem = rootItem
            self?.listViewController.setRootItem(rootItem)
            self?.summaryViewController.setRootItem(rootItem)

            // Hide progress sheet
            self?.hideProgressSheet()

            // Show completion message
            let alert = NSAlert()
            alert.messageText = "Scan Complete"
            alert.informativeText = "Scanned \(rootItem.fileCount) files in \(String(format: "%.1f", duration)) seconds.\nTotal size: \(rootItem.formattedSize)"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            if let window = self?.view.window {
                alert.beginSheetModal(for: window)
            }
        }
    }

    func analyzerDidFail(error: String) {
        DispatchQueue.main.async { [weak self] in
            self?.progressViewController?.setScanFailed(error: error)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self?.hideProgressSheet()
            }
        }
    }

    func analyzerWasCancelled() {
        DispatchQueue.main.async { [weak self] in
            self?.hideProgressSheet()
        }
    }
}

// MARK: - StorageListViewDelegate
extension StorageAnalyzerTabViewController: StorageListViewDelegate {
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
            // Open in a new file browser tab
            if let first = items.first {
                delegate?.splitPaneOpenInNewTab(url: first.url)
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

        if let window = view.window {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    for item in items {
                        do {
                            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                        } catch {
                            NSLog("Failed to trash item: \(error)")
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
}

// MARK: - NSWindowDelegate
extension StorageAnalyzerTabViewController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // If this is the scope sheet being closed
        if sender == scopeSheet {
            view.window?.endSheet(sender)
            scopeSheet = nil
            // Close this tab
            if let tabController = parent?.parent as? TabBarController {
                tabController.closeCurrentTab()
            }
            return false // We handle the closing ourselves
        }
        return true
    }
}
