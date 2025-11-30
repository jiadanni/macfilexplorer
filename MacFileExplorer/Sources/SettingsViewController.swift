import Cocoa
import Foundation

// Use AccentColorControls.swift for custom checkbox and popup controls
extension UserDefaults {
    enum Keys: String, CaseIterable {
        // General Settings
        case warnOnExtensionChange = "warnOnExtensionChange"
        case showFileExtensions = "showFileExtensions"
        case globalFolderColor = "globalFolderColor"
        case accentColor = "accentColor"
        case enableEasySelect = "enableEasySelect"
        case startupFolder = "startupFolder"

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
        case hideShowInFinder = "hideShowInFinder"

        // Sidebar Settings
        case expandSidebarToCurrentDirectory = "expandSidebarToCurrentDirectory"

        // Status Bar Settings
        case showStatusBar = "showStatusBar"

        // Preview Pane Settings
        case showPreviewPane = "showPreviewPane"
        case previewPanePosition = "previewPanePosition" // "right" or "bottom"
        case previewPaneWidth = "previewPaneWidth" // Stored width (CGFloat)
        // Icon appearance
        case useGrayscaleIcons = "useGrayscaleIcons"
        // Window traffic light appearance (grayscale when true)
        case useGrayscaleWindowControls = "useGrayscaleWindowControls"
        // Granted Directory Permissions (user-approved folder access list)
        case grantedDirectoriesPaths = "grantedDirectoriesPaths" // [String] of absolute paths
        case grantedDirectoryBookmarks = "grantedDirectoryBookmarks" // [Data] security-scoped bookmarks
        case grantedDirectoryBookmarksMigrated = "grantedDirectoryBookmarksMigrated" // Bool migration flag

        // File Operations Settings
        case autoRenameOnConflict = "autoRenameOnConflict"
        case deleteWithBackspaceOnly = "deleteWithBackspaceOnly"
        case confirmFileOperations = "confirmFileOperations" // Show confirmation dialogs for copy/move/paste/delete
        case showOperationProgress = "showOperationProgress" // Show progress sheets for operations

        // Toolbar Settings
        case showBackForwardButtons = "showBackForwardButtons"
        case showViewModeButton = "showViewModeButton"
        case showHiddenFilesButton = "showHiddenFilesButton"
        case showSplitButtons = "showSplitButtons"
        case showPreviewPaneButton = "showPreviewPaneButton"
        case showNewFolderButton = "showNewFolderButton"
        case showSortButton = "showSortButton"
        case showOpenTerminalButton = "showOpenTerminalButton"

        // Column Visibility (List View)
        case columnVisibility = "columnVisibility" // Dictionary: ColumnIdentifier -> Bool (visible)
        
        // Settings Placement
        case openSettingsInTab = "openSettingsInTab" // Bool: open preferences in a tab instead of window

        // Sorting Preferences
        case folderSortPreferences = "folderSortPreferences" // Dictionary path -> "Column|asc|desc"
        // Hidden Files State
        case hiddenFilesState = "hiddenFilesState"
        // Default View & Sort
        case defaultViewMode = "defaultViewMode"            // list|icons|columns|windowsList
        case defaultSortColumn = "defaultSortColumn"        // NameColumn, SizeColumn, etc.
        case defaultSortAscending = "defaultSortAscending"  // Bool

        // Split Panes Settings
        case maximumPanes = "maximumPanes"                  // Int, default 2, max 8

        // List View Settings
        case showFolderSizes = "showFolderSizes"            // Bool - calculate and display folder sizes (performance impact)

        // Go Menu Settings
        case showGoHome = "showGoHome"                      // Bool, default true
        case showGoDesktop = "showGoDesktop"                // Bool, default false
        case showGoDocuments = "showGoDocuments"            // Bool, default false
        case showGoDownloads = "showGoDownloads"            // Bool, default true
        case showGoApplications = "showGoApplications"      // Bool, default false
        case showGoUtilities = "showGoUtilities"            // Bool, default false
        case showGoLibrary = "showGoLibrary"                // Bool, default false
        case showGoComputer = "showGoComputer"              // Bool, default false
        case showGoAirDrop = "showGoAirDrop"                // Bool, default false
        case showGoNetwork = "showGoNetwork"                // Bool, default false
        case showGoiCloudDrive = "showGoiCloudDrive"        // Bool, default false
        case showGoRecent = "showGoRecent"                  // Bool, default false
        case showGoConnectToServer = "showGoConnectToServer" // Bool, default false

        // Start Page Settings
        case hasLaunchedBefore = "hasLaunchedBefore"       // Bool - tracks first launch
        case hasCompletedOnboarding = "hasCompletedOnboarding" // Bool - onboarding complete
        case showStartOnLaunch = "showStartOnLaunch"       // Bool - show Start tab on launch
        case dismissedWelcome = "dismissedWelcome"         // Bool - user dismissed welcome widget

        static var allCases: [Keys] {
            return [.warnOnExtensionChange, .enableEasySelect, .restoreTabsOnReopen, .showFavorites, .showRecents, .showLocations, .sidebarOrder, .openTerminalByDefault, .showContextMenuHotkeys, .hideOpenWith, .hideGetInfo, .hideCopy, .hideCut, .hidePaste, .hideRename, .hideMoveToTrash, .hideNewFolder, .hideShowInFinder, .expandSidebarToCurrentDirectory, .showStatusBar, .autoRenameOnConflict, .deleteWithBackspaceOnly, .confirmFileOperations, .showOperationProgress, .showBackForwardButtons, .showViewModeButton, .showHiddenFilesButton, .showSplitButtons, .showPreviewPaneButton, .showNewFolderButton, .showSortButton, .showOpenTerminalButton, .columnVisibility, .openSettingsInTab, .folderSortPreferences, .hiddenFilesState, .defaultViewMode, .defaultSortColumn, .defaultSortAscending, .maximumPanes, .showFolderSizes, .showGoHome, .showGoDesktop, .showGoDocuments, .showGoDownloads, .showGoApplications, .showGoUtilities, .showGoLibrary, .showGoComputer, .showGoAirDrop, .showGoNetwork, .showGoiCloudDrive, .showGoRecent, .showGoConnectToServer, .previewPaneWidth, .grantedDirectoriesPaths, .grantedDirectoryBookmarks, .grantedDirectoryBookmarksMigrated, .hasLaunchedBefore, .hasCompletedOnboarding, .showStartOnLaunch, .dismissedWelcome]
        }
    }
}

// MARK: - Settings Sidebar Delegate

protocol SettingsSidebarDelegate: AnyObject {
    func settingsSidebarDidSelectSection(_ section: SettingsSection)
}

// MARK: - Pending Settings Storage

class PendingSettings {
    static let shared = PendingSettings()
    private var pendingChanges: [String: Any] = [:]
    
    private init() {}
    
    func setValue(_ value: Any?, forKey key: String) {
        pendingChanges[key] = value
        // Notify listeners that pending settings have changed so UI (Apply button) can enable
        NotificationCenter.default.post(name: .pendingSettingsDidChange, object: nil)
    }
    
    func getValue(forKey key: String) -> Any? {
        return pendingChanges[key]
    }
    
    func bool(forKey key: String) -> Bool {
        if let pending = pendingChanges[key] as? Bool {
            return pending
        }
        return UserDefaults.standard.bool(forKey: key)
    }
    
    func string(forKey key: String) -> String? {
        if let pending = pendingChanges[key] as? String {
            return pending
        }
        return UserDefaults.standard.string(forKey: key)
    }
    
    func applyChanges() {
        let changedKeys = Set(pendingChanges.keys)
        
        for (key, value) in pendingChanges {
            UserDefaults.standard.set(value, forKey: key)
        }
        pendingChanges.removeAll()
        
        // Post notifications for settings that need immediate UI updates
        if changedKeys.contains(UserDefaults.Keys.showFileExtensions.rawValue) {
            NotificationCenter.default.post(name: .showFileExtensionsDidChangeNotification, object: nil)
        }
        if changedKeys.contains(UserDefaults.Keys.enableEasySelect.rawValue) {
            NotificationCenter.default.post(name: .easySelectDidChangeNotification, object: nil)
        }
        if changedKeys.contains(UserDefaults.Keys.accentColor.rawValue) {
            NotificationCenter.default.post(name: .accentColorDidChangeNotification, object: nil)
        }
        if changedKeys.contains(UserDefaults.Keys.useGrayscaleWindowControls.rawValue) {
            NotificationCenter.default.post(name: .didChangeWindowControlAppearance, object: nil)
        }
        if changedKeys.contains(UserDefaults.Keys.globalFolderColor.rawValue) {
            NotificationCenter.default.post(name: .globalFolderColorDidChangeNotification, object: nil)
        }
        if changedKeys.intersection([
            UserDefaults.Keys.showBackForwardButtons.rawValue,
            UserDefaults.Keys.showViewModeButton.rawValue,
            UserDefaults.Keys.showHiddenFilesButton.rawValue,
            UserDefaults.Keys.showSplitButtons.rawValue,
            UserDefaults.Keys.showPreviewPaneButton.rawValue,
            UserDefaults.Keys.showNewFolderButton.rawValue,
            UserDefaults.Keys.showSortButton.rawValue
        ]).isEmpty == false {
            NotificationCenter.default.post(name: .toolbarSettingsDidChangeNotification, object: nil)
        }
    }
    
    func cancelChanges() {
        pendingChanges.removeAll()
    }
    
    func hasChanges() -> Bool {
        return !pendingChanges.isEmpty
    }
}

// MARK: - Settings Change Delegate

protocol SettingsChangeDelegate: AnyObject {
    func settingsDidChange()
}

protocol SettingsApplyable: AnyObject {
    func applyChanges()
    func cancelChanges()
}

// MARK: - Settings Sections Enum

enum SettingsSection: String, CaseIterable {
    case general = "General"
    case appearance = "Appearance"
    case tabs = "Tabs"
    case toolbar = "Toolbar"
    case storage = "Storage"
    case fileOperations = "File Operations"
    case goMenu = "Go Menu"
    case terminal = "Terminal"
    case permissions = "Permissions"
    case advanced = "Advanced"
    case sidebar = "Sidebar"
    case contextMenu = "Context Menu"
}

class SettingsViewController: NSSplitViewController, SettingsSidebarDelegate {

    private var currentContentViewController: NSViewController?
    weak var changeDelegate: SettingsChangeDelegate?

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
        initialContentVC.changeDelegate = changeDelegate
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
            let vc = GeneralSettingsViewController()
            vc.changeDelegate = changeDelegate
            newContentVC = vc
        case .appearance:
            let vc = AppearanceSettingsViewController()
            vc.changeDelegate = changeDelegate
            newContentVC = vc
        case .tabs:
            newContentVC = TabsSettingsViewController()
        case .toolbar:
            newContentVC = ToolbarSettingsViewController()
        case .storage:
            newContentVC = StorageSettingsViewController()
        case .fileOperations:
            newContentVC = FileOperationsSettingsViewController()
        case .goMenu:
            newContentVC = GoMenuSettingsViewController()
        case .terminal:
            newContentVC = TerminalSettingsViewController()
        case .permissions:
            newContentVC = PermissionsSettingsViewController()
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
    
    // MARK: - Settings Application
    
    func applyChanges() {
        PendingSettings.shared.applyChanges()
    }
    
    func cancelChanges() {
        PendingSettings.shared.cancelChanges()
        // Reload the current view controller to reset UI
        if let currentVC = currentContentViewController {
            let section: SettingsSection
            switch currentVC {
            case is GeneralSettingsViewController:
                section = .general
            case is AppearanceSettingsViewController:
                section = .appearance
            case is TabsSettingsViewController:
                section = .tabs
            case is ToolbarSettingsViewController:
                section = .toolbar
            case is StorageSettingsViewController:
                section = .storage
            case is FileOperationsSettingsViewController:
                section = .fileOperations
            case is GoMenuSettingsViewController:
                section = .goMenu
            case is TerminalSettingsViewController:
                section = .terminal
            case is PermissionsSettingsViewController:
                section = .permissions
            case is AdvancedSettingsViewController:
                section = .advanced
            case is SidebarSettingsViewController:
                section = .sidebar
            case is ContextMenuSettingsViewController:
                section = .contextMenu
            default:
                return
            }
            settingsSidebarDidSelectSection(section)
        }
    }
}

// MARK: - Placeholder Settings View Controllers

class GeneralSettingsViewController: NSViewController {

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

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
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
            print("Failed to archive color: \(error)")
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
            print("Failed to archive accent color: \(error)")
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

// NOTE: Custom accent color functionality removed in favor of system accent color.
// Keep this helper for backward compatibility but return the system accent color.
extension NSColor {
    static var customAccentColor: NSColor {
        return .controlAccentColor
    }
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
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20)
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
}

class AppearanceSettingsViewController: NSViewController {

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
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
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
        let useGray = UserDefaults.standard.object(forKey: UserDefaults.Keys.useGrayscaleIcons.rawValue) as? Bool ?? false
        grayscaleCheckbox.state = useGray ? .on : .off
        // Ensure default exists
        if UserDefaults.standard.object(forKey: UserDefaults.Keys.useGrayscaleIcons.rawValue) == nil {
            UserDefaults.standard.set(false, forKey: UserDefaults.Keys.useGrayscaleIcons.rawValue)
        }
        stackView.addArrangedSubview(grayscaleCheckbox)

        // Window traffic lights appearance option
        let windowControlsCheckbox = AccentCheckbox(title: "Use grayscale window controls (traffic lights)", target: self, action: #selector(grayscaleWindowControlsChanged(_:)))
        windowControlsCheckbox.translatesAutoresizingMaskIntoConstraints = false
        let useGrayWindowControls = UserDefaults.standard.object(forKey: UserDefaults.Keys.useGrayscaleWindowControls.rawValue) as? Bool ?? false
        windowControlsCheckbox.state = useGrayWindowControls ? NSControl.StateValue.on : NSControl.StateValue.off
        if UserDefaults.standard.object(forKey: UserDefaults.Keys.useGrayscaleWindowControls.rawValue) == nil {
            UserDefaults.standard.set(false, forKey: UserDefaults.Keys.useGrayscaleWindowControls.rawValue)
        }
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
        let settingsKey = forAccent ? UserDefaults.Keys.accentColor.rawValue : UserDefaults.Keys.globalFolderColor.rawValue
        var currentColor = NSColor.controlAccentColor
        if let colorData = UserDefaults.standard.data(forKey: settingsKey),
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

        guard sender.tag < presetColors.count else { return }
        let selectedColor = presetColors[sender.tag]

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
            print("Failed to save folder color: \(error)")
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

        guard sender.tag < presetAccentColors.count else { return }
        let selectedColor = presetAccentColors[sender.tag]

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
            print("Failed to save accent color: \(error)")
        }
    }
}

class FileOperationsSettingsViewController: NSViewController {

    private var stackView: NSStackView!

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
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])

        addFileOperationsSettings()
    }

    private func addFileOperationsSettings() {
        let titleLabel = NSTextField(labelWithString: "File Operations:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 2)
        stackView.addArrangedSubview(titleLabel)

        // Auto-rename setting
        addCheckbox(title: "Auto-rename on file conflict", key: .autoRenameOnConflict, defaultValue: false)

        let autoRenameDesc = NSTextField(labelWithString: "Automatically rename files when copying/moving to a location with an existing file of the same name")
        autoRenameDesc.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        autoRenameDesc.textColor = .secondaryLabelColor
        autoRenameDesc.lineBreakMode = .byWordWrapping
        autoRenameDesc.maximumNumberOfLines = 0
        autoRenameDesc.preferredMaxLayoutWidth = 450
        stackView.addArrangedSubview(autoRenameDesc)

        // Add spacing
        let spacer1 = NSView()
        spacer1.translatesAutoresizingMaskIntoConstraints = false
        spacer1.heightAnchor.constraint(equalToConstant: 15).isActive = true
        stackView.addArrangedSubview(spacer1)

        // Delete key setting
        addCheckbox(title: "Delete files with Backspace key only (disable Command+Delete)", key: .deleteWithBackspaceOnly, defaultValue: false)

        let deleteDesc = NSTextField(labelWithString: "Press Backspace to move files to trash. Command+Delete will be disabled.")
        deleteDesc.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        deleteDesc.textColor = .secondaryLabelColor
        deleteDesc.lineBreakMode = .byWordWrapping
        deleteDesc.maximumNumberOfLines = 0
        deleteDesc.preferredMaxLayoutWidth = 450
        stackView.addArrangedSubview(deleteDesc)

        // Add spacing
        let spacer2 = NSView()
        spacer2.translatesAutoresizingMaskIntoConstraints = false
        spacer2.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacer2)

        // Confirmations & Progress section
        let confirmationsTitle = NSTextField(labelWithString: "Confirmations & Progress:")
        confirmationsTitle.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(confirmationsTitle)

        // Confirm operations
        addCheckbox(title: "Confirm file operations (copy/move/paste/delete)", key: .confirmFileOperations, defaultValue: true)
        
        let confirmDesc = NSTextField(labelWithString: "Show confirmation dialogs with item counts, sizes, and available space before executing operations.")
        confirmDesc.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        confirmDesc.textColor = .secondaryLabelColor
        confirmDesc.lineBreakMode = .byWordWrapping
        confirmDesc.maximumNumberOfLines = 0
        confirmDesc.preferredMaxLayoutWidth = 450
        stackView.addArrangedSubview(confirmDesc)

        // Add spacing
        let spacer3 = NSView()
        spacer3.translatesAutoresizingMaskIntoConstraints = false
        spacer3.heightAnchor.constraint(equalToConstant: 15).isActive = true
        stackView.addArrangedSubview(spacer3)

        // Show progress
        addCheckbox(title: "Show progress sheets during operations", key: .showOperationProgress, defaultValue: true)
        
        let progressDesc = NSTextField(labelWithString: "Display a progress dialog for multi-file copy, move, paste, and delete operations.")
        progressDesc.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        progressDesc.textColor = .secondaryLabelColor
        progressDesc.lineBreakMode = .byWordWrapping
        progressDesc.maximumNumberOfLines = 0
        progressDesc.preferredMaxLayoutWidth = 450
        stackView.addArrangedSubview(progressDesc)
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
}

class TerminalSettingsViewController: NSViewController {

    private var stackView: NSStackView!

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

        // Anchor the content view to the scroll view's contentView so the top stays pinned
        let contentContainer = scrollView.contentView
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            contentView.widthAnchor.constraint(lessThanOrEqualTo: contentContainer.widthAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
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

        addCheckbox(title: "Show \"Open in Terminal\" toolbar button", key: .showOpenTerminalButton, defaultValue: true)

        // Add description
        let toolbarButtonDescriptionLabel = NSTextField(labelWithString: "Display a toolbar button to open the current folder in Terminal.app")
        toolbarButtonDescriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        toolbarButtonDescriptionLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(toolbarButtonDescriptionLabel)
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

    @objc func sidebarOrderChanged(_ sender: NSSegmentedControl) {
        PendingSettings.shared.setValue(sender.selectedSegment, forKey: UserDefaults.Keys.sidebarOrder.rawValue)
    }
}

class ContextMenuSettingsViewController: NSViewController {

    private var stackView: NSStackView!

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
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
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        stackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        addContextMenuSettings()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // Scroll to top when view appears
        if let scrollView = view as? NSScrollView {
            scrollView.contentView.scroll(to: NSPoint.zero)
        }
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
            PendingSettings.shared.setValue(sender.state == .on, forKey: keyRawValue)
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
        addCheckbox(title: "Show Preview Pane button", key: .showPreviewPaneButton, defaultValue: true)
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
            PendingSettings.shared.setValue(sender.state == .on, forKey: keyRawValue)
            // Note: toolbar notification will be posted when Apply is clicked
        }
    }
}

class PermissionsSettingsViewController: NSViewController {

    private var stackView: NSStackView!
    private var permissionViews: [PermissionType: NSView] = [:]
    private var directoryListStack: NSStackView!

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.view = scrollView

        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        contentView.translatesAutoresizingMaskIntoConstraints = false

        stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 15
        contentView.addSubview(stackView)

        scrollView.documentView = contentView

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        stackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        addPermissionsSection()
        addGrantedDirectoriesSection()
    }

    private func addPermissionsSection() {
        let titleLabel = NSTextField(labelWithString: "App Permissions")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 2)
        stackView.addArrangedSubview(titleLabel)

        let descriptionLabel = NSTextField(labelWithString: "Manage permissions for MacFileExplorer. Click 'Open Settings' to change permissions in System Preferences.")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.maximumNumberOfLines = 0
        descriptionLabel.preferredMaxLayoutWidth = 500
        stackView.addArrangedSubview(descriptionLabel)

        // Add spacing
        let spacer1 = NSView()
        spacer1.translatesAutoresizingMaskIntoConstraints = false
        spacer1.heightAnchor.constraint(equalToConstant: 10).isActive = true
        stackView.addArrangedSubview(spacer1)

        // Add permission rows (only surface permissions the app might use)
        let visiblePermissions: [PermissionType] = [.fullDiskAccess]
        for permissionType in visiblePermissions {
            let permissionRow = createPermissionRow(for: permissionType)
            stackView.addArrangedSubview(permissionRow)
            permissionViews[permissionType] = permissionRow
        }

        // Add refresh button
        let spacer2 = NSView()
        spacer2.translatesAutoresizingMaskIntoConstraints = false
        spacer2.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacer2)

        let refreshButton = NSButton(title: "Refresh Permissions", target: self, action: #selector(refreshPermissions(_:)))
        refreshButton.bezelStyle = .rounded
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(refreshButton)
    }

    private func createPermissionRow(for type: PermissionType) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let iconImage = NSImage(systemSymbolName: type.icon, accessibilityDescription: type.rawValue)
        let iconView = NSImageView(image: iconImage ?? NSImage())
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentTintColor = .labelColor
        container.addSubview(iconView)

        // Permission name and description stack
        let textStack = NSStackView()
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let nameLabel = NSTextField(labelWithString: type.rawValue)
        nameLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        nameLabel.textColor = .labelColor
        textStack.addArrangedSubview(nameLabel)

        let descLabel = NSTextField(labelWithString: type.description)
        descLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descLabel.textColor = .secondaryLabelColor
        textStack.addArrangedSubview(descLabel)

        container.addSubview(textStack)

        // Status label
        let status = PermissionsManager.shared.checkPermissionStatus(for: type)
        let statusLabel = NSTextField(labelWithString: status.displayText)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize)
        statusLabel.textColor = status.color
        statusLabel.alignment = .right
        statusLabel.tag = 1000 // Tag to identify status label
        container.addSubview(statusLabel)

        // Open Settings button
        let settingsButton = NSButton(title: "Open Settings", target: self, action: #selector(openSystemPreferences(_:)))
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.bezelStyle = .rounded
        settingsButton.tag = type.hashValue
        container.addSubview(settingsButton)

        // Separator
        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator
        container.addSubview(separator)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),

            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -5),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -12),

            settingsButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            settingsButton.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -5),
            settingsButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

            statusLabel.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -5),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),

            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    @objc private func openSystemPreferences(_ sender: NSButton) {
        // Find the permission type from the button's tag
        if let permissionType = PermissionType.allCases.first(where: { $0.hashValue == sender.tag }) {
            PermissionsManager.shared.openSystemPreferences(for: permissionType)
        }
    }

    @objc private func refreshPermissions(_ sender: NSButton) {
        // Refresh all permission statuses
        for (permissionType, permissionView) in permissionViews {
            if let statusLabel = permissionView.viewWithTag(1000) as? NSTextField {
                let status = PermissionsManager.shared.checkPermissionStatus(for: permissionType)
                statusLabel.stringValue = status.displayText
                statusLabel.textColor = status.color
            }
        }
        refreshGrantedDirectories()
    }

    // MARK: - Granted Directories

    private func addGrantedDirectoriesSection() {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stackView.addArrangedSubview(spacer)

        let titleLabel = NSTextField(labelWithString: "Granted Directory Access")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 2)
        stackView.addArrangedSubview(titleLabel)

        let descLabel = NSTextField(labelWithString: "These are folders you have explicitly granted MacFileExplorer access to. You can reveal them in Finder or revoke access.")
        descLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descLabel.textColor = .secondaryLabelColor
        descLabel.maximumNumberOfLines = 0
        descLabel.preferredMaxLayoutWidth = 500
        stackView.addArrangedSubview(descLabel)

        directoryListStack = NSStackView()
        directoryListStack.translatesAutoresizingMaskIntoConstraints = false
        directoryListStack.orientation = .vertical
        directoryListStack.alignment = .leading
        directoryListStack.spacing = 6
        stackView.addArrangedSubview(directoryListStack)

        let buttonsRow = NSStackView()
        buttonsRow.translatesAutoresizingMaskIntoConstraints = false
        buttonsRow.orientation = .horizontal
        buttonsRow.alignment = .centerY
        buttonsRow.spacing = 8

        let addButton = NSButton(title: "Add Directory…", target: self, action: #selector(addDirectoryAccess(_:)))
        addButton.bezelStyle = .rounded
        buttonsRow.addArrangedSubview(addButton)

        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshGrantedDirectoriesAction(_:)))
        refreshButton.bezelStyle = .rounded
        buttonsRow.addArrangedSubview(refreshButton)

        let exportButton = NSButton(title: "Export List", target: self, action: #selector(exportGrantedDirectories(_:)))
        exportButton.bezelStyle = .rounded
        buttonsRow.addArrangedSubview(exportButton)

        let helpButton = NSButton(title: "How to revoke", target: self, action: #selector(showRevokeHelp(_:)))
        helpButton.bezelStyle = .rounded
        buttonsRow.addArrangedSubview(helpButton)

        stackView.addArrangedSubview(buttonsRow)

        refreshGrantedDirectories()
    }

    private func directoryRow(for url: URL) -> NSView {
        let entry = PermissionsManager.shared.resolvedGrantedDirectoryEntries().first { $0.path == url.path }
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let pathLabel = NSTextField(labelWithString: url.path)
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        container.addSubview(pathLabel)

        let statusText: String
        let statusColor: NSColor
        if let e = entry {
            if !e.isValid { statusText = "Missing"; statusColor = NSColor.systemRed }
            else if e.isStale { statusText = "Stale"; statusColor = NSColor.systemOrange }
            else { statusText = "Valid"; statusColor = NSColor.systemGreen }
        } else {
            statusText = "Valid"
            statusColor = NSColor.systemGreen
        }

        let statusLabel = NSTextField(labelWithString: statusText)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize)
        statusLabel.textColor = statusColor
        container.addSubview(statusLabel)

        let revealButton = NSButton(title: "Reveal", target: self, action: #selector(revealDirectory(_:)))
        revealButton.translatesAutoresizingMaskIntoConstraints = false
        revealButton.bezelStyle = .rounded
        revealButton.identifier = NSUserInterfaceItemIdentifier(url.path)
        container.addSubview(revealButton)

        let fixNeeded = statusText == "Missing" || statusText == "Stale"
        var fixButton: NSButton? = nil
        if fixNeeded {
            let btn = NSButton(title: "Fix…", target: self, action: #selector(fixDirectoryAccess(_:)))
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.bezelStyle = .rounded
            btn.identifier = NSUserInterfaceItemIdentifier(url.path)
            container.addSubview(btn)
            fixButton = btn
        }

        let removeButton = NSButton(title: "Remove", target: self, action: #selector(removeDirectoryAccess(_:)))
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.bezelStyle = .rounded
        removeButton.identifier = NSUserInterfaceItemIdentifier(url.path)
        container.addSubview(removeButton)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(separator)

        var constraints: [NSLayoutConstraint] = [
            pathLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            pathLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: pathLabel.trailingAnchor, constant: 12),
            statusLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ]

        if let fixButton = fixButton {
            constraints += [
                fixButton.leadingAnchor.constraint(equalTo: statusLabel.trailingAnchor, constant: 8),
                fixButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                revealButton.leadingAnchor.constraint(equalTo: fixButton.trailingAnchor, constant: 8)
            ]
        } else {
            constraints += [
                revealButton.leadingAnchor.constraint(equalTo: statusLabel.trailingAnchor, constant: 8)
            ]
        }

        constraints += [
            revealButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            removeButton.leadingAnchor.constraint(equalTo: revealButton.trailingAnchor, constant: 8),
            removeButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            removeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ]

        NSLayoutConstraint.activate(constraints)
        return container
    }

    @objc private func addDirectoryAccess(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Grant Access"
        panel.message = "Choose a folder to grant the app persistent access."
        if panel.runModal() == .OK, let url = panel.url {
            PermissionsManager.shared.addGrantedDirectory(url)
            refreshGrantedDirectories()
        }
    }

    @objc private func refreshGrantedDirectoriesAction(_ sender: NSButton) {
        refreshGrantedDirectories()
    }

    @objc private func exportGrantedDirectories(_ sender: NSButton) {
        let entries = PermissionsManager.shared.resolvedGrantedDirectoryEntries()
        var lines: [String] = []
        for entry in entries {
            if let url = entry.url {
                lines.append(url.path)
            } else {
                lines.append(entry.path)
            }
        }
        let text = lines.joined(separator: "\n")
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let outURL = desktop.appendingPathComponent("granted_directories.txt")
        do {
            try text.write(to: outURL, atomically: true, encoding: .utf8)
            let alert = NSAlert()
            alert.messageText = "Export Complete"
            alert.informativeText = "Exported \(lines.count) entries to \(outURL.path)"
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    @objc private func showRevokeHelp(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "How to Revoke Directory Access"
        alert.informativeText = "To revoke a granted folder:\n\n1) Open Settings → Permissions → Granted Directory Access.\n2) Find the folder and click 'Remove' to revoke access.\n\nAlternatively, you can remove saved entries by deleting the keys in your preferences plist (not recommended unless you know what you're doing):\ndefaults write com.macfileexplorer.app grantedDirectoriesPaths -array\ndefaults write com.macfileexplorer.app grantedDirectoryBookmarks -array\n\nAfter removing entries, restart the app to apply changes."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func refreshGrantedDirectories() {
        directoryListStack.arrangedSubviews.forEach { directoryListStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        let entries = PermissionsManager.shared.resolvedGrantedDirectoryEntries()
        if entries.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "No directories granted yet. Use 'Add Directory…' to grant persistent access to a folder. You can revoke access later with 'Remove'.")
            emptyLabel.textColor = .secondaryLabelColor
            emptyLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            emptyLabel.maximumNumberOfLines = 0
            emptyLabel.preferredMaxLayoutWidth = 500
            directoryListStack.addArrangedSubview(emptyLabel)
        } else {
            for entry in entries {
                if let url = entry.url ?? (entry.isValid ? URL(fileURLWithPath: entry.path) : URL(fileURLWithPath: entry.path)) as URL? {
                    directoryListStack.addArrangedSubview(directoryRow(for: url))
                }
            }
        }
    }

    private func urlFromButton(_ sender: NSButton) -> URL? {
        guard let raw = sender.identifier?.rawValue, !raw.isEmpty else { return nil }
        return URL(fileURLWithPath: raw)
    }

    @objc private func revealDirectory(_ sender: NSButton) {
        if let url = urlFromButton(sender) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
        }
    }

    @objc private func removeDirectoryAccess(_ sender: NSButton) {
        if let url = urlFromButton(sender) {
            PermissionsManager.shared.removeGrantedDirectory(url)
            refreshGrantedDirectories()
        }
    }

    @objc private func fixDirectoryAccess(_ sender: NSButton) {
        guard let oldURL = urlFromButton(sender) else { return }
        // Try automatic refresh if stale and still exists
        if FileManager.default.fileExists(atPath: oldURL.path) {
            PermissionsManager.shared.refreshBookmarkIfStale(for: oldURL)
            refreshGrantedDirectories()
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Replace"
        panel.message = "Select the new location to replace missing directory access."
        if panel.runModal() == .OK, let newURL = panel.url {
            PermissionsManager.shared.replaceGrantedDirectory(oldURL: oldURL, with: newURL)
            refreshGrantedDirectories()
        }
    }
}

// MARK: - Go Menu Settings View Controller

class GoMenuSettingsViewController: NSViewController {

    private var stackView: NSStackView!

    override func loadView() {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
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

        addGoMenuSettings()
    }

    private func addGoMenuSettings() {
        let titleLabel = NSTextField(labelWithString: "Go Menu Items")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(titleLabel)

        let descriptionLabel = NSTextField(labelWithString: "Choose which items appear in the Go menu. Home and Downloads are shown by default.")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.maximumNumberOfLines = 2
        descriptionLabel.lineBreakMode = .byWordWrapping
        stackView.addArrangedSubview(descriptionLabel)

        // Add spacing
        let spacer1 = NSView()
        spacer1.translatesAutoresizingMaskIntoConstraints = false
        spacer1.heightAnchor.constraint(equalToConstant: 10).isActive = true
        stackView.addArrangedSubview(spacer1)

        // Add checkboxes for each Go menu item
        addCheckbox(title: "Home (⇧⌘H)", key: .showGoHome, defaultValue: true)
        addCheckbox(title: "Desktop (⇧⌘D)", key: .showGoDesktop, defaultValue: false)
        addCheckbox(title: "Documents (⇧⌘O)", key: .showGoDocuments, defaultValue: false)
        addCheckbox(title: "Downloads (⇧⌘L)", key: .showGoDownloads, defaultValue: true)
        addCheckbox(title: "Applications (⇧⌘A)", key: .showGoApplications, defaultValue: false)
        addCheckbox(title: "Utilities (⇧⌘U)", key: .showGoUtilities, defaultValue: false)
        addCheckbox(title: "Library", key: .showGoLibrary, defaultValue: false)
        addCheckbox(title: "Computer", key: .showGoComputer, defaultValue: false)
        addCheckbox(title: "AirDrop (⇧⌘R)", key: .showGoAirDrop, defaultValue: false)
        addCheckbox(title: "Network", key: .showGoNetwork, defaultValue: false)
        addCheckbox(title: "iCloud Drive (⇧⌘I)", key: .showGoiCloudDrive, defaultValue: false)
        addCheckbox(title: "Recent Items", key: .showGoRecent, defaultValue: false)

        // Add spacing
        let spacer2 = NSView()
        spacer2.translatesAutoresizingMaskIntoConstraints = false
        spacer2.heightAnchor.constraint(equalToConstant: 10).isActive = true
        stackView.addArrangedSubview(spacer2)

        let connectLabel = NSTextField(labelWithString: "Network:")
        connectLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(connectLabel)

        addCheckbox(title: "Connect to Server... (⌘K)", key: .showGoConnectToServer, defaultValue: false)

        // Note about restarting
        let noteLabel = NSTextField(labelWithString: "Note: Menu changes require relaunching the app to take effect.")
        noteLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.maximumNumberOfLines = 2
        noteLabel.lineBreakMode = .byWordWrapping
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
            PendingSettings.shared.setValue(sender.state == .on, forKey: keyRawValue)
        }
    }
}
