import XCTest
@testable import MacFileExplorer

/// Tests for the PermissionsManager singleton.
///
/// These tests verify:
/// - Bookmark creation and resolution
/// - Security-scoped URL lifecycle management
/// - Thread-safe access to active URLs
/// - Permission status checking
class PermissionsManagerTests: XCTestCase {
    
    var permissionsManager: PermissionsManager!
    var tempDirectoryURL: URL!
    private var originalGrantedDirectories: [String] = []
    private var originalGrantedDirectoryBookmarks: [Data] = []
    private var originalMigrationFlag: Bool = false
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        permissionsManager = PermissionsManager.shared
        originalGrantedDirectories = SettingsStore.shared.grantedDirectories
        originalGrantedDirectoryBookmarks = SettingsStore.shared.grantedDirectoryBookmarks
        originalMigrationFlag = SettingsStore.shared.permissionsMigrationFlag
        SettingsStore.shared.grantedDirectories = []
        SettingsStore.shared.grantedDirectoryBookmarks = []
        SettingsStore.shared.permissionsMigrationFlag = false
        
        // Create temporary directory for testing
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PermissionsTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        // Clean up temporary directory
        if FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            try FileManager.default.removeItem(at: tempDirectoryURL)
        }
        SettingsStore.shared.grantedDirectories = originalGrantedDirectories
        SettingsStore.shared.grantedDirectoryBookmarks = originalGrantedDirectoryBookmarks
        SettingsStore.shared.permissionsMigrationFlag = originalMigrationFlag
        
        try super.tearDownWithError()
    }
    
    // MARK: - Granted Directories Tests
    
    func testAddGrantedDirectory() throws {
        let initialCount = permissionsManager.grantedDirectories().count
        
        permissionsManager.addGrantedDirectory(tempDirectoryURL)
        
        let grantedDirs = permissionsManager.grantedDirectories()
        XCTAssertEqual(grantedDirs.count, initialCount + 1, "Should have one more granted directory")
        let targetPath = tempDirectoryURL.resolvingSymlinksInPath().standardizedFileURL.path
        let containsGranted = grantedDirs.contains {
            $0.resolvingSymlinksInPath().standardizedFileURL.path == targetPath
        }
        XCTAssertTrue(containsGranted, "Should contain the added directory")
    }
    
    func testRemoveGrantedDirectory() throws {
        // Add directory first
        permissionsManager.addGrantedDirectory(tempDirectoryURL)
        XCTAssertTrue(permissionsManager.hasGrantedDirectory(tempDirectoryURL), "Directory should be granted")
        
        // Remove it
        permissionsManager.removeGrantedDirectory(tempDirectoryURL)
        XCTAssertFalse(permissionsManager.hasGrantedDirectory(tempDirectoryURL), "Directory should no longer be granted")
    }
    
    func testHasGrantedDirectory() throws {
        XCTAssertFalse(permissionsManager.hasGrantedDirectory(tempDirectoryURL), "Directory should not be granted initially")
        
        permissionsManager.addGrantedDirectory(tempDirectoryURL)
        XCTAssertTrue(permissionsManager.hasGrantedDirectory(tempDirectoryURL), "Directory should be granted after adding")
    }
    
    func testReplaceGrantedDirectory() throws {
        let oldURL = tempDirectoryURL!
        let newURL = tempDirectoryURL.appendingPathComponent("subfolder")
        try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: true)
        
        permissionsManager.addGrantedDirectory(oldURL)
        XCTAssertTrue(permissionsManager.hasGrantedDirectory(oldURL))
        
        permissionsManager.replaceGrantedDirectory(oldURL: oldURL, with: newURL)
        
        XCTAssertFalse(permissionsManager.hasGrantedDirectory(oldURL), "Old directory should no longer be granted")
        XCTAssertTrue(permissionsManager.hasGrantedDirectory(newURL), "New directory should be granted")
    }
    
    // MARK: - Resolved Entries Tests
    
    func testResolvedGrantedDirectoryEntries() throws {
        permissionsManager.addGrantedDirectory(tempDirectoryURL)
        
        let entries = permissionsManager.resolvedGrantedDirectoryEntries()
        
        XCTAssertGreaterThan(entries.count, 0, "Should have at least one entry")
        
        // Find our test directory entry
        let testEntry = entries.first { $0.path == tempDirectoryURL.path }
        XCTAssertNotNil(testEntry, "Should find our test directory")
        XCTAssertTrue(testEntry?.isValid ?? false, "Entry should be valid")
        XCTAssertFalse(testEntry?.isStale ?? true, "Entry should not be stale")
    }
    
    // MARK: - Permission Status Tests
    
    func testCheckFullDiskAccessPermission() throws {
        let status = permissionsManager.checkPermissionStatus(for: .fullDiskAccess)
        
        // Status should be either granted or denied, not notDetermined
        XCTAssertTrue(status == .granted || status == .denied, "Full Disk Access status should be determined")
    }
    
    func testCheckPhotosPermission() throws {
        let status = permissionsManager.checkPermissionStatus(for: .photos)
        
        // Status can be any of the valid states
        XCTAssertTrue([.granted, .denied, .notDetermined, .notApplicable].contains(status), 
                      "Photos status should be a valid PermissionStatus")
    }
    
    func testCheckCameraPermission() throws {
        let status = permissionsManager.checkPermissionStatus(for: .camera)
        
        // Status can be any of the valid states
        XCTAssertTrue([.granted, .denied, .notDetermined, .notApplicable].contains(status), 
                      "Camera status should be a valid PermissionStatus")
    }
    
    func testCheckMicrophonePermission() throws {
        let status = permissionsManager.checkPermissionStatus(for: .microphone)
        
        // Status can be any of the valid states
        XCTAssertTrue([.granted, .denied, .notDetermined, .notApplicable].contains(status), 
                      "Microphone status should be a valid PermissionStatus")
    }
    
    // MARK: - Permission Type Tests
    
    func testPermissionTypeIcons() throws {
        XCTAssertEqual(PermissionType.fullDiskAccess.icon, "internaldrive")
        XCTAssertEqual(PermissionType.photos.icon, "photo")
        XCTAssertEqual(PermissionType.camera.icon, "camera")
        XCTAssertEqual(PermissionType.microphone.icon, "mic")
    }
    
    func testPermissionTypeDescriptions() throws {
        XCTAssertFalse(PermissionType.fullDiskAccess.description.isEmpty)
        XCTAssertFalse(PermissionType.photos.description.isEmpty)
        XCTAssertFalse(PermissionType.camera.description.isEmpty)
        XCTAssertFalse(PermissionType.microphone.description.isEmpty)
    }
    
    func testPermissionTypeAllCases() throws {
        XCTAssertEqual(PermissionType.allCases.count, 4, "Should have 4 permission types")
        XCTAssertTrue(PermissionType.allCases.contains(.fullDiskAccess))
        XCTAssertTrue(PermissionType.allCases.contains(.photos))
        XCTAssertTrue(PermissionType.allCases.contains(.camera))
        XCTAssertTrue(PermissionType.allCases.contains(.microphone))
    }
    
    // MARK: - Permission Status Tests
    
    func testPermissionStatusDisplayText() throws {
        XCTAssertEqual(PermissionStatus.granted.displayText, "Granted")
        XCTAssertEqual(PermissionStatus.denied.displayText, "Denied")
        XCTAssertEqual(PermissionStatus.notDetermined.displayText, "Not Requested")
        XCTAssertEqual(PermissionStatus.notApplicable.displayText, "N/A")
    }
    
    func testPermissionStatusColors() throws {
        // Verify that colors are set (not nil/default)
        XCTAssertNotNil(PermissionStatus.granted.color)
        XCTAssertNotNil(PermissionStatus.denied.color)
        XCTAssertNotNil(PermissionStatus.notDetermined.color)
        XCTAssertNotNil(PermissionStatus.notApplicable.color)
        
        // Verify explicit status colors are distinct (exclude dynamic system color)
        let colors = [
            PermissionStatus.granted.color,
            PermissionStatus.denied.color,
            PermissionStatus.notDetermined.color
        ]
        let uniqueColors = Set(colors.map { "\($0.redComponent),\($0.greenComponent),\($0.blueComponent)" })
        XCTAssertEqual(uniqueColors.count, 3, "Explicit permission status colors should be distinct")
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAddRemoveDirectories() throws {
        let expectation = XCTestExpectation(description: "Concurrent directory operations complete")
        expectation.expectedFulfillmentCount = 50
        
        let queue = DispatchQueue(label: "test.permissions.concurrent", attributes: .concurrent)
        
        // Create test URLs
        var testURLs: [URL] = []
        for i in 0..<10 {
            let url = tempDirectoryURL.appendingPathComponent("test\(i)")
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            testURLs.append(url)
        }
        
        // Perform concurrent add/remove operations
        for i in 0..<50 {
            queue.async {
                let url = testURLs[i % testURLs.count]
                if i % 2 == 0 {
                    self.permissionsManager.addGrantedDirectory(url)
                } else {
                    self.permissionsManager.removeGrantedDirectory(url)
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        // Test passes if no crashes occur during concurrent access
    }
    
    func testConcurrentAccessChecks() throws {
        let expectation = XCTestExpectation(description: "Concurrent access checks complete")
        expectation.expectedFulfillmentCount = 100
        
        let queue = DispatchQueue(label: "test.permissions.access", attributes: .concurrent)
        
        permissionsManager.addGrantedDirectory(tempDirectoryURL)
        
        // Perform concurrent access checks
        for _ in 0..<100 {
            queue.async {
                _ = self.permissionsManager.hasGrantedDirectory(self.tempDirectoryURL)
                _ = self.permissionsManager.ensureAccess(for: self.tempDirectoryURL)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        // Test passes if no crashes occur
    }
    
    // MARK: - Security Scoped URL Lifecycle Tests
    
    func testStartStopAccessingSecurityScoped() throws {
        // This test verifies the lifecycle methods don't crash
        // Actual security-scoped behavior requires sandboxing
        
        permissionsManager.addGrantedDirectory(tempDirectoryURL)
        
        // These should not crash even if not in sandbox
        permissionsManager.startAccessingAllSecurityScoped()
        permissionsManager.stopAccessingAllSecurityScoped()
        
        // Test passes if no exception thrown
        XCTAssertTrue(true)
    }
    
    func testEnsureAccessForSubpath() throws {
        permissionsManager.addGrantedDirectory(tempDirectoryURL)
        
        // Create a subdirectory
        let subDir = tempDirectoryURL.appendingPathComponent("subfolder")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        // Ensure access for subpath should work
        let hasAccess = permissionsManager.ensureAccess(for: subDir)
        
        // Should return true (either granted or not sandboxed)
        XCTAssertTrue(hasAccess, "Should have access to subdirectory of granted directory")
    }
}
