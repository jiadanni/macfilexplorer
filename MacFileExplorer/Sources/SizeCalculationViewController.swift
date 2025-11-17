import Cocoa

class SizeCalculationViewController: NSViewController {
    private var progressIndicator: NSProgressIndicator!
    private var statusLabel: NSTextField!
    private var cancelButton: NSButton!
    private var isCancelled = false
    var cancelHandler: (() -> Void)?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 120))
        setupUI()
    }

    private func setupUI() {
        progressIndicator = NSProgressIndicator()
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.style = .spinning
        progressIndicator.startAnimation(self)
        view.addSubview(progressIndicator)

        statusLabel = NSTextField(labelWithString: "Calculating total size...")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.alignment = .center
        view.addSubview(statusLabel)

        cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped(_:)))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressIndicator.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),

            statusLabel.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            cancelButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    func updateStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    @objc private func cancelTapped(_ sender: Any) {
        guard !isCancelled else { return }
        isCancelled = true
        cancelHandler?()
        dismiss(self)
    }
}
