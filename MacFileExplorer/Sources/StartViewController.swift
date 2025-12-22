//
//  StartViewController.swift
//  MacFileExplorer
//
//  Main Start Page controller
//

import Cocoa

protocol StartViewControllerDelegate: AnyObject {
    func startViewDidRequestNavigate(to url: URL)
    func startViewDidRequestOpenSettings()
}

class StartViewController: NSViewController {

    // MARK: - Properties

    weak var delegate: StartViewControllerDelegate?

    private var scrollView: NSScrollView!
    private var contentStackView: NSStackView!

    // Widgets
    private var welcomeWidget: WelcomeWidgetView?
    private var favoritesWidget: FavoritesWidgetView!
    private var quickActionsWidget: QuickActionsWidgetView!
    private var gettingStartedWidget: GettingStartedWidgetView?
    private var storageWidget: StorageOverviewWidgetView?

    // MARK: - Lifecycle

    override func loadView() {
        // Create a custom view that doesn't impose size constraints
        let customView = NSView()
        customView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        customView.setContentHuggingPriority(.defaultLow, for: .vertical)
        customView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view = customView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupWidgets()
        observePermissions()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshWidgets()
    }

    // MARK: - Setup

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // Ensure the view can resize freely
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Scroll view for content
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.addSubview(scrollView)

        // Content stack inside a container view to avoid locking scroll/document sizing
        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.translatesAutoresizingMaskIntoConstraints = false

        contentStackView = NSStackView()
        contentStackView.orientation = .vertical
        contentStackView.spacing = StartDesignSystem.Spacing.gridSpacing
        contentStackView.alignment = .leading
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(contentStackView)
        scrollView.documentView = contentView

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Pin the document container to the scroll view's contentView
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            // Make the document container match the visible width (no horizontal scrolling)
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            // Stack inside the content container with padding
            contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: StartDesignSystem.Spacing.lg),
            contentStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: StartDesignSystem.Spacing.xxl),
            contentStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -StartDesignSystem.Spacing.xxl),
            contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -StartDesignSystem.Spacing.xxl)
        ])
    }

    private func setupWidgets() {
        // TESTING: Enable widgets one by one
        gettingStartedWidget = GettingStartedWidgetView()
        gettingStartedWidget?.delegate = self
        addWidget(gettingStartedWidget!)

        favoritesWidget = FavoritesWidgetView()
        favoritesWidget.delegate = self
        addWidget(favoritesWidget)

        quickActionsWidget = QuickActionsWidgetView()
        quickActionsWidget.delegate = self
        addWidget(quickActionsWidget)

        // Storage Overview
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        let hasHomeAccess = FileManager.default.isReadableFile(atPath: homeURL.path)
        if hasHomeAccess {
            storageWidget = StorageOverviewWidgetView()
            storageWidget?.delegate = self
            addWidget(storageWidget!)
        }
    }

    private func addWidget(_ widget: StartWidgetView) {
        widget.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(widget)

        // Widgets should fill the stack view width
        NSLayoutConstraint.activate([
            widget.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor),
            widget.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor)
        ])

        widget.animateIn()
    }

    private func checkAllTasksComplete() -> Bool {
        let tasks = ["pinFolder", "grantAccess", "tryStorage", "customize"]
        return tasks.allSatisfy { UserDefaults.standard.bool(forKey: "GettingStarted_\($0)") }
    }

    private func observePermissions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(permissionsChanged),
            name: .permissionStatusChanged,
            object: nil
        )
    }

    @objc private func permissionsChanged() {
        refreshWidgets()
    }

    private func refreshWidgets() {
        // Refresh storage widget if it exists
        storageWidget?.refresh()
        // Could refresh other widgets that depend on permissions
        
        // If storage widget doesn't exist but home access is now granted, add it
        if storageWidget == nil {
            let homeURL = URL(fileURLWithPath: NSHomeDirectory())
            let hasHomeAccess = FileManager.default.isReadableFile(atPath: homeURL.path)
            if hasHomeAccess {
                storageWidget = StorageOverviewWidgetView()
                storageWidget!.delegate = self
                addWidget(storageWidget!)
            }
        }
    }

    // MARK: - Actions

    private func handleOpenFolder(_ url: URL) {
        // Open in a new tab instead of navigating
        if let tabBarController = parent as? TabBarController {
            tabBarController.openInNewTab(url: url)
        } else {
            // Fallback to navigation if tab controller not found
            delegate?.startViewDidRequestNavigate(to: url)
        }
    }

    private func handleRequestPermission(folder: URL?) {
        guard let folder = folder else { return }

        ContextualPermissionManager.shared.requestFolderAccess(
            folder: folder,
            reason: "Founder needs access to your \(folder.lastPathComponent) folder to open it here."
        ) { [weak self] granted in
            if granted {
                self?.handleOpenFolder(folder)
                self?.gettingStartedWidget?.markTaskCompleted(id: "grantAccess")
            }
        }
    }

    private func handleAddFavorite() {
        debugLog("StartViewController: handleAddFavorite called")
        debugLog("StartViewController: favoritesWidget is \(favoritesWidget == nil ? "nil" : "set")")
        ContextualPermissionManager.shared.requestCustomFolder { [weak self] url in
            debugLog("StartViewController: requestCustomFolder completion handler called")
            if let url = url {
                debugLog("StartViewController: Got URL: \(url.path)")
                debugLog("StartViewController: favoritesWidget in completion is \(self?.favoritesWidget == nil ? "nil" : "set")")
                // Add to the Favorites widget on the Start page
                self?.favoritesWidget?.addFolder(url: url)

                self?.gettingStartedWidget?.markTaskCompleted(id: "pinFolder")
            } else {
                debugLog("StartViewController: URL is nil - user cancelled")
            }
        }
    }

    private func handleOpenStorageAnalyzer() {
        // Navigate up to find the SplitViewController and open Storage Analyzer in a tab
        if let tabBarController = parent as? TabBarController {
            tabBarController.openStorageAnalyzerTab()
        } else if let splitVC = view.window?.contentViewController as? SplitViewController {
            splitVC.openStorageAnalyzerTab()
        }
        gettingStartedWidget?.markTaskCompleted(id: "tryStorage")
    }

    private func handleNewFolder() {
        // Show folder creation dialog
        let alert = NSAlert()
        alert.messageText = L10n.text("Create New Folder")
        alert.informativeText = L10n.text("Choose a location to create a new folder")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.text("Choose Location"))
        alert.addButton(withTitle: L10n.text("Cancel"))

        if alert.runModal() == .alertFirstButtonReturn {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = L10n.text("Choose Location")

            panel.begin { _ in
                // Would create folder here - needs integration with file browser
            }
        }
    }

    private func handleOpenTerminal() {
        // Open terminal at home directory
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        NSWorkspace.shared.open([homeURL], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"), configuration: NSWorkspace.OpenConfiguration())
    }

    private func handleEjectAll() {
        let workspace = NSWorkspace.shared
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil)

        var ejected = 0
        for volume in volumes ?? [] {
            do {
                try workspace.unmountAndEjectDevice(at: volume)
                ejected += 1
            } catch {
                debugLog("Failed to eject \(volume): \(error)")
            }
        }

        if ejected > 0 {
            let alert = NSAlert()
            alert.messageText = String(format: L10n.text("Ejected %@ volume(s)"), "\(ejected)")
            alert.alertStyle = .informational
            alert.addButton(withTitle: L10n.text("OK"))
            alert.runModal()
        }
    }
}

// MARK: - StartWidgetDelegate
extension StartViewController: StartWidgetDelegate {
    func widgetDidRequestAction(_ action: StartWidgetAction, widget: StartWidgetView) {
        switch action {
        case .openFolder(let url):
            handleOpenFolder(url)

        case .requestPermission(let folder):
            handleRequestPermission(folder: folder)

        case .openStorageAnalyzer:
            handleOpenStorageAnalyzer()

        case .openSettings:
            delegate?.startViewDidRequestOpenSettings()

        case .addFavorite:
            handleAddFavorite()

        case .openTerminal:
            handleOpenTerminal()

        case .ejectAll:
            handleEjectAll()

        case .newFolder:
            handleNewFolder()

        case .taskCompleted(let taskId):
            debugLog("Task completed: \(taskId)")
        }
    }

    func widgetDidRequestNavigation(to url: URL) {
        delegate?.startViewDidRequestNavigate(to: url)
    }

    func widgetDidRequestDismiss(_ widget: StartWidgetView) {
        if widget === welcomeWidget {
            UserDefaults.standard.set(true, forKey: "dismissedWelcome")
        }

        widget.animateOut { [weak self] in
            if self?.contentStackView.arrangedSubviews.firstIndex(of: widget) != nil {
                self?.contentStackView.removeArrangedSubview(widget)
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let sidebarNeedsRefresh = Notification.Name("sidebarNeedsRefresh")
    static let permissionStatusChanged = Notification.Name("permissionStatusChanged")
}
