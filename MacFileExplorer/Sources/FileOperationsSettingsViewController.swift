import Cocoa

final class FileOperationsSettingsViewController: NSViewController {

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

        addFileOperationsSettings()
    }

    private func addFileOperationsSettings() {
        let titleLabel = NSTextField(labelWithString: "File Operations:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 2)
        stackView.addArrangedSubview(titleLabel)

        // Auto-rename setting
        addCheckbox(title: "Auto-rename on file conflict", key: .autoRenameOnConflict, defaultValue: false)

        let autoRenameDesc = NSTextField(labelWithString: "Automatically rename files when copying/moving to a location with an existing file of the same name")
        autoRenameDesc.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        autoRenameDesc.textColor = .secondaryLabelColor
        autoRenameDesc.lineBreakMode = .byWordWrapping
        autoRenameDesc.maximumNumberOfLines = 0
        autoRenameDesc.preferredMaxLayoutWidth = 450
        stackView.addArrangedSubview(autoRenameDesc)

        // Add spacing
        let spacer1 = NSView()
        spacer1.translatesAutoresizingMaskIntoConstraints = false
        spacer1.heightAnchor.constraint(equalToConstant: 15).isActive = true
        stackView.addArrangedSubview(spacer1)

        // Delete key setting
        addCheckbox(title: "Delete files with Backspace key only (disable Command+Delete)", key: .deleteWithBackspaceOnly, defaultValue: false)

        let deleteDesc = NSTextField(labelWithString: "Press Backspace to move files to trash. Command+Delete will be disabled.")
        deleteDesc.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        deleteDesc.textColor = .secondaryLabelColor
        deleteDesc.lineBreakMode = .byWordWrapping
        deleteDesc.maximumNumberOfLines = 0
        deleteDesc.preferredMaxLayoutWidth = 450
        stackView.addArrangedSubview(deleteDesc)

        // Add spacing
        let spacer2 = NSView()
        spacer2.translatesAutoresizingMaskIntoConstraints = false
        spacer2.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacer2)

        // Confirmations & Progress section
        let confirmationsTitle = NSTextField(labelWithString: "Confirmations & Progress:")
        confirmationsTitle.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(confirmationsTitle)

        // Confirm operations
        addCheckbox(title: "Confirm file operations (copy/move/paste/delete)", key: .confirmFileOperations, defaultValue: true)

        let confirmDesc = NSTextField(labelWithString: "Show confirmation dialogs with item counts, sizes, and available space before executing operations.")
        confirmDesc.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        confirmDesc.textColor = .secondaryLabelColor
        confirmDesc.lineBreakMode = .byWordWrapping
        confirmDesc.maximumNumberOfLines = 0
        confirmDesc.preferredMaxLayoutWidth = 450
        stackView.addArrangedSubview(confirmDesc)

        // Add spacing
        let spacer3 = NSView()
        spacer3.translatesAutoresizingMaskIntoConstraints = false
        spacer3.heightAnchor.constraint(equalToConstant: 15).isActive = true
        stackView.addArrangedSubview(spacer3)

        // Show progress
        addCheckbox(title: "Show progress sheets during operations", key: .showOperationProgress, defaultValue: true)

        let progressDesc = NSTextField(labelWithString: "Display a progress dialog for multi-file copy, move, paste, and delete operations.")
        progressDesc.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        progressDesc.textColor = .secondaryLabelColor
        progressDesc.lineBreakMode = .byWordWrapping
        progressDesc.maximumNumberOfLines = 0
        progressDesc.preferredMaxLayoutWidth = 450
        stackView.addArrangedSubview(progressDesc)
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
