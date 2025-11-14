import Cocoa

class SettingsWindowController: NSWindowController {

    convenience init() {
        let settingsVC = SettingsViewController()
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Preferences"
        window.contentViewController = settingsVC
        self.init(window: window)
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }
}
