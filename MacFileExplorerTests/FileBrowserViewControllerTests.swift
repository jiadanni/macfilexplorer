//
//  FileBrowserViewControllerTests.swift
//  MacFileExplorerTests
//
//  UI integration tests for FileBrowserViewController navigation and interactions
//

import XCTest
@testable import MacFileExplorer
import Foundation

class FileBrowserViewControllerTests: XCTestCase {

    // MARK: - Properties

    private var fileBrowserVC: FileBrowserViewController!
    private var tempDirectory: URL!
    private var testSettingsStore: SettingsStore!
    private var testDefaults: UserDefaults!
    private var settingsSuiteName: String!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create temporary test directory
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("FileBrowserVCTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Create test file structure
        try createTestFileStructure()

        // Setup isolated settings store
        settingsSuiteName = "com.macfileexplorer.fbvc.tests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: settingsSuiteName)!
        testDefaults.removePersistentDomain(forName: settingsSuiteName)
        testSettingsStore = SettingsStore(defaults: testDefaults)

        // Initialize FileBrowserViewController with test settings
        fileBrowserVC = FileBrowserViewController(settings: testSettingsStore)
    }

    override func tearDownWithError() throws {
        fileBrowserVC = nil
        testSettingsStore = nil

        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        if let suiteName = settingsSuiteName,
           let defaults = UserDefaults(suiteName: suiteName) {
            defaults.removePersistentDomain(forName: suiteName)
        }

        try super.tearDownWithError()
    }

    // MARK: - Helper Methods

    private func createTestFileStructure() throws {
        // Create directories
        let docsDir = tempDirectory.appendingPathComponent("Documents")
        let downloadsDir = tempDirectory.appendingPathComponent("Downloads")
        let photosDir = tempDirectory.appendingPathComponent("Photos")

        try FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)

        // Create test files
        let file1 = docsDir.appendingPathComponent("test1.txt")
        let file2 = docsDir.appendingPathComponent("test2.pdf")
        let hiddenFile = docsDir.appendingPathComponent(".hidden")

        try "Test content 1".write(to: file1, atomically: true, encoding: .utf8)
        try "Test content 2".write(to: file2, atomically: true, encoding: .utf8)
        try "Hidden content".write(to: hiddenFile, atomically: true, encoding: .utf8)

        // Create subdirectory with files
        let subDir = docsDir.appendingPathComponent("Subfolder")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let subFile = subDir.appendingPathComponent("subfile.txt")
        try "Subfolder content".write(to: subFile, atomically: true, encoding: .utf8)
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(fileBrowserVC)
        XCTAssertNotNil(fileBrowserVC.dataSource)
        XCTAssertEqual(fileBrowserVC.currentViewMode, testSettingsStore.defaultViewMode)
    }

    func testInitializationWithCustomSettings() {
        testSettingsStore.defaultViewMode = .icons
        let customVC = FileBrowserViewController(settings: testSettingsStore)

        XCTAssertEqual(customVC.currentViewMode, .icons)
    }

    // MARK: - Navigation Tests

    func testNavigateToDirectory() throws {
        let docsDir = tempDirectory.appendingPathComponent("Documents")
        XCTAssertTrue(FileManager.default.fileExists(atPath: docsDir.path))

        fileBrowserVC.navigationCoordinator.loadDirectory(docsDir)

        XCTAssertEqual(fileBrowserVC.currentDirectory, docsDir)
    }

    func testNavigateToParent() throws {
        let docsDir = tempDirectory.appendingPathComponent("Documents")
        let subDir = docsDir.appendingPathComponent("Subfolder")

        fileBrowserVC.navigationCoordinator.loadDirectory(subDir)
        XCTAssertEqual(fileBrowserVC.currentDirectory, subDir)

        fileBrowserVC.navigationCoordinator.navigateToParent()
        XCTAssertEqual(fileBrowserVC.currentDirectory, docsDir)
    }

    func testNavigationHistory() throws {
        let docsDir = tempDirectory.appendingPathComponent("Documents")
        let downloadsDir = tempDirectory.appendingPathComponent("Downloads")

        fileBrowserVC.navigationCoordinator.loadDirectory(docsDir)
        fileBrowserVC.navigationCoordinator.loadDirectory(downloadsDir)

        XCTAssertEqual(fileBrowserVC.currentDirectory, downloadsDir)

        fileBrowserVC.navigationCoordinator.goBack()
        XCTAssertEqual(fileBrowserVC.currentDirectory, docsDir)
    }

    // MARK: - Hidden Files Tests

    func testHiddenFilesToggle() {
        // Default should be false
        XCTAssertFalse(fileBrowserVC.showsHiddenFiles)

        // Toggle on
        fileBrowserVC.showsHiddenFilesState()
        XCTAssertTrue(fileBrowserVC.showsHiddenFiles)

        // Toggle off
        fileBrowserVC.showsHiddenFilesState()
        XCTAssertFalse(fileBrowserVC.showsHiddenFiles)
    }

    func testHiddenFilesPersistence() {
        fileBrowserVC.showsHiddenFilesState()
        let wasHidden = fileBrowserVC.showsHiddenFiles

        // Create new VC with same settings store
        let newVC = FileBrowserViewController(settings: testSettingsStore)
        XCTAssertEqual(newVC.showsHiddenFiles, wasHidden)
    }

    // MARK: - View Mode Tests

    func testViewModeSwitch_ListToIcons() {
        fileBrowserVC.currentViewMode = .list
        fileBrowserVC.viewModeCoordinator.displayFiles(for: .icons)

        // Give UI time to update
        let expectation = XCTestExpectation(description: "View mode updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(fileBrowserVC.currentViewMode, .icons)
    }

    func testViewModeSwitch_ListToColumns() {
        fileBrowserVC.currentViewMode = .list
        fileBrowserVC.viewModeCoordinator.displayFiles(for: .columns)

        let expectation = XCTestExpectation(description: "View mode updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(fileBrowserVC.currentViewMode, .columns)
    }

    // MARK: - Preview Pane Tests

    func testPreviewPaneVisibility() {
        XCTAssertFalse(fileBrowserVC.previewVisible)

        fileBrowserVC.previewPaneCoordinator.setPreviewPaneVisible(true)
        XCTAssertTrue(fileBrowserVC.previewVisible)

        fileBrowserVC.previewPaneCoordinator.setPreviewPaneVisible(false)
        XCTAssertFalse(fileBrowserVC.previewVisible)
    }

    func testPreviewPanePersistence() {
        fileBrowserVC.previewPaneCoordinator.setPreviewPaneVisible(true)
        let wasVisible = fileBrowserVC.previewVisible

        // Verify persistence through settings
        XCTAssertEqual(testSettingsStore.previewPaneVisible, wasVisible)
    }

    // MARK: - Sort Tests

    func testDefaultSortColumn() {
        XCTAssertEqual(fileBrowserVC.sortColumn, AppConfig.ColumnID.name)
    }

    func testSortColumnChange() {
        fileBrowserVC.sortColumn = AppConfig.ColumnID.size
        XCTAssertEqual(fileBrowserVC.sortColumn, AppConfig.ColumnID.size)
    }

    func testSortDirection() {
        XCTAssertTrue(fileBrowserVC.sortAscending)

        fileBrowserVC.sortAscending = false
        XCTAssertFalse(fileBrowserVC.sortAscending)
    }
}
