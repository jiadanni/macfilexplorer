import XCTest
@testable import MacFileExplorer

class FileBrowserViewModeCoordinatorTests: XCTestCase {
    var fileBrowserVC: FileBrowserViewController!
    var sut: FileBrowserViewModeCoordinator!
    var testSettings: SettingsStore!

    override func setUp() {
        super.setUp()
        
        let suiteName = "com.macfileexplorer.viewmode.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        testSettings = SettingsStore(defaults: defaults)
        
        fileBrowserVC = FileBrowserViewController(settings: testSettings)
        _ = fileBrowserVC.view // Load view
        
        sut = fileBrowserVC.viewModeCoordinator
    }

    override func tearDown() {
        fileBrowserVC = nil
        sut = nil
        super.tearDown()
    }

    func testDisplayListView() {
        sut.displayFiles(for: .list)
        
        // Wait for async dispatch
        let expectation = XCTestExpectation(description: "View mode updated to list")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(fileBrowserVC.currentViewMode, .list)
        XCTAssertFalse(fileBrowserVC.scrollView.isHidden)
        XCTAssertTrue(fileBrowserVC.collectionViewScrollView?.isHidden ?? true)
        XCTAssertTrue(fileBrowserVC.browserView?.isHidden ?? true)
    }

    func testDisplayIconsView() {
        sut.displayFiles(for: .icons)
        
        let expectation = XCTestExpectation(description: "View mode updated to icons")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(fileBrowserVC.currentViewMode, .icons)
        XCTAssertTrue(fileBrowserVC.scrollView.isHidden)
        XCTAssertFalse(fileBrowserVC.collectionViewScrollView?.isHidden ?? false)
    }

    func testDisplayColumnsView() {
        sut.displayFiles(for: .columns)
        
        let expectation = XCTestExpectation(description: "View mode updated to columns")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(fileBrowserVC.currentViewMode, .columns)
        XCTAssertTrue(fileBrowserVC.scrollView.isHidden)
        XCTAssertTrue(fileBrowserVC.collectionViewScrollView?.isHidden ?? true)
        XCTAssertFalse(fileBrowserVC.browserView?.isHidden ?? false)
    }
}
