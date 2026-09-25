import Cocoa

class TabButtonContainerView: NSView {
    override var isFlipped: Bool { return true }
    
    var isSelected: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let path = NSBezierPath(topRoundedRect: bounds, cornerRadius: 6.0)
        
        let fillColor = isSelected ? NSColor.customAccentColor.withAlphaComponent(0.15) : NSColor.windowBackgroundColor
        fillColor.setFill()
        path.fill()
        
        NSColor.gridColor.setStroke()
        path.stroke()
        
        if isSelected {
            // Erase the bottom line to merge with the view below
            let eraseLine = NSBezierPath()
            eraseLine.move(to: NSPoint(x: bounds.minX, y: bounds.maxY))
            eraseLine.line(to: NSPoint(x: bounds.maxX, y: bounds.maxY))
            NSColor.windowBackgroundColor.setStroke()
            eraseLine.lineWidth = 2.0
            eraseLine.stroke()
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
