import Cocoa

final class GeneralSettingsViewController: NSViewController {

    private var stackView: NSStackView!
    weak var changeDelegate: SettingsChangeDelegate?

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
        stackView.detachesHiddenViews = true
        contentView.addSubview(stackView)

        scrollView.documentView = contentView

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        stackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        addStartupFolderSettings()
        addFileExtensionSettings()
        addSelectionSettings()
        addDefaultViewAndSortSettings()
    }

    private func addStartupFolderSettings() {
        let titleLabel = NSTextField(labelWithString: "Startup Location:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(titleLabel)

        // Create horizontal container for path display and buttons
        let pathContainer = NSView()
        pathContainer.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(pathContainer)

        // Current path label
        let pathLabel = NSTextField(labelWithString: getStartupFolderPath())
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.isEditable = false
        pathLabel.isBordered = false
        pathLabel.backgroundColor = .clear
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.tag = 9001 // Tag to find this label later
        pathContainer.addSubview(pathLabel)

        // Change button
        let changeButton = NSButton(title: "Choose Folder...", target: self, action: #selector(chooseStartupFolder(_:)))
        changeButton.translatesAutoresizingMaskIntoConstraints = false
        changeButton.bezelStyle = .rounded
        pathContainer.addSubview(changeButton)

        // Reset to Start Page button
        let resetButton = NSButton(title: "Use Start Page", target: self, action: #selector(resetStartupFolder(_:)))
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.bezelStyle = .rounded
        pathContainer.addSubview(resetButton)

        NSLayoutConstraint.activate([
            pathContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 30),

            pathLabel.leadingAnchor.constraint(equalTo: pathContainer.leadingAnchor),
            pathLabel.centerYAnchor.constraint(equalTo: pathContainer.centerYAnchor),
            pathLabel.trailingAnchor.constraint(equalTo: changeButton.leadingAnchor, constant: -12),

            resetButton.trailingAnchor.constraint(equalTo: pathContainer.trailingAnchor),
            resetButton.centerYAnchor.constraint(equalTo: pathContainer.centerYAnchor),
            resetButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

            changeButton.trailingAnchor.constraint(equalTo: resetButton.leadingAnchor, constant: -8),
            changeButton.centerYAnchor.constraint(equalTo: pathContainer.centerYAnchor),
            changeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 130)
        ])

        // Add description
        let descriptionLabel = NSTextField(labelWithString: "Choose what opens when the app launches: Start Page or a specific folder")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 0
        descriptionLabel.preferredMaxLayoutWidth = 400
        stackView.addArrangedSubview(descriptionLabel)

        // Add spacing
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacer)
    }

    private func getStartupFolderPath() -> String {
        if let path = UserDefaults.standard.string(forKey: UserDefaults.Keys.startupFolder.rawValue) {
            return path
        }
        return "Start Page (default)"
    }

    @objc private func chooseStartupFolder(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = false

        // Set initial directory to a safe location to avoid permission dialogs
        // Only navigate to existing path if user explicitly wants to
        openPanel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())

        openPanel.begin { [weak self] response in
            guard response == .OK, let url = openPanel.url else { return }

            PendingSettings.shared.setValue(url.path, forKey: UserDefaults.Keys.startupFolder.rawValue)
            // Disable Start Page when a folder is chosen
            PendingSettings.shared.setValue(false, forKey: UserDefaults.Keys.showStartOnLaunch.rawValue)

            // Update the path label
            if let pathLabel = self?.view.viewWithTag(9001) as? NSTextField {
                pathLabel.stringValue = url.path
            }

            // Notify delegate of changes
            self?.changeDelegate?.settingsDidChange()
        }
    }

    @objc private func resetStartupFolder(_ sender: Any) {
        // Remove the setting to default to Start Page
        PendingSettings.shared.setValue(nil, forKey: UserDefaults.Keys.startupFolder.rawValue)
        PendingSettings.shared.setValue(true, forKey: UserDefaults.Keys.showStartOnLaunch.rawValue)

        // Update the path label
        if let pathLabel = view.viewWithTag(9001) as? NSTextField {
            pathLabel.stringValue = "Start Page (default)"
        }

        // Notify delegate of changes
        changeDelegate?.settingsDidChange()
    }

    private func addFileExtensionSettings() {
        let titleLabel = NSTextField(labelWithString: "File Extensions:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(titleLabel)

        addCheckbox(title: "Show all file extensions", key: .showFileExtensions, defaultValue: true)

        // Add description
        let showExtDescriptionLabel = NSTextField(labelWithString: "Display file extensions for all files (requires reload)")
        showExtDescriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        showExtDescriptionLabel.textColor = .secondaryLabelColor
        showExtDescriptionLabel.lineBreakMode = .byWordWrapping
        showExtDescriptionLabel.maximumNumberOfLines = 0
        showExtDescriptionLabel.preferredMaxLayoutWidth = 400
        stackView.addArrangedSubview(showExtDescriptionLabel)

        // Add small spacer
        let smallSpacer = NSView()
        smallSpacer.translatesAutoresizingMaskIntoConstraints = false
        smallSpacer.heightAnchor.constraint(equalToConstant: 10).isActive = true
        stackView.addArrangedSubview(smallSpacer)

        addCheckbox(title: "Warn on extension change", key: .warnOnExtensionChange, defaultValue: true)

        // Add description
        let descriptionLabel = NSTextField(labelWithString: "Display a warning when changing a file's extension")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 0
        descriptionLabel.preferredMaxLayoutWidth = 400
        stackView.addArrangedSubview(descriptionLabel)
    }

    private func addSelectionSettings() {
        // Add spacing
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacer)

        let titleLabel = NSTextField(labelWithString: "File Selection:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(titleLabel)

        addCheckbox(title: "Use checkboxes to select files (Easy Select)", key: .enableEasySelect, defaultValue: false)

        // Add description
        let descriptionLabel = NSTextField(labelWithString: "Show checkboxes next to files and folders for easier selection")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 0
        descriptionLabel.preferredMaxLayoutWidth = 400
        stackView.addArrangedSubview(descriptionLabel)
    }

    private func addFolderAppearanceSettings() {
        // Add spacing
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacer)

        let titleLabel = NSTextField(labelWithString: "Folder Appearance:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(titleLabel)

        let descriptionLabel = NSTextField(labelWithString: "Choose a global color for all folder icons:")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 0
        descriptionLabel.preferredMaxLayoutWidth = 400
        stackView.addArrangedSubview(descriptionLabel)

        // Create color palette with preset colors
        let paletteContainer = NSView()
        paletteContainer.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(paletteContainer)

        let presetColors: [(String, NSColor)] = [
            ("Default", .controlAccentColor),
            ("Blue", NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)),
            ("Purple", NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0)),
            ("Pink", NSColor(red: 1.0, green: 0.18, blue: 0.33, alpha: 1.0)),
            ("Red", NSColor(red: 1.0, green: 0.27, blue: 0.23, alpha: 1.0)),
            ("Orange", NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)),
            ("Yellow", NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)),
            ("Green", NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)),
            ("Gray", NSColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1.0)),
            ("None", .clear)
        ]

        var xOffset: CGFloat = 0
        var yOffset: CGFloat = 0
        let buttonSize: CGFloat = 36
        let spacing: CGFloat = 8
        let buttonsPerRow = 5

        // Load currently selected color
        var currentColor = NSColor.controlAccentColor
        if let colorData = UserDefaults.standard.data(forKey: UserDefaults.Keys.globalFolderColor.rawValue),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            currentColor = color
        }

        for (index, (name, color)) in presetColors.enumerated() {
            let colorButton = NSButton()
            colorButton.translatesAutoresizingMaskIntoConstraints = false
            colorButton.bezelStyle = .regularSquare
            colorButton.isBordered = true
            colorButton.wantsLayer = true
            colorButton.layer?.backgroundColor = color.cgColor
            colorButton.layer?.cornerRadius = 4
            colorButton.title = ""
            colorButton.target = self
            colorButton.action = #selector(colorButtonClicked(_:))
            colorButton.tag = index
            colorButton.toolTip = name

            // Highlight selected color with prominent border
            if colorsAreEqual(color, currentColor) {
                colorButton.layer?.borderWidth = 4
                colorButton.layer?.borderColor = NSColor.customAccentColor.cgColor
            } else {
                colorButton.layer?.borderWidth = 2
                colorButton.layer?.borderColor = NSColor.separatorColor.cgColor
            }

            paletteContainer.addSubview(colorButton)

            NSLayoutConstraint.activate([
                colorButton.widthAnchor.constraint(equalToConstant: buttonSize),
                colorButton.heightAnchor.constraint(equalToConstant: buttonSize),
                colorButton.leadingAnchor.constraint(equalTo: paletteContainer.leadingAnchor, constant: xOffset),
                colorButton.topAnchor.constraint(equalTo: paletteContainer.topAnchor, constant: yOffset)
            ])

            xOffset += buttonSize + spacing
            if (index + 1) % buttonsPerRow == 0 {
                xOffset = 0
                yOffset += buttonSize + spacing
            }
        }

        // Set palette container height
        let totalRows = CGFloat((presetColors.count + buttonsPerRow - 1) / buttonsPerRow)
        NSLayoutConstraint.activate([
            paletteContainer.heightAnchor.constraint(equalToConstant: totalRows * (buttonSize + spacing) - spacing),
            paletteContainer.widthAnchor.constraint(equalToConstant: CGFloat(buttonsPerRow) * (buttonSize + spacing) - spacing)
        ])
    }

    private func colorsAreEqual(_ color1: NSColor, _ color2: NSColor) -> Bool {
        guard let rgb1 = color1.usingColorSpace(.deviceRGB),
              let rgb2 = color2.usingColorSpace(.deviceRGB) else {
            return false
        }
        return abs(rgb1.redComponent - rgb2.redComponent) < 0.01 &&
            abs(rgb1.greenComponent - rgb2.greenComponent) < 0.01 &&
            abs(rgb1.blueComponent - rgb2.blueComponent) < 0.01
    }

    @objc private func colorButtonClicked(_ sender: NSButton) {
        let presetColors: [NSColor] = [
            .controlAccentColor,
            NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0),
            NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0),
            NSColor(red: 1.0, green: 0.18, blue: 0.33, alpha: 1.0),
            NSColor(red: 1.0, green: 0.27, blue: 0.23, alpha: 1.0),
            NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0),
            NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0),
            NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0),
            NSColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1.0),
            .clear
        ]

        guard sender.tag < presetColors.count else { return }
        let selectedColor = presetColors[sender.tag]

        // Save the color to pending settings
        do {
            let colorData = try NSKeyedArchiver.archivedData(withRootObject: selectedColor, requiringSecureCoding: false)
            PendingSettings.shared.setValue(colorData, forKey: UserDefaults.Keys.globalFolderColor.rawValue)

            // Update button borders to show selection
            if let paletteContainer = sender.superview {
                for view in paletteContainer.subviews {
                    if let button = view as? NSButton {
                        button.layer?.borderColor = NSColor.separatorColor.cgColor
                    }
                }
            }
            sender.layer?.borderColor = NSColor.selectedContentBackgroundColor.cgColor

            // Notify delegate that settings changed
            changeDelegate?.settingsDidChange()
        } catch {
            debugLog("Failed to archive color: \(error)")
        }
    }

    private func addCheckbox(title: String, key: UserDefaults.Keys, defaultValue: Bool = false) {
        let checkbox = AccentCheckbox(title: title, target: self, action: #selector(checkboxChanged(_:)))
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.tag = key.rawValue.hashValue // Use hashValue as a unique identifier for the key
        checkbox.state = UserDefaults.standard.bool(forKey: key.rawValue) ? .on : .off
        // Set default value if not already set
        if UserDefaults.standard.object(forKey: key.rawValue) == nil {
            UserDefaults.standard.set(defaultValue, forKey: key.rawValue)
            checkbox.state = defaultValue ? .on : .off
        }
        stackView.addArrangedSubview(checkbox)
    }

    @objc func checkboxChanged(_ sender: NSButton) {
        // Find the UserDefaults.Keys enum value from the tag
        if let key = UserDefaults.Keys.allCases.first(where: { $0.rawValue.hashValue == sender.tag }) {
            PendingSettings.shared.setValue(sender.state == .on, forKey: key.rawValue)
            changeDelegate?.settingsDidChange()

            // Note: Notifications for immediate UI updates will be sent when Apply is clicked
        }
    }

    private func addAccentColorSettings() {
        // Add spacing
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacer)

        let titleLabel = NSTextField(labelWithString: "Accent Color:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(titleLabel)

        let descriptionLabel = NSTextField(labelWithString: "Choose an accent color for UI elements like active tabs and sidebar highlights:")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 0
        descriptionLabel.preferredMaxLayoutWidth = 400
        stackView.addArrangedSubview(descriptionLabel)

        // Create color palette with preset colors
        let paletteContainer = NSView()
        paletteContainer.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(paletteContainer)

        let presetAccentColors: [(String, NSColor)] = [
            ("System Default", .controlAccentColor),
            ("Blue", NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)),
            ("Purple", NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0)),
            ("Pink", NSColor(red: 1.0, green: 0.18, blue: 0.33, alpha: 1.0)),
            ("Red", NSColor(red: 1.0, green: 0.27, blue: 0.23, alpha: 1.0)),
            ("Orange", NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)),
            ("Yellow", NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)),
            ("Green", NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)),
            ("Teal", NSColor(red: 0.19, green: 0.67, blue: 0.69, alpha: 1.0)),
            ("Gray", NSColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1.0))
        ]

        var xOffset: CGFloat = 0
        var yOffset: CGFloat = 0
        let buttonSize: CGFloat = 36
        let spacing: CGFloat = 8
        let buttonsPerRow = 5

        // Load currently selected accent color
        var currentAccentColor = NSColor.controlAccentColor
        if let colorData = UserDefaults.standard.data(forKey: UserDefaults.Keys.accentColor.rawValue),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            currentAccentColor = color
        }

        for (index, (name, color)) in presetAccentColors.enumerated() {
            let colorButton = NSButton()
            colorButton.translatesAutoresizingMaskIntoConstraints = false
            colorButton.bezelStyle = .regularSquare
            colorButton.isBordered = true
            colorButton.wantsLayer = true
            colorButton.layer?.backgroundColor = color.cgColor
            colorButton.layer?.cornerRadius = 4
            colorButton.title = ""
            colorButton.target = self
            colorButton.action = #selector(accentColorButtonClicked(_:))
            colorButton.tag = index
            colorButton.toolTip = name

            // Highlight selected color with prominent border
            if colorsAreEqual(color, currentAccentColor) {
                colorButton.layer?.borderWidth = 4
                colorButton.layer?.borderColor = NSColor.labelColor.cgColor
            } else {
                colorButton.layer?.borderWidth = 2
                colorButton.layer?.borderColor = NSColor.separatorColor.cgColor
            }

            paletteContainer.addSubview(colorButton)

            NSLayoutConstraint.activate([
                colorButton.widthAnchor.constraint(equalToConstant: buttonSize),
                colorButton.heightAnchor.constraint(equalToConstant: buttonSize),
                colorButton.leadingAnchor.constraint(equalTo: paletteContainer.leadingAnchor, constant: xOffset),
                colorButton.topAnchor.constraint(equalTo: paletteContainer.topAnchor, constant: yOffset)
            ])

            xOffset += buttonSize + spacing
            if (index + 1) % buttonsPerRow == 0 {
                xOffset = 0
                yOffset += buttonSize + spacing
            }
        }

        // Set palette container height
        let totalRows = CGFloat((presetAccentColors.count + buttonsPerRow - 1) / buttonsPerRow)
        NSLayoutConstraint.activate([
            paletteContainer.heightAnchor.constraint(equalToConstant: totalRows * (buttonSize + spacing) - spacing),
            paletteContainer.widthAnchor.constraint(equalToConstant: CGFloat(buttonsPerRow) * (buttonSize + spacing) - spacing)
        ])
    }

    @objc private func accentColorButtonClicked(_ sender: NSButton) {
        let presetAccentColors: [NSColor] = [
            .controlAccentColor,
            NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0),
            NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0),
            NSColor(red: 1.0, green: 0.18, blue: 0.33, alpha: 1.0),
            NSColor(red: 1.0, green: 0.27, blue: 0.23, alpha: 1.0),
            NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0),
            NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0),
            NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0),
            NSColor(red: 0.19, green: 0.67, blue: 0.69, alpha: 1.0),
            NSColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1.0)
        ]

        guard sender.tag < presetAccentColors.count else { return }
        let selectedColor = presetAccentColors[sender.tag]

        // Save the color to pending settings
        do {
            let colorData = try NSKeyedArchiver.archivedData(withRootObject: selectedColor, requiringSecureCoding: false)
            PendingSettings.shared.setValue(colorData, forKey: UserDefaults.Keys.accentColor.rawValue)

            // Update button borders to show selection
            if let paletteContainer = sender.superview {
                for view in paletteContainer.subviews {
                    if let button = view as? NSButton {
                        button.layer?.borderColor = NSColor.separatorColor.cgColor
                    }
                }
            }
            sender.layer?.borderColor = NSColor.selectedContentBackgroundColor.cgColor

            // Notify delegate that settings changed
            changeDelegate?.settingsDidChange()
        } catch {
            debugLog("Failed to archive accent color: \(error)")
        }
    }

    // MARK: - Default View & Sort Settings
    private func addDefaultViewAndSortSettings() {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacer)

        let header = NSTextField(labelWithString: "Defaults:")
        header.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(header)

        // Default View Mode
        let viewModeLabel = NSTextField(labelWithString: "Default View Mode:")
        viewModeLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(viewModeLabel)
        let viewPopup = AccentPopUpButton()
        viewPopup.translatesAutoresizingMaskIntoConstraints = false
        viewPopup.addItems(withTitles: ["List", "Icons", "Columns", "Windows List"])
        let storedViewMode = UserDefaults.standard.string(forKey: UserDefaults.Keys.defaultViewMode.rawValue) ?? "list"
        switch storedViewMode {
        case "icons": viewPopup.selectItem(withTitle: "Icons")
        case "columns": viewPopup.selectItem(withTitle: "Columns")
        case "windowsList": viewPopup.selectItem(withTitle: "Windows List")
        default: viewPopup.selectItem(withTitle: "List")
        }
        viewPopup.target = self
        viewPopup.action = #selector(defaultViewModeChanged(_:))
        stackView.addArrangedSubview(viewPopup)

        // Default Sort Column
        let sortLabel = NSTextField(labelWithString: "Default Sort Column:")
        sortLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(sortLabel)
        let sortPopup = AccentPopUpButton()
        sortPopup.translatesAutoresizingMaskIntoConstraints = false
        sortPopup.addItems(withTitles: ["Name", "Size", "Date Modified", "Date Created", "Type"])
        let storedSortCol = UserDefaults.standard.string(forKey: UserDefaults.Keys.defaultSortColumn.rawValue) ?? "NameColumn"
        switch storedSortCol {
        case "SizeColumn": sortPopup.selectItem(withTitle: "Size")
        case "DateModifiedColumn": sortPopup.selectItem(withTitle: "Date Modified")
        case "DateCreatedColumn": sortPopup.selectItem(withTitle: "Date Created")
        case "TypeColumn": sortPopup.selectItem(withTitle: "Type")
        default: sortPopup.selectItem(withTitle: "Name")
        }
        sortPopup.target = self
        sortPopup.action = #selector(defaultSortColumnChanged(_:))
        stackView.addArrangedSubview(sortPopup)

        // Default Sort Direction
        let ascendingCheckbox = AccentCheckbox(title: "Sort Ascending by Default", target: self, action: #selector(defaultSortAscendingChanged(_:)))
        if UserDefaults.standard.object(forKey: UserDefaults.Keys.defaultSortAscending.rawValue) == nil {
            UserDefaults.standard.set(true, forKey: UserDefaults.Keys.defaultSortAscending.rawValue)
        }
        ascendingCheckbox.state = UserDefaults.standard.bool(forKey: UserDefaults.Keys.defaultSortAscending.rawValue) ? .on : .off
        stackView.addArrangedSubview(ascendingCheckbox)
    }

    @objc private func defaultViewModeChanged(_ sender: NSPopUpButton) {
        let title = sender.titleOfSelectedItem ?? "List"
        let value: String
        switch title {
        case "Icons": value = "icons"
        case "Columns": value = "columns"
        case "Windows List": value = "windowsList"
        default: value = "list"
        }
        PendingSettings.shared.setValue(value, forKey: UserDefaults.Keys.defaultViewMode.rawValue)
    }

    @objc private func defaultSortColumnChanged(_ sender: NSPopUpButton) {
        let title = sender.titleOfSelectedItem ?? "Name"
        let column: String
        switch title {
        case "Size": column = "SizeColumn"
        case "Date Modified": column = "DateModifiedColumn"
        case "Date Created": column = "DateCreatedColumn"
        case "Type": column = "TypeColumn"
        default: column = "NameColumn"
        }
        PendingSettings.shared.setValue(column, forKey: UserDefaults.Keys.defaultSortColumn.rawValue)
    }

    @objc private func defaultSortAscendingChanged(_ sender: NSButton) {
        PendingSettings.shared.setValue(sender.state == .on, forKey: UserDefaults.Keys.defaultSortAscending.rawValue)
    }
}

