import XCTest
@testable import MacFileExplorer

/// Tests for the centralized SettingsStore.
///
/// These tests verify that:
/// - Settings can be read and written correctly
/// - Default values are returned when no value is set
/// - UserDefaults integration works properly
/// - Thread safety is maintained
class SettingsStoreTests: XCTestCase {
    
    var settingsStore: SettingsStore!
    var testDefaults: UserDefaults!
    var testSuiteName: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create a test UserDefaults suite to avoid polluting user preferences
        testSuiteName = "com.macfileexplorer.tests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        settingsStore = SettingsStore(defaults: testDefaults)
    }
    
    override func tearDownWithError() throws {
        // Clean up test suite
        if let suiteName = testSuiteName {
            testDefaults.removePersistentDomain(forName: suiteName)
        }
        settingsStore = nil
        testDefaults = nil
        testSuiteName = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - General Settings Tests
    
    func testHiddenFilesStateDefault() throws {
        XCTAssertFalse(settingsStore.hiddenFilesState, "hiddenFilesState should default to false")
    }
    
    func testHiddenFilesStateSetAndGet() throws {
        settingsStore.hiddenFilesState = true
        XCTAssertTrue(settingsStore.hiddenFilesState, "hiddenFilesState should be true after setting")
        
        settingsStore.hiddenFilesState = false
        XCTAssertFalse(settingsStore.hiddenFilesState, "hiddenFilesState should be false after setting")
    }
    
    func testShowFileExtensionsDefault() throws {
        XCTAssertTrue(settingsStore.showFileExtensions, "showFileExtensions should default to true")
    }
    
    func testShowFileExtensionsSetAndGet() throws {
        settingsStore.showFileExtensions = false
        XCTAssertFalse(settingsStore.showFileExtensions, "showFileExtensions should be false after setting")
        
        settingsStore.showFileExtensions = true
        XCTAssertTrue(settingsStore.showFileExtensions, "showFileExtensions should be true after setting")
    }
    
    func testUseGrayscaleIconsDefault() throws {
        XCTAssertFalse(settingsStore.useGrayscaleIcons, "useGrayscaleIcons should default to false")
    }
    
    func testUseGrayscaleIconsSetAndGet() throws {
        settingsStore.useGrayscaleIcons = true
        XCTAssertTrue(settingsStore.useGrayscaleIcons, "useGrayscaleIcons should be true after setting")
    }
    
    func testStartupFolder() throws {
        XCTAssertNil(settingsStore.startupFolder, "startupFolder should default to nil")
        
        let testPath = "/Users/test/Documents"
        settingsStore.startupFolder = testPath
        XCTAssertEqual(settingsStore.startupFolder, testPath, "startupFolder should match set value")
        
        settingsStore.startupFolder = nil
        XCTAssertNil(settingsStore.startupFolder, "startupFolder should be nil after clearing")
    }
    
    // MARK: - View Settings Tests
    
    func testDefaultViewModeDefault() throws {
        XCTAssertEqual(settingsStore.defaultViewMode, .list, "defaultViewMode should default to .list")
    }
    
    func testDefaultViewModeSetAndGet() throws {
        settingsStore.defaultViewMode = .icons
        XCTAssertEqual(settingsStore.defaultViewMode, .icons, "defaultViewMode should be .icons after setting")
        
        settingsStore.defaultViewMode = .columns
        XCTAssertEqual(settingsStore.defaultViewMode, .columns, "defaultViewMode should be .columns after setting")
    }
    
    func testDefaultSortColumn() throws {
        XCTAssertEqual(settingsStore.defaultSortColumn, "NameColumn", "defaultSortColumn should default to 'NameColumn'")
        
        settingsStore.defaultSortColumn = "SizeColumn"
        XCTAssertEqual(settingsStore.defaultSortColumn, "SizeColumn", "defaultSortColumn should be 'SizeColumn' after setting")
    }
    
    func testDefaultSortAscending() throws {
        XCTAssertTrue(settingsStore.defaultSortAscending, "defaultSortAscending should default to true")
        
        settingsStore.defaultSortAscending = false
        XCTAssertFalse(settingsStore.defaultSortAscending, "defaultSortAscending should be false after setting")
    }
    
    // MARK: - Preview Pane Tests
    
    func testPreviewPaneVisibleDefault() throws {
        XCTAssertFalse(settingsStore.previewPaneVisible, "previewPaneVisible should default to false")
    }
    
    func testPreviewPanePositionDefault() throws {
        XCTAssertEqual(settingsStore.previewPanePosition, "right", "previewPanePosition should default to 'right'")
    }
    
    func testPreviewPaneWidthDefault() throws {
        XCTAssertEqual(settingsStore.previewPaneWidth, 300.0, accuracy: 0.1, "previewPaneWidth should default to 300.0")
    }
    
    func testPreviewPaneWidthSetAndGet() throws {
        settingsStore.previewPaneWidth = 450.0
        XCTAssertEqual(settingsStore.previewPaneWidth, 450.0, accuracy: 0.1, "previewPaneWidth should be 450.0 after setting")
    }
    
    // MARK: - Sidebar Settings Tests
    
    func testShowFavoritesDefault() throws {
        XCTAssertTrue(settingsStore.showFavorites, "showFavorites should default to true")
    }
    
    func testShowRecentsDefault() throws {
        XCTAssertTrue(settingsStore.showRecents, "showRecents should default to true")
    }
    
    func testShowLocationsDefault() throws {
        XCTAssertTrue(settingsStore.showLocations, "showLocations should default to true")
    }
    
    func testSidebarOrderDefault() throws {
        XCTAssertEqual(settingsStore.sidebarOrder, 0, "sidebarOrder should default to 0")
    }
    
    // MARK: - File Operations Tests
    
    func testAutoRenameOnConflictDefault() throws {
        XCTAssertFalse(settingsStore.autoRenameOnConflict, "autoRenameOnConflict should default to false")
    }
    
    func testConfirmFileOperationsDefault() throws {
        XCTAssertTrue(settingsStore.confirmFileOperations, "confirmFileOperations should default to true")
    }
    
    func testShowOperationProgressDefault() throws {
        XCTAssertTrue(settingsStore.showOperationProgress, "showOperationProgress should default to true")
    }
    
    // MARK: - Toolbar Settings Tests
    
    func testShowBackForwardButtonsDefault() throws {
        XCTAssertTrue(settingsStore.showBackForwardButtons, "showBackForwardButtons should default to true")
    }
    
    func testShowViewModeButtonDefault() throws {
        XCTAssertTrue(settingsStore.showViewModeButton, "showViewModeButton should default to true")
    }
    
    // MARK: - Split Panes Tests
    
    func testMaximumPanesDefault() throws {
        XCTAssertEqual(settingsStore.maximumPanes, 2, "maximumPanes should default to 2")
    }
    
    func testMaximumPanesClamping() throws {
        settingsStore.maximumPanes = 10
        XCTAssertEqual(settingsStore.maximumPanes, 8, "maximumPanes should be clamped to 8")
        
        settingsStore.maximumPanes = 0
        XCTAssertEqual(settingsStore.maximumPanes, 1, "maximumPanes should be clamped to 1")
    }

    // MARK: - Appearance Settings Tests

    func testAccentColorSetAndGet() throws {
        let sampleData = Data([0x01, 0x02, 0x03])
        settingsStore.accentColor = sampleData
        XCTAssertEqual(settingsStore.accentColor, sampleData, "accentColor should round-trip")
    }

    // MARK: - Start Page Settings Tests

    func testDismissedWelcomeDefaultAndSet() throws {
        XCTAssertFalse(settingsStore.dismissedWelcome, "dismissedWelcome should default to false")
        settingsStore.dismissedWelcome = true
        XCTAssertTrue(settingsStore.dismissedWelcome, "dismissedWelcome should be true after setting")
    }

    func testHasCompletedOnboardingDefaultAndSet() throws {
        XCTAssertFalse(settingsStore.hasCompletedOnboarding, "hasCompletedOnboarding should default to false")
        settingsStore.hasCompletedOnboarding = true
        XCTAssertTrue(settingsStore.hasCompletedOnboarding, "hasCompletedOnboarding should be true after setting")
    }

    // MARK: - Go Menu Settings Tests

    func testGoMenuDefaults() throws {
        XCTAssertTrue(settingsStore.showGoHome, "showGoHome should default to true")
        XCTAssertTrue(settingsStore.showGoDownloads, "showGoDownloads should default to true")
        XCTAssertFalse(settingsStore.showGoDesktop, "showGoDesktop should default to false")
    }

    // MARK: - Window Layout Settings Tests

    func testSidebarFixedWidthSetAndGet() throws {
        settingsStore.sidebarFixedWidth = 220.0
        XCTAssertEqual(settingsStore.sidebarFixedWidth, 220.0, "sidebarFixedWidth should match set value")
    }

    func testTerminalVisibilitySetAndGet() throws {
        settingsStore.terminalIsVisible = true
        XCTAssertTrue(settingsStore.terminalIsVisible, "terminalIsVisible should be true after setting")
    }

    // MARK: - Favorites Widget Settings Tests

    func testFavoriteWidgetFoldersSetAndGet() throws {
        let paths = ["/", "/Users/test"]
        settingsStore.favoriteWidgetFolders = paths
        XCTAssertEqual(settingsStore.favoriteWidgetFolders, paths, "favoriteWidgetFolders should match set value")
    }

    // MARK: - Storage Analyzer Settings Tests

    func testStorageAnalyzerLastScanPathSetAndGet() throws {
        settingsStore.storageAnalyzerLastScanPath = "/Users/test"
        XCTAssertEqual(settingsStore.storageAnalyzerLastScanPath, "/Users/test", "storageAnalyzerLastScanPath should match set value")
    }

    // MARK: - View Options Tests

    func testViewOptionsRoundTrip() throws {
        var options = ViewOptions()
        options.iconSize = 128.0
        options.sortAscending = false
        options.groupBy = .kind
        settingsStore.saveViewOptions(options)

        let loaded = settingsStore.loadViewOptions()
        XCTAssertEqual(loaded.iconSize, 128.0, "viewOptions.iconSize should round-trip")
        XCTAssertEqual(loaded.sortAscending, false, "viewOptions.sortAscending should round-trip")
        XCTAssertEqual(loaded.groupBy, .kind, "viewOptions.groupBy should round-trip")
    }

    // MARK: - Operation Metrics Tests

    func testOperationMetricsLogDataSetAndGet() throws {
        let data = Data([0x0A, 0x0B])
        settingsStore.operationMetricsLogData = data
        XCTAssertEqual(settingsStore.operationMetricsLogData, data, "operationMetricsLogData should round-trip")
    }
    
    // MARK: - Reset Tests
    
    func testResetToDefaults() throws {
        // Set some non-default values
        settingsStore.hiddenFilesState = true
        settingsStore.useGrayscaleIcons = true
        settingsStore.defaultViewMode = .icons
        settingsStore.maximumPanes = 4
        
        // Verify they were set
        XCTAssertTrue(settingsStore.hiddenFilesState)
        XCTAssertTrue(settingsStore.useGrayscaleIcons)
        XCTAssertEqual(settingsStore.defaultViewMode, .icons)
        XCTAssertEqual(settingsStore.maximumPanes, 4)
        
        // Reset
        settingsStore.resetToDefaults()
        
        // Verify defaults are restored
        XCTAssertFalse(settingsStore.hiddenFilesState)
        XCTAssertFalse(settingsStore.useGrayscaleIcons)
        XCTAssertEqual(settingsStore.defaultViewMode, .list)
        XCTAssertEqual(settingsStore.maximumPanes, 2)
    }
    
    // MARK: - Persistence Tests
    
    func testSettingsPersistAcrossInstances() throws {
        // Set values in first instance
        settingsStore.hiddenFilesState = true
        settingsStore.defaultViewMode = .columns
        settingsStore.maximumPanes = 5
        
        // Create new instance with same UserDefaults
        let newStore = SettingsStore(defaults: testDefaults)
        
        // Verify values persisted
        XCTAssertTrue(newStore.hiddenFilesState, "hiddenFilesState should persist across instances")
        XCTAssertEqual(newStore.defaultViewMode, .columns, "defaultViewMode should persist across instances")
        XCTAssertEqual(newStore.maximumPanes, 5, "maximumPanes should persist across instances")
    }

    // MARK: - Delegate Tests

    func testMulticastDelegatesReceiveChanges() throws {
        let previewA = expectation(description: "delegateA preview update")
        let previewB = expectation(description: "delegateB preview update")
        let hiddenA = expectation(description: "delegateA hidden update")
        let hiddenB = expectation(description: "delegateB hidden update")

        let delegateA = SettingsStoreDelegateSpy()
        delegateA.onPreviewChange = { isVisible in
            XCTAssertTrue(isVisible)
            previewA.fulfill()
        }
        delegateA.onHiddenChange = { isVisible in
            XCTAssertTrue(isVisible)
            hiddenA.fulfill()
        }

        let delegateB = SettingsStoreDelegateSpy()
        delegateB.onPreviewChange = { isVisible in
            XCTAssertTrue(isVisible)
            previewB.fulfill()
        }
        delegateB.onHiddenChange = { isVisible in
            XCTAssertTrue(isVisible)
            hiddenB.fulfill()
        }

        settingsStore.addDelegate(delegateA)
        settingsStore.addDelegate(delegateB)

        settingsStore.previewPaneVisible = true
        settingsStore.hiddenFilesState = true

        wait(for: [previewA, previewB, hiddenA, hiddenB], timeout: 1.0)
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentReadWrite() throws {
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 100
        
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        // Perform 100 concurrent read/write operations
        for i in 0..<100 {
            queue.async {
                if i % 2 == 0 {
                    self.settingsStore.hiddenFilesState = true
                } else {
                    _ = self.settingsStore.hiddenFilesState
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        // Test passes if no crashes occur during concurrent access
    }
}

private final class SettingsStoreDelegateSpy: SettingsStoreDelegate {
    var onPreviewChange: ((Bool) -> Void)?
    var onHiddenChange: ((Bool) -> Void)?

    func settingsStore(_ settingsStore: SettingsStoreProtocol, previewPaneVisibilityDidChange isVisible: Bool) {
        onPreviewChange?(isVisible)
    }

    func settingsStore(_ settingsStore: SettingsStoreProtocol, hiddenFilesStateDidChange isVisible: Bool) {
        onHiddenChange?(isVisible)
    }
}
