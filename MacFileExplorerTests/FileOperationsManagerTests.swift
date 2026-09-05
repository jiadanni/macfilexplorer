import XCTest
@testable import MacFileExplorer

/// Comprehensive test suite for FileOperationsManager
///
/// Tests validation logic, drag & drop operations, and file operation coordination
class FileOperationsManagerTests: XCTestCase {
    
    var sut: FileOperationsManager!
    var mockDelegate: MockFileOperationsDelegate!
    var settingsStore: SettingsStore!
    var settingsSuiteName: String!
    var tempDirectory: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create temp directory for tests
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        settingsSuiteName = "com.macfileexplorer.fileoperations.tests.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: settingsSuiteName)!
        testDefaults.removePersistentDomain(forName: settingsSuiteName)
        settingsStore = SettingsStore(defaults: testDefaults)
        mockDelegate = MockFileOperationsDelegate()
        sut = FileOperationsManager(delegate: mockDelegate, settings: settingsStore)
    }
    
    override func tearDownWithError() throws {
        // Clean up temp directory
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        
        sut = nil
        mockDelegate = nil
        if let suiteName = settingsSuiteName,
           let defaults = UserDefaults(suiteName: suiteName) {
            defaults.removePersistentDomain(forName: suiteName)
        }
        settingsStore = nil
        settingsSuiteName = nil
        tempDirectory = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Destination Validation Tests
    
    func testIsValidDestination_ValidDestination_ReturnsTrue() {
        // Given
        let source = tempDirectory.appendingPathComponent("source.txt")
        let destination = tempDirectory.appendingPathComponent("subfolder", isDirectory: true)
        
        // When
        let isValid = sut.isValidDestination(destination, for: [source])
        
        // Then
        XCTAssertTrue(isValid, "Different paths should be valid")
    }
    
    func testIsValidDestination_SameDestination_ReturnsFalse() {
        // Given
        let source = tempDirectory.appendingPathComponent("file.txt")
        
        // When
        let isValid = sut.isValidDestination(source, for: [source])
        
        // Then
        XCTAssertFalse(isValid, "Cannot copy file to itself")
    }
    
    func testIsValidDestination_DestinationIsChildOfSource_ReturnsFalse() {
        // Given
        let source = tempDirectory.appendingPathComponent("folder", isDirectory: true)
        let destination = source.appendingPathComponent("subfolder", isDirectory: true)
        
        // When
        let isValid = sut.isValidDestination(destination, for: [source])
        
        // Then
        XCTAssertFalse(isValid, "Cannot copy folder into its own subfolder")
    }
    
    func testIsValidDestination_PathTraversalAttempt_ReturnsFalse() {
        // Given
        let source = tempDirectory.appendingPathComponent("folder", isDirectory: true)
        // Try to use path traversal to reference a child
        let maliciousPath = source.appendingPathComponent("../folder/child")
        
        // When
        let isValid = sut.isValidDestination(maliciousPath, for: [source])
        
        // Then
        XCTAssertFalse(isValid, "Path traversal should be prevented by canonical path comparison")
    }
    
    func testIsValidDestination_MultipleSourcesOneInvalid_ReturnsFalse() {
        // Given
        let validSource = tempDirectory.appendingPathComponent("file1.txt")
        let invalidSource = tempDirectory.appendingPathComponent("folder", isDirectory: true)
        let destination = invalidSource.appendingPathComponent("subfolder")
        
        // When
        let isValid = sut.isValidDestination(destination, for: [validSource, invalidSource])
        
        // Then
        XCTAssertFalse(isValid, "Should reject if any source is invalid")
    }
    
    func testIsValidDestination_NonExistentNestedDestination_ReturnsFalse() throws {
        // Given: a real source directory and a destination that does not exist on
        // disk yet but is nested inside it. The FileID check is a no-op here
        // (destination can't be stat'ed), so this exercises the string-prefix path.
        let source = tempDirectory.appendingPathComponent("realFolder", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let destination = source.appendingPathComponent("does/not/exist/yet", isDirectory: true)

        // When
        let isValid = sut.isValidDestination(destination, for: [source])

        // Then
        XCTAssertFalse(isValid, "Cannot move a folder into a not-yet-created path inside itself")
    }

    func testIsValidDestination_DestinationViaSymlinkIntoSource_ReturnsFalse() throws {
        // Given: source directory, and a symlink elsewhere that points back inside it.
        let source = tempDirectory.appendingPathComponent("srcDir", isDirectory: true)
        let realChild = source.appendingPathComponent("child", isDirectory: true)
        try FileManager.default.createDirectory(at: realChild, withIntermediateDirectories: true)

        let link = tempDirectory.appendingPathComponent("linkToChild")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: realChild)

        // When: the destination is given via the symlink, which resolves inside source.
        let isValid = sut.isValidDestination(link, for: [source])

        // Then
        XCTAssertFalse(isValid, "A symlinked destination that resolves inside the source must be rejected")
    }

    func testIsValidDestination_SourceViaSymlink_MatchesRealDestination_ReturnsFalse() throws {
        // Given: the source is passed via a symlink; the destination is the real path.
        let realDir = tempDirectory.appendingPathComponent("realDir", isDirectory: true)
        try FileManager.default.createDirectory(at: realDir, withIntermediateDirectories: true)

        let linkedSource = tempDirectory.appendingPathComponent("linkedSource")
        try FileManager.default.createSymbolicLink(at: linkedSource, withDestinationURL: realDir)

        // When
        let isValid = sut.isValidDestination(realDir, for: [linkedSource])

        // Then
        XCTAssertFalse(isValid, "Source and destination that resolve to the same path must be rejected")
    }

    func testIsValidDestination_SiblingWithSharedPrefix_ReturnsTrue() throws {
        // Given: "folder" and "folder2" share a string prefix but are siblings.
        let source = tempDirectory.appendingPathComponent("folder", isDirectory: true)
        let destination = tempDirectory.appendingPathComponent("folder2", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        // When
        let isValid = sut.isValidDestination(destination, for: [source])

        // Then
        XCTAssertTrue(isValid, "A sibling directory sharing a name prefix is a valid destination")
    }

    // MARK: - Drag Operation Tests
    
    func testPreferredDragOperation_OptionKey_ReturnsCopy() {
        // Given
        let mockDraggingInfo = MockDraggingInfo()
        mockDraggingInfo.mockSourceOperationMask = [.copy, .move]
        
        // When
        let operation = sut.preferredDragOperation(from: mockDraggingInfo, modifierFlags: [.option])
        
        // Then
        XCTAssertEqual(operation, .copy, "Option key should force copy operation")
    }
    
    func testPreferredDragOperation_NoModifiers_ReturnsMove() {
        // Given
        let mockDraggingInfo = MockDraggingInfo()
        mockDraggingInfo.mockSourceOperationMask = [.move, .copy]
        
        // When
        let operation = sut.preferredDragOperation(from: mockDraggingInfo, modifierFlags: [])
        
        // Then
        XCTAssertEqual(operation, .move, "Default should be move when available")
    }
    
    func testPreferredDragOperation_OnlyCopyAllowed_ReturnsCopy() {
        // Given
        let mockDraggingInfo = MockDraggingInfo()
        mockDraggingInfo.mockSourceOperationMask = [.copy]
        
        // When
        let operation = sut.preferredDragOperation(from: mockDraggingInfo, modifierFlags: [])
        
        // Then
        XCTAssertEqual(operation, .copy, "Should return copy if that's all that's allowed")
    }
    
    func testPreferredDragOperation_NoOperationsAllowed_ReturnsNil() {
        // Given
        let mockDraggingInfo = MockDraggingInfo()
        mockDraggingInfo.mockSourceOperationMask = []
        
        // When
        let operation = sut.preferredDragOperation(from: mockDraggingInfo, modifierFlags: [])
        
        // Then
        XCTAssertNil(operation, "Should return nil if no operations allowed")
    }
    
    // MARK: - File Operation Execution Tests
    
    func testPerform_WithConfirmationEnabled_ShowsDialog() {
        // Given
        settingsStore.confirmCopyOperations = true
        let source = tempDirectory.appendingPathComponent("file.txt")
        let destination = tempDirectory.appendingPathComponent("dest", isDirectory: true)
        
        // When
        sut.perform(.copy, items: [source], destination: destination, currentDirectory: tempDirectory)
        
        // Then
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        let hasSheet = mockDelegate.window?.attachedSheet != nil || !(mockDelegate.window?.sheets.isEmpty ?? true)
        XCTAssertTrue(hasSheet, "Should show confirmation dialog")
    }
    
    func testPerform_WithConfirmationDisabled_ExecutesDirectly() {
        // Given
        settingsStore.confirmCopyOperations = false
        settingsStore.showOperationProgress = false
        let source = tempDirectory.appendingPathComponent("file.txt")
        let destination = tempDirectory.appendingPathComponent("dest", isDirectory: true)
        
        // When
        sut.perform(.copy, items: [source], destination: destination, currentDirectory: tempDirectory)
        
        // Then
        // Since confirmation is disabled, should execute directly (no sheet shown)
        XCTAssertFalse(mockDelegate.didRequestPresentSheet, "Should not show dialog when disabled")
    }
    
    func testPerform_EmptyItems_DoesNothing() {
        // Given
        let destination = tempDirectory.appendingPathComponent("dest")
        
        // When
        sut.perform(.copy, items: [], destination: destination, currentDirectory: tempDirectory)
        
        // Then
        XCTAssertFalse(mockDelegate.didRequestPresentSheet)
        XCTAssertFalse(mockDelegate.didRequestRefresh)
    }
}

// MARK: - Mock Objects

class MockFileOperationsDelegate: FileOperationsManagerDelegate {
    var didRequestPresentSheet = false
    var didRequestPresentError = false
    var didRequestRefresh = false
    var lastErrorMessage: String?
    var window: NSWindow? = NSWindow()
    
    func fileOperationsManager(_ manager: FileOperationsManager, didRequestPresentSheet viewController: NSViewController) {
        didRequestPresentSheet = true
    }
    
    func fileOperationsManager(_ manager: FileOperationsManager, didRequestPresentError message: String) {
        didRequestPresentError = true
        lastErrorMessage = message
    }
    
    func fileOperationsManagerDidRequestRefresh(_ manager: FileOperationsManager) {
        didRequestRefresh = true
    }
    
    func fileOperationsManagerDidRequestRefreshSource(_ manager: FileOperationsManager, sourcePane: FileBrowserViewController) {
        // Not needed for these tests
    }
}

final class MockDraggingInfo: NSObject, NSDraggingInfo {
    var mockSourceOperationMask: NSDragOperation = []
    
    var draggingSourceOperationMask: NSDragOperation {
        return mockSourceOperationMask
    }

    // Required protocol implementations (stubbed)
    var draggingDestinationWindow: NSWindow? { nil }
    var draggingSequenceNumber: Int { 0 }
    var draggingLocation: NSPoint { .zero }
    var draggedImageLocation: NSPoint { .zero }
    var draggedImage: NSImage? { nil }
    var draggingPasteboard: NSPasteboard { NSPasteboard(name: .drag) }
    var draggingSource: Any? { nil }
    
    func slideDraggedImage(to screenPoint: NSPoint) {}
    override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }
    
    func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions = [], for view: NSView?, classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey : Any] = [:], using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
    
    var numberOfValidItemsForDrop: Int = 0
    var draggingFormation: NSDraggingFormation = .default
    var animatesToDestination: Bool = false
    
    var springLoadingHighlight: NSSpringLoadingHighlight { .standard }
    func resetSpringLoading() {}
}
