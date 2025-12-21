import Cocoa

final class ToolbarSettingsViewController: NSViewController {

    private var stackView: NSStackView!

    override func loadView() {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        self.view = view

        stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        addToolbarSettings()
    }

    private func addToolbarSettings() {
        let titleLabel = NSTextField(labelWithString: "Toolbar:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(titleLabel)

        let descriptionLabel = NSTextField(labelWithString: "Customize which buttons appear in the toolbar:")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descriptionLabel)

        // Add spacing
        let spacer1 = NSView()
        spacer1.translatesAutoresizingMaskIntoConstraints = false
        spacer1.heightAnchor.constraint(equalToConstant: 10).isActive = true
        stackView.addArrangedSubview(spacer1)

        addCheckbox(title: "Show Back/Forward navigation buttons", key: .showBackForwardButtons, defaultValue: true)
        addCheckbox(title: "Show View Mode button", key: .showViewModeButton, defaultValue: true)
        addCheckbox(title: "Show Hidden Files toggle button", key: .showHiddenFilesButton, defaultValue: true)
        addCheckbox(title: "Show Split Pane buttons", key: .showSplitButtons, defaultValue: true)
        addCheckbox(title: "Show Preview Pane button", key: .showPreviewPaneButton, defaultValue: true)
        addCheckbox(title: "Show New Folder button", key: .showNewFolderButton, defaultValue: true)
        addCheckbox(title: "Show Sort button", key: .showSortButton, defaultValue: true)

        // Add spacing
        let spacer2 = NSView()
        spacer2.translatesAutoresizingMaskIntoConstraints = false
        spacer2.heightAnchor.constraint(equalToConstant: 10).isActive = true
        stackView.addArrangedSubview(spacer2)

        let noteLabel = NSTextField(labelWithString: "Note: Changes will take effect after restarting the application or opening a new window.")
        noteLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.maximumNumberOfLines = 0
        noteLabel.preferredMaxLayoutWidth = 400
        stackView.addArrangedSubview(noteLabel)
    }

    private func addCheckbox(title: String, key: UserDefaults.Keys, defaultValue: Bool = false) {
        let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(checkboxChanged(_:)))
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.tag = key.rawValue.hashValue
        checkbox.state = UserDefaults.standard.bool(forKey: key.rawValue) ? .on : .off
        if UserDefaults.standard.object(forKey: key.rawValue) == nil {
            UserDefaults.standard.set(defaultValue, forKey: key.rawValue)
            checkbox.state = defaultValue ? .on : .off
        }
        stackView.addArrangedSubview(checkbox)
    }

    @objc func checkboxChanged(_ sender: NSButton) {
        if let keyRawValue = UserDefaults.Keys.allCases.first(where: { $0.rawValue.hashValue == sender.tag })?.rawValue {
            PendingSettings.shared.setValue(sender.state == .on, forKey: keyRawValue)
            // Note: toolbar notification will be posted when Apply is clicked
        }
    }
}

