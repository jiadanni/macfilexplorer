import Cocoa

class WindowTrafficLightManager {
    static let shared = WindowTrafficLightManager()

    private init() {
        // Observe setting changes
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
        // Attempt to find the standard window buttons and update their images.
        // Note: macOS doesn't provide direct API to recolor the system traffic lights.
        // We can overlay custom small views at the traffic-light positions to emulate colored controls.

        DispatchQueue.main.async {
            guard let contentView = window.contentView else { return }

            // Clean up previous overlays by identifier
            if let superview = contentView.superview {
                if let existing = superview.subviews.first(where: { $0.identifier?.rawValue == "trafficOverlay" }) {
                    existing.removeFromSuperview()
                }
            }

            // Only add overlays when titlebar is transparent/fullSizeContentView
            if !window.styleMask.contains(.fullSizeContentView) {
                return
            }

            // Compute traffic light approximate frame in window coordinate space
            // Traffic lights live in the titlebar area near top-left.
            // We'll place an overlay view with small colored circles to the left of the contentView's left edge.

            let overlay = NSView(frame: NSRect(x: 8, y: window.frame.height - 20 - 8, width: 60, height: 16))
            overlay.wantsLayer = true
            overlay.layer?.backgroundColor = NSColor.clear.cgColor
            overlay.translatesAutoresizingMaskIntoConstraints = false
            overlay.identifier = NSUserInterfaceItemIdentifier("trafficOverlay")

            // Create three circular views
            let sizes: CGFloat = 12
            let padding: CGFloat = 6
            let red = NSView(frame: NSRect(x: 0, y: 2, width: sizes, height: sizes))
            let yellow = NSView(frame: NSRect(x: sizes + padding, y: 2, width: sizes, height: sizes))
            let green = NSView(frame: NSRect(x: 2*(sizes + padding), y: 2, width: sizes, height: sizes))

            for v in [red, yellow, green] {
                v.wantsLayer = true
                v.layer?.cornerRadius = sizes / 2.0
                v.layer?.borderColor = NSColor.black.withAlphaComponent(0.06).cgColor
                v.layer?.borderWidth = 0.5
            }

            if grayscale {
                red.layer?.backgroundColor = NSColor.gray.cgColor
                yellow.layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.85).cgColor
                green.layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.7).cgColor
            } else {
                red.layer?.backgroundColor = NSColor.systemRed.cgColor
                yellow.layer?.backgroundColor = NSColor.systemYellow.cgColor
                green.layer?.backgroundColor = NSColor.systemGreen.cgColor
            }

            overlay.addSubview(red)
            overlay.addSubview(yellow)
            overlay.addSubview(green)

            // Convert overlay frame to contentView coordinates
            // We'll position overlay relative to contentView's superview (the window's content layout)
            if let superview = contentView.superview {
                superview.addSubview(overlay)
                NSLayoutConstraint.activate([
                    overlay.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: 6),
                    overlay.topAnchor.constraint(equalTo: superview.topAnchor, constant: 6),
                    overlay.widthAnchor.constraint(equalToConstant: 60),
                    overlay.heightAnchor.constraint(equalToConstant: 20)
                ])
            }
        }
    }
}

// Notification name for manual trigger
// moved to NotificationNames.swift
