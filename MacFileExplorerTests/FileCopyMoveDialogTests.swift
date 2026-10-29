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

    // MARK: - Copy engine regressions

    private final class RecordingDelegate: FileOperationDelegate {
        var failure: String?
        var completed = false
        func fileOperationDidStart(totalBytes: Int64, fileCount: Int) {}
        func fileOperationDidProgress(currentFile: String, bytesProcessed: Int64, totalBytes: Int64) {}
        func fileOperationDidComplete() { completed = true }
        func fileOperationDidFail(error: String) { failure = error }
        func fileOperationDidUpdateQueue(files: [String]) {}
    }

    private func makeSandbox() throws -> (root: URL, source: URL, dest: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CopyEngine-\(UUID().uuidString)")
        let source = root.appendingPathComponent("source")
        let dest = root.appendingPathComponent("dest")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        return (root, source, dest)
    }

    private func isSymlink(_ url: URL) -> Bool {
        FileOperation.sourceKind(at: url) == .symlink
    }

    func testCopyKeepsSymlinksAsLinksAndSurvivesCycles() async throws {
        let (root, source, dest) = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let fm = FileManager.default

        let folder = source.appendingPathComponent("folder")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try "hello".write(to: folder.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try fm.createSymbolicLink(atPath: folder.appendingPathComponent("link").path, withDestinationPath: "a.txt")
        try fm.createSymbolicLink(atPath: folder.appendingPathComponent("broken").path, withDestinationPath: "does-not-exist")
        try fm.createSymbolicLink(atPath: folder.appendingPathComponent("loop").path, withDestinationPath: "..")

        let delegate = RecordingDelegate()
        let operation = FileOperation(type: .copy, sourceFiles: [folder], destination: dest, delegate: delegate)
        operation.start()
        await operation.waitUntilFinished()

        XCTAssertNil(delegate.failure, "A cycle or broken link must not fail or recurse the copy")
        let copied = dest.appendingPathComponent("folder")
        XCTAssertTrue(isSymlink(copied.appendingPathComponent("link")))
        XCTAssertTrue(isSymlink(copied.appendingPathComponent("broken")), "Broken links are copied, not dropped")
        XCTAssertTrue(isSymlink(copied.appendingPathComponent("loop")), "Links are never dereferenced")
        XCTAssertEqual(try fm.destinationOfSymbolicLink(atPath: copied.appendingPathComponent("link").path), "a.txt")
        XCTAssertEqual(try String(contentsOf: copied.appendingPathComponent("a.txt")), "hello")
    }

    func testCrossVolumeMoveDoesNotLoseBrokenSymlinks() async throws {
        let (root, source, dest) = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let fm = FileManager.default

        let folder = source.appendingPathComponent("folder")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try fm.createSymbolicLink(atPath: folder.appendingPathComponent("broken").path, withDestinationPath: "nowhere")

        let delegate = RecordingDelegate()
        let operation = FileOperation(type: .move, sourceFiles: [folder], destination: dest, delegate: delegate)
        operation.sameVolumeCheckOverride = { _, _ in false } // force the copy-then-delete path
        operation.start()
        await operation.waitUntilFinished()

        XCTAssertNil(delegate.failure)
        XCTAssertTrue(isSymlink(dest.appendingPathComponent("folder/broken")),
                      "Items must be copied before the source is deleted")
        XCTAssertFalse(fm.fileExists(atPath: folder.path))
    }

    func testCopyPreservesPermissionsAndDoesNotExposeWideModes() async throws {
        let (root, source, dest) = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let fm = FileManager.default

        let secret = source.appendingPathComponent("secret.key")
        try "k".write(to: secret, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: secret.path)

        let delegate = RecordingDelegate()
        let operation = FileOperation(type: .copy, sourceFiles: [secret], destination: dest, delegate: delegate)
        operation.start()
        await operation.waitUntilFinished()

        let attrs = try fm.attributesOfItem(atPath: dest.appendingPathComponent("secret.key").path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testMovingIntoItsOwnFolderIsANoOp() async throws {
        let (root, source, _) = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let fm = FileManager.default

        let file = source.appendingPathComponent("f.txt")
        try "x".write(to: file, atomically: true, encoding: .utf8)

        let previous = SettingsStore.shared.autoRenameOnConflict
        SettingsStore.shared.autoRenameOnConflict = true
        defer { SettingsStore.shared.autoRenameOnConflict = previous }

        let delegate = RecordingDelegate()
        let operation = FileOperation(type: .move, sourceFiles: [file], destination: source, delegate: delegate)
        operation.start()
        await operation.waitUntilFinished()

        XCTAssertNil(delegate.failure)
        XCTAssertTrue(fm.fileExists(atPath: file.path), "The file must keep its name")
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: source.path), ["f.txt"], "No \"f (1).txt\" copy/rename may appear")
    }

    func testFailedCopyRemovesOnlyWhatItCreated() async throws {
        let (root, source, dest) = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let fm = FileManager.default

        // A named pipe cannot be copied; the partially created destination folder must be discarded.
        let folder = source.appendingPathComponent("folder")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try "ok".write(to: folder.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        XCTAssertEqual(mkfifo(folder.appendingPathComponent("pipe").path, 0o600), 0)

        let delegate = RecordingDelegate()
        let operation = FileOperation(type: .copy, sourceFiles: [folder], destination: dest, delegate: delegate)
        operation.start()
        await operation.waitUntilFinished()

        XCTAssertNotNil(delegate.failure, "Unsupported item types are reported, not silently skipped")
        XCTAssertFalse(fm.fileExists(atPath: dest.appendingPathComponent("folder").path), "Partial copy is cleaned up")
        XCTAssertTrue(fm.fileExists(atPath: folder.appendingPathComponent("a.txt").path), "Source is untouched")
    }
}
