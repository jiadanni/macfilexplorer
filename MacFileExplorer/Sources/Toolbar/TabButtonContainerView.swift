import Cocoa

class TabButtonContainerView: NSView {
    override var isFlipped: Bool { return true }

    var isSelected: Bool = false {
        didSet { needsDisplay = true }
    }

    private var isHovering = false {
        didSet { needsDisplay = true }
    }
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { isHovering = true }
    override func mouseExited(with event: NSEvent) { isHovering = false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let path = NSBezierPath(topRoundedRect: bounds, cornerRadius: 6.0)
        if isSelected {
            // Raised tab in the content color, with a faint top highlight
            AppDesignSystem.Chrome.contentBackground.setFill()
            path.fill()
            AppDesignSystem.Chrome.hairline.setFill()
            NSRect(x: bounds.minX + 6, y: bounds.minY, width: bounds.width - 12, height: 1).fill()
        } else if isHovering {
            AppDesignSystem.Chrome.controlHoverFill.setFill()
            path.fill()
        }
    }
}

extension NSBezierPath {
    convenience init(topRoundedRect rect: NSRect, cornerRadius: CGFloat) {
        self.init()
        self.move(to: NSPoint(x: rect.minX, y: rect.maxY))
        self.line(to: NSPoint(x: rect.minX, y: rect.minY + cornerRadius))
        self.appendArc(from: NSPoint(x: rect.minX, y: rect.minY), to: NSPoint(x: rect.minX + cornerRadius, y: rect.minY), radius: cornerRadius)
        self.line(to: NSPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        self.appendArc(from: NSPoint(x: rect.maxX, y: rect.minY), to: NSPoint(x: rect.maxX, y: rect.minY + cornerRadius), radius: cornerRadius)
        self.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
        self.close()
    }
}
