import XCTest
@testable import MacFileExplorer

class ColorManagerTests: XCTestCase {
    
    var colorManager: ColorManager!
    var testURL: URL!
    var testFolderName: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Get shared instance
        colorManager = ColorManager.shared
        
        // Create test URL
        testFolderName = "ColorManagerTest_\(UUID().uuidString)"
        testURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(testFolderName)
        
        // Clear any existing color for test folder name
        colorManager.removeColor(forFolderName: testFolderName)
    }
    
    override func tearDownWithError() throws {
        // Clean up - remove color for test folder name
        colorManager.removeColor(forFolderName: testFolderName)
        
        try super.tearDownWithError()
    }
    
    func testSharedInstance() {
        XCTAssertNotNil(ColorManager.shared, "ColorManager should have a shared instance")
        XCTAssertTrue(ColorManager.shared === colorManager, "Shared instance should be the same")
    }
    
    func testSetAndGetColor() {
        let testColor = NSColor.red
        
        // Set color
        colorManager.setColor(testColor, forFolderName: testFolderName)
        
        // Get color
        let retrievedColor = colorManager.getColor(for: testURL)
        
        XCTAssertNotNil(retrievedColor, "Should retrieve color that was set")
        XCTAssertEqual(retrievedColor, testColor, "Retrieved color should match set color")
    }
    
    func testRemoveColor() {
        let testColor = NSColor.blue
        
        // Set color
        colorManager.setColor(testColor, forFolderName: testFolderName)
        XCTAssertNotNil(colorManager.getColor(for: testURL), "Color should be set")
        
        // Remove color
        colorManager.removeColor(forFolderName: testFolderName)
        
        let retrievedColor = colorManager.getColor(for: testURL)
        XCTAssertNil(retrievedColor, "Color should be removed")
    }
    
    func testGetNonexistentColor() {
        let randomURL = URL(fileURLWithPath: "/nonexistent/path/\(UUID().uuidString)")
        let color = colorManager.getColor(for: randomURL)
        
        XCTAssertNil(color, "Should return nil for URL without set color")
    }
    
    func testMultipleColors() {
        let folderName1 = "test1"
        let folderName2 = "test2"
        let url1 = FileManager.default.temporaryDirectory.appendingPathComponent(folderName1)
        let url2 = FileManager.default.temporaryDirectory.appendingPathComponent(folderName2)
        
        let color1 = NSColor.red
        let color2 = NSColor.green
        
        colorManager.setColor(color1, forFolderName: folderName1)
        colorManager.setColor(color2, forFolderName: folderName2)
        
        XCTAssertEqual(colorManager.getColor(for: url1), color1, "Color for URL1 should be red")
        XCTAssertEqual(colorManager.getColor(for: url2), color2, "Color for URL2 should be green")
        
        // Clean up
        colorManager.removeColor(forFolderName: folderName1)
        colorManager.removeColor(forFolderName: folderName2)
    }
    
    func testOverwriteColor() {
        let color1 = NSColor.red
        let color2 = NSColor.blue
        
        // Set first color
        colorManager.setColor(color1, forFolderName: testFolderName)
        XCTAssertEqual(colorManager.getColor(for: testURL), color1, "First color should be set")
        
        // Overwrite with second color
        colorManager.setColor(color2, forFolderName: testFolderName)
        XCTAssertEqual(colorManager.getColor(for: testURL), color2, "Color should be overwritten")
    }
    
    func testColorPersistence() {
        let testColor = NSColor.yellow
        
        // Set color
        colorManager.setColor(testColor, forFolderName: testFolderName)
        
        // The color is stored in UserDefaults, which persists across runs
        // We can verify it's retrievable
        let retrievedColor = colorManager.getColor(for: testURL)
        XCTAssertEqual(retrievedColor, testColor, "Color should persist")
    }
}
