import XCTest
@testable import MacFileExplorer

class FileBrowserZoomCoordinatorTests: XCTestCase {
    var sut: FileBrowserZoomCoordinator!
    var mockDelegate: MockZoomCoordinatorDelegate!

    override func setUp() {
        super.setUp()
        sut = FileBrowserZoomCoordinator()
        mockDelegate = MockZoomCoordinatorDelegate()
        sut.delegate = mockDelegate
    }

    override func tearDown() {
        sut = nil
        mockDelegate = nil
        super.tearDown()
    }

    func testInitialZoomLevel() {
        XCTAssertEqual(sut.getCurrentZoomLevel(), 100.0)
        XCTAssertEqual(sut.getZoomScale(), 1.0)
    }

    func testZoomInIncreasesLevel() {
        let initialLevel = sut.getCurrentZoomLevel()
        sut.zoomIn()
        XCTAssertGreaterThan(sut.getCurrentZoomLevel(), initialLevel)
        XCTAssertTrue(mockDelegate.refreshViewsCalled)
    }

    func testZoomOutDecreasesLevel() {
        let initialLevel = sut.getCurrentZoomLevel()
        sut.zoomOut()
        XCTAssertLessThan(sut.getCurrentZoomLevel(), initialLevel)
        XCTAssertTrue(mockDelegate.refreshViewsCalled)
    }

    func testResetZoom() {
        sut.zoomIn()
        sut.resetZoom()
        XCTAssertEqual(sut.getCurrentZoomLevel(), 100.0)
    }

    func testActualSize() {
        sut.zoomIn()
        sut.actualSize()
        XCTAssertEqual(sut.getCurrentZoomLevel(), 100.0)
    }

    func testZoomBounds() {
        // Test max zoom
        for _ in 0...50 { sut.zoomIn() }
        XCTAssertLessThanOrEqual(sut.getCurrentZoomLevel(), 200.0)

        // Test min zoom
        for _ in 0...50 { sut.zoomOut() }
        XCTAssertGreaterThanOrEqual(sut.getCurrentZoomLevel(), 50.0)
    }

    func testAreZoomControlsEnabled() {
        mockDelegate.currentViewMode = .icons
        XCTAssertTrue(sut.areZoomControlsEnabled())

        mockDelegate.currentViewMode = .list
        XCTAssertFalse(sut.areZoomControlsEnabled())
    }

    func testToggleFreeFormPositioning() {
        mockDelegate.currentViewMode = .icons
        let initialValue = mockDelegate.isFreeFormEnabled
        sut.toggleFreeFormPositioning()
        XCTAssertNotEqual(mockDelegate.isFreeFormEnabled, initialValue)
        XCTAssertTrue(mockDelegate.refreshViewsCalled)
    }
}

class MockZoomCoordinatorDelegate: FileBrowserZoomCoordinatorDelegate {
    var currentViewMode: ViewMode = .icons
    var collectionView: NSCollectionView?
    var freeFormLayout: FreeFormCollectionViewLayout?
    var isFreeFormEnabled: Bool = true
    var zoomLevel: Double = 1.0
    
    var updateZoomDisplayCalled = false
    var refreshViewsCalled = false

    func updateZoomDisplay() {
        updateZoomDisplayCalled = true
    }

    func refreshViews() {
        refreshViewsCalled = true
    }
}
