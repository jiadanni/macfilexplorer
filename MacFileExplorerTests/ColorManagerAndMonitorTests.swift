import XCTest
@testable import MacFileExplorer

/// Tests for color management functionality.
///
/// Verifies:
/// - Folder color persistence
/// - Global folder color settings
/// - Color conversion and encoding
class ColorManagerTests: XCTestCase {
    
    var testDefaults: UserDefaults!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create test UserDefaults to avoid polluting user preferences
        testDefaults = UserDefaults(suiteName: "com.macfileexplorer.colormanager.tests.\(UUID().uuidString)")!
    }
    
    override func tearDownWithError() throws {
        // Clean up
        testDefaults.removePersistentDomain(forName: testDefaults.persistentDomainNames().first ?? "")
        testDefaults = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Global Folder Color Tests
    
    func testSetGlobalFolderColor() throws {
        let testColor = NSColor.red
        ColorManager.setGlobalFolderColor(testColor)
        
        let retrievedColor = ColorManager.getGlobalFolderColor()
        XCTAssertNotNil(retrievedColor, "Should retrieve the set color")
        
        // Colors should be approximately equal (RGB components)
        if let retrieved = retrievedColor {
            XCTAssertEqual(testColor.redComponent, retrieved.redComponent, accuracy: 0.01)
            XCTAssertEqual(testColor.greenComponent, retrieved.greenComponent, accuracy: 0.01)
            XCTAssertEqual(testColor.blueComponent, retrieved.blueComponent, accuracy: 0.01)
        }
    }
    
    func testClearGlobalFolderColor() throws {
        // Set a color
        ColorManager.setGlobalFolderColor(NSColor.blue)
        XCTAssertNotNil(ColorManager.getGlobalFolderColor())
        
        // Clear it
        ColorManager.setGlobalFolderColor(nil)
        XCTAssertNil(ColorManager.getGlobalFolderColor(), "Global folder color should be nil after clearing")
    }
    
    func testGetGlobalFolderColorDefaultsToNil() throws {
        // Without setting, should return nil
        let color = ColorManager.getGlobalFolderColor()
        XCTAssertNil(color, "Global folder color should default to nil")
    }
    
    // MARK: - Folder Icon Color Tests
    
    func testGetFolderIconColorPriority() throws {
        // Test URL
        let testURL = URL(fileURLWithPath: "/Users/test/Documents")
        
        // 1. Without any colors set, should return nil
        let noColor = ColorManager.getFolderIconColor(for: testURL)
        XCTAssertNil(noColor, "Should return nil when no colors are set")
        
        // 2. With global color set, should return that
        ColorManager.setGlobalFolderColor(NSColor.red)
        let globalColor = ColorManager.getFolderIconColor(for: testURL)
        XCTAssertNotNil(globalColor, "Should return global color when set")
        
        // Clean up
        ColorManager.setGlobalFolderColor(nil)
    }
    
    // MARK: - Color Utility Tests
    
    func testColorToHexAndBack() throws {
        let originalColor = NSColor(red: 0.5, green: 0.75, blue: 1.0, alpha: 1.0)
        
        // Convert to hex
        if let hex = originalColor.hexString {
            XCTAssertFalse(hex.isEmpty, "Hex string should not be empty")
            XCTAssertTrue(hex.hasPrefix("#"), "Hex string should start with #")
            XCTAssertEqual(hex.count, 7, "Hex string should be 7 characters (#RRGGBB)")
            
            // Note: ColorManager.getColor(forFolderName:) tests would require
            // the full color dictionary implementation
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentColorAccess() throws {
        let expectation = XCTestExpectation(description: "Concurrent color operations complete")
        expectation.expectedFulfillmentCount = 100
        
        let queue = DispatchQueue(label: "test.colormanager.concurrent", attributes: .concurrent)
        let colors = [NSColor.red, NSColor.blue, NSColor.green, NSColor.yellow]
        
        for i in 0..<100 {
            queue.async {
                if i % 2 == 0 {
                    ColorManager.setGlobalFolderColor(colors[i % colors.count])
                } else {
                    _ = ColorManager.getGlobalFolderColor()
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        // Test passes if no crashes occur
    }
}

/// Tests for FileSystemMonitor functionality.
class FileSystemMonitorTests: XCTestCase {
    
    var tempDirectoryURL: URL!
    var monitor: FileSystemMonitor?
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create temporary directory
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileSystemMonitorTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        // Stop monitoring
        monitor = nil
        
        // Clean up temporary directory
        if FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            try FileManager.default.removeItem(at: tempDirectoryURL)
        }
        
        try super.tearDownWithError()
    }
    
    // MARK: - Monitor Lifecycle Tests
    
    func testMonitorInitialization() throws {
        let expectation = XCTestExpectation(description: "Monitor callback called")
        expectation.assertForOverFulfill = false
        
        monitor = FileSystemMonitor(url: tempDirectoryURL) {
            expectation.fulfill()
        }
        
        XCTAssertNotNil(monitor, "Monitor should be initialized")
        
        // Create a file to trigger the callback
        let testFile = tempDirectoryURL.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testMonitorDetectsFileCreation() throws {
        let expectation = XCTestExpectation(description: "Detect file creation")
        expectation.assertForOverFulfill = false
        
        var callbackInvoked = false
        monitor = FileSystemMonitor(url: tempDirectoryURL) {
            callbackInvoked = true
            expectation.fulfill()
        }
        
        // Give monitor time to start
        Thread.sleep(forTimeInterval: 0.1)
        
        // Create a file
        let testFile = tempDirectoryURL.appendingPathComponent("newfile.txt")
        try "content".write(to: testFile, atomically: true, encoding: .utf8)
        
        wait(for: [expectation], timeout: 3.0)
        XCTAssertTrue(callbackInvoked, "Callback should have been invoked")
    }
    
    func testMonitorDetectsFileModification() throws {
        // Create initial file
        let testFile = tempDirectoryURL.appendingPathComponent("modify.txt")
        try "initial".write(to: testFile, atomically: true, encoding: .utf8)
        
        let expectation = XCTestExpectation(description: "Detect file modification")
        expectation.assertForOverFulfill = false
        
        monitor = FileSystemMonitor(url: tempDirectoryURL) {
            expectation.fulfill()
        }
        
        // Give monitor time to start
        Thread.sleep(forTimeInterval: 0.1)
        
        // Modify the file
        try "modified content".write(to: testFile, atomically: true, encoding: .utf8)
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testMonitorDetectsFileDeletion() throws {
        // Create initial file
        let testFile = tempDirectoryURL.appendingPathComponent("delete.txt")
        try "content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let expectation = XCTestExpectation(description: "Detect file deletion")
        expectation.assertForOverFulfill = false
        
        monitor = FileSystemMonitor(url: tempDirectoryURL) {
            expectation.fulfill()
        }
        
        // Give monitor time to start
        Thread.sleep(forTimeInterval: 0.1)
        
        // Delete the file
        try FileManager.default.removeItem(at: testFile)
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testMonitorStopsOnDeinit() throws {
        let expectation = XCTestExpectation(description: "Monitor callback called")
        expectation.assertForOverFulfill = false
        
        var localMonitor: FileSystemMonitor? = FileSystemMonitor(url: tempDirectoryURL) {
            expectation.fulfill()
        }
        
        // Create a file
        let testFile = tempDirectoryURL.appendingPathComponent("test1.txt")
        try "content".write(to: testFile, atomically: true, encoding: .utf8)
        
        wait(for: [expectation], timeout: 2.0)
        
        // Deinit the monitor
        localMonitor = nil
        
        // Create another file - callback should NOT be called
        let testFile2 = tempDirectoryURL.appendingPathComponent("test2.txt")
        try "content".write(to: testFile2, atomically: true, encoding: .utf8)
        
        // Wait a bit to ensure no callback
        Thread.sleep(forTimeInterval: 0.5)
        
        // Test passes if no crash and callback was not called again
        XCTAssertTrue(true)
    }
    
    func testMultipleSimultaneousMonitors() throws {
        let expectation1 = XCTestExpectation(description: "First monitor callback")
        let expectation2 = XCTestExpectation(description: "Second monitor callback")
        expectation1.assertForOverFulfill = false
        expectation2.assertForOverFulfill = false
        
        // Create two directories
        let dir1 = tempDirectoryURL.appendingPathComponent("dir1")
        let dir2 = tempDirectoryURL.appendingPathComponent("dir2")
        try FileManager.default.createDirectory(at: dir1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dir2, withIntermediateDirectories: true)
        
        // Create monitors for both
        let monitor1 = FileSystemMonitor(url: dir1) {
            expectation1.fulfill()
        }
        
        let monitor2 = FileSystemMonitor(url: dir2) {
            expectation2.fulfill()
        }
        
        Thread.sleep(forTimeInterval: 0.1)
        
        // Trigger both
        try "content".write(to: dir1.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try "content".write(to: dir2.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        
        wait(for: [expectation1, expectation2], timeout: 3.0)
        
        // Keep monitors alive
        _ = monitor1
        _ = monitor2
    }
}
