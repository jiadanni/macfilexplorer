//
//  StorageScopeSelectionViewController.swift
//  MacFileExplorer
//
//  Scan scope selection dialog for Storage Analyzer
//

import Cocoa

class StorageScopeSelectionViewController: NSViewController {
    // MARK: - Properties

    var completionHandler: ((URL, StorageAnalyzerEngine.ScanOptions) -> Void)?
    var cancelHandler: (() -> Void)?

    private var titleLabel: NSTextField!
    private var descriptionLabel: NSTextField!
    private var buttonStack: NSStackView!
    private var optionsStack: NSStackView!
    private var includeHiddenCheckbox: NSButton!
    private var minimumSizeTextField: NSTextField!
    private var cancelButton: NSButton!

    // Store scope buttons to maintain strong references
    private var thisMacButton: NSButton!
    private var homeFolderButton: NSButton!
    private var downloadsButton: NSButton!
    private var chooseFolderButton: NSButton!

    // MARK: - Lifecycle

    override func loadView() {
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 600))
        containerView.wantsLayer = false  // Disable layer-backing to allow proper event handling
        view = containerView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // Ensure the view can respond to actions
        view.window?.makeFirstResponder(view)
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Don't enable layer-backing on the main view to ensure button clicks work
        // Title
        titleLabel = NSTextField(labelWithString: "Storage Analyzer")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Description
        descriptionLabel = NSTextField(labelWithString: "What would you like to analyze?")
        descriptionLabel.font = NSFont.systemFont(ofSize: 13)
        descriptionLabel.alignment = .center
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        // Scan scope buttons
        buttonStack = NSStackView()
        buttonStack.orientation = .vertical
        buttonStack.spacing = 4  // Reduced spacing since labels are separate views
        buttonStack.alignment = .centerX
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        // Create buttons without containers - add directly to stack
        thisMacButton = createDirectButton(title: "This Mac", action: #selector(scanThisMac(_:)))
        let thisMacLabel = createSubtitleLabel("Scan entire system")

        homeFolderButton = createDirectButton(title: "Home Folder", action: #selector(scanHomeFolder(_:)))
        let homeFolderLabel = createSubtitleLabel("Scan your user directory")

        downloadsButton = createDirectButton(title: "Downloads", action: #selector(scanDownloads(_:)))
        let downloadsLabel = createSubtitleLabel("Scan Downloads folder")

        chooseFolderButton = createDirectButton(title: "Choose Folder...", action: #selector(chooseFolder(_:)))
        let chooseFolderLabel = createSubtitleLabel("Select a custom location")

        buttonStack.addArrangedSubview(thisMacButton)
        buttonStack.addArrangedSubview(thisMacLabel)
        buttonStack.setCustomSpacing(12, after: thisMacLabel)

        buttonStack.addArrangedSubview(homeFolderButton)
        buttonStack.addArrangedSubview(homeFolderLabel)
        buttonStack.setCustomSpacing(12, after: homeFolderLabel)

        buttonStack.addArrangedSubview(downloadsButton)
        buttonStack.addArrangedSubview(downloadsLabel)
        buttonStack.setCustomSpacing(12, after: downloadsLabel)

        buttonStack.addArrangedSubview(chooseFolderButton)
        buttonStack.addArrangedSubview(chooseFolderLabel)

        debugLog("StorageScopeSelection: All buttons added to stack, checking button states...")
        debugLog("StorageScopeSelection: thisMacButton.isEnabled=\(thisMacButton.isEnabled)")

        // Options section
        setupOptionsSection()

        // Layout
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(buttonStack)
        view.addSubview(optionsStack)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            buttonStack.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 24),
            buttonStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            buttonStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),

            optionsStack.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 24),
            optionsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            optionsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            optionsStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -24)
        ])
    }

    private func createDirectButton(title: String, action: Selector) -> NSButton {
        let button = NSButton()
        button.title = title
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
        button.isEnabled = true
        button.setButtonType(.momentaryPushIn)
        button.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            button.heightAnchor.constraint(equalToConstant: 32)
        ])

        debugLog("StorageScopeSelection: Created button '\(title)' with action: \(action)")
        return button
    }

    private func createSubtitleLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func setupOptionsSection() {
        optionsStack = NSStackView()
        optionsStack.orientation = .vertical
        optionsStack.spacing = 8
        optionsStack.alignment = .leading
        optionsStack.translatesAutoresizingMaskIntoConstraints = false

        // Section title
        let optionsTitle = NSTextField(labelWithString: "Scan Options")
        optionsTitle.font = NSFont.boldSystemFont(ofSize: 12)

        // Include hidden files checkbox
        includeHiddenCheckbox = AccentCheckbox(title: "Include hidden files", target: nil, action: nil)
        includeHiddenCheckbox.state = .off

        // Minimum size filter
        let sizeContainer = NSView()
        sizeContainer.translatesAutoresizingMaskIntoConstraints = false

        let sizeLabel = NSTextField(labelWithString: "Minimum file size (MB):")
        sizeLabel.font = NSFont.systemFont(ofSize: 12)
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false

        minimumSizeTextField = NSTextField(string: "0")
        minimumSizeTextField.placeholderString = "0"
        minimumSizeTextField.translatesAutoresizingMaskIntoConstraints = false

        sizeContainer.addSubview(sizeLabel)
        sizeContainer.addSubview(minimumSizeTextField)

        NSLayoutConstraint.activate([
            sizeLabel.leadingAnchor.constraint(equalTo: sizeContainer.leadingAnchor),
            sizeLabel.centerYAnchor.constraint(equalTo: sizeContainer.centerYAnchor),

            minimumSizeTextField.leadingAnchor.constraint(equalTo: sizeLabel.trailingAnchor, constant: 8),
            minimumSizeTextField.trailingAnchor.constraint(equalTo: sizeContainer.trailingAnchor),
            minimumSizeTextField.topAnchor.constraint(equalTo: sizeContainer.topAnchor),
            minimumSizeTextField.bottomAnchor.constraint(equalTo: sizeContainer.bottomAnchor),
            minimumSizeTextField.widthAnchor.constraint(equalToConstant: 60)
        ])

        optionsStack.addArrangedSubview(optionsTitle)
        optionsStack.addArrangedSubview(includeHiddenCheckbox)
        optionsStack.addArrangedSubview(sizeContainer)

        // Cancel button at the bottom
        cancelButton = NSButton()
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelAction(_:))
        cancelButton.setButtonType(.momentaryPushIn)
        cancelButton.isEnabled = true
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            cancelButton.widthAnchor.constraint(equalToConstant: 100)
        ])
    }

    // MARK: - Actions

    @objc private func cancelAction(_ sender: Any) {
        cancelHandler?()
    }

    @objc private func scanThisMac(_ sender: Any) {
        debugLog("StorageScopeSelection: scanThisMac action called")
        let url = URL(fileURLWithPath: "/")
        startScan(url: url)
    }

    @objc private func scanHomeFolder(_ sender: Any) {
        debugLog("StorageScopeSelection: scanHomeFolder action called")
        let url = FileManager.default.homeDirectoryForCurrentUser
        startScan(url: url)
    }

    @objc private func scanDownloads(_ sender: Any) {
        debugLog("StorageScopeSelection: scanDownloads action called")
        guard let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            debugLog("StorageScopeSelection: Failed to get downloads directory")
            return
        }
        startScan(url: url)
    }

    @objc private func chooseFolder(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"

        guard let window = view.window else {
            debugLog("Warning: Cannot show folder chooser - view has no window")
            return
        }

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.startScan(url: url)
        }
    }

    private func startScan(url: URL) {
        debugLog("StorageScopeSelection: startScan called for \(url.path)")
        debugLog("StorageScopeSelection: completionHandler is \(completionHandler == nil ? "nil" : "set")")

        // Build options
        var options = StorageAnalyzerEngine.ScanOptions()
        options.includeHiddenFiles = includeHiddenCheckbox.state == .on

        if let minSizeText = minimumSizeTextField.stringValue.isEmpty ? nil : minimumSizeTextField.stringValue,
           let minSizeMB = Int64(minSizeText) {
            options.minimumSize = minSizeMB * 1024 * 1024 // Convert MB to bytes
        }

        // Save last scan path
        UserDefaults.standard.set(url.path, forKey: "StorageAnalyzerLastScanPath")

        // Call completion handler - this will trigger the sheet dismissal in the parent
        debugLog("StorageScopeSelection: About to call completionHandler")
        completionHandler?(url, options)
        debugLog("StorageScopeSelection: completionHandler called")
    }
}
