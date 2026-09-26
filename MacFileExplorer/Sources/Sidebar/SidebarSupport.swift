import Cocoa

protocol SidebarDelegate: AnyObject {
    func sidebarDidSelectLocation(_ url: URL)
}

struct SidebarItem {
    let name: String
    let url: URL
    let icon: NSImage?
    /// Optional trailing caption, e.g. free space for a volume
    var detail: String? = nil
}

/// Shared row metrics for the sidebar sections so Favorites, Locations and
/// Folders line up on the same icon/text columns.
enum SidebarMetrics {
    static let rowHeight: CGFloat = 28
    static let folderRowHeight: CGFloat = 24
    static let headerHeight: CGFloat = 24
    /// Inset of the rounded selection from the sidebar edges
    static let rowInset: CGFloat = 10
    /// Icon leading offset inside a flat (non-outline) row
    static let iconLeading: CGFloat = 20

    static func makeRowView() -> NSTableRowView {
        RoundedSelectionRowView(selectionStyle: .neutral, horizontalInset: rowInset)
    }

    static func iconAndLabelConstraints(imageView: NSView, textField: NSView, in cellView: NSView, leading: CGFloat = iconLeading, trailingTo trailingAnchor: NSLayoutXAxisAnchor? = nil) -> [NSLayoutConstraint] {
        [
            imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: leading),
            imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16),

            textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            textField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor ?? cellView.trailingAnchor, constant: trailingAnchor == nil ? -iconLeading : -6)
        ]
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
