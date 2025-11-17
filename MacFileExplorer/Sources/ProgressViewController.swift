import Cocoa

class ProgressViewController: NSViewController {

    private var progressIndicator: NSProgressIndicator!
    private var statusLabel: NSTextField!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        setupUI()
    }

    private func setupUI() {
        progressIndicator = NSProgressIndicator()
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 100
        view.addSubview(progressIndicator)

        statusLabel = NSTextField(labelWithString: "Starting...")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.alignment = .center
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -10),
            progressIndicator.widthAnchor.constraint(equalToConstant: 250),

            statusLabel.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    func updateProgress(percent: Double, status: String) {
        progressIndicator.doubleValue = percent
        statusLabel.stringValue = status
    }
}
