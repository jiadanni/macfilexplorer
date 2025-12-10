//
//  QuickActionsWidgetView.swift
//  MacFileExplorer
//
//  Quick actions widget for Start Page
//

import Cocoa

class QuickActionsWidgetView: StartWidgetView {

    private var actionsStack: NSStackView!

    init() {
        super.init(title: L10n.text("Quick Actions"), icon: StartDesignSystem.Icons.settings, dismissible: false)
        setupContent()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupContent()
    }

    override func setupContent() {
        actionsStack = NSStackView()
        actionsStack.orientation = .vertical
        actionsStack.spacing = StartDesignSystem.Spacing.sm
        actionsStack.alignment = .leading
        actionsStack.distribution = .fillEqually
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(actionsStack)

        // Action buttons
        let actions: [(title: String, icon: String, action: Selector)] = [
            (L10n.text("New Folder"), StartDesignSystem.Icons.newFolder, #selector(newFolderTapped)),
            (L10n.text("Open Terminal"), StartDesignSystem.Icons.terminal, #selector(openTerminalTapped)),
            (L10n.text("Storage Analyzer"), StartDesignSystem.Icons.storage, #selector(storageAnalyzerTapped)),
            (L10n.text("Eject All Drives"), StartDesignSystem.Icons.eject, #selector(ejectAllTapped))
        ]

        for actionInfo in actions {
            let actionButton = createActionButton(title: actionInfo.title, icon: actionInfo.icon, action: actionInfo.action)
            actionsStack.addArrangedSubview(actionButton)
        }

        NSLayoutConstraint.activate([
            actionsStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            actionsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            actionsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            actionsStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func createActionButton(title: String, icon: String, action: Selector) -> NSView {
        let container = NSView()

        let button = NSButton()
        button.title = title
        button.bezelStyle = .texturedRounded
        button.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setAccessibilityLabel(title)
        button.setAccessibilityRole(.button)

        container.addSubview(button)

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            button.heightAnchor.constraint(equalToConstant: 32)
        ])

        return container
    }

    @objc private func newFolderTapped() {
        delegate?.widgetDidRequestAction(.newFolder, widget: self)
    }

    @objc private func openTerminalTapped() {
        delegate?.widgetDidRequestAction(.openTerminal, widget: self)
    }

    @objc private func storageAnalyzerTapped() {
        delegate?.widgetDidRequestAction(.openStorageAnalyzer, widget: self)
    }

    @objc private func ejectAllTapped() {
        delegate?.widgetDidRequestAction(.ejectAll, widget: self)
    }
}
