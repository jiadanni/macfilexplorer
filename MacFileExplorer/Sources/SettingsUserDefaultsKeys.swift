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
            [
                .warnOnExtensionChange, .enableEasySelect, .restoreTabsOnReopen, .showFavorites, .showRecents,
                .showLocations, .sidebarOrder, .openTerminalByDefault, .showContextMenuHotkeys, .hideOpenWith,
                .hideGetInfo, .hideCopy, .hideCut, .hidePaste, .hideRename, .hideMoveToTrash, .hideNewFolder,
                .hideShowInFinder, .expandSidebarToCurrentDirectory, .showStatusBar, .autoRenameOnConflict,
                .deleteWithBackspaceOnly, .confirmFileOperations, .showOperationProgress, .showBackForwardButtons,
                .showViewModeButton, .showHiddenFilesButton, .showSplitButtons, .showPreviewPaneButton,
                .showNewFolderButton, .showSortButton, .showOpenTerminalButton, .columnVisibility, .openSettingsInTab,
                .folderSortPreferences, .hiddenFilesState, .defaultViewMode, .defaultSortColumn, .defaultSortAscending,
                .maximumPanes, .showFolderSizes, .showGoHome, .showGoDesktop, .showGoDocuments, .showGoDownloads,
                .showGoApplications, .showGoUtilities, .showGoLibrary, .showGoComputer, .showGoAirDrop, .showGoNetwork,
                .showGoiCloudDrive, .showGoRecent, .showGoConnectToServer, .previewPaneWidth, .grantedDirectoriesPaths,
                .grantedDirectoryBookmarks, .grantedDirectoryBookmarksMigrated, .hasLaunchedBefore,
                .hasCompletedOnboarding, .showStartOnLaunch, .dismissedWelcome,
            ]
        }
    }
}

