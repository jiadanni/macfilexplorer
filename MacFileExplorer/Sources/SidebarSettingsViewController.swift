import Cocoa

final class SidebarSettingsViewController: NSViewController {

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

        addSidebarSettings()
    }

    private func addSidebarSettings() {
        let folderExplorerTitle = NSTextField(labelWithString: "Folder Explorer:")
        folderExplorerTitle.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(folderExplorerTitle)

        addCheckbox(title: "Expand to current directory by default", key: .expandSidebarToCurrentDirectory, defaultValue: false)

        let descriptionLabel = NSTextField(labelWithString: "Automatically expand the folder explorer to the currently active directory.")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descriptionLabel)

        let visibilityTitle = NSTextField(labelWithString: "Visibility:")
        visibilityTitle.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(visibilityTitle)

        addCheckbox(title: "Show Favorites", key: .showFavorites, defaultValue: true)
        addCheckbox(title: "Show Recents", key: .showRecents, defaultValue: true)
        addCheckbox(title: "Show Locations", key: .showLocations, defaultValue: true)

        let orderTitle = NSTextField(labelWithString: "Order:")
        orderTitle.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(orderTitle)

        let segmentedControl = NSSegmentedControl(labels: ["Favorites, Recents, Locations", "Locations, Favorites, Recents"], trackingMode: .selectOne, target: self, action: #selector(sidebarOrderChanged(_:)))
        let settings = SettingsStore.shared
        segmentedControl.selectedSegment = settings.sidebarOrder
        stackView.addArrangedSubview(segmentedControl)
    }

    private func addCheckbox(title: String, key: UserDefaults.Keys, defaultValue: Bool = false) {
        let checkbox = AccentCheckbox(title: title, target: self, action: #selector(checkboxChanged(_:)))
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

    @objc func sidebarOrderChanged(_ sender: NSSegmentedControl) {
        PendingSettings.shared.setValue(sender.selectedSegment, forKey: UserDefaults.Keys.sidebarOrder.rawValue)
    }
}

