import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var windowController: MainWindowController?
    var settingsWindowController: SettingsWindowController?


    func applicationDidFinishLaunching(_ aNotification: Notification) {
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
    }

    @objc func updateHiddenFilesMenuItem() {
        if let mainMenu = NSApp.mainMenu {
            if let viewMenu = mainMenu.item(withTitle: "View")?.submenu {
                if let hiddenFilesMenuItem = viewMenu.item(withTitle: "Show Hidden Files") ?? viewMenu.item(withTitle: "Hide Hidden Files") {
                    let isShowing = windowController?.isShowingHiddenFiles() ?? false
                    hiddenFilesMenuItem.title = isShowing ? "Hide Hidden Files" : "Show Hidden Files"
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
                }
            }
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
        goMenu.addItem(withTitle: "Back", action: #selector(goBack(_:)), keyEquivalent: "[")
        goMenu.addItem(withTitle: "Forward", action: #selector(goForward(_:)), keyEquivalent: "]")

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
    
    @IBAction func viewAsDetails(_ sender: Any?) {
        // Details view has been removed - redirect to list view
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

    // MARK: - Settings

    @IBAction func showPreferences(_ sender: Any?) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(sender)
        settingsWindowController?.window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}
