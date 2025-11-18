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

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

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
        buttonStack.spacing = 12
        buttonStack.alignment = .centerX
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let thisMacButton = createScopeButton(title: "This Mac", subtitle: "Scan entire system", action: #selector(scanThisMac(_:)))
        let homeFolderButton = createScopeButton(title: "Home Folder", subtitle: "Scan your user directory", action: #selector(scanHomeFolder(_:)))
        let downloadsButton = createScopeButton(title: "Downloads", subtitle: "Scan Downloads folder", action: #selector(scanDownloads(_:)))
        let chooseButton = createScopeButton(title: "Choose Folder...", subtitle: "Select a custom location", action: #selector(chooseFolder(_:)))

        buttonStack.addArrangedSubview(thisMacButton)
        buttonStack.addArrangedSubview(homeFolderButton)
        buttonStack.addArrangedSubview(downloadsButton)
        buttonStack.addArrangedSubview(chooseButton)

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

    private func createScopeButton(title: String, subtitle: String, action: Selector) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let button = NSButton()
        button.title = title
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(button)
        container.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),

            subtitleLabel.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 4),
            subtitleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
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
        let url = URL(fileURLWithPath: "/")
        startScan(url: url)
    }

    @objc private func scanHomeFolder(_ sender: Any) {
        let url = FileManager.default.homeDirectoryForCurrentUser
        startScan(url: url)
    }

    @objc private func scanDownloads(_ sender: Any) {
        let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        startScan(url: url)
    }

    @objc private func chooseFolder(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.startScan(url: url)
        }
    }

    private func startScan(url: URL) {
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
        completionHandler?(url, options)
    }
}
