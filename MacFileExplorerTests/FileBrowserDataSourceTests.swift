import XCTest
@testable import MacFileExplorer

/// Comprehensive test suite for FileBrowserDataSource
///
/// Tests data loading, sorting, filtering, and search functionality
class FileBrowserDataSourceTests: XCTestCase {
    
    var sut: FileBrowserDataSource!
    var mockDelegate: MockDataSourceDelegate!
    var tempDirectory: URL!
    var testFiles: [URL] = []
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create temp directory with test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create test files
        let file1 = tempDirectory.appendingPathComponent("apple.txt")
        let file2 = tempDirectory.appendingPathComponent("banana.txt")
        let file3 = tempDirectory.appendingPathComponent("cherry.pdf")
        let hiddenFile = tempDirectory.appendingPathComponent(".hidden.txt")
        
        try "Content 1".write(to: file1, atomically: true, encoding: .utf8)
        try "Content 2 longer".write(to: file2, atomically: true, encoding: .utf8)
        try "Content 3".write(to: file3, atomically: true, encoding: .utf8)
        try "Hidden".write(to: hiddenFile, atomically: true, encoding: .utf8)
        
        testFiles = [file1, file2, file3, hiddenFile]
        
        mockDelegate = MockDataSourceDelegate()
        sut = FileBrowserDataSource(currentDirectory: tempDirectory)
        sut.delegate = mockDelegate
    }
    
    override func tearDownWithError() throws {
        // Clean up
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        
        sut = nil
        mockDelegate = nil
        tempDirectory = nil
        testFiles = []
        
        try super.tearDownWithError()
    }
    
    // MARK: - Data Loading Tests
    
    func testNavigate_LoadsDirectoryContents() {
        // Given
        let expectation = expectation(description: "Data loaded")
        mockDelegate.onDataLoaded = { items in
            expectation.fulfill()
        }
        
        // When
        sut.navigate(to: tempDirectory)
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(sut.rootItem, "Root item should be loaded")
        XCTAssertEqual(mockDelegate.loadedItemsCount, 3, "Should load 3 visible files (hidden file excluded)")
    }
    
    func testNavigate_WithShowHiddenFiles_LoadsHiddenFiles() {
        // Given
        sut.showsHiddenFiles = true
        let expectation = expectation(description: "Data loaded")
        mockDelegate.onDataLoaded = { items in
            expectation.fulfill()
        }
        
        // When
        sut.navigate(to: tempDirectory)
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(mockDelegate.loadedItemsCount, 4, "Should load all 4 files including hidden")
    }
    
    func testReload_RefreshesCurrentDirectory() {
        // Given
        sut.navigate(to: tempDirectory)
        Thread.sleep(forTimeInterval: 0.5) // Wait for initial load
        
        // Add new file
        let newFile = tempDirectory.appendingPathComponent("delta.txt")
        try? "New".write(to: newFile, atomically: true, encoding: .utf8)
        
        let expectation = expectation(description: "Reload completed")
        mockDelegate.onDataLoaded = { items in
            expectation.fulfill()
        }
        
        // When
        sut.reload()
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(mockDelegate.loadedItemsCount, 4, "Should load new file after reload")
    }
    
    // MARK: - Sorting Tests
    
    func testSortColumn_ByName_Ascending() {
        // Given
        let expectation = expectation(description: "Data loaded")
        mockDelegate.onDataLoaded = { _ in
            expectation.fulfill()
        }
        sut.navigate(to: tempDirectory)
        wait(for: [expectation], timeout: 2.0)
        
        // When
        sut.sortColumn = AppConfig.ColumnID.name
        sut.sortAscending = true
        
        // Then
        let children = sut.rootItem?.children ?? []
        XCTAssertTrue(children.count >= 2)
        if children.count >= 2,
           let first = children.safe(at: 0),
           let second = children.safe(at: 1) {
            XCTAssertLessThan(first.name, second.name, "Files should be sorted alphabetically")
        }
    }
    
    func testSortColumn_ByName_Descending() {
        // Given
        let expectation = expectation(description: "Data loaded")
        mockDelegate.onDataLoaded = { _ in
            expectation.fulfill()
        }
        sut.navigate(to: tempDirectory)
        wait(for: [expectation], timeout: 2.0)
        
        // When
        sut.sortColumn = AppConfig.ColumnID.name
        sut.sortAscending = false
        
        // Then
        let children = sut.rootItem?.children ?? []
        XCTAssertTrue(children.count >= 2)
        if children.count >= 2,
           let first = children.safe(at: 0),
           let second = children.safe(at: 1) {
            XCTAssertGreaterThan(first.name, second.name, "Files should be sorted reverse alphabetically")
        }
    }
    
    func testSortColumn_BySize() {
        // Given
        let expectation = expectation(description: "Data loaded")
        mockDelegate.onDataLoaded = { _ in
            expectation.fulfill()
        }
        sut.navigate(to: tempDirectory)
        wait(for: [expectation], timeout: 2.0)
        
        // When
        sut.sortColumn = AppConfig.ColumnID.size
        sut.sortAscending = false // Largest first
        
        // Then
        let children = sut.rootItem?.children ?? []
        if children.count >= 2,
           let first = children.safe(at: 0),
           let second = children.safe(at: 1) {
            XCTAssertGreaterThanOrEqual(first.size, second.size, "Files should be sorted by size descending")
        }
    }
    
    // MARK: - Filtering Tests
    
    func testSearchFilter_MatchingText_FiltersResults() {
        // Given
        sut.navigate(to: tempDirectory)
        Thread.sleep(forTimeInterval: 0.5)
        
        let expectation = expectation(description: "Filter applied")
        mockDelegate.onDataLoaded = { items in
            expectation.fulfill()
        }
        
        // When
        sut.searchFilter = "apple"
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        let children = sut.rootItem?.children ?? []
        XCTAssertEqual(children.count, 1, "Should match only 'apple.txt'")
        XCTAssertEqual(children.first?.name, "apple.txt")
    }
    
    func testSearchFilter_NoMatches_ReturnsEmpty() {
        // Given
        sut.navigate(to: tempDirectory)
        Thread.sleep(forTimeInterval: 0.5)
        
        let expectation = expectation(description: "Filter applied")
        mockDelegate.onDataLoaded = { items in
            expectation.fulfill()
        }
        
        // When
        sut.searchFilter = "nonexistent"
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        let children = sut.rootItem?.children ?? []
        XCTAssertEqual(children.count, 0, "Should return no matches")
    }
    
    func testFilterCriteria_ByFileType() {
        // Given
        sut.navigate(to: tempDirectory)
        Thread.sleep(forTimeInterval: 0.5)
        
        var criteria = FilterCriteria()
        criteria.fileTypes = ["pdf"]
        
        let expectation = expectation(description: "Filter applied")
        mockDelegate.onDataLoaded = { items in
            expectation.fulfill()
        }
        
        // When
        sut.filterCriteria = criteria
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        let children = sut.rootItem?.children ?? []
        XCTAssertEqual(children.count, 1, "Should match only .pdf file")
        XCTAssertEqual(children.first?.url.pathExtension, "pdf")
    }
    
    func testFilterCriteria_BySize() {
        // Given
        sut.navigate(to: tempDirectory)
        Thread.sleep(forTimeInterval: 0.5)
        
        var criteria = FilterCriteria()
        criteria.sizeMin = 10 // Only files >= 10 bytes
        
        let expectation = expectation(description: "Filter applied")
        mockDelegate.onDataLoaded = { items in
            expectation.fulfill()
        }
        
        // When
        sut.filterCriteria = criteria
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        let children = sut.rootItem?.children ?? []
        XCTAssertGreaterThan(children.count, 0, "Should have some matches")
        for child in children {
            XCTAssertGreaterThanOrEqual(child.size, 10, "All results should meet size criteria")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testNavigate_NonexistentPath_CallsErrorDelegate() {
        // Given
        let nonexistentPath = tempDirectory.appendingPathComponent("nonexistent")
        let expectation = expectation(description: "Error reported")
        mockDelegate.onError = { error in
            expectation.fulfill()
        }
        
        // When
        sut.navigate(to: nonexistentPath)
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(mockDelegate.didReceiveError, "Should report error for invalid path")
    }
    
    // MARK: - Google Drive Special Handling Tests
    
    func testNavigate_GoogleDrivePath_RedirectsToMyDrive() {
        // This test verifies the special case handling mentioned in the code review
        // Note: Actual Google Drive paths won't exist in test environment,
        // but we can verify the logic doesn't crash
        
        // Given
        let fakePath = URL(fileURLWithPath: "/Users/test/Google Drive/CloudStorage")
        
        // When/Then - Should not crash
        sut.navigate(to: fakePath)
        
        // The implementation should handle this gracefully
        XCTAssertNotNil(sut.currentDirectory, "Current directory should be set")
    }
}

// MARK: - Mock Delegate

class MockDataSourceDelegate: FileBrowserDataSourceDelegate {
    var loadedItemsCount = 0
    var didReceiveError = false
    var onDataLoaded: (([FileItem]) -> Void)?
    var onError: ((Error) -> Void)?
    
    func dataSource(_ dataSource: FileBrowserDataSource, didLoadItems items: [FileItem]) {
        loadedItemsCount = items.count
        onDataLoaded?(items)
    }
    
    func dataSource(_ dataSource: FileBrowserDataSource, didFailToLoad error: Error) {
        didReceiveError = true
        onError?(error)
    }
}
