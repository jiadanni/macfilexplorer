//
//  WelcomeWidgetView.swift
//  MacFileExplorer
//
//  Welcome message widget for Start Page
//

import Cocoa

class WelcomeWidgetView: StartWidgetView {

    private var messageLabel: NSTextField!
    private var quickStartButton: NSButton!

    init() {
        super.init(title: "Welcome to Founder", icon: StartDesignSystem.Icons.start, dismissible: true)
        setupContent()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupContent()
    }

    override func setupContent() {
        // Welcome message
        messageLabel = StartDesignSystem.createLabel(
            text: "Your files, your way. Get started by pinning your favorite folders and exploring powerful features.",
            style: .body
        )
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(messageLabel)

        // Quick Start button
        quickStartButton = StartDesignSystem.createButton(title: "Quick Start Guide", style: .secondary)
        quickStartButton.target = self
        quickStartButton.action = #selector(quickStartTapped)
        quickStartButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(quickStartButton)

        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            quickStartButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: StartDesignSystem.Spacing.lg),
            quickStartButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            quickStartButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    @objc private func quickStartTapped() {
        // Could show a popover with tips or expand inline
        let alert = NSAlert()
        alert.messageText = "Quick Start"
        alert.informativeText = """
        • Pin your favorite folders for quick access
        • Try the dual-pane view for efficient file management
        • Use the Storage Analyzer to find what's taking up space
        • Customize your toolbar and sidebar
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Got it!")
        alert.runModal()
    }
}
