import Cocoa

protocol StatusBarDelegate: AnyObject {
    func zoomLevelDidChange(to level: Double)
}

class StatusBarViewController: NSViewController {

    weak var delegate: StatusBarDelegate?

    private var statusLabel: NSTextField!
    private var centerLabel: NSTextField!
    private var zoomSlider: NSSlider!
    private var zoomPercentageLabel: NSTextField!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 22)) // Standard status bar height
        setupUI()
        updateZoomPercentageLabel() // Initialize the percentage label
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = AppDesignSystem.Colors.widgetBackground.cgColor

        // Left Status Label (for disk space info)
        statusLabel = NSTextField(labelWithString: L10n.text("Ready"))
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = AppDesignSystem.Typography.caption
        statusLabel.textColor = AppDesignSystem.Colors.inactive
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusLabel.setAccessibilityLabel(L10n.text("Status"))
        statusLabel.setAccessibilityRole(.staticText)
        view.addSubview(statusLabel)

        // Center Label (for file selection info)
        centerLabel = NSTextField(labelWithString: "")
        centerLabel.translatesAutoresizingMaskIntoConstraints = false
        centerLabel.font = AppDesignSystem.Typography.caption
        centerLabel.textColor = AppDesignSystem.Colors.inactive
        centerLabel.lineBreakMode = .byTruncatingTail
        centerLabel.alignment = .center
        centerLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        centerLabel.setAccessibilityLabel(L10n.text("Selection details"))
        centerLabel.setAccessibilityRole(.staticText)
        view.addSubview(centerLabel)

        // Zoom Slider
        zoomSlider = NSSlider()
        zoomSlider.translatesAutoresizingMaskIntoConstraints = false
        zoomSlider.minValue = 0.5
        zoomSlider.maxValue = 2.0
        zoomSlider.floatValue = 1.0 // Default zoom
        zoomSlider.target = self
        zoomSlider.action = #selector(zoomSliderChanged(_:))
        zoomSlider.setAccessibilityRole(.slider)
        zoomSlider.setAccessibilityLabel(L10n.text("Zoom level"))
        view.addSubview(zoomSlider)

        // Zoom Percentage Label
        zoomPercentageLabel = NSTextField(labelWithString: String(format: L10n.text("%d%%"), 100))
        zoomPercentageLabel.translatesAutoresizingMaskIntoConstraints = false
        zoomPercentageLabel.font = AppDesignSystem.Typography.caption
        zoomPercentageLabel.textColor = AppDesignSystem.Colors.inactive
        zoomPercentageLabel.alignment = .right
        zoomPercentageLabel.setAccessibilityRole(.staticText)
        zoomPercentageLabel.setAccessibilityLabel(L10n.text("Zoom percentage"))
        view.addSubview(zoomPercentageLabel)

        NSLayoutConstraint.activate([
            // Left label
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.widthAnchor.constraint(equalToConstant: 200),

            // Center label
            centerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            centerLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 300),

            // Right side - zoom controls
            zoomPercentageLabel.trailingAnchor.constraint(equalTo: zoomSlider.leadingAnchor, constant: -5),
            zoomPercentageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            zoomPercentageLabel.widthAnchor.constraint(equalToConstant: 40),

            zoomSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            zoomSlider.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            zoomSlider.widthAnchor.constraint(equalToConstant: 100)
        ])
    }

    // MARK: - Public Methods

    func updateStatus(message: String) {
        statusLabel.stringValue = message
    }
    
    func setZoomControlsVisible(_ visible: Bool) {
        zoomSlider.isHidden = !visible
        zoomPercentageLabel.isHidden = !visible
    }
    
    func updateFileInformation(selectedCount: Int, totalSize: Int64, diskSpace: String?) {
        if selectedCount > 0 {
            let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
            let itemText = selectedCount == 1 ? L10n.text("item") : L10n.text("items")
            statusLabel.stringValue = String(format: L10n.text("%d %@ selected, %@"), selectedCount, itemText, formattedSize)
            // Show disk space in center when files are selected
            if let diskSpace = diskSpace {
                centerLabel.stringValue = String(format: L10n.text("%@ available"), diskSpace)
            } else {
                centerLabel.stringValue = ""
            }
        } else {
            statusLabel.stringValue = L10n.text("Ready")
            // Show disk space in center when no files are selected
            if let diskSpace = diskSpace {
                centerLabel.stringValue = String(format: L10n.text("%@ available"), diskSpace)
            } else {
                centerLabel.stringValue = ""
            }
        }
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
