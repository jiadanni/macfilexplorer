import XCTest
@testable import MacFileExplorer

class FileItemTests: XCTestCase {
    
    var tempDirectoryURL: URL!
    var tempFileURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create temporary directory for testing
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileItemTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        
        // Create a temporary file
        tempFileURL = tempDirectoryURL.appendingPathComponent("test.txt")
        try "Test content".write(to: tempFileURL, atomically: true, encoding: .utf8)
    }
    
    override func tearDownWithError() throws {
        // Clean up temporary directory
        if FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            try FileManager.default.removeItem(at: tempDirectoryURL)
        }
        
        try super.tearDownWithError()
    }
    
    func testFileItemInitialization() throws {
        let fileItem = FileItem(url: tempFileURL)
        
        XCTAssertNotNil(fileItem, "FileItem should be initialized")
        XCTAssertEqual(fileItem.name, "test.txt", "File name should match")
        XCTAssertEqual(fileItem.url, tempFileURL, "URL should match")
        XCTAssertFalse(fileItem.isDirectory, "File should not be a directory")
    }
    
    func testDirectoryItemInitialization() throws {
        let dirItem = FileItem(url: tempDirectoryURL)
        
        XCTAssertNotNil(dirItem, "Directory FileItem should be initialized")
        XCTAssertTrue(dirItem.isDirectory, "Should be identified as directory")
        XCTAssertNotNil(dirItem.children, "Directory should have children array")
    }
    
    func testFileItemName() throws {
        let fileItem = FileItem(url: tempFileURL)
        XCTAssertEqual(fileItem.name, "test.txt", "Name should be extracted from URL")
        
        let dirItem = FileItem(url: tempDirectoryURL)
        XCTAssertTrue(dirItem.name.hasPrefix("FileItemTests_"), "Directory name should be correct")
    }
    
    func testFileItemPath() throws {
        let fileItem = FileItem(url: tempFileURL)
        XCTAssertEqual(fileItem.url.path, tempFileURL.path, "Path should match URL path")
    }
    
    func testDirectoryChildren() throws {
        // Create multiple files in directory
        let file1URL = tempDirectoryURL.appendingPathComponent("file1.txt")
        let file2URL = tempDirectoryURL.appendingPathComponent("file2.txt")
        try "Content 1".write(to: file1URL, atomically: true, encoding: .utf8)
        try "Content 2".write(to: file2URL, atomically: true, encoding: .utf8)
        
        let dirItem = FileItem(url: tempDirectoryURL)
        dirItem.loadChildren()
        
        XCTAssertNotNil(dirItem.children, "Children should be loaded")
        XCTAssertGreaterThanOrEqual(dirItem.children?.count ?? 0, 3, "Should have at least 3 items (test.txt, file1.txt, file2.txt)")
    }
    
    func testFileIcon() throws {
        let fileItem = FileItem(url: tempFileURL)
        XCTAssertNotNil(fileItem.icon, "File should have an icon")
    }
    
    func testFileSize() throws {
        let fileItem = FileItem(url: tempFileURL)
        XCTAssertGreaterThan(fileItem.size, 0, "File should have a size greater than 0")
    }
    
    func testModificationDate() throws {
        let fileItem = FileItem(url: tempFileURL)
        XCTAssertNotNil(fileItem.modificationDate, "File should have a modification date")
    }
    
    func testHiddenFileDetection() throws {
        // Create a hidden file
        let hiddenFileURL = tempDirectoryURL.appendingPathComponent(".hidden")
        try "Hidden content".write(to: hiddenFileURL, atomically: true, encoding: .utf8)
        
        let hiddenItem = FileItem(url: hiddenFileURL)
        XCTAssertTrue(hiddenItem.name.hasPrefix("."), "Hidden file should start with dot")
    }
    
    func testFileType() throws {
        let fileItem = FileItem(url: tempFileURL)
        XCTAssertNotNil(fileItem.fileType, "File should have a type")
        XCTAssertEqual(fileItem.fileType, "TXT", "File type should be TXT")
    }
}
