import XCTest
@testable import MacFileExplorer
import Foundation

class TextPreviewHandlerTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MacFileExplorerTextTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testTextPreviewTruncation() throws {
        let handler = TextPreviewHandler()

        // Create a 2MB file (exceeds the 1MB limit we will implement)
        let largeSize = 2_000_000
        let largeContent = String(repeating: "a", count: largeSize)
        let fileURL = tempDirectory.appendingPathComponent("large.txt")
        try largeContent.write(to: fileURL, atomically: true, encoding: .utf8)

        let fileItem = FileItem(url: fileURL)

        // When: Create the preview view
        let view = handler.createView(for: fileItem)

        // Then: It should be a scroll view containing a text view
        XCTAssertTrue(view is NSScrollView)
        guard let scrollView = view as? NSScrollView,
              let textView = scrollView.documentView as? NSTextView else {
            XCTFail("View structure is not as expected")
            return
        }

        // And: The content should be truncated
        let content = textView.string
        XCTAssertTrue(content.count < largeSize, "Content should be truncated")
        XCTAssertTrue(content.contains("[Preview truncated"), "Should contain truncation message")
    }

    func testTextPreviewSmallFile() throws {
        let handler = TextPreviewHandler()

        let smallContent = "Hello, world!"
        let fileURL = tempDirectory.appendingPathComponent("small.txt")
        try smallContent.write(to: fileURL, atomically: true, encoding: .utf8)

        let fileItem = FileItem(url: fileURL)

        // When: Create the preview view
        let view = handler.createView(for: fileItem)

        // Then: The content should be fully present
        guard let scrollView = view as? NSScrollView,
              let textView = scrollView.documentView as? NSTextView else {
            XCTFail("View structure is not as expected")
            return
        }

        XCTAssertEqual(textView.string, smallContent)
    }
}
