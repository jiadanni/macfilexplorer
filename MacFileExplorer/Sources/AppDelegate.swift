import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create and show the main window
        windowController = MainWindowController()
        windowController?.showWindow(self)
        windowController?.window?.makeKeyAndOrderFront(self)
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

    @IBAction func showColorPicker(_ sender: Any?) {
        windowController?.showBulkColorPicker()
    }
}
