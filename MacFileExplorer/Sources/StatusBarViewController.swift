import Cocoa

protocol StatusBarDelegate: AnyObject {
    func zoomLevelDidChange(to level: Double)
}

class StatusBarViewController: NSViewController {

    weak var delegate: StatusBarDelegate?

    private var statusLabel: NSTextField!
    private var zoomSlider: NSSlider!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 22)) // Standard status bar height
        setupUI()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Status Label
        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        view.addSubview(statusLabel)

        // Zoom Slider
        zoomSlider = NSSlider()
        zoomSlider.translatesAutoresizingMaskIntoConstraints = false
        zoomSlider.minValue = 0.5
        zoomSlider.maxValue = 2.0
        zoomSlider.floatValue = 1.0 // Default zoom
        zoomSlider.target = self
        zoomSlider.action = #selector(zoomSliderChanged(_:))
        view.addSubview(zoomSlider)

        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: zoomSlider.leadingAnchor, constant: -10),

            zoomSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            zoomSlider.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            zoomSlider.widthAnchor.constraint(equalToConstant: 100) // Adjust width as needed
        ])
    }

    // MARK: - Public Methods

    func updateStatus(message: String) {
        statusLabel.stringValue = message
    }

    // MARK: - Actions

    @objc private func zoomSliderChanged(_ sender: NSSlider) {
        delegate?.zoomLevelDidChange(to: Double(sender.floatValue))
    }
}
