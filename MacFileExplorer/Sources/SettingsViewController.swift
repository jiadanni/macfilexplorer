import Cocoa
import Foundation

extension UserDefaults {
    enum Keys: String, CaseIterable {
        // General Settings
        case warnOnExtensionChange = "warnOnExtensionChange"
        case globalFolderColor = "globalFolderColor"

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

        static var allCases: [Keys] {
            return [.warnOnExtensionChange, .restoreTabsOnReopen, .showFavorites, .showRecents, .showLocations, .sidebarOrder, .openTerminalByDefault, .showContextMenuHotkeys, .hideOpenWith, .hideGetInfo, .hideCopy, .hideCut, .hidePaste, .hideRename, .hideMoveToTrash, .hideNewFolder, .hideChangeFolderColor, .hideShowInFinder, .expandSidebarToCurrentDirectory, .showStatusBar]
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
        let contentItem = splitViewItems[1]

        // Create new content view controller based on section
        let newContentVC: NSViewController
        switch section {
        case .general:
            newContentVC = GeneralSettingsViewController()
        case .tabs:
            newContentVC = TabsSettingsViewController()
        case .terminal:
            newContentVC = TerminalSettingsViewController()
        case .advanced:
            newContentVC = AdvancedSettingsViewController()
        case .sidebar:
            newContentVC = SidebarSettingsViewController()
        case .contextMenu:
            newContentVC = ContextMenuSettingsViewController()
        }

        // Replace the view controller in the content item
        contentItem.viewController = newContentVC
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
    
    private func addFolderAppearanceSettings() {
        // Add spacing
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacer)
        
        let titleLabel = NSTextField(labelWithString: "Folder Appearance:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(titleLabel)
        
        let colorStackView = NSStackView()
        colorStackView.orientation = .horizontal
        colorStackView.alignment = .centerY
        colorStackView.spacing = 8
        stackView.addArrangedSubview(colorStackView)
        
        let colorLabel = NSTextField(labelWithString: "Global Folder Color:")
        colorStackView.addArrangedSubview(colorLabel)
        
        globalFolderColorWell = NSColorWell()
        globalFolderColorWell.translatesAutoresizingMaskIntoConstraints = false
        globalFolderColorWell.action = #selector(globalFolderColorChanged(_:))
        globalFolderColorWell.target = self
        colorStackView.addArrangedSubview(globalFolderColorWell)
        
        // Load saved color or default
        if let colorData = UserDefaults.standard.data(forKey: UserDefaults.Keys.globalFolderColor.rawValue),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            globalFolderColorWell.color = color
        } else {
            globalFolderColorWell.color = .controlAccentColor // Default color
        }
        
        let descriptionLabel = NSTextField(labelWithString: "Sets a global accent color for all folder icons.")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descriptionLabel)
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