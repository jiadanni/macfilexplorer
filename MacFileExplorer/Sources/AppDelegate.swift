import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var windowController: MainWindowController?
    var settingsWindowController: SettingsWindowController?
    var aboutWindowController: AboutWindowController?


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Configure tooltip delay via UserDefaults (reduce from default ~1.0 seconds to 0.3 seconds)
        UserDefaults.standard.set(0.3, forKey: "NSInitialToolTipDelay")

        // Migration: remove obsolete per-folder color context menu setting key
        if UserDefaults.standard.object(forKey: "hideChangeFolderColor") != nil {
            UserDefaults.standard.removeObject(forKey: "hideChangeFolderColor")
        }

        // Create and show the main window
        let controller = MainWindowController()
        windowController = controller

        // Load the window to trigger windowDidLoad
        controller.window?.makeKeyAndOrderFront(nil)

        // Ensure it's visible
        NSApp.activate(ignoringOtherApps: true)

        createEditMenu()

        NotificationCenter.default.addObserver(self, selector: #selector(updatePreviewPaneMenuItem), name: Notification.Name("previewPaneToggled"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateHiddenFilesMenuItem), name: Notification.Name("hiddenFilesToggled"), object: nil)

        // Set initial dynamic titles based on current states
        updatePreviewPaneMenuItem()
        updateHiddenFilesMenuItem()
        configureViewMenuShortcuts()
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
                    let isShowing = UserDefaults.standard.bool(forKey: UserDefaults.Keys.showPreviewPane.rawValue)
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
    }

    func createGoMenu() {
        guard let mainMenu = NSApp.mainMenu else { return }

        let goMenu = NSMenu(title: "Go")

        // Always show Back and Forward
        goMenu.addItem(withTitle: "Back", action: #selector(goBack(_:)), keyEquivalent: "[")
        goMenu.addItem(withTitle: "Forward", action: #selector(goForward(_:)), keyEquivalent: "]")
        goMenu.addItem(NSMenuItem.separator())

        // Helper to check if menu item should be shown
        func shouldShow(_ key: UserDefaults.Keys, defaultValue: Bool = false) -> Bool {
            if UserDefaults.standard.object(forKey: key.rawValue) == nil {
                UserDefaults.standard.set(defaultValue, forKey: key.rawValue)
                return defaultValue
            }
            return UserDefaults.standard.bool(forKey: key.rawValue)
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

    func applicationWillTerminate(_ aNotification: Notification) {
        // Clean up resources
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
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.AirDrop-Handoff-Settings")!)
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
        alert.messageText = "Connect to Server"
        alert.informativeText = "Enter the server address (e.g., smb://server.local or afp://server.com)"
        alert.alertStyle = .informational

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "smb://server.local/share"
        alert.accessoryView = input

        alert.addButton(withTitle: "Connect")
        alert.addButton(withTitle: "Cancel")

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
            showError("Invalid server address. Please use format: smb://server/share or afp://server/share")
            return
        }

        // Try to mount the network location
        NSWorkspace.shared.open(url)
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Settings

    @IBAction func showPreferences(_ sender: Any?) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(sender)
        settingsWindowController?.window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @IBAction func showAbout(_ sender: Any?) {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController()
        }
        aboutWindowController?.show()
    }
}
