import Cocoa

final class AdvancedSettingsViewController: NSViewController {

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
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20)
        ])

        addAdvancedSettings()
    }

    private func addAdvancedSettings() {
        let titleLabel = NSTextField(labelWithString: "Advanced Settings")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(titleLabel)

        let statusBarTitle = NSTextField(labelWithString: "Status Bar:")
        statusBarTitle.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(statusBarTitle)

        addCheckbox(title: "Show Status Bar", key: .showStatusBar, defaultValue: true)

        let descriptionLabel = NSTextField(labelWithString: "Display file information or free space in the status bar")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descriptionLabel)

        // Add spacing
        let spacer1 = NSView()
        spacer1.translatesAutoresizingMaskIntoConstraints = false
        spacer1.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacer1)

        // Maximum Panes section
        let maxPanesTitle = NSTextField(labelWithString: "Split Panes:")
        maxPanesTitle.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(maxPanesTitle)

        // Create horizontal stack for stepper and label
        let maxPanesRow = NSStackView()
        maxPanesRow.orientation = .horizontal
        maxPanesRow.spacing = 8
        maxPanesRow.alignment = .centerY
        maxPanesRow.translatesAutoresizingMaskIntoConstraints = false

        let maxPanesLabel = NSTextField(labelWithString: "Maximum number of panes:")
        maxPanesLabel.isEditable = false
        maxPanesLabel.isBordered = false
        maxPanesLabel.backgroundColor = .clear
        maxPanesRow.addArrangedSubview(maxPanesLabel)

        let currentMaxPanes = UserDefaults.standard.integer(forKey: UserDefaults.Keys.maximumPanes.rawValue)
        let initialValue = currentMaxPanes > 0 ? currentMaxPanes : 2

        let maxPanesValueLabel = NSTextField(labelWithString: "\(initialValue)")
        maxPanesValueLabel.isEditable = false
        maxPanesValueLabel.isBordered = false
        maxPanesValueLabel.backgroundColor = .clear
        maxPanesValueLabel.alignment = .right
        maxPanesValueLabel.translatesAutoresizingMaskIntoConstraints = false
        maxPanesValueLabel.widthAnchor.constraint(equalToConstant: 30).isActive = true
        maxPanesRow.addArrangedSubview(maxPanesValueLabel)

        let maxPanesStepper = NSStepper()
        maxPanesStepper.minValue = 2
        maxPanesStepper.maxValue = 8
        maxPanesStepper.integerValue = initialValue
        maxPanesStepper.target = self
        maxPanesStepper.action = #selector(maxPanesStepperChanged(_:))
        maxPanesStepper.tag = maxPanesValueLabel.hashValue // Store label reference
        maxPanesRow.addArrangedSubview(maxPanesStepper)

        stackView.addArrangedSubview(maxPanesRow)

        let maxPanesDescription = NSTextField(labelWithString: "Maximum number of split panes allowed (2-8). Default is 2.")
        maxPanesDescription.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        maxPanesDescription.textColor = .secondaryLabelColor
        maxPanesDescription.maximumNumberOfLines = 2
        maxPanesDescription.lineBreakMode = .byWordWrapping
        stackView.addArrangedSubview(maxPanesDescription)

        // Add spacing
        let spacer1b = NSView()
        spacer1b.translatesAutoresizingMaskIntoConstraints = false
        spacer1b.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacer1b)

        // Folder Size Display section
        let folderSizeTitle = NSTextField(labelWithString: "List View:")
        folderSizeTitle.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(folderSizeTitle)

        addCheckbox(title: "Calculate and display folder sizes", key: .showFolderSizes, defaultValue: false)

        // Warning label
        let warningLabel = NSTextField(labelWithString: "⚠️ Warning: Calculating folder sizes may impact performance, especially for folders with many items. Sizes are estimates and may not be up-to-date if folder contents change.")
        warningLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        warningLabel.textColor = .systemOrange
        warningLabel.maximumNumberOfLines = 0
        warningLabel.lineBreakMode = .byWordWrapping
        warningLabel.preferredMaxLayoutWidth = 450
        stackView.addArrangedSubview(warningLabel)

        // Add spacing
        let spacer1c = NSView()
        spacer1c.translatesAutoresizingMaskIntoConstraints = false
        spacer1c.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacer1c)

        // Settings Export/Import section
        let exportImportTitle = NSTextField(labelWithString: "Settings Export/Import:")
        exportImportTitle.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(exportImportTitle)

        let exportImportDescription = NSTextField(labelWithString: "Backup and restore your preferences")
        exportImportDescription.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        exportImportDescription.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(exportImportDescription)

        // Export button
        let exportButton = NSButton(title: "Export Settings...", target: self, action: #selector(exportSettings(_:)))
        exportButton.bezelStyle = .rounded
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(exportButton)

        // Import button
        let importButton = NSButton(title: "Import Settings...", target: self, action: #selector(importSettings(_:)))
        importButton.bezelStyle = .rounded
        importButton.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(importButton)

        // Add spacing
        let spacer2 = NSView()
        spacer2.translatesAutoresizingMaskIntoConstraints = false
        spacer2.heightAnchor.constraint(equalToConstant: 10).isActive = true
        stackView.addArrangedSubview(spacer2)

        // Reset button
        let resetButton = NSButton(title: "Reset All Settings to Defaults", target: self, action: #selector(resetSettings(_:)))
        resetButton.bezelStyle = .rounded
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(resetButton)
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

    @objc func maxPanesStepperChanged(_ sender: NSStepper) {
        let newValue = sender.integerValue
        PendingSettings.shared.setValue(newValue, forKey: UserDefaults.Keys.maximumPanes.rawValue)

        // Find and update the value label in the same row
        if let parentStack = stackView.arrangedSubviews.compactMap({ $0 as? NSStackView }).first(where: { stack in
            stack.arrangedSubviews.contains(where: { ($0 as? NSStepper) === sender })
        }) {
            if let valueLabel = parentStack.arrangedSubviews.compactMap({ $0 as? NSTextField }).last {
                valueLabel.stringValue = "\(newValue)"
            }
        }
    }

    @objc func exportSettings(_ sender: NSButton) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "MacFileExplorer Settings.json"
        savePanel.title = "Export Settings"
        savePanel.message = "Choose where to save your settings"

        savePanel.begin { [weak self] response in
            guard response == .OK, let url = savePanel.url else { return }
            self?.performExport(to: url)
        }
    }

    @objc func importSettings(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Import Settings"
        openPanel.message = "Select a settings file to import"

        openPanel.begin { [weak self] response in
            guard response == .OK, let url = openPanel.urls.first else { return }
            self?.performImport(from: url)
        }
    }

    @objc func resetSettings(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "Reset All Settings"
        alert.informativeText = "Are you sure you want to reset all settings to their default values? This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            performReset()
        }
    }

    private func performExport(to url: URL) {
        // Collect all settings
        var settings: [String: Any] = [:]
        for key in UserDefaults.Keys.allCases {
            if let value = UserDefaults.standard.object(forKey: key.rawValue) {
                settings[key.rawValue] = value
            }
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
            try jsonData.write(to: url)

            let alert = NSAlert()
            alert.messageText = "Export Successful"
            alert.informativeText = "Your settings have been exported successfully."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = "Failed to export settings: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func performImport(from url: URL) {
        do {
            let jsonData = try Data(contentsOf: url)
            guard let settings = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                throw NSError(domain: "com.macfileexplorer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid settings file format"])
            }

            // Import settings
            for (key, value) in settings {
                UserDefaults.standard.set(value, forKey: key)
            }

            let alert = NSAlert()
            alert.messageText = "Import Successful"
            alert.informativeText = "Your settings have been imported successfully. Please restart the application for all changes to take effect."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Import Failed"
            alert.informativeText = "Failed to import settings: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func performReset() {
        // Reset all settings to defaults
        for key in UserDefaults.Keys.allCases {
            UserDefaults.standard.removeObject(forKey: key.rawValue)
        }

        let alert = NSAlert()
        alert.messageText = "Settings Reset"
        alert.informativeText = "All settings have been reset to their default values. Please restart the application for all changes to take effect."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

