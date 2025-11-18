import Cocoa

protocol SettingsSplitPaneDelegate: AnyObject {
    func settingsDidApply()
    func settingsDidCancel()
}

// A specialized SplitPaneViewController that hosts the SettingsViewController inside a tab.
class SettingsSplitPaneViewController: SplitPaneViewController, SettingsChangeDelegate {
    private var settingsVC: SettingsViewController?
    weak var settingsDelegate: SettingsSplitPaneDelegate?

    // Button bar views
    private var buttonContainerView: NSView?
    private var applyButton: NSButton?
    private var cancelButton: NSButton?
    private var okButton: NSButton?
    private var resetButton: NSButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Remove any file browser panes added by base implementation
        for item in splitViewItems { removeSplitViewItem(item) }
        for child in children { child.removeFromParent() }

        setupSettingsWithButtons()
    }

    private func setupSettingsWithButtons() {
        // Create settings view controller
        let svc = SettingsViewController()
        settingsVC = svc
        svc.changeDelegate = self

        // Create a container view that will hold both settings and button bar
        let containerVC = NSViewController()
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerVC.view = containerView

        // Add settings view
        let settingsView = svc.view
        settingsView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(settingsView)

        // Create button bar
        let buttonBar = createButtonBar()
        containerView.addSubview(buttonBar)

        // Setup constraints
        NSLayoutConstraint.activate([
            // Settings view takes up most of the space
            settingsView.topAnchor.constraint(equalTo: containerView.topAnchor),
            settingsView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            settingsView.bottomAnchor.constraint(equalTo: buttonBar.topAnchor),

            // Button bar at the bottom
            buttonBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            buttonBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            buttonBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            buttonBar.heightAnchor.constraint(equalToConstant: 60)
        ])

        // Add container to split view
        let item = NSSplitViewItem(viewController: containerVC)
        item.canCollapse = false
        addSplitViewItem(item)
    }

    private func createButtonBar() -> NSView {
        let buttonContainer = NSView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.wantsLayer = true
        buttonContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        buttonContainerView = buttonContainer

        // Add separator line
        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator
        buttonContainer.addSubview(separator)

        // Create buttons - left side
        resetButton = NSButton()
        resetButton?.title = "Reset to Defaults"
        resetButton?.bezelStyle = .rounded
        resetButton?.target = self
        resetButton?.action = #selector(resetButtonClicked)
        resetButton?.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(resetButton!)

        // Create buttons - right side
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
        applyButton?.isEnabled = false // Initially disabled
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
            // Separator at top
            separator.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
            separator.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            // Reset button (left aligned)
            resetButton!.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor, constant: 16),
            resetButton!.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor, constant: -12),
            resetButton!.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

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

        return buttonContainer
    }

    // MARK: - SettingsChangeDelegate

    func settingsDidChange() {
        applyButton?.isEnabled = true
    }

    // MARK: - Button Actions

    @objc private func okButtonClicked() {
        // Apply changes and close the tab
        settingsVC?.applyChanges()
        settingsDelegate?.settingsDidApply()

        // Close this settings tab by triggering close current tab
        if let tabBarController = delegate as? TabBarController {
            tabBarController.closeCurrentTab()
        }
    }

    @objc private func cancelButtonClicked() {
        // Revert changes and close the tab
        settingsVC?.cancelChanges()
        settingsDelegate?.settingsDidCancel()

        // Close this settings tab by triggering close current tab
        if let tabBarController = delegate as? TabBarController {
            tabBarController.closeCurrentTab()
        }
    }

    @objc private func applyButtonClicked() {
        // Apply changes without closing
        settingsVC?.applyChanges()
        settingsDelegate?.settingsDidApply()
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
            // Reset all settings to defaults
            for key in UserDefaults.Keys.allCases {
                UserDefaults.standard.removeObject(forKey: key.rawValue)
            }
            // Post notification to refresh all UI
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
            applyButton?.isEnabled = false
        }
    }

    // MARK: - Overrides to neutralize file operations
    override func navigateToURL(_ url: URL) { /* No-op in settings tab */ }
    override func cutSelection() { }
    override func copySelection() { }
    override func pasteSelection() { }
    override func setViewMode(_ viewMode: ViewMode) { }
    override func toggleHiddenFiles() { }
    override func isShowingHiddenFiles() -> Bool { return false }
    override func updateZoomLevel(to level: Double) { }
    override func goBack() { }
    override func goForward() { }
}
