import Cocoa

protocol SidebarDelegate: AnyObject {
    func sidebarDidSelectLocation(_ url: URL)
}

struct SidebarItem {
    let name: String
    let url: URL
    let icon: NSImage?
}

// Custom table row view with accent color selection
class AccentTableRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        if selectionHighlightStyle != .none {
            let selectionRect = bounds
            AppDesignSystem.Colors.selectionOverlay.setFill()
            let selectionPath = NSBezierPath(roundedRect: selectionRect, xRadius: AppDesignSystem.Spacing.xs, yRadius: AppDesignSystem.Spacing.xs)
            selectionPath.fill()
        }
    }

    override var isEmphasized: Bool {
        didSet {
            needsDisplay = true
        }
    }
}

// Custom button with hover effect
class HoverButton: NSButton {
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovering = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // Draw circular background on hover
        if isHovering {
            let circlePath = NSBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2))
            AppDesignSystem.Colors.hoverOverlayStrong.setFill()
            circlePath.fill()
        }

        super.draw(dirtyRect)
    }

    // Update drawing when accent color changes
    func accentColorDidChange() {
        needsDisplay = true
    }
}
