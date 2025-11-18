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
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Left Status Label (for disk space info)
        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.addSubview(statusLabel)

        // Center Label (for file selection info)
        centerLabel = NSTextField(labelWithString: "")
        centerLabel.translatesAutoresizingMaskIntoConstraints = false
        centerLabel.font = NSFont.systemFont(ofSize: 11)
        centerLabel.textColor = .secondaryLabelColor
        centerLabel.lineBreakMode = .byTruncatingTail
        centerLabel.alignment = .center
        centerLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.addSubview(centerLabel)

        // Zoom Slider
        zoomSlider = NSSlider()
        zoomSlider.translatesAutoresizingMaskIntoConstraints = false
        zoomSlider.minValue = 0.5
        zoomSlider.maxValue = 2.0
        zoomSlider.floatValue = 1.0 // Default zoom
        zoomSlider.target = self
        zoomSlider.action = #selector(zoomSliderChanged(_:))
        view.addSubview(zoomSlider)

        // Zoom Percentage Label
        zoomPercentageLabel = NSTextField(labelWithString: "100%")
        zoomPercentageLabel.translatesAutoresizingMaskIntoConstraints = false
        zoomPercentageLabel.font = NSFont.systemFont(ofSize: 11)
        zoomPercentageLabel.textColor = .secondaryLabelColor
        zoomPercentageLabel.alignment = .right
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
            let itemText = selectedCount == 1 ? "item" : "items"
            statusLabel.stringValue = "\(selectedCount) \(itemText) selected, \(formattedSize)"
            // Show disk space in center when files are selected
            if let diskSpace = diskSpace {
                centerLabel.stringValue = "\(diskSpace) available"
            } else {
                centerLabel.stringValue = ""
            }
        } else {
            statusLabel.stringValue = "Ready"
            // Show disk space in center when no files are selected
            if let diskSpace = diskSpace {
                centerLabel.stringValue = "\(diskSpace) available"
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
        zoomPercentageLabel.stringValue = "\(zoomPercentage)%"
    }

    // MARK: - Actions

    @objc private func zoomSliderChanged(_ sender: NSSlider) {
        updateZoomPercentageLabel()
        delegate?.zoomLevelDidChange(to: sender.doubleValue)
    }
}
