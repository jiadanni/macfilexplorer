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

    // MARK: - Special files must not hang or exhaust the app

    func testFIFOIsNotOpenedBlocking() throws {
        let fifo = tempDirectory.appendingPathComponent("pipe.txt")
        XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)

        let view = TextPreviewHandler().createView(for: FileItem(url: fifo))

        XCTAssertFalse(view is NSScrollView, "A FIFO is not a regular file and must not be read")
    }

    func testSymlinkToDeviceIsRefused() throws {
        let link = tempDirectory.appendingPathComponent("zero.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: URL(fileURLWithPath: "/dev/zero"))

        let view = TextPreviewHandler().createView(for: FileItem(url: link))

        XCTAssertFalse(view is NSScrollView, "Reading /dev/zero through a symlink must be refused, not buffered forever")
    }

    func testReadBoundedPrefixCapsRegularFiles() throws {
        let file = tempDirectory.appendingPathComponent("big.txt")
        try Data(repeating: 0x61, count: 5000).write(to: file)

        let result = TextPreviewHandler.readBoundedPrefix(of: file, limit: 1000)

        XCTAssertEqual(result?.data.count, 1000)
        XCTAssertEqual(result?.truncated, true)
        XCTAssertEqual(TextPreviewHandler.readBoundedPrefix(of: file, limit: 10_000)?.truncated, false)
    }

    func testUnsupportedEncodingShowsMessageInsteadOfBlankView() throws {
        let file = tempDirectory.appendingPathComponent("latin1.txt")
        try Data([0x63, 0x61, 0x66, 0xE9]).write(to: file) // "café" in Latin-1, invalid UTF-8

        let view = TextPreviewHandler().createView(for: FileItem(url: file))

        XCTAssertFalse(view is NSScrollView)
        XCTAssertFalse(view.subviews.isEmpty, "A message must explain why there is no preview")
    }
}
