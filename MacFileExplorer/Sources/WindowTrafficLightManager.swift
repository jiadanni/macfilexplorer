import Cocoa

private final class TrafficOverlayView: NSView {
    // Let mouse events reach the underlying standard buttons.
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}

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
        DispatchQueue.main.async {
            guard
                let contentView = window.contentView,
                let titlebarView = contentView.superview,
                let closeButton = window.standardWindowButton(.closeButton),
                let minimizeButton = window.standardWindowButton(.miniaturizeButton),
                let zoomButton = window.standardWindowButton(.zoomButton)
            else {
                return
            }

            // Skip non-standard windows (panels that aren't user-facing)
            if window.isKind(of: NSPanel.self) && !window.isFloatingPanel {
                return
            }

            let hasStandardButtons = window.styleMask.contains(.titled) &&
                                     (window.styleMask.contains(.closable) ||
                                      window.styleMask.contains(.miniaturizable) ||
                                      window.styleMask.contains(.resizable))

            if !hasStandardButtons {
                return
            }

            // Remove any prior overlays so we start from a clean state
            titlebarView.subviews
                .filter { $0.identifier?.rawValue == "trafficOverlay" }
                .forEach { $0.removeFromSuperview() }

            // If grayscale is off, leave the native traffic lights untouched
            if !grayscale {
                return
            }

            // Draw a lightweight overlay directly above the native buttons so only one set is visible.
            let overlay = TrafficOverlayView()
            overlay.translatesAutoresizingMaskIntoConstraints = false
            overlay.identifier = NSUserInterfaceItemIdentifier("trafficOverlay")

            titlebarView.addSubview(overlay, positioned: .above, relativeTo: closeButton)
            NSLayoutConstraint.activate([
                overlay.leadingAnchor.constraint(equalTo: titlebarView.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: titlebarView.trailingAnchor),
                overlay.topAnchor.constraint(equalTo: titlebarView.topAnchor),
                overlay.bottomAnchor.constraint(equalTo: titlebarView.bottomAnchor)
            ])

            let buttons: [(NSButton, NSColor)] = [
                (closeButton, NSColor.gray),
                (minimizeButton, NSColor.gray.withAlphaComponent(0.85)),
                (zoomButton, NSColor.gray.withAlphaComponent(0.7))
            ]

            for (button, color) in buttons {
                let dot = NSView()
                dot.translatesAutoresizingMaskIntoConstraints = false
                dot.wantsLayer = true
                dot.layer?.cornerRadius = button.frame.height / 2.0
                dot.layer?.backgroundColor = color.cgColor
                dot.layer?.borderColor = NSColor.black.withAlphaComponent(0.06).cgColor
                dot.layer?.borderWidth = 0.5

                overlay.addSubview(dot)
                NSLayoutConstraint.activate([
                    dot.widthAnchor.constraint(equalToConstant: button.frame.width),
                    dot.heightAnchor.constraint(equalToConstant: button.frame.height),
                    dot.centerXAnchor.constraint(equalTo: overlay.leadingAnchor, constant: button.frame.midX),
                    dot.centerYAnchor.constraint(equalTo: overlay.topAnchor, constant: button.frame.midY)
                ])
            }
        }
    }
}

// Notification name for manual trigger
// moved to NotificationNames.swift
