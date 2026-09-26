//
//  ChromeViews.swift
//  MacFileExplorer
//
//  Small reusable building blocks for the window chrome: appearance-aware
//  surfaces, hairlines, borderless toolbar buttons and the view-mode pill.
//

import Cocoa

// MARK: - Surfaces

/// Layer-backed view whose fill is re-resolved whenever the effective
/// appearance changes. Assigning a dynamic `NSColor` to `layer.backgroundColor`
/// directly freezes it at the appearance active at assignment time.
class ChromeSurfaceView: NSView {
    var fillColor: NSColor = .clear {
        didSet { needsDisplay = true }
    }

    var cornerRadius: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    convenience init(fillColor: NSColor) {
        self.init(frame: .zero)
        self.fillColor = fillColor
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = fillColor.cgColor
        }
        layer?.cornerRadius = cornerRadius
    }
}

/// One-point divider line using a chrome color token.
///
/// The color/axis initializer is the designated one so that `HairlineView()`
/// can't fall through to `init(frame:)` and skip the Auto Layout setup (a
/// zero-width autoresizing constraint would otherwise pin its superview to 0).
final class HairlineView: ChromeSurfaceView {
    enum Axis { case horizontal, vertical }

    init(color: NSColor = AppDesignSystem.Chrome.hairline, axis: Axis = .horizontal) {
        super.init(frame: .zero)
        fillColor = color
        translatesAutoresizingMaskIntoConstraints = false
        switch axis {
        case .horizontal:
            heightAnchor.constraint(equalToConstant: 1).isActive = true
        case .vertical:
            widthAnchor.constraint(equalToConstant: 1).isActive = true
        }
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

// MARK: - Toolbar Icon Button

/// Borderless, icon-only toolbar button with a rounded hover fill.
/// When `isToggle` is set, the `.on` state renders as an accent-tinted chip.
final class ToolbarIconButton: NSButton {
    private var trackingArea: NSTrackingArea?
    private var isHovering = false {
        didSet { needsDisplay = true }
    }

    var isToggle = false {
        didSet {
            setButtonType(isToggle ? .pushOnPushOff : .momentaryChange)
            updateTint()
        }
    }

    override var state: NSControl.StateValue {
        didSet { updateTint() }
    }

    override var isEnabled: Bool {
        didSet { updateTint() }
    }

    init(symbolName: String, accessibilityDescription: String) {
        super.init(frame: .zero)
        image = NSImage.mfeSymbol(named: symbolName, accessibilityDescription: accessibilityDescription)
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        isBordered = false
        bezelStyle = .shadowlessSquare
        setButtonType(.momentaryChange)
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityRole(.button)
        setAccessibilityLabel(accessibilityDescription)
        updateTint()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 30, height: 28)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
    }

    override func draw(_ dirtyRect: NSRect) {
        let fill: NSColor?
        if isToggle && state == .on {
            fill = AppDesignSystem.Chrome.toggleOnFill
        } else if isHovering && isEnabled {
            fill = AppDesignSystem.Chrome.controlHoverFill
        } else {
            fill = nil
        }
        if let fill {
            fill.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
        }
        super.draw(dirtyRect)
    }

    /// Re-applies tint after the accent color changes.
    func refreshAccent() {
        updateTint()
    }

    private func updateTint() {
        if !isEnabled {
            contentTintColor = .tertiaryLabelColor
        } else if isToggle && state == .on {
            contentTintColor = .customAccentColor
        } else {
            contentTintColor = .secondaryLabelColor
        }
        needsDisplay = true
    }
}

// MARK: - Pill Segmented Control

/// Finder-style grouped icon selector: a rounded pill with one highlighted
/// segment. Used for the toolbar view-mode switcher.
final class PillSegmentedControl: NSView {
    struct Segment {
        let symbolName: String
        let label: String
        let toolTip: String
    }

    var onSelectionChange: ((Int) -> Void)?

    private(set) var selectedIndex: Int = 0
    private var buttons: [SegmentButton] = []
    private let background = ChromeSurfaceView(fillColor: AppDesignSystem.Chrome.controlFill)

    private static let segmentSize = NSSize(width: 30, height: 24)
    private static let inset: CGFloat = 2

    init(segments: [Segment]) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityElement(true)
        setAccessibilityRole(.radioGroup)

        background.cornerRadius = 7
        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = Self.inset
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)

        for (index, segment) in segments.enumerated() {
            let button = SegmentButton()
            button.image = NSImage.mfeSymbol(named: segment.symbolName, accessibilityDescription: segment.label)
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.isBordered = false
            button.bezelStyle = .shadowlessSquare
            button.setButtonType(.momentaryChange)
            button.toolTip = segment.toolTip
            button.tag = index
            button.target = self
            button.action = #selector(segmentClicked(_:))
            button.setAccessibilityRole(.radioButton)
            button.setAccessibilityLabel(segment.label)
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: Self.segmentSize.width),
                button.heightAnchor.constraint(equalToConstant: Self.segmentSize.height)
            ])
            stack.addArrangedSubview(button)
            buttons.append(button)
        }

        NSLayoutConstraint.activate([
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.topAnchor, constant: Self.inset),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -Self.inset),
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: Self.inset),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -Self.inset)
        ])

        updateSelectionAppearance()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override var intrinsicContentSize: NSSize {
        let count = CGFloat(buttons.count)
        let width = count * Self.segmentSize.width + max(0, count - 1) * Self.inset + Self.inset * 2
        return NSSize(width: width, height: Self.segmentSize.height + Self.inset * 2)
    }

    func selectSegment(_ index: Int) {
        guard buttons.indices.contains(index) else { return }
        selectedIndex = index
        updateSelectionAppearance()
    }

    @objc private func segmentClicked(_ sender: NSButton) {
        guard sender.tag != selectedIndex else { return }
        selectSegment(sender.tag)
        onSelectionChange?(sender.tag)
    }

    private func updateSelectionAppearance() {
        for (index, button) in buttons.enumerated() {
            let isSelected = index == selectedIndex
            button.isSelectedSegment = isSelected
            button.contentTintColor = isSelected ? .labelColor : .secondaryLabelColor
            button.setAccessibilityValue(isSelected)
        }
    }

    private final class SegmentButton: NSButton {
        var isSelectedSegment = false {
            didSet { needsDisplay = true }
        }

        override func draw(_ dirtyRect: NSRect) {
            if isSelectedSegment {
                AppDesignSystem.Chrome.controlSelectedFill.setFill()
                NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5).fill()
            }
            super.draw(dirtyRect)
        }
    }
}

// MARK: - Table Rows & Headers

/// Row view that draws an inset, rounded selection and (optionally) inset
/// alternating stripes. Stripes are drawn here instead of via
/// `usesAlternatingRowBackgroundColors` so they share the selection's inset
/// and don't fill the empty area below the last row.
final class RoundedSelectionRowView: NSTableRowView {
    enum SelectionStyle {
        /// Accent fill with inverted (white) cell text, e.g. the file list
        case accent
        /// Subtle neutral fill that keeps normal text colors, e.g. the sidebar
        case neutral
    }

    var selectionStyle: SelectionStyle = .accent
    var drawsStripes = false
    var horizontalInset: CGFloat = 6
    var cornerRadius: CGFloat = 6

    convenience init(selectionStyle: SelectionStyle, drawsStripes: Bool = false, horizontalInset: CGFloat = 6) {
        self.init(frame: .zero)
        self.selectionStyle = selectionStyle
        self.drawsStripes = drawsStripes
        self.horizontalInset = horizontalInset
    }

    override var isEmphasized: Bool {
        didSet { needsDisplay = true }
    }

    override var interiorBackgroundStyle: NSView.BackgroundStyle {
        selectionStyle == .neutral ? .normal : super.interiorBackgroundStyle
    }

    private var contentRect: NSRect {
        bounds.insetBy(dx: horizontalInset, dy: 0)
    }

    override func drawBackground(in dirtyRect: NSRect) {
        guard drawsStripes, let tableView = superview as? NSTableView else { return }
        let row = tableView.row(for: self)
        guard row >= 0, row % 2 == 1 else { return }
        AppDesignSystem.Chrome.rowStripe.setFill()
        NSBezierPath(roundedRect: contentRect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
    }

    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        let fill: NSColor
        switch selectionStyle {
        case .accent:
            fill = isEmphasized ? .customAccentColor : .unemphasizedSelectedContentBackgroundColor
        case .neutral:
            fill = AppDesignSystem.Chrome.sidebarSelection
        }
        fill.setFill()
        NSBezierPath(roundedRect: contentRect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
    }

    override func setFrameOrigin(_ newOrigin: NSPoint) {
        let moved = newOrigin.y != frame.origin.y
        super.setFrameOrigin(newOrigin)
        // Rows shift after expand/collapse; stripe parity depends on the row index.
        if moved && drawsStripes { needsDisplay = true }
    }
}

/// Flat column header: small medium-weight secondary titles over the content
/// background, a single bottom hairline and no column separators.
final class ChromeTableHeaderCell: NSTableHeaderCell {
    /// nil hides the indicator; true/false draws ⌃/⌄ after the title.
    var sortAscending: Bool?

    override init(textCell string: String) {
        super.init(textCell: string)
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    // Note: overriding draw(withFrame:in:) (without calling super) stops the
    // table body from rendering, so the flat background is painted here instead.
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        if controlView is NSTableHeaderView {
            // Cover the system bezel and column separators with a flat fill + bottom hairline.
            let fullFrame = NSRect(x: cellFrame.minX - 1, y: controlView.bounds.minY, width: cellFrame.width + 2, height: controlView.bounds.height)
            AppDesignSystem.Chrome.contentBackground.setFill()
            fullFrame.fill()
            AppDesignSystem.Chrome.hairline.setFill()
            let hairlineY = controlView.isFlipped ? fullFrame.maxY - 1 : fullFrame.minY
            NSRect(x: fullFrame.minX, y: hairlineY, width: fullFrame.width, height: 1).fill()
        }

        var title = stringValue
        if let sortAscending {
            title += sortAscending ? "  ⌃" : "  ⌄"
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph
        ]
        let text = NSAttributedString(string: title, attributes: attributes)
        let textHeight = text.size().height
        let textRect = NSRect(
            x: cellFrame.minX + 8,
            y: cellFrame.midY - textHeight / 2,
            width: max(0, cellFrame.width - 16),
            height: textHeight
        )
        text.draw(in: textRect)
    }
}

/// Outline view that shifts disclosure triangles and cells inward so they sit
/// inside a `RoundedSelectionRowView`'s inset selection rather than on its edge.
final class InsetOutlineView: NSOutlineView {
    var leadingContentInset: CGFloat = 8

    override func frameOfOutlineCell(atRow row: Int) -> NSRect {
        var frame = super.frameOfOutlineCell(atRow: row)
        guard !frame.isEmpty else { return frame }
        frame.origin.x += leadingContentInset
        return frame
    }

    override func frameOfCell(atColumn column: Int, row: Int) -> NSRect {
        var frame = super.frameOfCell(atColumn: column, row: row)
        // Only the outline column is indented (it may not be first if columns were reordered).
        if tableColumns.indices.contains(column), tableColumns[column] === outlineTableColumn {
            frame.origin.x += leadingContentInset
            frame.size.width = max(0, frame.size.width - leadingContentInset)
        }
        return frame
    }
}
