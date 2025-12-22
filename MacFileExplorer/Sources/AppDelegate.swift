import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate, SettingsStoreDelegate {

    var windowController: MainWindowController?
    var settingsWindowController: SettingsWindowController?
    var aboutWindowController: AboutWindowController?


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize locale early to prevent ICU crashes during localized comparisons
        _ = Locale.current
        _ = NSLocale.current
        
        // Configure tooltip delay via UserDefaults (reduce from default ~1.0 seconds to 0.3 seconds)
        SettingsStore.shared.setValue(0.3, forKey: "NSInitialToolTipDelay")

        // Migration: remove obsolete per-folder color context menu setting key
        if SettingsStore.shared.value(forKey: "hideChangeFolderColor") != nil {
            SettingsStore.shared.removeValue(forKey: "hideChangeFolderColor")
        }

        // Check if this is first launch
        let settings = SettingsStore.shared
        let hasLaunchedBefore = settings.hasLaunchedBefore
        if !hasLaunchedBefore {
            settings.hasLaunchedBefore = true
        }

        // Create and show the main window
        let controller = MainWindowController()
        windowController = controller

        // Load the window to trigger windowDidLoad
        controller.window?.makeKeyAndOrderFront(nil)

        // Ensure it's visible
        NSApp.activate(ignoringOtherApps: true)

        createEditMenu()

        // Register as delegate for settings changes
        SettingsStore.shared.addDelegate(self)

        // Set initial dynamic titles based on current states
        updatePreviewPaneMenuItem()
        updateHiddenFilesMenuItem()
        configureViewMenuShortcuts()

        // Defer any sandbox-only bookmark migration to next run loop and guard sandbox check
        Task { @MainActor in
            PermissionsManager.shared.migratePathsToBookmarksIfNeeded()
            PermissionsManager.shared.startAccessingAllSecurityScoped()
        }
    }

    @objc func updateHiddenFilesMenuItem() {
        if let mainMenu = NSApp.mainMenu {
            if let viewMenu = mainMenu.item(withTitle: "View")?.submenu {
                if let hiddenFilesMenuItem = viewMenu.item(withTitle: "Show Hidden Files") ?? viewMenu.item(withTitle: "Hide Hidden Files") {
                    let isShowing = windowController?.isShowingHiddenFiles() ?? false
                    hiddenFilesMenuItem.title = isShowing ? "Hide Hidden Files" : "Show Hidden Files"
                    // Ensure shortcut remains applied
                    hiddenFilesMenuItem.keyEquivalent = "."
                    hiddenFilesMenuItem.keyEquivalentModifierMask = [.command, .shift]
                }
            }
        }
    }

    @objc func updatePreviewPaneMenuItem() {
        if let mainMenu = NSApp.mainMenu {
            if let viewMenu = mainMenu.item(withTitle: "View")?.submenu {
                if let previewMenuItem = viewMenu.item(withTitle: "Show Preview Pane") ?? viewMenu.item(withTitle: "Hide Preview Pane") {
                    let isShowing = SettingsStore.shared.previewPaneVisible
                    previewMenuItem.title = isShowing ? "Hide Preview Pane" : "Show Preview Pane"
                    previewMenuItem.keyEquivalent = "p"
                    previewMenuItem.keyEquivalentModifierMask = [.command]
                }
            }
        }
    }

    private func configureViewMenuShortcuts() {
        guard let mainMenu = NSApp.mainMenu, let viewMenu = mainMenu.item(withTitle: "View")?.submenu else { return }
        if let hiddenFilesMenuItem = viewMenu.item(withTitle: "Show Hidden Files") ?? viewMenu.item(withTitle: "Hide Hidden Files") {
            hiddenFilesMenuItem.keyEquivalent = "."
            hiddenFilesMenuItem.keyEquivalentModifierMask = [.command, .shift]
        }
        if let previewMenuItem = viewMenu.item(withTitle: "Show Preview Pane") ?? viewMenu.item(withTitle: "Hide Preview Pane") {
            previewMenuItem.keyEquivalent = "p"
            previewMenuItem.keyEquivalentModifierMask = [.command]
        }
    }




    func createEditMenu() {
        guard let mainMenu = NSApp.mainMenu else { return }

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(cutSelection(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(copySelection(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(pasteSelection(_:)), keyEquivalent: "v")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Select All", action: #selector(NSStandardKeyBindingResponding.selectAll(_:)), keyEquivalent: "a")

        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu

        // Find the "Edit" menu and replace it, or add it if it doesn't exist
        if let existingEditMenu = mainMenu.item(withTitle: "Edit") {
            existingEditMenu.submenu = editMenu
        } else {
            mainMenu.insertItem(editMenuItem, at: 2)
        }

        // Add Go menu with back/forward navigation
        createGoMenu()

        // Add Terminal menu
        createTerminalMenu()
    }

    func createGoMenu() {
        guard let mainMenu = NSApp.mainMenu else { return }

        let goMenu = NSMenu(title: "Go")

        // Always show Back and Forward
        goMenu.addItem(withTitle: "Back", action: #selector(goBack(_:)), keyEquivalent: "[")
        goMenu.addItem(withTitle: "Forward", action: #selector(goForward(_:)), keyEquivalent: "]")
        goMenu.addItem(NSMenuItem.separator())

        // Helper to check if menu item should be shown
        let settings = SettingsStore.shared
        func shouldShow(_ key: UserDefaults.Keys, defaultValue: Bool = false) -> Bool {
            if let stored = settings.value(forKey: key.rawValue) as? Bool {
                return stored
            }
            settings.setValue(defaultValue, forKey: key.rawValue)
            return defaultValue
        }

        // Add location shortcuts based on settings
        if shouldShow(.showGoHome, defaultValue: true) {
            let homeItem = goMenu.addItem(withTitle: "Home", action: #selector(goToHome(_:)), keyEquivalent: "H")
            homeItem.keyEquivalentModifierMask = [.command, .shift]
        }

        if shouldShow(.showGoDesktop) {
            let desktopItem = goMenu.addItem(withTitle: "Desktop", action: #selector(goToDesktop(_:)), keyEquivalent: "D")
            desktopItem.keyEquivalentModifierMask = [.command, .shift]
        }

        if shouldShow(.showGoDocuments) {
            let documentsItem = goMenu.addItem(withTitle: "Documents", action: #selector(goToDocuments(_:)), keyEquivalent: "O")
            documentsItem.keyEquivalentModifierMask = [.command, .shift]
        }

        if shouldShow(.showGoDownloads, defaultValue: true) {
            let downloadsItem = goMenu.addItem(withTitle: "Downloads", action: #selector(goToDownloads(_:)), keyEquivalent: "L")
            downloadsItem.keyEquivalentModifierMask = [.command, .shift]
        }

        if shouldShow(.showGoApplications) {
            let applicationsItem = goMenu.addItem(withTitle: "Applications", action: #selector(goToApplications(_:)), keyEquivalent: "A")
            applicationsItem.keyEquivalentModifierMask = [.command, .shift]
        }

        if shouldShow(.showGoUtilities) {
            let utilitiesItem = goMenu.addItem(withTitle: "Utilities", action: #selector(goToUtilities(_:)), keyEquivalent: "U")
            utilitiesItem.keyEquivalentModifierMask = [.command, .shift]
        }

        if shouldShow(.showGoLibrary) {
            let libraryItem = goMenu.addItem(withTitle: "Library", action: #selector(goToLibrary(_:)), keyEquivalent: "")
            libraryItem.keyEquivalentModifierMask = []
        }

        if shouldShow(.showGoComputer) {
            let computerItem = goMenu.addItem(withTitle: "Computer", action: #selector(goToComputer(_:)), keyEquivalent: "")
            computerItem.keyEquivalentModifierMask = []
        }

        if shouldShow(.showGoAirDrop) {
            let airdropItem = goMenu.addItem(withTitle: "AirDrop", action: #selector(goToAirDrop(_:)), keyEquivalent: "R")
            airdropItem.keyEquivalentModifierMask = [.command, .shift]
        }

        if shouldShow(.showGoNetwork) {
            let networkItem = goMenu.addItem(withTitle: "Network", action: #selector(goToNetwork(_:)), keyEquivalent: "")
            networkItem.keyEquivalentModifierMask = []
        }

        if shouldShow(.showGoiCloudDrive) {
            let icloudItem = goMenu.addItem(withTitle: "iCloud Drive", action: #selector(goToiCloudDrive(_:)), keyEquivalent: "I")
            icloudItem.keyEquivalentModifierMask = [.command, .shift]
        }

        if shouldShow(.showGoRecent) {
            goMenu.addItem(NSMenuItem.separator())
            let recentItem = goMenu.addItem(withTitle: "Recent Items", action: #selector(goToRecent(_:)), keyEquivalent: "")
            recentItem.keyEquivalentModifierMask = []
        }

        // Connect to Server
        if shouldShow(.showGoConnectToServer) {
            goMenu.addItem(NSMenuItem.separator())
            let connectItem = goMenu.addItem(withTitle: "Connect to Server...", action: #selector(connectToServer(_:)), keyEquivalent: "K")
            connectItem.keyEquivalentModifierMask = [.command]
        }

        let goMenuItem = NSMenuItem()
        goMenuItem.submenu = goMenu

        // Find the "Go" menu and replace it, or add it after Edit menu
        if let existingGoMenu = mainMenu.item(withTitle: "Go") {
            existingGoMenu.submenu = goMenu
        } else {
            mainMenu.insertItem(goMenuItem, at: 3)
        }
    }

    func createTerminalMenu() {
        guard let mainMenu = NSApp.mainMenu else { return }

        let terminalMenu = NSMenu(title: "Terminal")

        // Toggle Terminal with Cmd+`
        let toggleItem = terminalMenu.addItem(
            withTitle: "Toggle Terminal",
            action: #selector(toggleTerminal(_:)),
            keyEquivalent: "`"
        )
        toggleItem.keyEquivalentModifierMask = [.command]

        let terminalMenuItem = NSMenuItem()
        terminalMenuItem.submenu = terminalMenu

        // Find the "Terminal" menu and replace it, or add it after Go menu
        if let existingTerminalMenu = mainMenu.item(withTitle: "Terminal") {
            existingTerminalMenu.submenu = terminalMenu
        } else {
            mainMenu.insertItem(terminalMenuItem, at: 4)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Release security-scoped resources
        PermissionsManager.shared.stopAccessingAllSecurityScoped()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: - Menu Actions

    @IBAction func newTab(_ sender: Any?) {
        windowController?.addNewTab()
    }

    @IBAction func closeTab(_ sender: Any?) {
        windowController?.closeCurrentTab()
    }

    @IBAction func toggleTerminal(_ sender: Any?) {
        windowController?.toggleTerminal()
    }

    @IBAction func cutSelection(_ sender: Any?) {
        windowController?.cutSelection()
    }

    @IBAction func copySelection(_ sender: Any?) {
        windowController?.copySelection()
    }

    @IBAction func pasteSelection(_ sender: Any?) {
        windowController?.pasteSelection()
    }

    // MARK: - View Menu Actions
    
    @IBAction func viewAsList(_ sender: Any?) {
        windowController?.setViewMode(.list)
    }
    
    @IBAction func viewAsIcons(_ sender: Any?) {
        windowController?.setViewMode(.icons)
    }
    
    @IBAction func viewAsColumns(_ sender: Any?) {
        windowController?.setViewMode(.columns)
    }
    
    @IBAction func viewAsWindowsList(_ sender: Any?) {
        windowController?.setViewMode(.windowsList)
    }
    
    @IBAction func toggleHiddenFiles(_ sender: Any?) {
        windowController?.toggleHiddenFiles()
    }

    @IBAction func togglePreviewPane(_ sender: Any?) {
        windowController?.togglePreviewPane()
    }

    @IBAction func splitVertically(_ sender: Any?) {
        windowController?.splitVertically()
    }

    @IBAction func splitHorizontally(_ sender: Any?) {
        windowController?.splitHorizontally()
    }

    @IBAction func showStorageAnalyzer(_ sender: Any?) {
        windowController?.openStorageAnalyzerTab()
    }

    // MARK: - Navigation Actions

    @IBAction func goBack(_ sender: Any?) {
        windowController?.goBack()
    }

    @IBAction func goForward(_ sender: Any?) {
        windowController?.goForward()
    }

    @IBAction func goToHome(_ sender: Any?) {
        if let homeURL = FileManager.default.homeDirectoryForCurrentUser as URL? {
            windowController?.navigateToURL(homeURL)
        }
    }

    @IBAction func goToDesktop(_ sender: Any?) {
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            windowController?.navigateToURL(desktopURL)
        }
    }

    @IBAction func goToDocuments(_ sender: Any?) {
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            windowController?.navigateToURL(documentsURL)
        }
    }

    @IBAction func goToDownloads(_ sender: Any?) {
        if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            windowController?.navigateToURL(downloadsURL)
        }
    }

    @IBAction func goToApplications(_ sender: Any?) {
        let applicationsURL = URL(fileURLWithPath: "/Applications")
        windowController?.navigateToURL(applicationsURL)
    }

    @IBAction func goToUtilities(_ sender: Any?) {
        let utilitiesURL = URL(fileURLWithPath: "/Applications/Utilities")
        windowController?.navigateToURL(utilitiesURL)
    }

    @IBAction func goToLibrary(_ sender: Any?) {
        if let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            windowController?.navigateToURL(libraryURL)
        }
    }

    @IBAction func goToComputer(_ sender: Any?) {
        let computerURL = URL(fileURLWithPath: "/")
        windowController?.navigateToURL(computerURL)
    }

    @IBAction func goToAirDrop(_ sender: Any?) {
        // AirDrop uses a special URL scheme
        guard let url = URL(string: "x-apple.systempreferences:com.apple.AirDrop-Handoff-Settings") else {
            debugLog("Invalid AirDrop preferences URL")
            return
        }

        if !NSWorkspace.shared.open(url) {
            showError(L10n.text("Unable to open AirDrop settings."))
        }
    }

    @IBAction func goToNetwork(_ sender: Any?) {
        let networkURL = URL(fileURLWithPath: "/Network")
        windowController?.navigateToURL(networkURL)
    }

    @IBAction func goToiCloudDrive(_ sender: Any?) {
        if let icloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.deletingLastPathComponent() {
            windowController?.navigateToURL(icloudURL)
        } else {
            // Fallback to ~/Library/Mobile Documents
            let homePath = FileManager.default.homeDirectoryForCurrentUser
            let icloudPath = homePath.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
            if FileManager.default.fileExists(atPath: icloudPath.path) {
                windowController?.navigateToURL(icloudPath)
            }
        }
    }

    @IBAction func goToRecent(_ sender: Any?) {
        // Use the system Recent folder in Finder
        NSWorkspace.shared.activateFileViewerSelecting([])
    }

    @IBAction func connectToServer(_ sender: Any?) {
        showConnectToServerDialog()
    }

    private func showConnectToServerDialog() {
        let alert = NSAlert()
        alert.messageText = L10n.text("Connect to Server")
        alert.informativeText = L10n.text("Enter the server address (e.g., smb://server.local or afp://server.com)")
        alert.alertStyle = .informational

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = L10n.text("smb://server.local/share")
        alert.accessoryView = input

        alert.addButton(withTitle: L10n.text("Connect"))
        alert.addButton(withTitle: L10n.text("Cancel"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let serverPath = input.stringValue.trimmingCharacters(in: .whitespaces)
            if !serverPath.isEmpty {
                connectToNetworkLocation(serverPath)
            }
        }
    }

    private func connectToNetworkLocation(_ path: String) {
        guard let url = URL(string: path) else {
            showError(L10n.text("Invalid server address. Please use format: smb://server/share or afp://server/share"))
            return
        }

        // Try to mount the network location
        let success = NSWorkspace.shared.open(url)
        if !success {
            showError(L10n.text("Unable to mount the network location. Please verify the address and your permissions."))
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = L10n.text("Error")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.text("OK"))
        alert.runModal()
    }

    // MARK: - Settings

    @IBAction func showPreferences(_ sender: Any?) {
        let openInTab = SettingsStore.shared.openSettingsInTab
        if openInTab {
            windowController?.addSettingsTab()
            NSApp.activate(ignoringOtherApps: true)
        } else {
            if settingsWindowController == nil { settingsWindowController = SettingsWindowController() }
            settingsWindowController?.showWindow(sender)
            settingsWindowController?.window?.makeKeyAndOrderFront(sender)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    @IBAction func showAbout(_ sender: Any?) {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController()
        }
        aboutWindowController?.show()
    }

    @IBAction func showHelp(_ sender: Any?) {
        // Get the path to the help HTML file in the app bundle
        // Try multiple methods to locate the help file
        var helpURL: URL?

        // Method 1: Direct path in Resources/Help
        if let resourcePath = Bundle.main.resourcePath {
            let helpPath = (resourcePath as NSString).appendingPathComponent("Help/index.html")
            if FileManager.default.fileExists(atPath: helpPath) {
                helpURL = URL(fileURLWithPath: helpPath)
            }
        }

        // Method 2: Using Bundle.main.path
        if helpURL == nil, let helpPath = Bundle.main.path(forResource: "index", ofType: "html", inDirectory: "Help") {
            helpURL = URL(fileURLWithPath: helpPath)
        }

        // Method 3: Using Bundle.main.url
        if helpURL == nil {
            helpURL = Bundle.main.url(forResource: "Help/index", withExtension: "html")
        }

        if let url = helpURL {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback: show an alert if help file is not found
            let alert = NSAlert()
            alert.messageText = "Help Not Available"
            alert.informativeText = "The help documentation could not be found. Please ensure the application is properly installed."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

// MARK: - SettingsStoreDelegate
extension AppDelegate {
    func settingsStore(_ settingsStore: SettingsStoreProtocol, previewPaneVisibilityDidChange isVisible: Bool) {
        updatePreviewPaneMenuItem()
    }
    
    func settingsStore(_ settingsStore: SettingsStoreProtocol, hiddenFilesStateDidChange isVisible: Bool) {
        updateHiddenFilesMenuItem()
    }
}
