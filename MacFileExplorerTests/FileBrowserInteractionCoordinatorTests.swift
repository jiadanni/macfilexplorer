import XCTest
@testable import MacFileExplorer

class FileBrowserInteractionCoordinatorTests: XCTestCase {
    var sut: FileBrowserInteractionCoordinator!
    var mockDelegate: MockInteractionDelegate!

    override func setUp() {
        super.setUp()
        sut = FileBrowserInteractionCoordinator()
        mockDelegate = MockInteractionDelegate()
        sut.delegate = mockDelegate
    }

    override func tearDown() {
        sut = nil
        mockDelegate = nil
        super.tearDown()
    }

    func testClickTracking() {
        let row = 5
        sut.recordClick(row: row)
        
        // Immediately after click, it should be eligible for rename (if within delay)
        XCTAssertTrue(sut.isRenameEligibleClick(row: row))
        
        // Different row should not be eligible
        XCTAssertFalse(sut.isRenameEligibleClick(row: row + 1))
    }

    func testClearClickTracking() {
        let row = 5
        sut.recordClick(row: row)
        sut.clearClickTracking()
        
        XCTAssertFalse(sut.isRenameEligibleClick(row: row))
    }

    func testRenameEligibilityDelay() {
        let row = 10
        sut.recordClick(row: row)
        
        // Wait longer than renameClickDelay (0.5s)
        let expectation = XCTestExpectation(description: "Wait for delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertFalse(sut.isRenameEligibleClick(row: row), "Should not be eligible after delay")
    }

    func testHandleDoubleClick() {
        sut.recordClick(row: 3)
        sut.handleDoubleClick()
        
        XCTAssertTrue(mockDelegate.openSelectionCalled)
        XCTAssertFalse(sut.isRenameEligibleClick(row: 3), "Click tracking should be cleared after double click")
    }
}

class MockInteractionDelegate: FileBrowserInteractionDelegate {
    var openSelectionCalled = false
    var renameCalledWithItem: FileItem?
    var lastErrorMessage: String?

    func openSelection() {
        openSelectionCalled = true
    }

    func contextMenuRename(_ item: FileItem) {
        renameCalledWithItem = item
    }

    func showError(_ message: String) {
        lastErrorMessage = message
    }
}
