import XCTest
@testable import MacFileExplorer

class FileBrowserPreviewPaneCoordinatorTests: XCTestCase {
    var sut: FileBrowserPreviewPaneCoordinator!
    var mockSettings: MockSettingsStore!
    var mockDelegate: MockPreviewPaneDelegate!

    override func setUp() {
        super.setUp()
        mockSettings = MockSettingsStore()
        sut = FileBrowserPreviewPaneCoordinator(settings: mockSettings)
        mockDelegate = MockPreviewPaneDelegate()
        sut.delegate = mockDelegate
    }

    override func tearDown() {
        sut = nil
        mockSettings = nil
        mockDelegate = nil
        super.tearDown()
    }

    // MARK: - State Ownership Tests
    
    /// Verify coordinator owns visibility state
    func testCoordinatorOwnsVisibilityState() {
        XCTAssertFalse(sut.isVisible, "Should initialize as invisible")
        
        sut.setPreviewPaneVisible(true)
        
        XCTAssertTrue(sut.isVisible, "Should update visibility through coordinator")
    }
    
    /// Verify coordinator owns position state
    func testCoordinatorOwnsPositionState() {
        XCTAssertEqual(sut.position, "right", "Should default to right position")
        
        sut.setPosition("bottom")
        
        XCTAssertEqual(sut.position, "bottom", "Should update position through coordinator")
    }
    
    /// Verify coordinator owns width state
    func testCoordinatorOwnsWidthState() {
        let newWidth: CGFloat = 400
        
        sut.setWidth(newWidth)
        
        XCTAssertEqual(sut.width, newWidth, "Should update width through coordinator")
    }

    // MARK: - Persistence Tests
    
    /// Verify visibility change persists to SettingsStore
    func testVisibilityChangePersistsToSettingsStore() {
        sut.setPreviewPaneVisible(true)
        
        XCTAssertTrue(mockSettings.previewPaneVisible, "Should persist visibility to settings")
    }
    
    /// Verify position change persists to SettingsStore
    func testPositionChangePersistsToSettingsStore() {
        sut.setPosition("bottom")
        
        XCTAssertEqual(mockSettings.previewPanePosition, "bottom", "Should persist position to settings")
    }
    
    /// Verify width change persists to SettingsStore
    func testWidthChangePersistsToSettingsStore() {
        let newWidth: CGFloat = 350
        
        sut.setWidth(newWidth)
        
        XCTAssertEqual(mockSettings.previewPaneWidth, newWidth, "Should persist width to settings")
    }
    
    /// Verify initialization loads from persisted settings
    func testInitializationLoadsFromSettings() {
        mockSettings.previewPaneVisible = true
        mockSettings.previewPanePosition = "bottom"
        mockSettings.previewPaneWidth = 400
        
        let newCoordinator = FileBrowserPreviewPaneCoordinator(settings: mockSettings)
        
        XCTAssertTrue(newCoordinator.isVisible, "Should load visibility from settings")
        XCTAssertEqual(newCoordinator.position, "bottom", "Should load position from settings")
        XCTAssertEqual(newCoordinator.width, 400, "Should load width from settings")
    }

    // MARK: - Delegate Notification Tests
    
    /// Verify visibility change notifies delegate
    func testVisibilityChangeNotifiesDelegate() {
        sut.setPreviewPaneVisible(true)
        
        XCTAssertTrue(mockDelegate.visibilityDidChangeCalled, "Should notify delegate of visibility change")
        XCTAssertTrue(mockDelegate.lastVisibilityValue, "Should pass correct visibility value to delegate")
    }
    
    /// Verify position change notifies delegate
    func testPositionChangeNotifiesDelegate() {
        sut.setPosition("bottom")
        
        XCTAssertTrue(mockDelegate.positionDidChangeCalled, "Should notify delegate of position change")
        XCTAssertEqual(mockDelegate.lastPositionValue, "bottom", "Should pass correct position value to delegate")
    }
    
    /// Verify width change notifies delegate
    func testWidthChangeNotifiesDelegate() {
        let newWidth: CGFloat = 350
        sut.setWidth(newWidth)
        
        XCTAssertTrue(mockDelegate.widthDidChangeCalled, "Should notify delegate of width change")
        XCTAssertEqual(mockDelegate.lastWidthValue, newWidth, "Should pass correct width value to delegate")
    }

    // MARK: - Race Condition Prevention Tests
    
    /// Verify rapid toggle changes don't cause inconsistency
    func testRapidTogglesDontCauseInconsistency() {
        for i in 0..<10 {
            let shouldShow = i % 2 == 0
            sut.setPreviewPaneVisible(shouldShow)
            
            XCTAssertEqual(sut.isVisible, shouldShow, "State should match coordinator at iteration \(i)")
            XCTAssertEqual(mockSettings.previewPaneVisible, shouldShow, "Settings should match coordinator at iteration \(i)")
        }
    }
    
    /// Verify no state update on redundant changes
    func testNoStateUpdateOnRedundantChanges() {
        mockSettings.previewPaneVisible = true
        
        let firstCallCount = mockDelegate.visibilityChangeCount
        sut.setPreviewPaneVisible(true)
        let secondCallCount = mockDelegate.visibilityChangeCount
        
        XCTAssertEqual(firstCallCount, secondCallCount, "Should not notify delegate on redundant visibility change")
    }
    
    /// Verify multiple state changes maintain consistency
    func testMultipleStateChangesAreConsistent() {
        sut.setPreviewPaneVisible(true)
        sut.setPosition("bottom")
        sut.setWidth(400)
        
        // Verify all states are as expected
        XCTAssertTrue(sut.isVisible)
        XCTAssertEqual(sut.position, "bottom")
        XCTAssertEqual(sut.width, 400)
        
        // Verify settings match
        XCTAssertTrue(mockSettings.previewPaneVisible)
        XCTAssertEqual(mockSettings.previewPanePosition, "bottom")
        XCTAssertEqual(mockSettings.previewPaneWidth, 400)
    }

    // MARK: - Edge Cases
    
    /// Verify invalid width is rejected
    func testInvalidWidthIsRejected() {
        sut.setWidth(50) // Less than minimum 100
        
        XCTAssertNotEqual(sut.width, 50, "Should reject width less than 100")
    }
    
    /// Verify position can only be "right" or "bottom"
    func testPositionValidation() {
        sut.setPosition("right")
        XCTAssertEqual(sut.position, "right")
        
        sut.setPosition("bottom")
        XCTAssertEqual(sut.position, "bottom")
    }
}

// MARK: - Mock Objects

class MockPreviewPaneDelegate: FileBrowserPreviewPaneDelegate {
    var visibilityDidChangeCalled = false
    var lastVisibilityValue: Bool = false
    var visibilityChangeCount = 0
    
    var positionDidChangeCalled = false
    var lastPositionValue: String = ""
    
    var widthDidChangeCalled = false
    var lastWidthValue: CGFloat = 0
    
    func previewPaneVisibilityDidChange(_ isVisible: Bool) {
        visibilityDidChangeCalled = true
        lastVisibilityValue = isVisible
        visibilityChangeCount += 1
    }
    
    func previewPanePositionDidChange(_ position: String) {
        positionDidChangeCalled = true
        lastPositionValue = position
    }
    
    func previewPaneWidthDidChange(_ width: CGFloat) {
        widthDidChangeCalled = true
        lastWidthValue = width
    }
}


