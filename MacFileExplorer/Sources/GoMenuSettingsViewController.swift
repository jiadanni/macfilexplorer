import Cocoa

final class GoMenuSettingsViewController: NSViewController {

    private var stackView: NSStackView!

    override func loadView() {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
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
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20)
        ])

        addGoMenuSettings()
    }

    private func addGoMenuSettings() {
        let titleLabel = NSTextField(labelWithString: "Go Menu Items")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(titleLabel)

        let descriptionLabel = NSTextField(labelWithString: "Choose which items appear in the Go menu. Home and Downloads are shown by default.")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.maximumNumberOfLines = 2
        descriptionLabel.lineBreakMode = .byWordWrapping
        stackView.addArrangedSubview(descriptionLabel)

        // Add spacing
        let spacer1 = NSView()
        spacer1.translatesAutoresizingMaskIntoConstraints = false
        spacer1.heightAnchor.constraint(equalToConstant: 10).isActive = true
        stackView.addArrangedSubview(spacer1)

        // Add checkboxes for each Go menu item
        addCheckbox(title: "Home (⇧⌘H)", key: .showGoHome, defaultValue: true)
        addCheckbox(title: "Desktop (⇧⌘D)", key: .showGoDesktop, defaultValue: false)
        addCheckbox(title: "Documents (⇧⌘O)", key: .showGoDocuments, defaultValue: false)
        addCheckbox(title: "Downloads (⇧⌘L)", key: .showGoDownloads, defaultValue: true)
        addCheckbox(title: "Applications (⇧⌘A)", key: .showGoApplications, defaultValue: false)
        addCheckbox(title: "Utilities (⇧⌘U)", key: .showGoUtilities, defaultValue: false)
        addCheckbox(title: "Library", key: .showGoLibrary, defaultValue: false)
        addCheckbox(title: "Computer", key: .showGoComputer, defaultValue: false)
        addCheckbox(title: "AirDrop (⇧⌘R)", key: .showGoAirDrop, defaultValue: false)
        addCheckbox(title: "Network", key: .showGoNetwork, defaultValue: false)
        addCheckbox(title: "iCloud Drive (⇧⌘I)", key: .showGoiCloudDrive, defaultValue: false)
        addCheckbox(title: "Recent Items", key: .showGoRecent, defaultValue: false)

        // Add spacing
        let spacer2 = NSView()
        spacer2.translatesAutoresizingMaskIntoConstraints = false
        spacer2.heightAnchor.constraint(equalToConstant: 10).isActive = true
        stackView.addArrangedSubview(spacer2)

        let connectLabel = NSTextField(labelWithString: "Network:")
        connectLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(connectLabel)

        addCheckbox(title: "Connect to Server... (⌘K)", key: .showGoConnectToServer, defaultValue: false)

        // Note about restarting
        let noteLabel = NSTextField(labelWithString: "Note: Menu changes require relaunching the app to take effect.")
        noteLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.maximumNumberOfLines = 2
        noteLabel.lineBreakMode = .byWordWrapping
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
        }
    }
}

