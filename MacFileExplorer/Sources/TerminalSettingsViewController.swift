import Cocoa

final class TerminalSettingsViewController: NSViewController {

    private var stackView: NSStackView!
    private let settingsStore: SettingsStoreProtocol = SettingsStore.shared

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.controlBackgroundColor
        self.view = scrollView

        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        contentView.translatesAutoresizingMaskIntoConstraints = false

        stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        contentView.addSubview(stackView)

        scrollView.documentView = contentView

        // Anchor the content view to the scroll view's contentView so the top stays pinned
        let contentContainer = scrollView.contentView
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            contentView.widthAnchor.constraint(lessThanOrEqualTo: contentContainer.widthAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])

        addTerminalSettings()
    }

    private func addTerminalSettings() {
        let titleLabel = NSTextField(labelWithString: "Terminal:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(titleLabel)

        addCheckbox(title: "Open by default", key: .openTerminalByDefault)

        // Add description
        let descriptionLabel = NSTextField(labelWithString: "Show the terminal panel by default when opening windows")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descriptionLabel)

        addCheckbox(title: "Show \"Open in Terminal\" toolbar button", key: .showOpenTerminalButton, defaultValue: true)

        // Add description
        let toolbarButtonDescriptionLabel = NSTextField(labelWithString: "Display a toolbar button to open the current folder in Terminal.app")
        toolbarButtonDescriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        toolbarButtonDescriptionLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(toolbarButtonDescriptionLabel)

        // Add spacer
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 10).isActive = true
        stackView.addArrangedSubview(spacer)

        // Configuration section
        let configTitleLabel = NSTextField(labelWithString: "Configuration:")
        configTitleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(configTitleLabel)

        // Edit config button
        let editConfigButton = NSButton(title: "Edit Terminal Configuration…", target: self, action: #selector(editTerminalConfig(_:)))
        editConfigButton.bezelStyle = .rounded
        stackView.addArrangedSubview(editConfigButton)

        // Config description
        let configDescriptionLabel = NSTextField(labelWithString: "Opens the terminal's .zshrc file in your default editor. Changes take effect on next terminal launch.")
        configDescriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        configDescriptionLabel.textColor = .secondaryLabelColor
        configDescriptionLabel.maximumNumberOfLines = 2
        configDescriptionLabel.preferredMaxLayoutWidth = 300
        stackView.addArrangedSubview(configDescriptionLabel)
    }

    @objc private func editTerminalConfig(_ sender: NSButton) {
        guard let configPath = TerminalViewController.terminalConfigFilePath() else {
            let alert = NSAlert()
            alert.messageText = "Configuration Not Found"
            alert.informativeText = "Could not locate the terminal configuration file. Try opening the built-in terminal first to generate the default configuration."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }

        // Create the config file if it doesn't exist by ensuring the directory setup runs
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: configPath.path) {
            // The file will be created when the terminal is first opened
            // For now, show a helpful message
            let alert = NSAlert()
            alert.messageText = "Configuration Not Generated Yet"
            alert.informativeText = "The terminal configuration file will be created when you first open the built-in terminal. Open the terminal once, then come back here to edit the configuration."
            alert.alertStyle = .informational
            alert.runModal()
            return
        }

        // Open the config file in the default editor
        NSWorkspace.shared.open(configPath)
    }

    private func addCheckbox(title: String, key: UserDefaults.Keys, defaultValue: Bool = false) {
        let checkbox = AccentCheckbox(title: title, target: self, action: #selector(checkboxChanged(_:)))
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.tag = key.rawValue.hashValue
        let storedValue = settingsStore.value(forKey: key.rawValue) as? Bool
        checkbox.state = (storedValue ?? defaultValue) ? .on : .off
        if storedValue == nil {
            settingsStore.setValue(defaultValue, forKey: key.rawValue)
        }
        stackView.addArrangedSubview(checkbox)
    }

    @objc func checkboxChanged(_ sender: NSButton) {
        if let keyRawValue = UserDefaults.Keys.allCases.first(where: { $0.rawValue.hashValue == sender.tag })?.rawValue {
            PendingSettings.shared.setValue(sender.state == .on, forKey: keyRawValue)
        }
    }
}
