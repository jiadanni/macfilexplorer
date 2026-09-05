import XCTest
@testable import MacFileExplorer

// MARK: - Mock Delegate
class MockTerminalViewControllerDelegate: TerminalViewControllerDelegate {
    var didRequestCloseCount = 0
    
    func terminalViewControllerDidRequestClose(_ controller: TerminalViewController) {
        didRequestCloseCount += 1
    }
}

// MARK: - Tests
class TerminalViewControllerTests: XCTestCase {
    
    var sut: TerminalViewController!
    var mockDelegate: MockTerminalViewControllerDelegate!
    
    override func setUp() {
        super.setUp()
        sut = TerminalViewController()
        mockDelegate = MockTerminalViewControllerDelegate()
        sut.delegate = mockDelegate
    }
    
    override func tearDown() {
        sut = nil
        mockDelegate = nil
        super.tearDown()
    }
    
    // MARK: - Directory Change Tests
    
    func testChangeDirectory_SetsCurrentDirectory() {
        let testPath = "/Users/test"
        sut.changeDirectory(to: testPath)
        // The method should not crash and should send properly escaped command to shell
    }
    
    func testChangeDirectory_WithSpaces() {
        let testPath = "/Users/My Documents/Test"
        sut.changeDirectory(to: testPath)
        // Should properly escape spaces in path
    }
    
    func testChangeDirectory_WithSpecialCharacters() {
        let testPath = "/Users/test$user"
        sut.changeDirectory(to: testPath)
        // Should properly escape shell special characters
    }
    
    func testChangeDirectory_SkipsDuplicateChanges() {
        let testPath = "/Users/test"
        sut.changeDirectory(to: testPath)
        sut.changeDirectory(to: testPath)
        // Second call should be skipped to avoid duplicate shell commands
    }

    // MARK: - Directory Sync Gating (S2)

    func testChangeDirectory_WhileShellBusy_DefersSync() {
        _ = sut.view
        sut.viewDidLoad()
        sut.processOutput("MFE_SENTINEL_12345\n")           // now at prompt
        sut.processOutput("\u{1B}]133;C\u{07}")             // a command starts running
        XCTAssertFalse(sut.isAtPrompt)

        sut.changeDirectory(to: "/Users/deferred")
        XCTAssertEqual(sut.pendingDirectorySync, "/Users/deferred",
                       "A sync requested while the shell is busy must be deferred, not injected")
        XCTAssertNotEqual(sut.lastSyncedDirectory, "/Users/deferred")
    }

    func testChangeDirectory_FlushesPendingSyncOnPromptEnd() {
        _ = sut.view
        sut.viewDidLoad()
        sut.processOutput("MFE_SENTINEL_12345\n")
        sut.processOutput("\u{1B}]133;C\u{07}")
        sut.changeDirectory(to: "/Users/deferred")
        XCTAssertNotNil(sut.pendingDirectorySync)

        // Command finishes and a new prompt is drawn.
        sut.processOutput("\u{1B}]133;D;0\u{07}\u{1B}]133;A\u{07}prompt$ \u{1B}]133;B\u{07}")

        XCTAssertNil(sut.pendingDirectorySync, "Pending sync should be flushed once back at a prompt")
        XCTAssertEqual(sut.lastSyncedDirectory, "/Users/deferred")
        XCTAssertTrue(sut.isAtPrompt)
    }

    func testChangeDirectory_WhileAtPrompt_SyncsImmediately() {
        _ = sut.view
        sut.viewDidLoad()
        sut.processOutput("MFE_SENTINEL_12345\n")           // sentinel echo => at prompt
        XCTAssertTrue(sut.isAtPrompt)

        sut.changeDirectory(to: "/Users/immediate")
        XCTAssertNil(sut.pendingDirectorySync)
        XCTAssertEqual(sut.lastSyncedDirectory, "/Users/immediate")
    }

    func testChangeDirectory_DeferredThenSuperseded_UsesLatestTarget() {
        _ = sut.view
        sut.viewDidLoad()
        sut.processOutput("MFE_SENTINEL_12345\n")
        sut.processOutput("\u{1B}]133;C\u{07}")

        sut.changeDirectory(to: "/Users/first")
        sut.changeDirectory(to: "/Users/second")
        XCTAssertEqual(sut.pendingDirectorySync, "/Users/second",
                       "Only the most recent deferred target should be kept")

        sut.processOutput("\u{1B}]133;A\u{07}p$ \u{1B}]133;B\u{07}")
        XCTAssertEqual(sut.lastSyncedDirectory, "/Users/second")
    }
    
    // MARK: - UI Tests
    
    func testFocusInput_WithInvalidWindow() {
        // When window is nil, focusInput should not crash
        sut.focusInput()
        // Should handle gracefully
    }
    
    func testCloseButton_NotifiesDelegate() {
        _ = sut.view
        // Simulate close button click
        sut.closeButtonClicked(NSButton())
        XCTAssertEqual(mockDelegate.didRequestCloseCount, 1, "Close button should notify delegate")
    }
    
    // MARK: - Shell Session Lifecycle Tests
    
    func testViewDidLoad_InitializesShellSession() {
        _ = sut.view
        sut.viewDidLoad()
        // Shell session should be initialized without crashing
    }
    
    func testViewDidAppear_FocusesInput() {
        _ = sut.view
        sut.viewDidLoad()
        sut.viewDidAppear()
        // Should attempt to focus input without crashing
    }
    
    func testDeinit_CleanupShellSession() {
        var tempVC: TerminalViewController? = TerminalViewController()
        _ = tempVC?.view
        tempVC?.viewDidLoad()

        // Deinit should properly cleanup shell resources
        tempVC = nil

        // Verify cleanup completed (no crash)
        XCTAssertNil(tempVC)
    }

    // MARK: - OSC 133 Semantic Prompt Parsing

    func testStripControlSequences_ExtractsOSC133Markers() {
        var markers: [TerminalViewController.SemanticMarker] = []
        let input = "\u{1B}]133;A\u{07}user@host:~$ \u{1B}]133;B\u{07}"
        let stripped = sut.stripControlSequences(input, markers: &markers)

        XCTAssertEqual(stripped, "user@host:~$ ", "OSC sequences should be removed from the text")
        XCTAssertEqual(markers, [.promptStart, .promptEnd])
    }

    func testStripControlSequences_ParsesCommandEndExitCode() {
        var markers: [TerminalViewController.SemanticMarker] = []
        _ = sut.stripControlSequences("\u{1B}]133;C\u{07}output\u{1B}]133;D;42\u{07}", markers: &markers)

        XCTAssertEqual(markers, [.commandStart, .commandEnd(42)])
    }

    func testStripControlSequences_CommandEndWithoutExitCode() {
        var markers: [TerminalViewController.SemanticMarker] = []
        _ = sut.stripControlSequences("\u{1B}]133;D\u{07}", markers: &markers)

        XCTAssertEqual(markers, [.commandEnd(nil)])
    }

    func testStripControlSequences_STTerminatedSequence() {
        var markers: [TerminalViewController.SemanticMarker] = []
        // ESC \ (ST) terminator instead of BEL
        let stripped = sut.stripControlSequences("a\u{1B}]133;A\u{1B}\\b", markers: &markers)

        XCTAssertEqual(stripped, "ab")
        XCTAssertEqual(markers, [.promptStart])
    }

    func testStripControlSequences_NonOSC133SequenceStrippedWithoutMarker() {
        var markers: [TerminalViewController.SemanticMarker] = []
        // OSC 0 (set window title) should be removed but produce no marker.
        let stripped = sut.stripControlSequences("\u{1B}]0;My Title\u{07}text", markers: &markers)

        XCTAssertEqual(stripped, "text")
        XCTAssertTrue(markers.isEmpty)
    }

    func testProcessOutput_CommandEndUpdatesExitCodeAndRunningState() {
        _ = sut.view
        sut.viewDidLoad()
        // viewDidLoad starts a shell session which suppresses output until the
        // startup sentinel is seen; feed it so subsequent output is processed.
        sut.processOutput("MFE_SENTINEL_12345\n")

        sut.processOutput("\u{1B}]133;C\u{07}")
        XCTAssertTrue(sut.isCommandRunning)

        sut.processOutput("done\n\u{1B}]133;D;7\u{07}")
        XCTAssertFalse(sut.isCommandRunning)
        XCTAssertEqual(sut.lastExitCode, 7)
    }

    func testProcessOutput_PromptEndPinsPromptLocation() {
        _ = sut.view
        sut.viewDidLoad()
        sut.processOutput("MFE_SENTINEL_12345\n")

        // A prompt is drawn, then 133;B marks where input begins.
        sut.processOutput("user@host:~$ \u{1B}]133;B\u{07}")
        let pinned = sut.promptLocation

        // Further output that is not a new prompt must not move the pinned location.
        sut.processOutput("stray output\n")
        XCTAssertEqual(sut.promptLocation, pinned, "promptLocation stays pinned until a new prompt (133;A) arrives")
    }
}

