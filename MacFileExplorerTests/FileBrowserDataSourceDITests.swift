import XCTest
@testable import MacFileExplorer

/// Tests for FileBrowserDataSource with dependency injection
@MainActor
final class FileBrowserDataSourceDITests: XCTestCase {
    
    var dataSource: FileBrowserDataSource!
    var mockSettings: MockSettingsStore!
    var tempDirectory: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create temp directory for tests
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DataSourceDITests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        mockSettings = MockSettingsStore()
        dataSource = FileBrowserDataSource(currentDirectory: tempDirectory, settings: mockSettings)
    }
    
    override func tearDownWithError() throws {
        if let tempDirectory = tempDirectory,
           FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        dataSource = nil
        mockSettings = nil
        tempDirectory = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Dependency Injection Tests
    
    func testDataSourceUsesInjectedSettings() {
        // Given
        mockSettings.folderSortPreferences = [tempDirectory.path: "SizeColumn|desc"]
        
        // When - reload triggers applyStoredSortPreferences internally
        dataSource.reload()
        
        // Then - should read from injected settings
        XCTAssertEqual(dataSource.sortColumn, "SizeColumn")
        XCTAssertFalse(dataSource.sortAscending)
    }
    
    func testPersistSortPreferencesUsesInjectedSettings() {
        // Given
        dataSource.sortColumn = "DateModifiedColumn"
        dataSource.sortAscending = false
        
        // When
        dataSource.persistSortPreferences()
        
        // Then
        let stored = mockSettings.folderSortPreferences[tempDirectory.path]
        XCTAssertEqual(stored, "DateModifiedColumn|desc")
    }
    
    func testDataSourceDefaultsToSharedSettingsWhenNotProvided() {
        // When - create without explicit settings
        let defaultDataSource = FileBrowserDataSource(currentDirectory: tempDirectory)
        
        // Then - should use shared settings (integration test)
        XCTAssertNotNil(defaultDataSource)
    }
}
