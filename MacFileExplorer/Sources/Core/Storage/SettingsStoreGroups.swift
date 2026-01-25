import Cocoa

/// Settings grouped into logical domains for better organization and maintainability
extension SettingsStore {
    
    // MARK: - Appearance Settings Group
    /// All appearance-related settings (colors, window controls, zoom, etc.)
    struct AppearanceSettings {
        private let store: SettingsStoreProtocol
        
        init(store: SettingsStoreProtocol) {
            self.store = store
        }
        
        var accentColor: NSColor? {
            get {
                guard let data = store.accentColor else { return .controlAccentColor }
                return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
            }
            set {
                if let color = newValue {
                    store.accentColor = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
                } else {
                    store.accentColor = nil
                }
            }
        }
        
        var globalFolderColor: Data? {
            get { store.globalFolderColor }
            set { store.globalFolderColor = newValue }
        }
        
        var folderColors: [String: String] {
            get { store.folderColors }
            set { store.folderColors = newValue }
        }
        
        var useGrayscaleWindowControls: Bool {
            get { store.useGrayscaleWindowControls }
            set { store.useGrayscaleWindowControls = newValue }
        }
        
        var zoomLevel: Double {
            get { store.zoomLevel }
            set { store.zoomLevel = newValue }
        }
    }
    
    // MARK: - View Settings Group
    /// File browser view and display settings
    struct ViewSettings {
        private let store: SettingsStoreProtocol
        
        init(store: SettingsStoreProtocol) {
            self.store = store
        }
        
        var defaultViewMode: ViewMode {
            get { store.defaultViewMode }
            set { store.defaultViewMode = newValue }
        }
        
        var defaultSortColumn: String {
            get { store.defaultSortColumn }
            set { store.defaultSortColumn = newValue }
        }
        
        var defaultSortAscending: Bool {
            get { store.defaultSortAscending }
            set { store.defaultSortAscending = newValue }
        }
        
        var showFolderSizes: Bool {
            get { store.showFolderSizes }
            set { store.showFolderSizes = newValue }
        }
        
        var showFileExtensions: Bool {
            get { store.showFileExtensions }
            set { store.showFileExtensions = newValue }
        }
        
        var hiddenFilesState: Bool {
            get { store.hiddenFilesState }
            set { store.hiddenFilesState = newValue }
        }
        
        var columnVisibility: [String: Bool] {
            get { store.columnVisibility }
            set { store.columnVisibility = newValue }
        }
        
        var folderSortPreferences: [String: String] {
            get { store.folderSortPreferences }
            set { store.folderSortPreferences = newValue }
        }
    }
    
    // MARK: - File Operations Settings Group
    /// Settings controlling file operation behavior
    struct FileOperationsSettings {
        private let store: SettingsStoreProtocol
        
        init(store: SettingsStoreProtocol) {
            self.store = store
        }
        
        var autoRenameOnConflict: Bool {
            get { store.autoRenameOnConflict }
            set { store.autoRenameOnConflict = newValue }
        }
        
        var confirmFileOperations: Bool {
            get { store.confirmFileOperations }
            set { store.confirmFileOperations = newValue }
        }
        
        var showOperationProgress: Bool {
            get { store.showOperationProgress }
            set { store.showOperationProgress = newValue }
        }
        
        var deleteWithBackspaceOnly: Bool {
            get { store.deleteWithBackspaceOnly }
            set { store.deleteWithBackspaceOnly = newValue }
        }
    }
    
    // MARK: - UI Visibility Settings Group
    /// Controls which UI elements are visible
    struct UIVisibilitySettings {
        private let store: SettingsStoreProtocol
        
        init(store: SettingsStoreProtocol) {
            self.store = store
        }
        
        // Toolbar buttons
        var showBackForwardButtons: Bool {
            get { store.showBackForwardButtons }
            set { store.showBackForwardButtons = newValue }
        }
        
        var showViewModeButton: Bool {
            get { store.showViewModeButton }
            set { store.showViewModeButton = newValue }
        }
        
        var showHiddenFilesButton: Bool {
            get { store.showHiddenFilesButton }
            set { store.showHiddenFilesButton = newValue }
        }
        
        var showSplitButtons: Bool {
            get { store.showSplitButtons }
            set { store.showSplitButtons = newValue }
        }
        
        var showPreviewPaneButton: Bool {
            get { store.showPreviewPaneButton }
            set { store.showPreviewPaneButton = newValue }
        }
        
        var showNewFolderButton: Bool {
            get { store.showNewFolderButton }
            set { store.showNewFolderButton = newValue }
        }
        
        var showSortButton: Bool {
            get { store.showSortButton }
            set { store.showSortButton = newValue }
        }
        
        var showStorageAnalyzerButton: Bool {
            get { store.showStorageAnalyzerButton }
            set { store.showStorageAnalyzerButton = newValue }
        }
        
        var showOpenTerminalButton: Bool {
            get { store.showOpenTerminalButton }
            set { store.showOpenTerminalButton = newValue }
        }
        
        // Other UI elements
        var showStatusBar: Bool {
            get { store.showStatusBar }
            set { store.showStatusBar = newValue }
        }
        
        var showContextMenuHotkeys: Bool {
            get { store.showContextMenuHotkeys }
            set { store.showContextMenuHotkeys = newValue }
        }
    }
    
    // MARK: - Context Menu Settings Group
    /// Controls which items appear in context menus
    struct ContextMenuSettings {
        private let store: SettingsStoreProtocol
        
        init(store: SettingsStoreProtocol) {
            self.store = store
        }
        
        var hideOpenWith: Bool {
            get { store.hideOpenWith }
            set { store.hideOpenWith = newValue }
        }
        
        var hideGetInfo: Bool {
            get { store.hideGetInfo }
            set { store.hideGetInfo = newValue }
        }
        
        var hideCopy: Bool {
            get { store.hideCopy }
            set { store.hideCopy = newValue }
        }
        
        var hideCut: Bool {
            get { store.hideCut }
            set { store.hideCut = newValue }
        }
        
        var hidePaste: Bool {
            get { store.hidePaste }
            set { store.hidePaste = newValue }
        }
        
        var hideRename: Bool {
            get { store.hideRename }
            set { store.hideRename = newValue }
        }
        
        var hideMoveToTrash: Bool {
            get { store.hideMoveToTrash }
            set { store.hideMoveToTrash = newValue }
        }
        
        var hideNewFolder: Bool {
            get { store.hideNewFolder }
            set { store.hideNewFolder = newValue }
        }
        
        var hideShowInFinder: Bool {
            get { store.hideShowInFinder }
            set { store.hideShowInFinder = newValue }
        }
    }
    
    // MARK: - Sidebar Settings Group
    struct SidebarSettings {
        private let store: SettingsStoreProtocol
        
        init(store: SettingsStoreProtocol) {
            self.store = store
        }
        
        var showFavorites: Bool {
            get { store.showFavorites }
            set { store.showFavorites = newValue }
        }
        
        var showRecents: Bool {
            get { store.showRecents }
            set { store.showRecents = newValue }
        }
        
        var showLocations: Bool {
            get { store.showLocations }
            set { store.showLocations = newValue }
        }
        
        var sidebarOrder: Int {
            get { store.sidebarOrder }
            set { store.sidebarOrder = newValue }
        }
        
        var expandSidebarToCurrentDirectory: Bool {
            get { store.expandSidebarToCurrentDirectory }
            set { store.expandSidebarToCurrentDirectory = newValue }
        }
        
        var sidebarFavorites: [String] {
            get { store.sidebarFavorites }
            set { store.sidebarFavorites = newValue }
        }
    }
    
    // MARK: - Go Menu Settings Group
    struct GoMenuSettings {
        private let store: SettingsStoreProtocol
        
        init(store: SettingsStoreProtocol) {
            self.store = store
        }
        
        var showGoHome: Bool {
            get { store.showGoHome }
            set { store.showGoHome = newValue }
        }
        
        var showGoDesktop: Bool {
            get { store.showGoDesktop }
            set { store.showGoDesktop = newValue }
        }
        
        var showGoDocuments: Bool {
            get { store.showGoDocuments }
            set { store.showGoDocuments = newValue }
        }
        
        var showGoDownloads: Bool {
            get { store.showGoDownloads }
            set { store.showGoDownloads = newValue }
        }
        
        var showGoApplications: Bool {
            get { store.showGoApplications }
            set { store.showGoApplications = newValue }
        }
        
        var showGoUtilities: Bool {
            get { store.showGoUtilities }
            set { store.showGoUtilities = newValue }
        }
        
        var showGoLibrary: Bool {
            get { store.showGoLibrary }
            set { store.showGoLibrary = newValue }
        }
        
        var showGoComputer: Bool {
            get { store.showGoComputer }
            set { store.showGoComputer = newValue }
        }
        
        var showGoAirDrop: Bool {
            get { store.showGoAirDrop }
            set { store.showGoAirDrop = newValue }
        }
        
        var showGoNetwork: Bool {
            get { store.showGoNetwork }
            set { store.showGoNetwork = newValue }
        }
        
        var showGoiCloudDrive: Bool {
            get { store.showGoiCloudDrive }
            set { store.showGoiCloudDrive = newValue }
        }
        
        var showGoRecent: Bool {
            get { store.showGoRecent }
            set { store.showGoRecent = newValue }
        }
        
        var showGoConnectToServer: Bool {
            get { store.showGoConnectToServer }
            set { store.showGoConnectToServer = newValue }
        }
    }
    
    // MARK: - Start Page Settings Group
    struct StartPageSettings {
        private let store: SettingsStoreProtocol
        
        init(store: SettingsStoreProtocol) {
            self.store = store
        }
        
        var hasLaunchedBefore: Bool {
            get { store.hasLaunchedBefore }
            set { store.hasLaunchedBefore = newValue }
        }
        
        var showStartOnLaunch: Bool {
            get { store.showStartOnLaunch }
            set { store.showStartOnLaunch = newValue }
        }
        
        var hasCompletedOnboarding: Bool {
            get { store.hasCompletedOnboarding }
            set { store.hasCompletedOnboarding = newValue }
        }
        
        var dismissedWelcome: Bool {
            get { store.dismissedWelcome }
            set { store.dismissedWelcome = newValue }
        }
        
        var favoriteWidgetFolders: [String] {
            get { store.favoriteWidgetFolders }
            set { store.favoriteWidgetFolders = newValue }
        }
    }
    
    // MARK: - Window & Layout Settings Group
    struct WindowLayoutSettings {
        private let store: SettingsStoreProtocol
        
        init(store: SettingsStoreProtocol) {
            self.store = store
        }
        
        var sidebarFixedWidth: Double {
            get { store.sidebarFixedWidth }
            set { store.sidebarFixedWidth = newValue }
        }
        
        var terminalIsVisible: Bool {
            get { store.terminalIsVisible }
            set { store.terminalIsVisible = newValue }
        }
        
        var previewPaneIsVisible: Bool {
            get { store.previewPaneVisible }
            set { store.previewPaneVisible = newValue }
        }
        
        var previewPaneWidth: CGFloat {
            get { store.previewPaneWidth }
            set { store.previewPaneWidth = newValue }
        }
        
        var maximumPanes: Int {
            get { store.maximumPanes }
            set { store.maximumPanes = newValue }
        }
        
        var restoreTabsOnReopen: Bool {
            get { store.restoreTabsOnReopen }
            set { store.restoreTabsOnReopen = newValue }
        }
        
        var openSettingsInTab: Bool {
            get { store.openSettingsInTab }
            set { store.openSettingsInTab = newValue }
        }
    }
    
    // MARK: - Terminal Settings Group
    struct TerminalSettings {
        private let store: SettingsStoreProtocol
        
        init(store: SettingsStoreProtocol) {
            self.store = store
        }
        
        var openTerminalByDefault: Bool {
            get { store.openTerminalByDefault }
            set { store.openTerminalByDefault = newValue }
        }
    }
    
    // MARK: - Other Settings Group
    struct OtherSettings {
        private let store: SettingsStoreProtocol
        
        init(store: SettingsStoreProtocol) {
            self.store = store
        }
        
        var enableEasySelect: Bool {
            get { store.enableEasySelect }
            set { store.enableEasySelect = newValue }
        }
        
        var filterCriteriaData: Data? {
            get { store.filterCriteriaData }
            set { store.filterCriteriaData = newValue }
        }
        
        var searchHistory: [String] {
            get { store.searchHistory }
            set { store.searchHistory = newValue }
        }
        
        var storageAnalyzerLastScanPath: String? {
            get { store.storageAnalyzerLastScanPath }
            set { store.storageAnalyzerLastScanPath = newValue }
        }
    }
}
