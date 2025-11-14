import Cocoa
import Foundation

extension UserDefaults {
    enum Keys: String, CaseIterable {
        // General Settings
        case warnOnExtensionChange = "warnOnExtensionChange"
        case globalFolderColor = "globalFolderColor"
        case enableEasySelect = "enableEasySelect"

        // Tabs Settings
        case restoreTabsOnReopen = "restoreTabsOnReopen"

        // Sidebar Settings
        case showFavorites = "showFavorites"
        case showRecents = "showRecents"
        case showLocations = "showLocations"
        case sidebarOrder = "sidebarOrder"

        // Terminal Settings
        case openTerminalByDefault = "openTerminalByDefault"

        // Context Menu Settings
        case showContextMenuHotkeys = "showContextMenuHotkeys"
        case hideOpenWith = "hideOpenWith"
        case hideGetInfo = "hideGetInfo"
        case hideCopy = "hideCopy"
        case hideCut = "hideCut"
        case hidePaste = "hidePaste"
        case hideRename = "hideRename"
        case hideMoveToTrash = "hideMoveToTrash"
        case hideNewFolder = "hideNewFolder"
        case hideChangeFolderColor = "hideChangeFolderColor"
        case hideShowInFinder = "hideShowInFinder"

        // Sidebar Settings
        case expandSidebarToCurrentDirectory = "expandSidebarToCurrentDirectory"

        // Status Bar Settings
        case showStatusBar = "showStatusBar"

        // File Operations Settings
        case autoRenameOnConflict = "autoRenameOnConflict"

        // Toolbar Settings
        case showBackForwardButtons = "showBackForwardButtons"
        case showViewModeButton = "showViewModeButton"
        case showHiddenFilesButton = "showHiddenFilesButton"
        case showSplitButtons = "showSplitButtons"
        case showNewFolderButton = "showNewFolderButton"
        case showSortButton = "showSortButton"

        static var allCases: [Keys] {
            return [.warnOnExtensionChange, .enableEasySelect, .restoreTabsOnReopen, .showFavorites, .showRecents, .showLocations, .sidebarOrder, .openTerminalByDefault, .showContextMenuHotkeys, .hideOpenWith, .hideGetInfo, .hideCopy, .hideCut, .hidePaste, .hideRename, .hideMoveToTrash, .hideNewFolder, .hideChangeFolderColor, .hideShowInFinder, .expandSidebarToCurrentDirectory, .showStatusBar, .autoRenameOnConflict, .showBackForwardButtons, .showViewModeButton, .showHiddenFilesButton, .showSplitButtons, .showNewFolderButton, .showSortButton]
        }
    }
}

// MARK: - Settings Sidebar Delegate

protocol SettingsSidebarDelegate: AnyObject {
    func settingsSidebarDidSelectSection(_ section: SettingsSection)
}

// MARK: - Settings Sections Enum

enum SettingsSection: String, CaseIterable {
    case general = "General"
    case tabs = "Tabs"
    case toolbar = "Toolbar"
    case terminal = "Terminal"
    case advanced = "Advanced"
    case sidebar = "Sidebar"
    case contextMenu = "Context Menu"
}

class SettingsViewController: NSSplitViewController, SettingsSidebarDelegate {

    private var currentContentViewController: NSViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        splitView.isVertical = true // Vertical divider for sidebar on left, content on right
        splitView.dividerStyle = .thin

        // Sidebar for navigation
        let sidebarVC = SettingsSidebarViewController()
        sidebarVC.delegate = self
        let sidebarItem = NSSplitViewItem(viewController: sidebarVC)
        sidebarItem.minimumThickness = 150
        sidebarItem.maximumThickness = 250
        sidebarItem.canCollapse = false
        addSplitViewItem(sidebarItem)

        // Initial content area (General settings)
        let initialContentVC = GeneralSettingsViewController()
        let contentItem = NSSplitViewItem(viewController: initialContentVC)
        contentItem.minimumThickness = 400
        addSplitViewItem(contentItem)
        currentContentViewController = initialContentVC
    }

    // MARK: - SettingsSidebarDelegate

    func settingsSidebarDidSelectSection(_ section: SettingsSection) {
        // Get the content split view item (second item)
        guard splitViewItems.count > 1 else { return }

        // Create new content view controller based on section
        let newContentVC: NSViewController
        switch section {
        case .general:
            newContentVC = GeneralSettingsViewController()
        case .tabs:
            newContentVC = TabsSettingsViewController()
        case .toolbar:
            newContentVC = ToolbarSettingsViewController()
        case .terminal:
            newContentVC = TerminalSettingsViewController()
        case .advanced:
            newContentVC = AdvancedSettingsViewController()
        case .sidebar:
            newContentVC = SidebarSettingsViewController()
        case .contextMenu:
            newContentVC = ContextMenuSettingsViewController()
        }

        // Remove the old content item
        let oldContentItem = splitViewItems[1]
        removeSplitViewItem(oldContentItem)
        
        // Add new content item
        let newContentItem = NSSplitViewItem(viewController: newContentVC)
        newContentItem.minimumThickness = 400
        addSplitViewItem(newContentItem)
        
        currentContentViewController = newContentVC
    }
}

// MARK: - Placeholder Settings View Controllers

class GeneralSettingsViewController: NSViewController {

    private var stackView: NSStackView!
    private var globalFolderColorWell: NSColorWell!

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
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        addFileExtensionSettings()
        addSelectionSettings()
        addFileOperationsSettings()
        addFolderAppearanceSettings()
    }

    private func addFileExtensionSettings() {
        let titleLabel = NSTextField(labelWithString: "File Extensions:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(titleLabel)

        addCheckbox(title: "Warn on extension change", key: .warnOnExtensionChange, defaultValue: true)
        
        // Add description
        let descriptionLabel = NSTextField(labelWithString: "Display a warning when changing a file's extension")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
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
        stackView.addArrangedSubview(descriptionLabel)
    }

    private func addFileOperationsSettings() {
        // Add spacing
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacer)

        let titleLabel = NSTextField(labelWithString: "File Operations:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(titleLabel)

        addCheckbox(title: "Auto-rename on file conflict", key: .autoRenameOnConflict, defaultValue: false)

        // Add description
        let descriptionLabel = NSTextField(labelWithString: "Automatically rename files when copying/moving to a location with an existing file of the same name")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
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
            colorButton.layer?.borderWidth = 2
            colorButton.title = ""
            colorButton.target = self
            colorButton.action = #selector(colorButtonClicked(_:))
            colorButton.tag = index
            colorButton.toolTip = name

            // Highlight selected color
            if colorsAreEqual(color, currentColor) {
                colorButton.layer?.borderColor = NSColor.selectedContentBackgroundColor.cgColor
            } else {
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

        // Save the color
        do {
            let colorData = try NSKeyedArchiver.archivedData(withRootObject: selectedColor, requiringSecureCoding: false)
            UserDefaults.standard.set(colorData, forKey: UserDefaults.Keys.globalFolderColor.rawValue)
            NotificationCenter.default.post(name: .globalFolderColorDidChangeNotification, object: nil)

            // Update button borders to show selection
            if let paletteContainer = sender.superview {
                for view in paletteContainer.subviews {
                    if let button = view as? NSButton {
                        button.layer?.borderColor = NSColor.separatorColor.cgColor
                    }
                }
            }
            sender.layer?.borderColor = NSColor.selectedContentBackgroundColor.cgColor
        } catch {
            print("Failed to archive color: \(error)")
        }
    }

    private func addCheckbox(title: String, key: UserDefaults.Keys, defaultValue: Bool = false) {
        let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(checkboxChanged(_:)))
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
        if let keyRawValue = UserDefaults.Keys.allCases.first(where: { $0.rawValue.hashValue == sender.tag })?.rawValue {
            UserDefaults.standard.set(sender.state == .on, forKey: keyRawValue)
        }
    }
    
    @objc private func globalFolderColorChanged(_ sender: NSColorWell) {
        do {
            let colorData = try NSKeyedArchiver.archivedData(withRootObject: sender.color, requiringSecureCoding: false)
            UserDefaults.standard.set(colorData, forKey: UserDefaults.Keys.globalFolderColor.rawValue)
            NotificationCenter.default.post(name: .globalFolderColorDidChangeNotification, object: nil)
        } catch {
            print("Failed to archive color: \(error)")
        }
    }
}

extension Notification.Name {
    static let globalFolderColorDidChangeNotification = Notification.Name("globalFolderColorDidChangeNotification")
}

class TabsSettingsViewController: NSViewController {

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
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        addTabsSettings()
    }

    private func addTabsSettings() {
        let titleLabel = NSTextField(labelWithString: "Tabs:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(titleLabel)

        addCheckbox(title: "Restore tabs on reopen", key: .restoreTabsOnReopen, defaultValue: true)
        
        // Add description
        let descriptionLabel = NSTextField(labelWithString: "Automatically restore all open tabs when reopening the application")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descriptionLabel)
    }

    private func addCheckbox(title: String, key: UserDefaults.Keys, defaultValue: Bool = false) {
        let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(checkboxChanged(_:)))
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
            UserDefaults.standard.set(sender.state == .on, forKey: keyRawValue)
        }
    }
}

class TerminalSettingsViewController: NSViewController {

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
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        addTerminalSettings()
    }

    private func addTerminalSettings() {
        let titleLabel = NSTextField(labelWithString: "Terminal:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(titleLabel)

        addCheckbox(title: "Open by default", key: .openTerminalByDefault)
        
        // Add description
        let descriptionLabel = NSTextField(labelWithString: "Show the terminal panel by default when opening windows")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descriptionLabel)
    }

    private func addCheckbox(title: String, key: UserDefaults.Keys, defaultValue: Bool = false) {
        let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(checkboxChanged(_:)))
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
            UserDefaults.standard.set(sender.state == .on, forKey: keyRawValue)
        }
    }
}

class AdvancedSettingsViewController: NSViewController {

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
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
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
        let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(checkboxChanged(_:)))
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
            UserDefaults.standard.set(sender.state == .on, forKey: keyRawValue)
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

class SidebarSettingsViewController: NSViewController {

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
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        addSidebarSettings()
    }

    private func addSidebarSettings() {
        let folderExplorerTitle = NSTextField(labelWithString: "Folder Explorer:")
        folderExplorerTitle.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(folderExplorerTitle)

        addCheckbox(title: "Expand to current directory by default", key: .expandSidebarToCurrentDirectory, defaultValue: false)
        
        let descriptionLabel = NSTextField(labelWithString: "Automatically expand the folder explorer to the currently active directory.")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descriptionLabel)

        let visibilityTitle = NSTextField(labelWithString: "Visibility:")
        visibilityTitle.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(visibilityTitle)

        addCheckbox(title: "Show Favorites", key: .showFavorites, defaultValue: true)
        addCheckbox(title: "Show Recents", key: .showRecents, defaultValue: true)
        addCheckbox(title: "Show Locations", key: .showLocations, defaultValue: true)

        let orderTitle = NSTextField(labelWithString: "Order:")
        orderTitle.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(orderTitle)

        let segmentedControl = NSSegmentedControl(labels: ["Favorites, Recents, Locations", "Locations, Favorites, Recents"], trackingMode: .selectOne, target: self, action: #selector(sidebarOrderChanged(_:)))
        segmentedControl.selectedSegment = UserDefaults.standard.integer(forKey: UserDefaults.Keys.sidebarOrder.rawValue)
        stackView.addArrangedSubview(segmentedControl)
    }

    private func addCheckbox(title: String, key: UserDefaults.Keys, defaultValue: Bool = false) {
        let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(checkboxChanged(_:)))
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
            UserDefaults.standard.set(sender.state == .on, forKey: keyRawValue)
        }
    }

    @objc func sidebarOrderChanged(_ sender: NSSegmentedControl) {
        UserDefaults.standard.set(sender.selectedSegment, forKey: UserDefaults.Keys.sidebarOrder.rawValue)
    }
}

class ContextMenuSettingsViewController: NSViewController {

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
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

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
        addCheckbox(title: "Hide 'Change Folder Color...'", key: .hideChangeFolderColor)
        addCheckbox(title: "Hide 'Show in Finder'", key: .hideShowInFinder)
    }

    private func addCheckbox(title: String, key: UserDefaults.Keys, defaultValue: Bool = false) {
        let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(checkboxChanged(_:)))
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
            UserDefaults.standard.set(sender.state == .on, forKey: keyRawValue)
        }
    }
}

class ToolbarSettingsViewController: NSViewController {

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
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        addToolbarSettings()
    }

    private func addToolbarSettings() {
        let titleLabel = NSTextField(labelWithString: "Toolbar:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(titleLabel)

        let descriptionLabel = NSTextField(labelWithString: "Customize which buttons appear in the toolbar:")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descriptionLabel)

        // Add spacing
        let spacer1 = NSView()
        spacer1.translatesAutoresizingMaskIntoConstraints = false
        spacer1.heightAnchor.constraint(equalToConstant: 10).isActive = true
        stackView.addArrangedSubview(spacer1)

        addCheckbox(title: "Show Back/Forward navigation buttons", key: .showBackForwardButtons, defaultValue: true)
        addCheckbox(title: "Show View Mode button", key: .showViewModeButton, defaultValue: true)
        addCheckbox(title: "Show Hidden Files toggle button", key: .showHiddenFilesButton, defaultValue: true)
        addCheckbox(title: "Show Split Pane buttons", key: .showSplitButtons, defaultValue: true)
        addCheckbox(title: "Show New Folder button", key: .showNewFolderButton, defaultValue: true)
        addCheckbox(title: "Show Sort button", key: .showSortButton, defaultValue: true)

        // Add spacing
        let spacer2 = NSView()
        spacer2.translatesAutoresizingMaskIntoConstraints = false
        spacer2.heightAnchor.constraint(equalToConstant: 10).isActive = true
        stackView.addArrangedSubview(spacer2)

        let noteLabel = NSTextField(labelWithString: "Note: Changes will take effect after restarting the application or opening a new window.")
        noteLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.maximumNumberOfLines = 0
        noteLabel.preferredMaxLayoutWidth = 400
        stackView.addArrangedSubview(noteLabel)
    }

    private func addCheckbox(title: String, key: UserDefaults.Keys, defaultValue: Bool = false) {
        let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(checkboxChanged(_:)))
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
            UserDefaults.standard.set(sender.state == .on, forKey: keyRawValue)
            // Post notification to update toolbar
            NotificationCenter.default.post(name: .toolbarSettingsDidChangeNotification, object: nil)
        }
    }
}

extension Notification.Name {
    static let toolbarSettingsDidChangeNotification = Notification.Name("toolbarSettingsDidChangeNotification")
}