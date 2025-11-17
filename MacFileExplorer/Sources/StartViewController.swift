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
    private var storageWidget: StorageOverviewWidgetView!

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
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

        // Scroll view for content
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        // Content stack
        contentStackView = NSStackView()
        contentStackView.orientation = .vertical
        contentStackView.spacing = StartDesignSystem.Spacing.gridSpacing
        contentStackView.alignment = .centerX
        contentStackView.edgeInsets = NSEdgeInsets(
            top: StartDesignSystem.Spacing.xxl,
            left: StartDesignSystem.Spacing.xxl,
            bottom: StartDesignSystem.Spacing.xxl,
            right: StartDesignSystem.Spacing.xxl
        )
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = contentStackView

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStackView.widthAnchor.constraint(lessThanOrEqualToConstant: StartDesignSystem.Layout.maxContentWidth)
        ])
    }

    private func setupWidgets() {
        // Check if first time
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

        // Welcome widget (only on first launch, unless dismissed)
        if !hasLaunchedBefore || !UserDefaults.standard.bool(forKey: "dismissedWelcome") {
            welcomeWidget = WelcomeWidgetView()
            welcomeWidget?.delegate = self
            addWidget(welcomeWidget!)
        }

        // Favorites widget (always visible)
        favoritesWidget = FavoritesWidgetView()
        favoritesWidget.delegate = self
        addWidget(favoritesWidget)

        // Quick Actions (always visible)
        quickActionsWidget = QuickActionsWidgetView()
        quickActionsWidget.delegate = self
        addWidget(quickActionsWidget)

        // Getting Started (only on first launch or until all complete)
        let allTasksComplete = checkAllTasksComplete()
        if !hasLaunchedBefore || !allTasksComplete {
            gettingStartedWidget = GettingStartedWidgetView()
            gettingStartedWidget?.delegate = self
            addWidget(gettingStartedWidget!)
        }

        // Storage Overview (always visible)
        storageWidget = StorageOverviewWidgetView()
        storageWidget.delegate = self
        addWidget(storageWidget)
    }

    private func addWidget(_ widget: StartWidgetView) {
        widget.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(widget)

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
        storageWidget.refresh()
        // Could refresh other widgets that depend on permissions
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
        ContextualPermissionManager.shared.requestCustomFolder { [weak self] url in
            if let url = url {
                // Add to sidebar favorites
                var favorites = UserDefaults.standard.array(forKey: "SidebarFavorites") as? [String] ?? []
                if !favorites.contains(url.path) {
                    favorites.append(url.path)
                    UserDefaults.standard.set(favorites, forKey: "SidebarFavorites")
                }

                self?.gettingStartedWidget?.markTaskCompleted(id: "pinFolder")

                // TODO: Notify sidebar to refresh
                NotificationCenter.default.post(name: .sidebarNeedsRefresh, object: nil)
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
        alert.messageText = "Create New Folder"
        alert.informativeText = "Choose a location to create a new folder"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Choose Location")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Choose Location"

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
                NSLog("Failed to eject \(volume): \(error)")
            }
        }

        if ejected > 0 {
            let alert = NSAlert()
            alert.messageText = "Ejected \(ejected) volume(s)"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
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
            NSLog("Task completed: \(taskId)")
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
