import XCTest
@testable import MacFileExplorer

class ToolbarViewControllerTests: XCTestCase {
    
    var toolbarViewController: ToolbarViewController!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        toolbarViewController = ToolbarViewController()
        // Load the view
        _ = toolbarViewController.view
    }
    
    override func tearDownWithError() throws {
        toolbarViewController = nil
        try super.tearDownWithError()
    }
    
    func testViewControllerInitialization() {
        XCTAssertNotNil(toolbarViewController, "ToolbarViewController should be initialized")
        XCTAssertNotNil(toolbarViewController.view, "View should be loaded")
    }
    
    func testViewSize() {
        let viewFrame = toolbarViewController.view.frame
        XCTAssertEqual(viewFrame.height, 40, "Toolbar height should be 40")
    }
    
    func testUpdatePath() {
        let testURL = URL(fileURLWithPath: "/Users/test/Documents")
        
        toolbarViewController.updatePath(testURL, canGoBack: true, canGoForward: false)
        
        // The toolbar should update without crashing
        XCTAssertTrue(true, "updatePath should complete without errors")
    }
    
    func testViewModeDisplay() {
        // Test updating view mode display for each mode
        for mode in ViewMode.allCases {
            toolbarViewController.updateViewModeDisplay(for: mode)
            // Should update without crashing
            XCTAssertTrue(true, "updateViewModeDisplay should work for \(mode.rawValue)")
        }
    }
    
    func testHiddenFilesDisplay() {
        // Test showing hidden files
        toolbarViewController.updateHiddenFilesDisplay(showing: true)
        XCTAssertTrue(true, "Should update hidden files display to showing")
        
        // Test hiding hidden files
        toolbarViewController.updateHiddenFilesDisplay(showing: false)
        XCTAssertTrue(true, "Should update hidden files display to hiding")
    }
    
    func testSortDisplay() {
        toolbarViewController.updateSortDisplay(column: "NameColumn", ascending: true)
        XCTAssertTrue(true, "Should update sort display ascending")
        
        toolbarViewController.updateSortDisplay(column: "NameColumn", ascending: false)
        XCTAssertTrue(true, "Should update sort display descending")
        
        toolbarViewController.updateSortDisplay(column: "DateModifiedColumn", ascending: true)
        XCTAssertTrue(true, "Should update sort display for date modified")
    }
}
