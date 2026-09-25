import Cocoa

final class TabsSettingsViewController: NSViewController {

    private var stackView: NSStackView!
    private let settingsStore: SettingsStoreProtocol = SettingsStore.shared

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
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20)
        ])

        addTabsSettings()
    }

    private func addTabsSettings() {
        let titleLabel = NSTextField(labelWithString: "Tabs:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(titleLabel)

        addCheckbox(title: "Restore tabs on reopen", key: .restoreTabsOnReopen, defaultValue: true)

        // Add description
        let descriptionLabel = NSTextField(labelWithString: "Automatically restore all open tabs when reopening the application")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descriptionLabel)
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
