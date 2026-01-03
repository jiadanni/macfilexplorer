import Foundation

/// Protocol defining type-safe access to application settings.
///
/// Provides a testable interface for all user preferences,
/// eliminating scattered `UserDefaults` access throughout the codebase.
///
/// **Benefits:**
/// - Dependency injection for testing
/// - Type safety for all settings
/// - Single source of truth
/// - Easier to mock in tests
///
/// **Usage:**
/// ```swift
/// class MyViewController {
///     private let settings: SettingsStoreProtocol
///     
///     init(settings: SettingsStoreProtocol = SettingsStore.shared) {
///         self.settings = settings
///     }
///     
///     func loadSettings() {
///         let showHidden = settings.hiddenFilesState
///     }
/// }
/// ```
protocol SettingsStoreProtocol: AnyObject {
    // MARK: - General Settings
    
    var showFileExtensions: Bool { get set }
    var useGrayscaleIcons: Bool { get set }
    var useGrayscaleWindowControls: Bool { get set }
    var warnOnExtensionChange: Bool { get set }
    var enableEasySelect: Bool { get set }
    var startupFolder: String? { get set }
    var accentColor: Data? { get set }

    // MARK: - Preview Pane Settings
    
    var previewPaneVisible: Bool { get set }
    var previewPanePosition: String { get set }
    var previewPaneWidth: CGFloat { get set }

    // MARK: - View Settings
    
    var defaultViewMode: ViewMode { get set }
    var defaultSortColumn: String { get set }
    var defaultSortAscending: Bool { get set }
    var showFolderSizes: Bool { get set }

    // MARK: - Tabs Settings
    
    var restoreTabsOnReopen: Bool { get set }

    // MARK: - Sidebar Settings
    
    var showFavorites: Bool { get set }
    var showRecents: Bool { get set }
    var showLocations: Bool { get set }
    var sidebarOrder: Int { get set }
    var expandSidebarToCurrentDirectory: Bool { get set }

    // MARK: - Terminal Settings

    var openTerminalByDefault: Bool { get set }

    // MARK: - Status Bar Settings
    
    var showStatusBar: Bool { get set }

    // MARK: - File Operations Settings
    
    var autoRenameOnConflict: Bool { get set }
    var deleteWithBackspaceOnly: Bool { get set }
    var confirmFileOperations: Bool { get set }
    var showOperationProgress: Bool { get set }

    // MARK: - Filter Settings

    var filterCriteriaData: Data? { get set }
    var searchHistory: [String] { get set }

    // MARK: - Toolbar Settings
    
    var showBackForwardButtons: Bool { get set }
    var showViewModeButton: Bool { get set }
    var showHiddenFilesButton: Bool { get set }
    var showSplitButtons: Bool { get set }
    var showPreviewPaneButton: Bool { get set }
    var showNewFolderButton: Bool { get set }
    var showSortButton: Bool { get set }
    var showStorageAnalyzerButton: Bool { get set }
    var showOpenTerminalButton: Bool { get set }

    // MARK: - Start Page Settings
    
    var hasLaunchedBefore: Bool { get set }
    var showStartOnLaunch: Bool { get set }
    var hasCompletedOnboarding: Bool { get set }
    var dismissedWelcome: Bool { get set }

    // MARK: - Go Menu Settings

    var showGoHome: Bool { get set }
    var showGoDesktop: Bool { get set }
    var showGoDocuments: Bool { get set }
    var showGoDownloads: Bool { get set }
    var showGoApplications: Bool { get set }
    var showGoUtilities: Bool { get set }
    var showGoLibrary: Bool { get set }
    var showGoComputer: Bool { get set }
    var showGoAirDrop: Bool { get set }
    var showGoNetwork: Bool { get set }
    var showGoiCloudDrive: Bool { get set }
    var showGoRecent: Bool { get set }
    var showGoConnectToServer: Bool { get set }

    // MARK: - Split Panes Settings
    
    var maximumPanes: Int { get set }

    // MARK: - Window Layout Settings

    var sidebarFixedWidth: Double { get set }
    var terminalIsVisible: Bool { get set }

    // MARK: - Favorites Widget Settings

    var favoriteWidgetFolders: [String] { get set }

    // MARK: - Storage Analyzer Settings

    var storageAnalyzerLastScanPath: String? { get set }

    // MARK: - Context Menu Settings
    
    var showContextMenuHotkeys: Bool { get set }
    var hideOpenWith: Bool { get set }
    var hideGetInfo: Bool { get set }
    var hideCopy: Bool { get set }
    var hideCut: Bool { get set }
    var hidePaste: Bool { get set }
    var hideRename: Bool { get set }
    var hideMoveToTrash: Bool { get set }
    var hideNewFolder: Bool { get set }
    var hideShowInFinder: Bool { get set }
    
    // MARK: - Column Visibility
    
    var columnVisibility: [String: Bool] { get set }
    
    // MARK: - Hidden Files State
    
    var hiddenFilesState: Bool { get set }

    // MARK: - Settings Placement
    
    var openSettingsInTab: Bool { get set }

    // MARK: - Data Source Settings

    var folderSortPreferences: [String: String] { get set }

    // MARK: - Sidebar Favorites
    
    var sidebarFavorites: [String] { get set }
    
    // MARK: - Permissions Management
    
    var permissionsMigrationFlag: Bool { get set }
    var grantedDirectories: [String] { get set }
    var grantedDirectoryBookmarks: [Data] { get set }
    
    func lastContextualPermissionDate(for key: String) -> Date?
    func setLastContextualPermissionDate(_ date: Date, for key: String)
    
    // MARK: - Color Manager Settings
    
    var globalFolderColor: Data? { get set }
    var globalFolderColorHex: String? { get set }
    var folderColors: [String: String] { get set }

    // MARK: - View Options Settings

    func loadViewOptions() -> ViewOptions
    func saveViewOptions(_ options: ViewOptions)

    // MARK: - Operation Metrics

    var operationMetricsLogData: Data? { get set }

    // MARK: - Observability

    func addDelegate(_ delegate: SettingsStoreDelegate)
    func removeDelegate(_ delegate: SettingsStoreDelegate)

    // MARK: - Utility Methods
    
    func resetToDefaults()

    func data(forKey key: String) -> Data?
    func value(forKey key: String) -> Any?
    func setValue(_ value: Any?, forKey key: String)
    func removeValue(forKey key: String)
}
