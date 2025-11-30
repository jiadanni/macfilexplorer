import Cocoa

protocol SettingsWindowDelegate: AnyObject {
    func settingsWindowDidApply()
    func settingsWindowDidCancel()
    func settingsWindowDidReset()
}

class SettingsWindowController: NSWindowController, SettingsChangeDelegate {

    weak var settingsDelegate: SettingsWindowDelegate?
    private var settingsViewController: SettingsViewController?

    // Button container
    private var buttonContainerView: NSView?
    private var applyButton: NSButton?
    private var cancelButton: NSButton?
    private var okButton: NSButton?
    private var resetButton: NSButton?
    private var exportButton: NSButton?
    private var importButton: NSButton?

    convenience init() {
        let settingsVC = SettingsViewController()

        // Create a container view for the entire settings UI
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 650))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 650),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Preferences"
        window.minSize = NSSize(width: 600, height: 450)

        // Create a wrapper view controller
        let wrapperVC = NSViewController()
        wrapperVC.view = containerView

        window.contentViewController = wrapperVC
        self.init(window: window)

        self.settingsViewController = settingsVC
        settingsVC.changeDelegate = self
        setupButtonBar(in: containerView, settingsVC: settingsVC)
    }

    // MARK: - SettingsChangeDelegate

    func settingsDidChange() {
        enableApplyButton()
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        // Observe pending settings changes to enable Apply button
        NotificationCenter.default.addObserver(self, selector: #selector(pendingSettingsChanged), name: .pendingSettingsDidChange, object: nil)
    }

    private func setupButtonBar(in containerView: NSView, settingsVC: SettingsViewController) {
        // Add settings view controller's view
        let settingsView = settingsVC.view
        settingsView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(settingsView)

        // Create button container
        let buttonContainer = NSView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.wantsLayer = true
        buttonContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        containerView.addSubview(buttonContainer)
        buttonContainerView = buttonContainer

        // Add a separator line
        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator
        buttonContainer.addSubview(separator)

        // Create buttons
        resetButton = NSButton()
        resetButton?.title = "Reset to Defaults"
        resetButton?.bezelStyle = .rounded
        resetButton?.target = self
        resetButton?.action = #selector(resetButtonClicked)
        resetButton?.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(resetButton!)

        importButton = NSButton()
        importButton?.title = "Import..."
        importButton?.bezelStyle = .rounded
        importButton?.target = self
        importButton?.action = #selector(importButtonClicked)
        importButton?.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(importButton!)

        exportButton = NSButton()
        exportButton?.title = "Export..."
        exportButton?.bezelStyle = .rounded
        exportButton?.target = self
        exportButton?.action = #selector(exportButtonClicked)
        exportButton?.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(exportButton!)

        cancelButton = NSButton()
        cancelButton?.title = "Cancel"
        cancelButton?.bezelStyle = .rounded
        cancelButton?.keyEquivalent = "\u{1b}" // Escape key
        cancelButton?.target = self
        cancelButton?.action = #selector(cancelButtonClicked)
        cancelButton?.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(cancelButton!)

        applyButton = NSButton()
        applyButton?.title = "Apply"
        applyButton?.bezelStyle = .rounded
        applyButton?.target = self
        applyButton?.action = #selector(applyButtonClicked)
        applyButton?.translatesAutoresizingMaskIntoConstraints = false
        applyButton?.isEnabled = false // Initially disabled until changes are made
        buttonContainer.addSubview(applyButton!)

        okButton = NSButton()
        okButton?.title = "OK"
        okButton?.bezelStyle = .rounded
        okButton?.keyEquivalent = "\r" // Return key
        okButton?.target = self
        okButton?.action = #selector(okButtonClicked)
        okButton?.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(okButton!)

        // Setup constraints
        NSLayoutConstraint.activate([
            // Settings view (top section)
            settingsView.topAnchor.constraint(equalTo: containerView.topAnchor),
            settingsView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            settingsView.bottomAnchor.constraint(equalTo: buttonContainer.topAnchor),

            // Button container (bottom section)
            buttonContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            buttonContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            buttonContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            buttonContainer.heightAnchor.constraint(equalToConstant: 60),

            // Separator
            separator.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
            separator.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            // Reset button (left aligned)
            resetButton!.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor, constant: 16),
            resetButton!.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor, constant: -12),
            resetButton!.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

            // Import button (next to Reset)
            importButton!.leadingAnchor.constraint(equalTo: resetButton!.trailingAnchor, constant: 12),
            importButton!.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor, constant: -12),
            importButton!.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),

            // Export button (next to Import)
            exportButton!.leadingAnchor.constraint(equalTo: importButton!.trailingAnchor, constant: 12),
            exportButton!.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor, constant: -12),
            exportButton!.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),

            // OK button (right aligned)
            okButton!.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor, constant: -16),
            okButton!.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor, constant: -12),
            okButton!.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),

            // Apply button (next to OK)
            applyButton!.trailingAnchor.constraint(equalTo: okButton!.leadingAnchor, constant: -12),
            applyButton!.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor, constant: -12),
            applyButton!.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),

            // Cancel button (next to Apply)
            cancelButton!.trailingAnchor.constraint(equalTo: applyButton!.leadingAnchor, constant: -12),
            cancelButton!.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor, constant: -12),
            cancelButton!.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])

        // Set the settings delegate (commented out until methods are implemented)
        // settingsVC.windowDelegate = self
    }

    func enableApplyButton() {
        applyButton?.isEnabled = true
    }

    @objc private func pendingSettingsChanged() {
        enableApplyButton()
    }

    // MARK: - Button Actions

    @objc private func okButtonClicked() {
        // Apply changes and close
        settingsViewController?.applyChanges()
        settingsDelegate?.settingsWindowDidApply()
        close()
    }

    @objc private func cancelButtonClicked() {
        // Revert changes and close
        settingsViewController?.cancelChanges()
        settingsDelegate?.settingsWindowDidCancel()
        close()
    }

    @objc private func applyButtonClicked() {
        // Apply changes without closing
        settingsViewController?.applyChanges()
        settingsDelegate?.settingsWindowDidApply()
        applyButton?.isEnabled = false
    }

    @objc private func resetButtonClicked() {
        let alert = NSAlert()
        alert.messageText = "Reset to Defaults"
        alert.informativeText = "Are you sure you want to reset all settings to their default values? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // settingsViewController?.resetToDefaults()
            settingsDelegate?.settingsWindowDidReset()
            applyButton?.isEnabled = false
        }
    }

    @objc private func exportButtonClicked() {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Settings"
        savePanel.message = "Choose a location to save your settings"
        savePanel.nameFieldStringValue = "MacFileExplorer-Settings.json"
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true

        savePanel.begin { [weak self] response in
            guard response == .OK, let url = savePanel.url else { return }
            self?.exportSettings(to: url)
        }
    }

    @objc private func importButtonClicked() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Settings"
        openPanel.message = "Select a settings file to import"
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false

        openPanel.begin { [weak self] response in
            guard response == .OK, let url = openPanel.urls.first else { return }
            self?.importSettings(from: url)
        }
    }

    // MARK: - Export/Import Helpers

    private func exportSettings(to url: URL) {
        var settingsDict: [String: Any] = [:]
        let defaults = UserDefaults.standard

        // Export all settings keys
        for key in UserDefaults.Keys.allCases {
            if let value = defaults.object(forKey: key.rawValue) {
                settingsDict[key.rawValue] = value
            }
        }

        // Also export favorites
        if let favorites = defaults.array(forKey: "SidebarFavorites") {
            settingsDict["SidebarFavorites"] = favorites
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: settingsDict, options: [.prettyPrinted, .sortedKeys])
            try jsonData.write(to: url)

            // Show success alert
            let alert = NSAlert()
            alert.messageText = "Export Successful"
            alert.informativeText = "Your settings have been exported successfully."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } catch {
            // Show error alert
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = "Failed to export settings: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func importSettings(from url: URL) {
        do {
            let jsonData = try Data(contentsOf: url)
            guard let settingsDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                throw NSError(domain: "SettingsImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid settings file format"])
            }

            let defaults = UserDefaults.standard

            // Import all settings
            for (key, value) in settingsDict {
                defaults.set(value, forKey: key)
            }

            // Synchronize to ensure changes are saved
            defaults.synchronize()

            // Show success alert and offer to restart
            let alert = NSAlert()
            alert.messageText = "Import Successful"
            alert.informativeText = "Your settings have been imported successfully. Some changes may require restarting the application to take effect."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()

            // Notify delegate to refresh settings
            settingsDelegate?.settingsWindowDidApply()
            applyButton?.isEnabled = false

            // Post notification to refresh all UI
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        } catch {
            // Show error alert
            let alert = NSAlert()
            alert.messageText = "Import Failed"
            alert.informativeText = "Failed to import settings: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

// Notification names moved to NotificationNames.swift

