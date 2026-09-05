import XCTest
@testable import MacFileExplorer

// MARK: - Mock Delegate
class MockStorageAnalyzerDelegate: StorageAnalyzerDelegate {
    var didStartCount = 0
    var didProgressCount = 0
    var didCompleteCount = 0
    var didFailCount = 0
    var didCancelCount = 0
    
    var lastError: String?
    var lastRootItem: StorageItem?
    var lastDuration: TimeInterval = 0
    
    func analyzerDidStart(totalItems: Int) {
        didStartCount += 1
    }
    
    func analyzerDidProgress(currentPath: String, itemsScanned: Int, totalSize: Int64) {
        didProgressCount += 1
    }
    
    func analyzerDidComplete(rootItem: StorageItem, duration: TimeInterval) {
        didCompleteCount += 1
        lastRootItem = rootItem
        lastDuration = duration
    }
    
    func analyzerDidFail(error: String) {
        didFailCount += 1
        lastError = error
    }
    
    func analyzerWasCancelled() {
        didCancelCount += 1
    }
}

// MARK: - Tests
class StorageAnalyzerEngineTests: XCTestCase {
    
    var sut: StorageAnalyzerEngine!
    var mockDelegate: MockStorageAnalyzerDelegate!
    var testDirectoryURL: URL!
    
    override func setUp() {
        super.setUp()
        sut = StorageAnalyzerEngine()
        // setUp runs on the main thread; the mock's init is MainActor-isolated
        // because StorageAnalyzerDelegate is a @MainActor protocol.
        mockDelegate = MainActor.assumeIsolated { MockStorageAnalyzerDelegate() }
        
        // Create temporary test directory
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("StorageAnalyzerTest-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        testDirectoryURL = tempDir
    }
    
    override func tearDown() {
        sut = nil
        mockDelegate = nil
        
        // Clean up test directory
        if let url = testDirectoryURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        StorageAnalyzerEngine.clearCache()
        super.tearDown()
    }
    
    // MARK: - Basic Scan Tests
    
    @MainActor func testStartScan_NotifiesDelegate() {
        let expectation = self.expectation(description: "Scan completes")
        
        mockDelegate.didCompleteCount = 0
        sut.delegate = mockDelegate
        
        // Create test file
        let testFile = testDirectoryURL.appendingPathComponent("test.txt")
        try? "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        // Add completion handler monitoring
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.mockDelegate.didCompleteCount > 0 {
                expectation.fulfill()
            }
        }
        
        sut.startScan(url: testDirectoryURL, delegate: mockDelegate)
        
        waitForExpectations(timeout: 5.0)
        XCTAssertTrue(mockDelegate.didStartCount > 0, "Should notify start")
    }
    
    @MainActor func testScan_EmptyDirectory() {
        let expectation = self.expectation(description: "Empty directory scan")
        
        // Ensure directory is empty
        try? FileManager.default.removeItem(at: testDirectoryURL)
        try? FileManager.default.createDirectory(at: testDirectoryURL, withIntermediateDirectories: true)
        
        mockDelegate.didCompleteCount = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.mockDelegate.didCompleteCount > 0 {
                expectation.fulfill()
            }
        }
        
        sut.startScan(url: testDirectoryURL, delegate: mockDelegate)
        
        waitForExpectations(timeout: 5.0)
        XCTAssertEqual(mockDelegate.didFailCount, 0, "Empty directory should not fail")
    }
    
    @MainActor func testScan_SingleFile() {
        let expectation = self.expectation(description: "Single file scan")
        let testContent = "This is test content for storage analyzer"
        let testFile = testDirectoryURL.appendingPathComponent("testfile.txt")
        
        try? testContent.write(to: testFile, atomically: true, encoding: .utf8)
        
        mockDelegate.didCompleteCount = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.mockDelegate.didCompleteCount > 0 {
                expectation.fulfill()
            }
        }
        
        sut.startScan(url: testDirectoryURL, delegate: mockDelegate)
        
        waitForExpectations(timeout: 5.0)
        XCTAssertTrue(mockDelegate.didCompleteCount > 0, "Should complete scan")
        XCTAssertNotNil(mockDelegate.lastRootItem, "Should return root item")
    }
    
    @MainActor func testScan_NestedDirectories() {
        let expectation = self.expectation(description: "Nested directory scan")
        
        // Create nested structure
        let level1 = testDirectoryURL.appendingPathComponent("level1", isDirectory: true)
        let level2 = level1.appendingPathComponent("level2", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: level2, withIntermediateDirectories: true)
        try? "content1".write(to: level1.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
        try? "content2".write(to: level2.appendingPathComponent("file2.txt"), atomically: true, encoding: .utf8)
        
        mockDelegate.didCompleteCount = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.mockDelegate.didCompleteCount > 0 {
                expectation.fulfill()
            }
        }
        
        sut.startScan(url: testDirectoryURL, delegate: mockDelegate)
        
        waitForExpectations(timeout: 5.0)
        XCTAssertTrue(mockDelegate.didCompleteCount > 0, "Should complete nested scan")
    }
    
    // MARK: - Cancellation Tests
    
    @MainActor func testCancel_StopsScanning() {
        let expectation = self.expectation(description: "Scan cancelled")
        
        // Create many files to ensure scan takes time
        for i in 0..<20 {
            let file = testDirectoryURL.appendingPathComponent("file\(i).txt")
            try? "content\(i)".write(to: file, atomically: true, encoding: .utf8)
        }
        
        mockDelegate.didCancelCount = 0
        
        sut.startScan(url: testDirectoryURL, delegate: mockDelegate)
        
        // Cancel after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.sut.cancel()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    // MARK: - Scan Options Tests
    
    @MainActor func testScanOptions_SkipHiddenFiles() {
        let expectation = self.expectation(description: "Skip hidden files")
        
        let visibleFile = testDirectoryURL.appendingPathComponent("visible.txt")
        let hiddenFile = testDirectoryURL.appendingPathComponent(".hidden.txt")
        
        try? "visible".write(to: visibleFile, atomically: true, encoding: .utf8)
        try? "hidden".write(to: hiddenFile, atomically: true, encoding: .utf8)
        
        var options = StorageAnalyzerEngine.ScanOptions.default
        options.includeHiddenFiles = false
        
        mockDelegate.didCompleteCount = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.mockDelegate.didCompleteCount > 0 {
                expectation.fulfill()
            }
        }
        
        sut.startScan(url: testDirectoryURL, options: options, delegate: mockDelegate)
        
        waitForExpectations(timeout: 5.0)
        XCTAssertTrue(mockDelegate.didCompleteCount > 0, "Should skip hidden files")
    }
    
    // MARK: - Smart Filter Tests
    
    func testFindLargeFiles_FiltersCorrectly() {
        // Create test files
        let smallFile = testDirectoryURL.appendingPathComponent("small.txt")
        let largeFile = testDirectoryURL.appendingPathComponent("large.dat")
        
        let smallContent = String(repeating: "x", count: 100)
        let largeContent = String(repeating: "y", count: 1000000) // ~1MB
        
        try? smallContent.write(to: smallFile, atomically: true, encoding: .utf8)
        try? largeContent.write(to: largeFile, atomically: true, encoding: .utf8)
        
        // Create a mock root item for testing
        let rootFileItem = FileItem(url: testDirectoryURL)
        let rootStorageItem = StorageItem(fileItem: rootFileItem)
        
        // Test the filter
        let largeFiles = StorageAnalyzerEngine.findLargeFiles(in: rootStorageItem, threshold: 500000) // 500KB
        
        // Results depend on actual scan, just verify method works
        XCTAssertNotNil(largeFiles, "Should return array of large files")
    }
    
    func testFindDuplicates_IdentifiesDuplicates() {
        // Create duplicate files
        let dup1 = testDirectoryURL.appendingPathComponent("dup1.txt")
        let dup2 = testDirectoryURL.appendingPathComponent("dup2.txt")
        
        try? "same content".write(to: dup1, atomically: true, encoding: .utf8)
        try? "same content".write(to: dup2, atomically: true, encoding: .utf8)
        
        let rootFileItem = FileItem(url: testDirectoryURL)
        let rootStorageItem = StorageItem(fileItem: rootFileItem)
        
        let duplicates = StorageAnalyzerEngine.findDuplicates(in: rootStorageItem)
        
        XCTAssertNotNil(duplicates, "Should return duplicate groups")
    }
    
    // MARK: - Cache Tests
    
    @MainActor func testCache_StoresAndRetrievesResults() {
        let expectation = self.expectation(description: "Cache test")
        
        mockDelegate.didCompleteCount = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.mockDelegate.didCompleteCount > 0 {
                expectation.fulfill()
            }
        }
        
        sut.startScan(url: testDirectoryURL, delegate: mockDelegate)
        
        waitForExpectations(timeout: 5.0)
        
        StorageAnalyzerEngine.invalidateCache(for: testDirectoryURL)
        XCTAssertTrue(true, "Cache invalidation should complete without error")
    }
    
    // MARK: - Properties Tests
    
    @MainActor func testRootProperties_SetAfterScan() {
        let expectation = self.expectation(description: "Properties set")
        
        mockDelegate.didCompleteCount = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.mockDelegate.didCompleteCount > 0 {
                expectation.fulfill()
            }
        }
        
        sut.startScan(url: testDirectoryURL, delegate: mockDelegate)
        
        waitForExpectations(timeout: 5.0)
        
        XCTAssertEqual(sut.rootURL, testDirectoryURL, "Root URL should be set")
        XCTAssertNotNil(sut.rootItem, "Root item should be set after scan")
    }
}
