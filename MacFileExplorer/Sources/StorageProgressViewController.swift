//
//  StorageProgressViewController.swift
//  MacFileExplorer
//
//  Progress UI for storage scanning
//

import Cocoa

class StorageProgressViewController: NSViewController {
    // MARK: - Properties

    var cancelHandler: (() -> Void)?

    private var progressIndicator: NSProgressIndicator!
    private var statusLabel: NSTextField!
    private var pathLabel: NSTextField!
    private var itemsScannedLabel: NSTextField!
    private var totalSizeLabel: NSTextField!
    private var cancelButton: NSButton!

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 180))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // Status label
        statusLabel = NSTextField(labelWithString: "Scanning...")
        statusLabel.font = NSFont.boldSystemFont(ofSize: 14)
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        // Progress indicator
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = true
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.startAnimation(nil)

        // Path label
        pathLabel = NSTextField(labelWithString: "")
        pathLabel.font = NSFont.systemFont(ofSize: 11)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.alignment = .center
        pathLabel.translatesAutoresizingMaskIntoConstraints = false

        // Items scanned label
        itemsScannedLabel = NSTextField(labelWithString: "Items scanned: 0")
        itemsScannedLabel.font = NSFont.systemFont(ofSize: 11)
        itemsScannedLabel.alignment = .center
        itemsScannedLabel.translatesAutoresizingMaskIntoConstraints = false

        // Total size label
        totalSizeLabel = NSTextField(labelWithString: "Total size: 0 bytes")
        totalSizeLabel.font = NSFont.systemFont(ofSize: 11)
        totalSizeLabel.alignment = .center
        totalSizeLabel.translatesAutoresizingMaskIntoConstraints = false

        // Cancel button
        cancelButton = NSButton()
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped(_:))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        // Add to view
        view.addSubview(statusLabel)
        view.addSubview(progressIndicator)
        view.addSubview(pathLabel)
        view.addSubview(itemsScannedLabel)
        view.addSubview(totalSizeLabel)
        view.addSubview(cancelButton)

        // Layout
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            progressIndicator.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            progressIndicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            progressIndicator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            pathLabel.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor, constant: 12),
            pathLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            pathLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            itemsScannedLabel.topAnchor.constraint(equalTo: pathLabel.bottomAnchor, constant: 8),
            itemsScannedLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            totalSizeLabel.topAnchor.constraint(equalTo: itemsScannedLabel.bottomAnchor, constant: 4),
            totalSizeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            cancelButton.topAnchor.constraint(equalTo: totalSizeLabel.bottomAnchor, constant: 16),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - Public Methods

    func updateProgress(currentPath: String, itemsScanned: Int, totalSize: Int64) {
        DispatchQueue.main.async { [weak self] in
            self?.pathLabel.stringValue = currentPath
            self?.itemsScannedLabel.stringValue = "Items scanned: \(self?.formatNumber(itemsScanned) ?? "0")"
            self?.totalSizeLabel.stringValue = "Total size: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))"
        }
    }

    func setScanComplete() {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.stringValue = "Scan Complete!"
            self?.progressIndicator.stopAnimation(nil)
            self?.cancelButton.title = "Close"
        }
    }

    func setScanFailed(error: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.stringValue = "Scan Failed"
            self?.pathLabel.stringValue = error
            self?.progressIndicator.stopAnimation(nil)
            self?.cancelButton.title = "Close"
        }
    }

    // MARK: - Actions

    @objc private func cancelTapped(_ sender: Any) {
        if cancelButton.title == "Cancel" {
            cancelHandler?()
        } else {
            dismiss(self)
        }
    }

    // MARK: - Helpers

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
