import Cocoa

final class AppearanceSettingsViewController: NSViewController {

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

        addFolderAppearanceSettings()
        addWindowAppearanceSettings()
        // Custom accent color settings removed for consistency with macOS.
        // addAccentColorSettings() // intentionally disabled
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // Scroll to top when view appears
        if let scrollView = view as? NSScrollView {
            scrollView.contentView.scroll(to: NSPoint.zero)
        }
    }

    private func addFolderAppearanceSettings() {
        // Folder color feature is currently disabled because it does not work reliably
        // across all macOS environments (see issue tracker). Hide the UI to avoid
        // confusing users. The underlying ColorManager is a no-op.
        let titleLabel = NSTextField(labelWithString: "Folder Color: (disabled)")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 2)
        stackView.addArrangedSubview(titleLabel)

        let descriptionLabel = NSTextField(labelWithString: "Folder color customization is disabled in Appearance Settings.\nConsider using custom icon sets instead.")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 0
        descriptionLabel.preferredMaxLayoutWidth = 450
        stackView.addArrangedSubview(descriptionLabel)
    }

    private func addWindowAppearanceSettings() {
        // Grayscale icons option
        let spacer2 = NSView()
        spacer2.translatesAutoresizingMaskIntoConstraints = false
        spacer2.heightAnchor.constraint(equalToConstant: 12).isActive = true
        stackView.addArrangedSubview(spacer2)

        let grayscaleCheckbox = AccentCheckbox(title: "Use grayscale icons", target: self, action: #selector(grayscaleCheckboxChanged(_:)))
        grayscaleCheckbox.translatesAutoresizingMaskIntoConstraints = false
        let settings = SettingsStore.shared
        grayscaleCheckbox.state = settings.useGrayscaleIcons ? .on : .off
        stackView.addArrangedSubview(grayscaleCheckbox)

        // Window traffic lights appearance option
        let windowControlsCheckbox = AccentCheckbox(title: "Use grayscale window controls (traffic lights)", target: self, action: #selector(grayscaleWindowControlsChanged(_:)))
        windowControlsCheckbox.translatesAutoresizingMaskIntoConstraints = false
        let useGrayWindowControls = settings.useGrayscaleWindowControls
        windowControlsCheckbox.state = useGrayWindowControls ? NSControl.StateValue.on : NSControl.StateValue.off
        stackView.addArrangedSubview(windowControlsCheckbox)
    }

    private func addAccentColorSettings() {
        // Add spacing
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stackView.addArrangedSubview(spacer)

        let titleLabel = NSTextField(labelWithString: "Accent Color:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 2)
        stackView.addArrangedSubview(titleLabel)

        let descriptionLabel = NSTextField(labelWithString: "Choose an accent color for UI elements like active tabs and sidebar highlights:")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 0
        descriptionLabel.preferredMaxLayoutWidth = 450
        stackView.addArrangedSubview(descriptionLabel)

        // Add note about system controls
        let noteLabel = NSTextField(labelWithString: "Note: Checkboxes and dropdown arrows use your system's accent color from macOS Settings → Appearance.")
        noteLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize - 1)
        noteLabel.textColor = .tertiaryLabelColor
        noteLabel.lineBreakMode = .byWordWrapping
        noteLabel.maximumNumberOfLines = 0
        noteLabel.preferredMaxLayoutWidth = 450
        stackView.addArrangedSubview(noteLabel)

        // Add spacing
        let spacer1 = NSView()
        spacer1.translatesAutoresizingMaskIntoConstraints = false
        spacer1.heightAnchor.constraint(equalToConstant: 10).isActive = true
        stackView.addArrangedSubview(spacer1)

        // Create accent color palette
        createColorPalette(forAccent: true)
    }

    @objc private func grayscaleWindowControlsChanged(_ sender: NSButton) {
        PendingSettings.shared.setValue(sender.state == NSControl.StateValue.on, forKey: UserDefaults.Keys.useGrayscaleWindowControls.rawValue)
        changeDelegate?.settingsDidChange()
    }

    @objc private func grayscaleCheckboxChanged(_ sender: NSButton) {
        PendingSettings.shared.setValue(sender.state == .on, forKey: UserDefaults.Keys.useGrayscaleIcons.rawValue)
        changeDelegate?.settingsDidChange()
    }

    private func createColorPalette(forAccent: Bool) {
        // If asked to create accent palette, skip — we rely on system accent color.
        if forAccent {
            return
        }
        let paletteContainer = NSView()
        paletteContainer.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(paletteContainer)

        let presetColors: [(String, NSColor)] = forAccent ? [
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
        ] : [
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
        let buttonSize: CGFloat = 40
        let spacing: CGFloat = 10
        let buttonsPerRow = 5

        // Load currently selected color
        var currentColor = NSColor.controlAccentColor
        if let colorData = SettingsStore.shared.globalFolderColor,
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
            colorButton.layer?.cornerRadius = 6
            colorButton.title = ""
            colorButton.target = self
            colorButton.action = forAccent ? #selector(accentColorButtonClicked(_:)) : #selector(folderColorButtonClicked(_:))
            colorButton.tag = index
            colorButton.toolTip = name

            // Highlight selected color with prominent border
            if colorsAreEqual(color, currentColor) {
                colorButton.layer?.borderWidth = 4
                if forAccent {
                    colorButton.layer?.borderColor = NSColor.labelColor.cgColor
                } else {
                    colorButton.layer?.borderColor = NSColor.customAccentColor.cgColor
                }
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

    @objc private func folderColorButtonClicked(_ sender: NSButton) {
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

        guard let selectedColor = presetColors.safe(at: sender.tag) else { return }

        do {
            let colorData = try NSKeyedArchiver.archivedData(withRootObject: selectedColor, requiringSecureCoding: false)
            PendingSettings.shared.setValue(colorData, forKey: UserDefaults.Keys.globalFolderColor.rawValue)

            // Update button borders
            if let paletteContainer = sender.superview {
                for view in paletteContainer.subviews {
                    if let button = view as? NSButton {
                        button.layer?.borderWidth = 2
                        button.layer?.borderColor = NSColor.separatorColor.cgColor
                    }
                }
            }
            sender.layer?.borderWidth = 4
            sender.layer?.borderColor = NSColor.customAccentColor.cgColor

            // Notify delegate that settings changed
            changeDelegate?.settingsDidChange()
        } catch {
            debugLog("Failed to save folder color: \(error)")
        }
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

        guard let selectedColor = presetAccentColors.safe(at: sender.tag) else { return }

        do {
            let colorData = try NSKeyedArchiver.archivedData(withRootObject: selectedColor, requiringSecureCoding: false)
            PendingSettings.shared.setValue(colorData, forKey: UserDefaults.Keys.accentColor.rawValue)

            // Update button borders
            if let paletteContainer = sender.superview {
                for view in paletteContainer.subviews {
                    if let button = view as? NSButton {
                        button.layer?.borderWidth = 2
                        button.layer?.borderColor = NSColor.separatorColor.cgColor
                    }
                }
            }
            sender.layer?.borderWidth = 4
            sender.layer?.borderColor = NSColor.labelColor.cgColor

            // Notify delegate that settings changed
            changeDelegate?.settingsDidChange()
        } catch {
            debugLog("Failed to save accent color: \(error)")
        }
    }
}
