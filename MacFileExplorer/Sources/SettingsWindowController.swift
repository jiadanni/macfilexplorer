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

    convenience init() {
        let settingsVC = SettingsViewController()

        // Create a container view for the entire settings UI
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 650),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Preferences"
        window.minSize = NSSize(width: 600, height: 400)

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

    private func setupButtonBar(in containerView: NSView, settingsVC: SettingsViewController) {
        // Add settings view controller's view
        let settingsView = settingsVC.view
        settingsView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(settingsView)

        // Create button container
        let buttonContainer = NSView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.wantsLayer = true
        buttonContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
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
            buttonContainer.heightAnchor.constraint(equalToConstant: 50),

            // Separator
            separator.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
            separator.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),

            // Reset button (left aligned)
            resetButton!.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor, constant: 16),
            resetButton!.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            resetButton!.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

            // OK button (right aligned)
            okButton!.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor, constant: -16),
            okButton!.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            okButton!.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),

            // Apply button (next to OK)
            applyButton!.trailingAnchor.constraint(equalTo: okButton!.leadingAnchor, constant: -12),
            applyButton!.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            applyButton!.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),

            // Cancel button (next to Apply)
            cancelButton!.trailingAnchor.constraint(equalTo: applyButton!.leadingAnchor, constant: -12),
            cancelButton!.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            cancelButton!.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])

        // Set the settings delegate (commented out until methods are implemented)
        // settingsVC.windowDelegate = self
    }

    func enableApplyButton() {
        applyButton?.isEnabled = true
    }

    // MARK: - Button Actions

    @objc private func okButtonClicked() {
        // Apply changes and close
        // settingsViewController?.applyChanges()
        settingsDelegate?.settingsWindowDidApply()
        close()
    }

    @objc private func cancelButtonClicked() {
        // Revert changes and close
        // settingsViewController?.cancelChanges()
        settingsDelegate?.settingsWindowDidCancel()
        close()
    }

    @objc private func applyButtonClicked() {
        // Apply changes without closing
        // settingsViewController?.applyChanges()
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
}
