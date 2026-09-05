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
        // Simulate two clicks: first click selects, second click (after short delay)
        sut.recordClick(row: row)

        let exp = expectation(description: "Second click")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.sut.recordClick(row: row)
            // After the second click (within rename delay), rename should be eligible
            XCTAssertTrue(self.sut.isRenameEligibleClick(row: row))
            // Different row should not be eligible
            XCTAssertFalse(self.sut.isRenameEligibleClick(row: row + 1))
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
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

    func testHandleDoubleClickOnItem() {
        let item = FileItem(url: URL(fileURLWithPath: "/tmp/example.txt"))

        sut.recordClick(row: 2)
        sut.handleDoubleClick(on: item)

        XCTAssertEqual(mockDelegate.openedItem?.url, item.url)
        XCTAssertFalse(sut.isRenameEligibleClick(row: 2), "Click tracking should be cleared after opening a specific item")
    }
}

class MockInteractionDelegate: FileBrowserInteractionDelegate {
    var openSelectionCalled = false
    var openedItem: FileItem?
    var renameCalledWithItem: FileItem?
    var lastErrorMessage: String?

    func openSelection() {
        openSelectionCalled = true
    }

    func openItem(_ item: FileItem) {
        openedItem = item
    }

    func contextMenuRename(_ item: FileItem) {
        renameCalledWithItem = item
    }

    func showError(_ message: String) {
        lastErrorMessage = message
    }
}
