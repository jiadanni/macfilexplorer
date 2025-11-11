import XCTest
@testable import MacFileExplorer

class ColorManagerTests: XCTestCase {
    
    var colorManager: ColorManager!
    var testURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Get shared instance
        colorManager = ColorManager.shared
        
        // Create test URL
        testURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ColorManagerTest_\(UUID().uuidString)")
        
        // Clear any existing color for test URL
        colorManager.setColor(nil, for: testURL)
    }
    
    override func tearDownWithError() throws {
        // Clean up - remove color for test URL
        colorManager.setColor(nil, for: testURL)
        
        try super.tearDownWithError()
    }
    
    func testSharedInstance() {
        XCTAssertNotNil(ColorManager.shared, "ColorManager should have a shared instance")
        XCTAssertTrue(ColorManager.shared === colorManager, "Shared instance should be the same")
    }
    
    func testSetAndGetColor() {
        let testColor = NSColor.red
        
        // Set color
        colorManager.setColor(testColor, for: testURL)
        
        // Get color
        let retrievedColor = colorManager.getColor(for: testURL)
        
        XCTAssertNotNil(retrievedColor, "Should retrieve color that was set")
        XCTAssertEqual(retrievedColor, testColor, "Retrieved color should match set color")
    }
    
    func testRemoveColor() {
        let testColor = NSColor.blue
        
        // Set color
        colorManager.setColor(testColor, for: testURL)
        XCTAssertNotNil(colorManager.getColor(for: testURL), "Color should be set")
        
        // Remove color
        colorManager.setColor(nil, for: testURL)
        
        let retrievedColor = colorManager.getColor(for: testURL)
        XCTAssertNil(retrievedColor, "Color should be removed")
    }
    
    func testGetNonexistentColor() {
        let randomURL = URL(fileURLWithPath: "/nonexistent/path/\(UUID().uuidString)")
        let color = colorManager.getColor(for: randomURL)
        
        XCTAssertNil(color, "Should return nil for URL without set color")
    }
    
    func testMultipleColors() {
        let url1 = FileManager.default.temporaryDirectory.appendingPathComponent("test1")
        let url2 = FileManager.default.temporaryDirectory.appendingPathComponent("test2")
        
        let color1 = NSColor.red
        let color2 = NSColor.green
        
        colorManager.setColor(color1, for: url1)
        colorManager.setColor(color2, for: url2)
        
        XCTAssertEqual(colorManager.getColor(for: url1), color1, "Color for URL1 should be red")
        XCTAssertEqual(colorManager.getColor(for: url2), color2, "Color for URL2 should be green")
        
        // Clean up
        colorManager.setColor(nil, for: url1)
        colorManager.setColor(nil, for: url2)
    }
    
    func testOverwriteColor() {
        let color1 = NSColor.red
        let color2 = NSColor.blue
        
        // Set first color
        colorManager.setColor(color1, for: testURL)
        XCTAssertEqual(colorManager.getColor(for: testURL), color1, "First color should be set")
        
        // Overwrite with second color
        colorManager.setColor(color2, for: testURL)
        XCTAssertEqual(colorManager.getColor(for: testURL), color2, "Color should be overwritten")
    }
    
    func testColorPersistence() {
        let testColor = NSColor.yellow
        
        // Set color
        colorManager.setColor(testColor, for: testURL)
        
        // The color is stored in UserDefaults, which persists across runs
        // We can verify it's retrievable
        let retrievedColor = colorManager.getColor(for: testURL)
        XCTAssertEqual(retrievedColor, testColor, "Color should persist")
    }
}
