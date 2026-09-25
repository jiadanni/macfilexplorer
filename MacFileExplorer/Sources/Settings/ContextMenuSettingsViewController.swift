import Cocoa

final class ContextMenuSettingsViewController: NSViewController {

    private var stackView: NSStackView!
    private let settingsStore: SettingsStoreProtocol = SettingsStore.shared

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.view = scrollView

        let contentView = SettingsContentView()
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

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        stackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        addContextMenuSettings()
    }

    private func addContextMenuSettings() {
        let titleLabel = NSTextField(labelWithString: "Context Menu:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(titleLabel)

        addCheckbox(title: "Show hotkeys in context menu", key: .showContextMenuHotkeys, defaultValue: true)

        // Add spacing
        let spacer1 = NSView()
        spacer1.translatesAutoresizingMaskIntoConstraints = false
        spacer1.heightAnchor.constraint(equalToConstant: 10).isActive = true
        stackView.addArrangedSubview(spacer1)

        let visibilityTitleLabel = NSTextField(labelWithString: "Toggle options on/off:")
        visibilityTitleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(visibilityTitleLabel)

        let descriptionLabel = NSTextField(labelWithString: "Hide specific menu items from the context menu:")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descriptionLabel)

        addCheckbox(title: "Hide 'Open With...'", key: .hideOpenWith)
        addCheckbox(title: "Hide 'Get Info'", key: .hideGetInfo)
        addCheckbox(title: "Hide 'Copy'", key: .hideCopy)
        addCheckbox(title: "Hide 'Cut'", key: .hideCut)
        addCheckbox(title: "Hide 'Paste'", key: .hidePaste)
        addCheckbox(title: "Hide 'Rename'", key: .hideRename)
        addCheckbox(title: "Hide 'Move to Trash'", key: .hideMoveToTrash)
        addCheckbox(title: "Hide 'New Folder'", key: .hideNewFolder)
        addCheckbox(title: "Hide 'Show in Finder'", key: .hideShowInFinder)
    }

    private func addCheckbox(title: String, key: UserDefaults.Keys, defaultValue: Bool = false) {
        let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(checkboxChanged(_:)))
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
