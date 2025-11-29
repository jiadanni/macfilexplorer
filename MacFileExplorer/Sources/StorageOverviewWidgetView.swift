//
//  StorageOverviewWidgetView.swift
//  MacFileExplorer
//
//  Storage overview widget for Start Page
//

import Cocoa

class StorageOverviewWidgetView: StartWidgetView {

    private var statusLabel: NSTextField!
    private var actionButton: NSButton!
    private var hasFullDiskAccess: Bool = false

    init() {
        super.init(title: "Storage Overview", icon: StartDesignSystem.Icons.storage, dismissible: false)
        checkPermissions()
        setupContent()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        checkPermissions()
        setupContent()
    }

    private func checkPermissions() {
        // Check Full Disk Access by attempting to read a protected directory
        // This avoids triggering permission dialogs unless actually needed
        let protectedPath = "/Library/Application Support"
        hasFullDiskAccess = FileManager.default.isReadableFile(atPath: protectedPath)
    }

    override func setupContent() {
        if hasFullDiskAccess {
            setupGrantedView()
        } else {
            setupPlaceholderView()
        }
    }

    private func setupPlaceholderView() {
        // Placeholder icon
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: StartDesignSystem.Icons.storage, accessibilityDescription: "Storage")
        iconView.contentTintColor = StartDesignSystem.Colors.inactive
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        // Status message
        statusLabel = StartDesignSystem.createLabel(
            text: "Enable Full Disk Access to see a detailed breakdown of your storage",
            style: .body
        )
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentView.addSubview(statusLabel)

        // Grant access button
        actionButton = StartDesignSystem.createButton(title: "Enable Full Disk Access", style: .primary)
        actionButton.target = self
        actionButton.action = #selector(grantAccessTapped)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(actionButton)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor),
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),

            statusLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: StartDesignSystem.Spacing.md),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            actionButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: StartDesignSystem.Spacing.lg),
            actionButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            actionButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func setupGrantedView() {
        // Simple message for now - could show actual storage info
        statusLabel = StartDesignSystem.createLabel(
            text: "Storage analysis enabled",
            style: .body
        )
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentView.addSubview(statusLabel)

        // Button to open analyzer
        actionButton = StartDesignSystem.createButton(title: "Open Storage Analyzer", style: .secondary)
        actionButton.target = self
        actionButton.action = #selector(openAnalyzerTapped)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(actionButton)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            actionButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: StartDesignSystem.Spacing.lg),
            actionButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            actionButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    @objc private func grantAccessTapped() {
        // Show explanation alert
        let alert = NSAlert()
        alert.messageText = "Full Disk Access Required"
        alert.informativeText = "The Storage Analyzer works by scanning your entire disk to find what's taking up space. This requires the 'Full Disk Access' permission.\n\nClick 'Open System Preferences' to grant this permission."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            PermissionsManager.shared.openSystemPreferences(for: .fullDiskAccess)
        }
    }

    @objc private func openAnalyzerTapped() {
        delegate?.widgetDidRequestAction(.openStorageAnalyzer, widget: self)
    }

    override func refresh() {
        // Clear and rebuild based on current permissions
        contentView.subviews.forEach { $0.removeFromSuperview() }
        checkPermissions()
        setupContent()
    }
}
