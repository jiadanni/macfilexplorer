import XCTest
@testable import MacFileExplorer

class FileCopyMoveDialogTests: XCTestCase {
    
    func testFileOperationQueueLimit() async throws {
        // The queue shown in the dialog is capped at 500 names plus a summary row.
        class MockDelegate: FileOperationDelegate {
            var capturedFiles: [String] = []
            func fileOperationDidStart(totalBytes: Int64, fileCount: Int) {}
            func fileOperationDidProgress(currentFile: String, bytesProcessed: Int64, totalBytes: Int64) {}
            func fileOperationDidComplete() {}
            func fileOperationDidFail(error: String) {}
            func fileOperationDidUpdateQueue(files: [String]) {
                capturedFiles = files
            }
        }

        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("FileOperationQueueTest-\(UUID().uuidString)")
        let sourceDir = tempDir.appendingPathComponent("source")
        let destDir = tempDir.appendingPathComponent("dest")
        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        let sourceFiles = (0..<1000).map { sourceDir.appendingPathComponent("file\($0).txt") }
        for url in sourceFiles {
            XCTAssertTrue(fileManager.createFile(atPath: url.path, contents: nil))
        }

        let delegate = MockDelegate()
        let operation = FileOperation(
            type: .copy,
            sourceFiles: sourceFiles,
            destination: destDir,
            delegate: delegate
        )
        operation.start()
        await operation.waitUntilFinished()

        XCTAssertEqual(delegate.capturedFiles.count, 501)
        XCTAssertEqual(delegate.capturedFiles.first, "file0.txt")
        XCTAssertEqual(delegate.capturedFiles.last, "... and 500 more items")
    }

    func testCancellingCrossVolumeMoveKeepsSourceFile() async throws {
        // Regression test: cancelling a cross-volume move mid-copy must not delete the source.
        class CancellingDelegate: FileOperationDelegate {
            var operation: FileOperation?
            var didFail = false
            var didComplete = false
            var didCancel = false
            func fileOperationDidStart(totalBytes: Int64, fileCount: Int) {}
            func fileOperationDidProgress(currentFile: String, bytesProcessed: Int64, totalBytes: Int64) {
                // The first progress report fires after the first 1MB chunk, so
                // cancelling here always lands mid-copy of the 8MB file.
                if !didCancel {
                    didCancel = true
                    operation?.cancel()
                }
            }
            func fileOperationDidComplete() { didComplete = true }
            func fileOperationDidFail(error: String) { didFail = true }
            func fileOperationDidUpdateQueue(files: [String]) {}
        }

        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("FileOperationCancelTest-\(UUID().uuidString)")
        let sourceDir = tempDir.appendingPathComponent("source")
        let destDir = tempDir.appendingPathComponent("dest")
        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        // Large enough for several 1MB chunks so cancellation lands mid-copy.
        let sourceFile = sourceDir.appendingPathComponent("large.bin")
        let payload = Data(count: 8 * 1024 * 1024)
        try payload.write(to: sourceFile)

        let delegate = CancellingDelegate()
        let operation = FileOperation(
            type: .move,
            sourceFiles: [sourceFile],
            destination: destDir,
            delegate: delegate
        )
        // Force the chunked path a real cross-volume move would take.
        operation.sameVolumeCheckOverride = { _, _ in false }
        delegate.operation = operation

        operation.start()
        await operation.waitUntilFinished()

        XCTAssertTrue(fileManager.fileExists(atPath: sourceFile.path),
                      "Cancelled move must leave the source file in place")
        XCTAssertFalse(fileManager.fileExists(atPath: destDir.appendingPathComponent("large.bin").path),
                       "Cancelled move must clean up the partial destination file")
        XCTAssertFalse(delegate.didComplete, "Cancelled operation must not report completion")
        XCTAssertFalse(delegate.didFail, "Cancellation is not a failure")
    }
}
