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
    
    @IBAction func changeFolderColors(_ sender: Any?) {
        windowController?.changeFolderColor()
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
    
    @IBAction func splitVertically(_ sender: Any?) {
        windowController?.splitVertically()
    }
    
    @IBAction func splitHorizontally(_ sender: Any?) {
        windowController?.splitHorizontally()
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
