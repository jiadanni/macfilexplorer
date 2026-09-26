import Cocoa

protocol StatusBarDelegate: AnyObject {
    func zoomLevelDidChange(to level: Double)
}

/// Footer under the file list: selection summary on the left, free space
/// (and the zoom slider for icon views) on the right.
class StatusBarViewController: NSViewController {

    static let height: CGFloat = 26

    weak var delegate: StatusBarDelegate?

    private var statusLabel: NSTextField!
    private var diskSpaceLabel: NSTextField!
    private var zoomSlider: NSSlider!
    private var zoomPercentageLabel: NSTextField!

    override func loadView() {
        view = ChromeSurfaceView(fillColor: AppDesignSystem.Chrome.contentBackground)
        view.frame = NSRect(x: 0, y: 0, width: 800, height: Self.height)
        setupUI()
        updateZoomPercentageLabel()
    }

    private func setupUI() {
        let topBorder = HairlineView()
        view.addSubview(topBorder)

        // Left: selection / item count
        statusLabel = makeLabel(L10n.text("Ready"))
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusLabel.setAccessibilityLabel(L10n.text("Status"))
        view.addSubview(statusLabel)

        // Right: available disk space
        diskSpaceLabel = makeLabel("")
        diskSpaceLabel.alignment = .right
        diskSpaceLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        diskSpaceLabel.setAccessibilityLabel(L10n.text("Available disk space"))
        view.addSubview(diskSpaceLabel)

        // Zoom controls (icon views only)
        zoomSlider = NSSlider()
        zoomSlider.translatesAutoresizingMaskIntoConstraints = false
        zoomSlider.controlSize = .small
        zoomSlider.minValue = 0.5
        zoomSlider.maxValue = 2.0
        zoomSlider.floatValue = 1.0
        zoomSlider.target = self
        zoomSlider.action = #selector(zoomSliderChanged(_:))
        zoomSlider.setAccessibilityLabel(L10n.text("Zoom level"))
        view.addSubview(zoomSlider)

        zoomPercentageLabel = makeLabel(String(format: L10n.text("%d%%"), 100))
        zoomPercentageLabel.alignment = .right
        zoomPercentageLabel.setAccessibilityLabel(L10n.text("Zoom percentage"))
        view.addSubview(zoomPercentageLabel)

        let rightStack = NSStackView(views: [diskSpaceLabel, zoomPercentageLabel, zoomSlider])
        rightStack.orientation = .horizontal
        rightStack.spacing = 8
        rightStack.setCustomSpacing(4, after: zoomPercentageLabel)
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rightStack)

        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: view.topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: rightStack.leadingAnchor, constant: -12),

            rightStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            rightStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            zoomPercentageLabel.widthAnchor.constraint(equalToConstant: 36),
            zoomSlider.widthAnchor.constraint(equalToConstant: 90)
        ])
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = AppDesignSystem.Typography.captionMonospacedDigits
        label.textColor = .secondaryLabelColor
        label.setAccessibilityRole(.staticText)
        return label
    }

    // MARK: - Public Methods

    func updateStatus(message: String) {
        statusLabel.stringValue = message
    }

    func setZoomControlsVisible(_ visible: Bool) {
        zoomSlider.isHidden = !visible
        zoomPercentageLabel.isHidden = !visible
    }

    func updateFileInformation(selectedCount: Int, totalSize: Int64, itemCount: Int, diskSpace: String?) {
        if selectedCount > 0 {
            let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
            statusLabel.stringValue = String(format: L10n.text("%d of %d selected, %@"), selectedCount, itemCount, formattedSize)
        } else {
            let itemText = itemCount == 1 ? L10n.text("item") : L10n.text("items")
            statusLabel.stringValue = String(format: L10n.text("%d %@"), itemCount, itemText)
        }
        diskSpaceLabel.stringValue = diskSpace.map { String(format: L10n.text("%@ available"), $0) } ?? ""
    }

    func setZoomLevel(_ level: Double) {
        zoomSlider.doubleValue = level
        updateZoomPercentageLabel()
    }

    private func updateZoomPercentageLabel() {
        let zoomPercentage = Int(zoomSlider.doubleValue * 100)
        zoomPercentageLabel.stringValue = String(format: L10n.text("%d%%"), zoomPercentage)
    }

    // MARK: - Actions

    @objc private func zoomSliderChanged(_ sender: NSSlider) {
        updateZoomPercentageLabel()
        delegate?.zoomLevelDidChange(to: sender.doubleValue)
    }
}
