import Foundation
import CoreGraphics
@testable import MacFileExplorer

class MockSettingsStore: SettingsStoreProtocol {
    // MARK: - General Settings
    var showFileExtensions: Bool = true
    var useGrayscaleIcons: Bool = false
    var useGrayscaleWindowControls: Bool = false
    var warnOnExtensionChange: Bool = true
    var enableEasySelect: Bool = false
    var startupFolder: String? = nil
    var accentColor: Data? = nil

    // MARK: - Preview Pane Settings
    var previewPaneVisible: Bool = false
    var previewPanePosition: String = "right"
    var previewPaneWidth: CGFloat = 300
    var zoomLevel: Double = 1.0

    // MARK: - View Settings
    var defaultViewMode: ViewMode = .list
    var defaultSortColumn: String = "name"
    var defaultSortAscending: Bool = true
    var showFolderSizes: Bool = false

    // MARK: - Tabs Settings
    var restoreTabsOnReopen: Bool = true

    // MARK: - Sidebar Settings
    var showFavorites: Bool = true
    var showRecents: Bool = true
    var showLocations: Bool = true
    var sidebarOrder: Int = 0
    var expandSidebarToCurrentDirectory: Bool = true

    // MARK: - Terminal Settings
    var openTerminalByDefault: Bool = false

    // MARK: - Status Bar Settings
    var showStatusBar: Bool = true

    // MARK: - File Operations Settings
    var autoRenameOnConflict: Bool = false
    var deleteWithBackspaceOnly: Bool = false
    var confirmCopyOperations: Bool = true
    var confirmMoveOperations: Bool = true
    var confirmDeleteOperations: Bool = true
    var showOperationProgress: Bool = true

    // MARK: - Filter Settings
    var filterCriteriaData: Data? = nil
    var searchHistory: [String] = []

    // MARK: - Toolbar Settings
    var showBackForwardButtons: Bool = true
    var showViewModeButton: Bool = true
    var showHiddenFilesButton: Bool = true
    var showSplitButtons: Bool = true
    var showPreviewPaneButton: Bool = true
    var showNewFolderButton: Bool = true
    var showSortButton: Bool = true
    var showStorageAnalyzerButton: Bool = true
    var showOpenTerminalButton: Bool = true

    // MARK: - Start Page Settings
    var hasLaunchedBefore: Bool = true
    var showStartOnLaunch: Bool = true
    var hasCompletedOnboarding: Bool = true
    var dismissedWelcome: Bool = true

    // MARK: - Go Menu Settings
    var showGoHome: Bool = true
    var showGoDesktop: Bool = true
    var showGoDocuments: Bool = true
    var showGoDownloads: Bool = true
    var showGoApplications: Bool = true
    var showGoUtilities: Bool = true
    var showGoLibrary: Bool = true
    var showGoComputer: Bool = true
    var showGoAirDrop: Bool = true
    var showGoNetwork: Bool = true
    var showGoiCloudDrive: Bool = true
    var showGoRecent: Bool = true
    var showGoConnectToServer: Bool = true

    // MARK: - Split Panes Settings
    var maximumPanes: Int = 2

    // MARK: - Window Layout Settings
    var sidebarFixedWidth: Double = 200.0
    var terminalIsVisible: Bool = false

    // MARK: - Favorites Widget Settings
    var favoriteWidgetFolders: [String] = []

    // MARK: - Storage Analyzer Settings
    var storageAnalyzerLastScanPath: String? = nil

    // MARK: - Context Menu Settings
    var showContextMenuHotkeys: Bool = true
    var hideOpenWith: Bool = false
    var hideGetInfo: Bool = false
    var hideCopy: Bool = false
    var hideCut: Bool = false
    var hidePaste: Bool = false
    var hideRename: Bool = false
    var hideMoveToTrash: Bool = false
    var hideNewFolder: Bool = false
    var hideShowInFinder: Bool = false
    
    // MARK: - Column Visibility
    var columnVisibility: [String: Bool] = [:]
    
    // MARK: - Hidden Files State
    var hiddenFilesState: Bool = false

    // MARK: - Settings Placement
    var openSettingsInTab: Bool = false

    // MARK: - Data Source Settings
    var folderSortPreferences: [String: String] = [:]

    // MARK: - Sidebar Favorites
    var sidebarFavorites: [String] = []
    
    // MARK: - Permissions Management
    var permissionsMigrationFlag: Bool = false
    var grantedDirectories: [String] = []
    var grantedDirectoryBookmarks: [Data] = []
    
    func lastContextualPermissionDate(for key: String) -> Date? { nil }
    func setLastContextualPermissionDate(_ date: Date, for key: String) {}
    
    // MARK: - Color Manager Settings
    var globalFolderColor: Data? = nil
    var globalFolderColorHex: String? = nil
    var folderColors: [String: String] = [:]

    // MARK: - View Options Settings
    func loadViewOptions() -> ViewOptions { ViewOptions() }
    func saveViewOptions(_ options: ViewOptions) {}

    // MARK: - Operation Metrics
    var operationMetricsLogData: Data? = nil

    // MARK: - Observability
    func addDelegate(_ delegate: SettingsStoreDelegate) {}
    func removeDelegate(_ delegate: SettingsStoreDelegate) {}

    // MARK: - Utility Methods
    func resetToDefaults() {}
    func data(forKey key: String) -> Data? { nil }
    func value(forKey key: String) -> Any? { nil }
    func setValue(_ value: Any?, forKey key: String) {}
    func removeValue(forKey key: String) {}
}
