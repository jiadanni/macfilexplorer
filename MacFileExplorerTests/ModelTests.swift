import XCTest
@testable import MacFileExplorer

class ViewModeTests: XCTestCase {
    
    func testAllViewModes() {
        let modes = ViewMode.allCases
        
        XCTAssertEqual(modes.count, 5, "Should have 5 view modes")
        XCTAssertTrue(modes.contains(.list), "Should include list mode")
        XCTAssertTrue(modes.contains(.details), "Should include details mode")
        XCTAssertTrue(modes.contains(.icons), "Should include icons mode")
        XCTAssertTrue(modes.contains(.columns), "Should include columns mode")
        XCTAssertTrue(modes.contains(.windowsList), "Should include windowsList mode")
    }
    
    func testViewModeRawValues() {
        XCTAssertEqual(ViewMode.list.rawValue, "List")
        XCTAssertEqual(ViewMode.details.rawValue, "Details")
        XCTAssertEqual(ViewMode.icons.rawValue, "Icons")
        XCTAssertEqual(ViewMode.columns.rawValue, "Columns")
        XCTAssertEqual(ViewMode.windowsList.rawValue, "Windows List")
    }
    
    func testViewModeInitFromRawValue() {
        XCTAssertEqual(ViewMode(rawValue: "List"), .list)
        XCTAssertEqual(ViewMode(rawValue: "Details"), .details)
        XCTAssertEqual(ViewMode(rawValue: "Icons"), .icons)
        XCTAssertEqual(ViewMode(rawValue: "Columns"), .columns)
        XCTAssertEqual(ViewMode(rawValue: "Windows List"), .windowsList)
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
