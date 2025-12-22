import Foundation

/// Delegate for receiving notifications about settings changes.
///
/// Use this protocol to be notified when critical settings change without relying on NotificationCenter.
/// This allows for type-safe, testable communication with the settings store.
protocol SettingsStoreDelegate: AnyObject {
    /// Called when the preview pane visibility changes.
    ///
    /// - Parameters:
    ///   - settingsStore: The SettingsStore instance
    ///   - isVisible: Whether the preview pane is now visible
    func settingsStore(_ settingsStore: SettingsStoreProtocol, previewPaneVisibilityDidChange isVisible: Bool)
    
    /// Called when the hidden files visibility state changes.
    ///
    /// - Parameters:
    ///   - settingsStore: The SettingsStore instance
    ///   - isVisible: Whether hidden files are now visible
    func settingsStore(_ settingsStore: SettingsStoreProtocol, hiddenFilesStateDidChange isVisible: Bool)
}

/// Centralized type-safe access to application settings.
///
/// `SettingsStore` provides a single source of truth for all user preferences,
/// eliminating scattered `UserDefaults` access throughout the codebase.
///
/// **Benefits:**
/// - Type safety for all settings
/// - Testable through dependency injection
/// - Single place to document defaults
/// - Easier to track what settings exist
///
/// **Usage:**
/// ```swift
/// // Reading a setting
/// let showHidden = SettingsStore.shared.hiddenFilesState
///
/// // Writing a setting
/// SettingsStore.shared.hiddenFilesState = true
///
/// // Testing with custom UserDefaults
/// let testStore = SettingsStore(defaults: UserDefaults(suiteName: "test")!)
/// ```
///
/// **Thread Safety:** All properties are thread-safe as they use UserDefaults,
/// which is thread-safe for read/write operations.
final class SettingsStore: SettingsStoreProtocol {
    /// Shared singleton instance for app-wide access.
    static let shared = SettingsStore()

    private let defaults: UserDefaults
    private let delegates = NSHashTable<AnyObject>.weakObjects()
    private enum AdditionalKeys {
        static let sidebarFixedWidth = "sidebarFixedWidth"
        static let terminalIsVisible = "terminalIsVisible"
        static let favoriteWidgetFolders = "FavoriteWidgetFolders"
        static let storageAnalyzerLastScanPath = "StorageAnalyzerLastScanPath"
        static let operationMetricsLog = "operationMetricsLog"
    }

    /// Initialize with a specific UserDefaults instance.
    ///
    /// - Parameter defaults: The UserDefaults instance to use. Defaults to `.standard`.
    ///
    /// For production code, use the default parameter.
    /// For testing, inject a custom UserDefaults instance:
    /// ```swift
    /// let testDefaults = UserDefaults(suiteName: "test")!
    /// let testStore = SettingsStore(defaults: testDefaults)
    /// ```
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Delegates

    func addDelegate(_ delegate: SettingsStoreDelegate) {
        delegates.add(delegate)
    }

    func removeDelegate(_ delegate: SettingsStoreDelegate) {
        delegates.remove(delegate)
    }

    private func notifyDelegates(_ block: @escaping (SettingsStoreDelegate) -> Void) {
        let currentDelegates = delegates.allObjects.compactMap { $0 as? SettingsStoreDelegate }
        let notifyBlock = {
            currentDelegates.forEach { block($0) }
        }
        if Thread.isMainThread {
            notifyBlock()
        } else {
            Task { @MainActor in
                notifyBlock()
            }
        }
    }

    // MARK: - General Settings
    
    /// Whether to show file extensions in file names.
    /// Default: `true`
    var showFileExtensions: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.showFileExtensions.rawValue) as? Bool ?? true }
        set { 
            defaults.set(newValue, forKey: UserDefaults.Keys.showFileExtensions.rawValue)
            postSettingsChangeNotification()
        }
    }

    /// Whether to display file icons in grayscale.
    /// Default: `false`
    var useGrayscaleIcons: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.useGrayscaleIcons.rawValue) }
        set { 
            defaults.set(newValue, forKey: UserDefaults.Keys.useGrayscaleIcons.rawValue)
            postSettingsChangeNotification()
        }
    }
    
    /// Whether to display window traffic lights in grayscale.
    /// Default: `false`
    var useGrayscaleWindowControls: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.useGrayscaleWindowControls.rawValue) }
        set {
            defaults.set(newValue, forKey: UserDefaults.Keys.useGrayscaleWindowControls.rawValue)
            postSettingsChangeNotification()
        }
    }
    
    /// Whether to warn when changing file extensions.
    /// Default: `true`
    var warnOnExtensionChange: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.warnOnExtensionChange.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.warnOnExtensionChange.rawValue) }
    }
    
    /// Whether to enable easy select mode (single-click selection).
    /// Default: `false`
    var enableEasySelect: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.enableEasySelect.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.enableEasySelect.rawValue) }
    }
    
    /// Startup folder path. If nil, uses default behavior.
    /// Default: `nil`
    var startupFolder: String? {
        get { defaults.string(forKey: UserDefaults.Keys.startupFolder.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.startupFolder.rawValue) }
    }

    /// Accent color for UI elements.
    /// Key: UserDefaults.Keys.accentColor
    var accentColor: Data? {
        get { defaults.data(forKey: UserDefaults.Keys.accentColor.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.accentColor.rawValue) }
    }

    // MARK: - Preview Pane Settings
    
    /// Whether the preview pane is visible.
    /// Default: `false`
    var previewPaneVisible: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.showPreviewPane.rawValue) }
        set { 
            defaults.set(newValue, forKey: UserDefaults.Keys.showPreviewPane.rawValue)
            notifyDelegates { delegate in
                delegate.settingsStore(self, previewPaneVisibilityDidChange: newValue)
            }
            // Keep notification for backward compatibility during transition period
            NotificationCenter.default.post(name: .previewPaneToggled, object: nil)
        }
    }
    
    /// Preview pane position: "right" or "bottom".
    /// Default: `"right"`
    var previewPanePosition: String {
        get { defaults.string(forKey: UserDefaults.Keys.previewPanePosition.rawValue) ?? "right" }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.previewPanePosition.rawValue) }
    }
    
    /// Preview pane width in points.
    /// Default: `300.0`
    var previewPaneWidth: CGFloat {
        get { 
            let value = defaults.double(forKey: UserDefaults.Keys.previewPaneWidth.rawValue)
            return value > 0 ? CGFloat(value) : 300.0
        }
        set { defaults.set(Double(newValue), forKey: UserDefaults.Keys.previewPaneWidth.rawValue) }
    }

    // MARK: - View Settings
    
    /// Default view mode for new file browser instances.
    /// Default: `.list`
    var defaultViewMode: ViewMode {
        get {
            if let raw = defaults.string(forKey: UserDefaults.Keys.defaultViewMode.rawValue) {
                if let mode = ViewMode(rawValue: raw) {
                    return mode
                }
                switch raw.lowercased() {
                case "list":
                    return .list
                case "icons":
                    return .icons
                case "columns":
                    return .columns
                case "windowslist":
                    return .windowsList
                default:
                    break
                }
            }
            return .list
        }
        set { defaults.set(newValue.rawValue, forKey: UserDefaults.Keys.defaultViewMode.rawValue) }
    }
    
    /// Default sort column.
    /// Default: `"NameColumn"`
    var defaultSortColumn: String {
        get { defaults.string(forKey: UserDefaults.Keys.defaultSortColumn.rawValue) ?? AppConfig.ColumnID.name }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.defaultSortColumn.rawValue) }
    }
    
    /// Default sort direction.
    /// Default: `true` (ascending)
    var defaultSortAscending: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.defaultSortAscending.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.defaultSortAscending.rawValue) }
    }
    
    /// Whether to calculate and show folder sizes.
    /// Default: `false` (performance consideration)
    var showFolderSizes: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.showFolderSizes.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showFolderSizes.rawValue) }
    }

    // MARK: - Tabs Settings
    
    /// Whether to restore tabs when reopening the app.
    /// Default: `false`
    var restoreTabsOnReopen: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.restoreTabsOnReopen.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.restoreTabsOnReopen.rawValue) }
    }

    // MARK: - Sidebar Settings
    
    /// Whether to show Favorites section in sidebar.
    /// Default: `true`
    var showFavorites: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.showFavorites.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showFavorites.rawValue) }
    }
    
    /// Whether to show Recents section in sidebar.
    /// Default: `true`
    var showRecents: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.showRecents.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showRecents.rawValue) }
    }
    
    /// Whether to show Locations section in sidebar.
    /// Default: `true`
    var showLocations: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.showLocations.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showLocations.rawValue) }
    }
    
    /// Sidebar section order index.
    /// Default: `0`
    var sidebarOrder: Int {
        get { defaults.integer(forKey: UserDefaults.Keys.sidebarOrder.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.sidebarOrder.rawValue) }
    }
    
    /// Whether to expand sidebar to current directory.
    /// Default: `false`
    var expandSidebarToCurrentDirectory: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.expandSidebarToCurrentDirectory.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.expandSidebarToCurrentDirectory.rawValue) }
    }

    // MARK: - Terminal Settings
    
    /// Whether to open terminal by default.
    /// Default: `false`
    var openTerminalByDefault: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.openTerminalByDefault.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.openTerminalByDefault.rawValue) }
    }

    // MARK: - Status Bar Settings
    
    /// Whether to show the status bar.
    /// Default: `true`
    var showStatusBar: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.showStatusBar.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showStatusBar.rawValue) }
    }

    // MARK: - File Operations Settings
    
    /// Whether to auto-rename files on conflict.
    /// Default: `false`
    var autoRenameOnConflict: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.autoRenameOnConflict.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.autoRenameOnConflict.rawValue) }
    }
    
    /// Whether delete only works with backspace key.
    /// Default: `false`
    var deleteWithBackspaceOnly: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.deleteWithBackspaceOnly.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.deleteWithBackspaceOnly.rawValue) }
    }
    
    /// Whether to confirm file operations.
    /// Default: `true`
    var confirmFileOperations: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.confirmFileOperations.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.confirmFileOperations.rawValue) }
    }
    
    /// Whether to show operation progress dialogs.
    /// Default: `true`
    var showOperationProgress: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.showOperationProgress.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showOperationProgress.rawValue) }
    }

    // MARK: - Filter Settings

    /// Persisted filter criteria data.
    /// Key: AppConfig.SettingsKeys.filterCriteria
    var filterCriteriaData: Data? {
        get { defaults.data(forKey: AppConfig.SettingsKeys.filterCriteria) }
        set { defaults.set(newValue, forKey: AppConfig.SettingsKeys.filterCriteria) }
    }

    /// Search history entries.
    /// Key: AppConfig.SettingsKeys.searchHistory
    var searchHistory: [String] {
        get { defaults.array(forKey: AppConfig.SettingsKeys.searchHistory) as? [String] ?? [] }
        set { defaults.set(newValue, forKey: AppConfig.SettingsKeys.searchHistory) }
    }

    // MARK: - Toolbar Settings
    
    /// Whether to show back/forward buttons in toolbar.
    /// Default: `true`
    var showBackForwardButtons: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.showBackForwardButtons.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showBackForwardButtons.rawValue) }
    }
    
    /// Whether to show view mode button in toolbar.
    /// Default: `true`
    var showViewModeButton: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.showViewModeButton.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showViewModeButton.rawValue) }
    }
    
    /// Whether to show hidden files button in toolbar.
    /// Default: `true`
    var showHiddenFilesButton: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.showHiddenFilesButton.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showHiddenFilesButton.rawValue) }
    }
    
    /// Whether to show split buttons in toolbar.
    /// Default: `true`
    var showSplitButtons: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.showSplitButtons.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showSplitButtons.rawValue) }
    }
    
    /// Whether to show preview pane button in toolbar.
    /// Default: `true`
    var showPreviewPaneButton: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.showPreviewPaneButton.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showPreviewPaneButton.rawValue) }
    }
    
    /// Whether to show new folder button in toolbar.
    /// Default: `true`
    var showNewFolderButton: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.showNewFolderButton.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showNewFolderButton.rawValue) }
    }
    
    /// Whether to show sort button in toolbar.
    /// Default: `true`
    var showSortButton: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.showSortButton.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showSortButton.rawValue) }
    }
    
    /// Whether to show storage analyzer button in toolbar.
    /// Default: `true`
    var showStorageAnalyzerButton: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.showStorageAnalyzerButton.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showStorageAnalyzerButton.rawValue) }
    }
    
    /// Whether to show open terminal button in toolbar.
    /// Default: `true`
    var showOpenTerminalButton: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.showOpenTerminalButton.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showOpenTerminalButton.rawValue) }
    }

    // MARK: - Start Page Settings
    
    /// Whether app has been launched before.
    /// Default: `false`
    var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.hasLaunchedBefore.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.hasLaunchedBefore.rawValue) }
    }
    
    /// Whether to show start page on launch.
    /// Default: `false`
    var showStartOnLaunch: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.showStartOnLaunch.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showStartOnLaunch.rawValue) }
    }

    /// Whether onboarding is complete.
    /// Default: `false`
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.hasCompletedOnboarding.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.hasCompletedOnboarding.rawValue) }
    }

    /// Whether the welcome widget was dismissed.
    /// Default: `false`
    var dismissedWelcome: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.dismissedWelcome.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.dismissedWelcome.rawValue) }
    }

    // MARK: - Split Panes Settings
    
    /// Maximum number of split panes.
    /// Default: `2`, Maximum: `8`
    var maximumPanes: Int {
        get {
            let value = defaults.integer(forKey: UserDefaults.Keys.maximumPanes.rawValue)
            return value > 0 ? min(value, 8) : 2
        }
        set { defaults.set(min(max(newValue, 1), 8), forKey: UserDefaults.Keys.maximumPanes.rawValue) }
    }

    // MARK: - Go Menu Settings

    /// Whether to show Home in the Go menu.
    /// Default: `true`
    var showGoHome: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.showGoHome.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showGoHome.rawValue) }
    }

    /// Whether to show Desktop in the Go menu.
    /// Default: `false`
    var showGoDesktop: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.showGoDesktop.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showGoDesktop.rawValue) }
    }

    /// Whether to show Documents in the Go menu.
    /// Default: `false`
    var showGoDocuments: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.showGoDocuments.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showGoDocuments.rawValue) }
    }

    /// Whether to show Downloads in the Go menu.
    /// Default: `true`
    var showGoDownloads: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.showGoDownloads.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showGoDownloads.rawValue) }
    }

    /// Whether to show Applications in the Go menu.
    /// Default: `false`
    var showGoApplications: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.showGoApplications.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showGoApplications.rawValue) }
    }

    /// Whether to show Utilities in the Go menu.
    /// Default: `false`
    var showGoUtilities: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.showGoUtilities.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showGoUtilities.rawValue) }
    }

    /// Whether to show Library in the Go menu.
    /// Default: `false`
    var showGoLibrary: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.showGoLibrary.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showGoLibrary.rawValue) }
    }

    /// Whether to show Computer in the Go menu.
    /// Default: `false`
    var showGoComputer: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.showGoComputer.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showGoComputer.rawValue) }
    }

    /// Whether to show AirDrop in the Go menu.
    /// Default: `false`
    var showGoAirDrop: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.showGoAirDrop.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showGoAirDrop.rawValue) }
    }

    /// Whether to show Network in the Go menu.
    /// Default: `false`
    var showGoNetwork: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.showGoNetwork.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showGoNetwork.rawValue) }
    }

    /// Whether to show iCloud Drive in the Go menu.
    /// Default: `false`
    var showGoiCloudDrive: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.showGoiCloudDrive.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showGoiCloudDrive.rawValue) }
    }

    /// Whether to show Recent Items in the Go menu.
    /// Default: `false`
    var showGoRecent: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.showGoRecent.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showGoRecent.rawValue) }
    }

    /// Whether to show Connect to Server in the Go menu.
    /// Default: `false`
    var showGoConnectToServer: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.showGoConnectToServer.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showGoConnectToServer.rawValue) }
    }

    // MARK: - Window Layout Settings

    /// Fixed sidebar width in points.
    /// Default: `0` (use UI fallback)
    var sidebarFixedWidth: Double {
        get { defaults.double(forKey: AdditionalKeys.sidebarFixedWidth) }
        set { defaults.set(newValue, forKey: AdditionalKeys.sidebarFixedWidth) }
    }

    /// Whether the terminal panel was visible.
    /// Default: `false`
    var terminalIsVisible: Bool {
        get { defaults.bool(forKey: AdditionalKeys.terminalIsVisible) }
        set { defaults.set(newValue, forKey: AdditionalKeys.terminalIsVisible) }
    }

    // MARK: - Favorites Widget Settings

    /// Saved favorite folders for the Start page widget.
    var favoriteWidgetFolders: [String] {
        get { defaults.array(forKey: AdditionalKeys.favoriteWidgetFolders) as? [String] ?? [] }
        set { defaults.set(newValue, forKey: AdditionalKeys.favoriteWidgetFolders) }
    }

    // MARK: - Storage Analyzer Settings

    /// Last scan path for the Storage Analyzer.
    var storageAnalyzerLastScanPath: String? {
        get { defaults.string(forKey: AdditionalKeys.storageAnalyzerLastScanPath) }
        set { defaults.set(newValue, forKey: AdditionalKeys.storageAnalyzerLastScanPath) }
    }

    // MARK: - Context Menu Settings
    
    /// Whether to show keyboard shortcuts in context menus.
    /// Default: `true`
    var showContextMenuHotkeys: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.showContextMenuHotkeys.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.showContextMenuHotkeys.rawValue) }
    }
    
    /// Whether to hide "Open With" in context menu.
    /// Default: `false`
    var hideOpenWith: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.hideOpenWith.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.hideOpenWith.rawValue) }
    }
    
    /// Whether to hide "Get Info" in context menu.
    /// Default: `false`
    var hideGetInfo: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.hideGetInfo.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.hideGetInfo.rawValue) }
    }
    
    /// Whether to hide "Copy" in context menu.
    /// Default: `false`
    var hideCopy: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.hideCopy.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.hideCopy.rawValue) }
    }
    
    /// Whether to hide "Cut" in context menu.
    /// Default: `false`
    var hideCut: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.hideCut.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.hideCut.rawValue) }
    }
    
    /// Whether to hide "Paste" in context menu.
    /// Default: `false`
    var hidePaste: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.hidePaste.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.hidePaste.rawValue) }
    }
    
    /// Whether to hide "Rename" in context menu.
    /// Default: `false`
    var hideRename: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.hideRename.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.hideRename.rawValue) }
    }
    
    /// Whether to hide "Move to Trash" in context menu.
    /// Default: `false`
    var hideMoveToTrash: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.hideMoveToTrash.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.hideMoveToTrash.rawValue) }
    }
    
    /// Whether to hide "New Folder" in context menu.
    /// Default: `false`
    var hideNewFolder: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.hideNewFolder.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.hideNewFolder.rawValue) }
    }
    
    /// Whether to hide "Show in Finder" in context menu.
    /// Default: `false`
    var hideShowInFinder: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.hideShowInFinder.rawValue) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.hideShowInFinder.rawValue) }
    }
    
    // MARK: - Column Visibility
    
    /// Dictionary storing column visibility preferences.
    /// Key: Column identifier, Value: Visibility
    var columnVisibility: [String: Bool] {
        get { defaults.dictionary(forKey: UserDefaults.Keys.columnVisibility.rawValue) as? [String: Bool] ?? [:] }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.columnVisibility.rawValue) }
    }
    
    // MARK: - Hidden Files State
    
    /// Current hidden files visibility state.
    /// Default: `false`
    var hiddenFilesState: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.hiddenFilesState.rawValue) }
        set { 
            defaults.set(newValue, forKey: UserDefaults.Keys.hiddenFilesState.rawValue)
            notifyDelegates { delegate in
                delegate.settingsStore(self, hiddenFilesStateDidChange: newValue)
            }
            postSettingsChangeNotification()
        }
    }

    // MARK: - Settings Placement
    
    /// Whether to open settings in a tab instead of a window.
    /// Default: `true`
    var openSettingsInTab: Bool {
        get { defaults.object(forKey: UserDefaults.Keys.openSettingsInTab.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.openSettingsInTab.rawValue) }
    }

    // MARK: - Data Source Settings

    /// Dictionary storing per-folder sort preferences.
    /// Key: Folder path, Value: "ColumnName|asc/desc"
    internal var folderSortPreferences: [String: String] {
        get { defaults.dictionary(forKey: UserDefaults.Keys.folderSortPreferences.rawValue) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.folderSortPreferences.rawValue) }
    }

    // MARK: - Sidebar Favorites
    
    /// List of paths favorited in the sidebar.
    /// Default: `[]` (will be populated by SidebarViewController logic if empty)
    /// Key: "SidebarFavorites"
    var sidebarFavorites: [String] {
        get { defaults.array(forKey: "SidebarFavorites") as? [String] ?? [] }
        set { defaults.set(newValue, forKey: "SidebarFavorites") }
    }
    
    // MARK: - Permissions Management
    
    /// Flag indicating if permissions migration has occurred.
    /// Key: "hasMigratedPermissions"
    var permissionsMigrationFlag: Bool {
        get { defaults.bool(forKey: "hasMigratedPermissions") }
        set { defaults.set(newValue, forKey: "hasMigratedPermissions") }
    }
    
    /// Array of paths that have been granted access.
    /// Key: "grantedDirectories"
    var grantedDirectories: [String] {
        get { defaults.array(forKey: "grantedDirectories") as? [String] ?? [] }
        set { defaults.set(newValue, forKey: "grantedDirectories") }
    }
    
    /// Array of security-scoped bookmarks for granted directories.
    /// Key: "grantedDirectoryBookmarks"
    var grantedDirectoryBookmarks: [Data] {
        get {
            if let data = KeychainStore.loadData(forKey: AppConfig.Keychain.grantedDirectoryBookmarksKey),
               let decoded = try? JSONDecoder().decode([Data].self, from: data) {
                return decoded
            }

            let legacy = defaults.array(forKey: AppConfig.Keychain.grantedDirectoryBookmarksKey) as? [Data] ?? []
            if !legacy.isEmpty, let encoded = try? JSONEncoder().encode(legacy) {
                _ = KeychainStore.saveData(encoded, forKey: AppConfig.Keychain.grantedDirectoryBookmarksKey)
                defaults.removeObject(forKey: AppConfig.Keychain.grantedDirectoryBookmarksKey)
            }
            return legacy
        }
        set {
            if newValue.isEmpty {
                KeychainStore.deleteData(forKey: AppConfig.Keychain.grantedDirectoryBookmarksKey)
                defaults.removeObject(forKey: AppConfig.Keychain.grantedDirectoryBookmarksKey)
                return
            }

            if let encoded = try? JSONEncoder().encode(newValue) {
                _ = KeychainStore.saveData(encoded, forKey: AppConfig.Keychain.grantedDirectoryBookmarksKey)
                defaults.removeObject(forKey: AppConfig.Keychain.grantedDirectoryBookmarksKey)
            }
        }
    }
    
    /// Helper to get the last time a contextual permission was asked for a specific key.
    func lastContextualPermissionDate(for key: String) -> Date? {
        return defaults.object(forKey: key) as? Date
    }
    
    /// Helper to set the last time a contextual permission was asked.
    func setLastContextualPermissionDate(_ date: Date, for key: String) {
        defaults.set(date, forKey: key)
    }
    
    // MARK: - Color Manager Settings
    
    /// Global folder color applied to all folders (unless overridden).
    /// Key: UserDefaults.Keys.globalFolderColor
    var globalFolderColor: Data? {
        get { defaults.data(forKey: UserDefaults.Keys.globalFolderColor.rawValue) }
        set { 
            defaults.set(newValue, forKey: UserDefaults.Keys.globalFolderColor.rawValue)
            NotificationCenter.default.post(name: .globalFolderColorDidChangeNotification, object: nil)
        }
    }

    /// Legacy support for global folder color stored as Hex string.
    /// Key: UserDefaults.Keys.globalFolderColor
    var globalFolderColorHex: String? {
        get { defaults.string(forKey: UserDefaults.Keys.globalFolderColor.rawValue) }
        set { 
            defaults.set(newValue, forKey: UserDefaults.Keys.globalFolderColor.rawValue) 
            NotificationCenter.default.post(name: .globalFolderColorDidChangeNotification, object: nil)
        }
    }
    
    /// Custom folder colors.
    /// Key: "GlobalFolderColors"
    var folderColors: [String: String] {
        get { defaults.dictionary(forKey: "GlobalFolderColors") as? [String: String] ?? [:] }
        set { 
            defaults.set(newValue, forKey: "GlobalFolderColors") 
            NotificationCenter.default.post(name: .globalFolderColorDidChangeNotification, object: nil)
        }
    }

    // MARK: - View Options Settings

    func loadViewOptions() -> ViewOptions {
        defaults.loadViewOptions()
    }

    func saveViewOptions(_ options: ViewOptions) {
        defaults.saveViewOptions(options)
    }

    // MARK: - Operation Metrics

    var operationMetricsLogData: Data? {
        get { defaults.data(forKey: AdditionalKeys.operationMetricsLog) }
        set { defaults.set(newValue, forKey: AdditionalKeys.operationMetricsLog) }
    }

    // MARK: - Utility Methods
    
    /// Resets all settings to their default values.
    ///
    /// **Warning:** This operation cannot be undone.
    func resetToDefaults() {
        for key in UserDefaults.Keys.allCases {
            defaults.removeObject(forKey: key.rawValue)
        }
        postSettingsChangeNotification()
    }

    // MARK: - Compatibility Helpers

    func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func value(forKey key: String) -> Any? {
        defaults.object(forKey: key)
    }

    func setValue(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func removeValue(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
    
    /// Posts a notification that settings have changed.
    private func postSettingsChangeNotification() {
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
}
