import XCTest
@testable import MacFileExplorer

class ViewModeTests: XCTestCase {
    
    func testAllViewModes() {
        let modes = ViewMode.allCases
        
        XCTAssertEqual(modes.count, 4, "Should have 4 view modes")
        XCTAssertTrue(modes.contains(.list), "Should include list mode")
        XCTAssertTrue(modes.contains(.icons), "Should include icons mode")
        XCTAssertTrue(modes.contains(.columns), "Should include columns mode")
        XCTAssertTrue(modes.contains(.windowsList), "Should include windowsList mode")
    }
    
    func testViewModeRawValues() {
        XCTAssertEqual(ViewMode.list.rawValue, "List")
        XCTAssertEqual(ViewMode.icons.rawValue, "Icons")
        XCTAssertEqual(ViewMode.columns.rawValue, "Columns")
        XCTAssertEqual(ViewMode.windowsList.rawValue, "List (Win)")
    }
    
    func testViewModeInitFromRawValue() {
        XCTAssertEqual(ViewMode(rawValue: "List"), .list)
        XCTAssertEqual(ViewMode(rawValue: "Icons"), .icons)
        XCTAssertEqual(ViewMode(rawValue: "Columns"), .columns)
        XCTAssertEqual(ViewMode(rawValue: "List (Win)"), .windowsList)
        XCTAssertNil(ViewMode(rawValue: "Invalid"))
    }
}

class SplitOrientationTests: XCTestCase {
    
    func testSplitOrientations() {
        // Test that split orientations exist
        let vertical = SplitOrientation.vertical
        let horizontal = SplitOrientation.horizontal
        
        XCTAssertNotNil(vertical, "Vertical orientation should exist")
        XCTAssertNotNil(horizontal, "Horizontal orientation should exist")
    }
}
