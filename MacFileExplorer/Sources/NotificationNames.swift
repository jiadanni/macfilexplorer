import Foundation

extension Notification.Name {
    static let previewPaneToggled = Notification.Name("previewPaneToggled")
    static let hiddenFilesToggled = Notification.Name("hiddenFilesToggled")
    static let globalFolderColorDidChangeNotification = Notification.Name("globalFolderColorDidChangeNotification")
    static let accentColorDidChangeNotification = Notification.Name("accentColorDidChangeNotification")
    static let showFileExtensionsDidChangeNotification = Notification.Name("showFileExtensionsDidChangeNotification")
    static let easySelectDidChangeNotification = Notification.Name("easySelectDidChangeNotification")
    static let toolbarSettingsDidChangeNotification = Notification.Name("toolbarSettingsDidChangeNotification")
    static let settingsDidChange = Notification.Name("settingsDidChange")
    static let pendingSettingsDidChange = Notification.Name("pendingSettingsDidChange")
    static let didChangeWindowControlAppearance = Notification.Name("didChangeWindowControlAppearance")
    static let zoomDidChangeNotification = Notification.Name("zoomDidChangeNotification")
    static let tabDidChangeNotification = Notification.Name("tabDidChangeNotification")
}

import Cocoa

/// A small NSView subclass that ignores hit testing so clicks pass through to underlying controls.
private class ClickThroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}

class WindowTrafficLightManager {
    static let shared = WindowTrafficLightManager()

    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: Notification.Name("didChangeWindowControlAppearance"), object: nil)
    }

    @objc private func settingsChanged() {
        applyToAllWindows()
    }

    func applyToAllWindows() {
        let useGray = UserDefaults.standard.bool(forKey: "useGrayscaleWindowControls")
        for win in NSApp.windows {
            apply(to: win, grayscale: useGray)
        }
    }

    func apply(to window: NSWindow, grayscale: Bool) {
        DispatchQueue.main.async {
            // Remove any existing overlays we added earlier
            if let contentSuperview = window.contentView?.superview {
                for sub in contentSuperview.subviews where sub.identifier?.rawValue.hasPrefix("trafficOverlay-") == true {
                    sub.removeFromSuperview()
                }
            }

            // Ensure the window uses fullSizeContentView/titlebar so buttons are visible in title area
            guard window.styleMask.contains(.fullSizeContentView) else { return }

            // Try to find the standard window buttons; if present create click-through colored overlays that exactly match their frames
            let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]

            for (idx, btnType) in buttonTypes.enumerated() {
                guard let button = window.standardWindowButton(btnType) else { continue }
                guard let superview = button.superview else { continue }

                // Create overlay view that will sit on top but ignore mouse events
                let overlay = ClickThroughView()
                overlay.wantsLayer = true
                overlay.translatesAutoresizingMaskIntoConstraints = false
                overlay.identifier = NSUserInterfaceItemIdentifier("trafficOverlay-\(idx)")

                // Create colored circle layer to match the button size
                let circle = NSView()
                circle.wantsLayer = true
                circle.translatesAutoresizingMaskIntoConstraints = false
                let bgColor: NSColor
                switch idx {
                case 0: bgColor = grayscale ? NSColor.gray : NSColor.systemRed
                case 1: bgColor = grayscale ? NSColor.gray.withAlphaComponent(0.85) : NSColor.systemYellow
                default: bgColor = grayscale ? NSColor.gray.withAlphaComponent(0.7) : NSColor.systemGreen
                }
                circle.layer?.backgroundColor = bgColor.cgColor
                circle.layer?.cornerRadius = 999 // will be constrained to button size
                circle.layer?.borderColor = NSColor.black.withAlphaComponent(0.06).cgColor
                circle.layer?.borderWidth = 0.5

                // Add overlay to the same superview as the standard button so we can align constraints
                superview.addSubview(overlay)
                overlay.addSubview(circle)

                // Constrain overlay to match button frame (center and size)
                NSLayoutConstraint.activate([
                    overlay.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                    overlay.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                    overlay.widthAnchor.constraint(equalTo: button.widthAnchor),
                    overlay.heightAnchor.constraint(equalTo: button.heightAnchor),

                    circle.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                    circle.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
                    circle.widthAnchor.constraint(equalTo: overlay.widthAnchor, multiplier: 0.9),
                    circle.heightAnchor.constraint(equalTo: overlay.heightAnchor, multiplier: 0.9)
                ])
            }
        }
    }
}
