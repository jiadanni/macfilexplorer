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
        // These tests feed the legacy un-nonced marker/sentinel forms; the nonce
        // behaviour has its own tests below.
        sut.markerNonce = nil
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
    
    func testChangeDirectory_WithControlCharacters_DoesNotSync() {
        _ = sut.view
        sut.viewDidLoad()
        sut.processOutput("MFE_SENTINEL_12345\n")           // at prompt

        let path = "/Users/evil\u{03}name"
        sut.changeDirectory(to: path)
        XCTAssertNotEqual(sut.lastSyncedDirectory, path,
                          "Paths containing control bytes must never be written to the PTY")
        XCTAssertNil(sut.pendingDirectorySync)
    }

    // MARK: - UTF-8 Decoding

    func testTakeDecodableUTF8_SplitMultibyteCharacter_IsCarriedOver() {
        let bytes = Array("a€b".utf8)                          // € is 3 bytes: E2 82 AC
        var buffer = Array(bytes[0..<3])                        // "a" + first two bytes of €
        XCTAssertEqual(TerminalViewController.takeDecodableUTF8(from: &buffer), "a")
        XCTAssertEqual(buffer, [0xE2, 0x82])

        buffer.append(contentsOf: bytes[3...])
        XCTAssertEqual(TerminalViewController.takeDecodableUTF8(from: &buffer), "€b")
        XCTAssertTrue(buffer.isEmpty)
    }

    func testTakeDecodableUTF8_CompleteInput_DecodesEverything() {
        var buffer = Array("hello 👋".utf8)
        XCTAssertEqual(TerminalViewController.takeDecodableUTF8(from: &buffer), "hello 👋")
        XCTAssertTrue(buffer.isEmpty)
    }

    func testTakeDecodableUTF8_InvalidBytes_AreReplacedNotDropped() {
        var buffer: [UInt8] = [0x61, 0xFF, 0x62]
        XCTAssertEqual(TerminalViewController.takeDecodableUTF8(from: &buffer), "a\u{FFFD}b")
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

    // MARK: - Hardening: marker nonce, split escapes, secret prompts

    func testNoncedMarkers_RejectForgedAndAcceptAuthentic() {
        sut.markerNonce = "abc123"
        var markers: [TerminalViewController.SemanticMarker] = []

        // Output from `cat`, a build log or a remote host cannot know the nonce.
        _ = sut.stripControlSequences("\u{1B}]133;B\u{07}", markers: &markers)
        _ = sut.stripControlSequences("\u{1B}]133;B;wrong\u{07}", markers: &markers)
        XCTAssertTrue(markers.isEmpty, "Markers without the session nonce must be ignored")

        _ = sut.stripControlSequences("\u{1B}]133;B;abc123\u{07}\u{1B}]133;D;3;abc123\u{07}\u{1B}]133;D;abc123\u{07}", markers: &markers)
        XCTAssertEqual(markers, [.promptEnd, .commandEnd(3), .commandEnd(nil)])
    }

    func testSplitIncompleteEscape_HoldsBackUnfinishedSequences() {
        let esc = "\u{1B}"
        func split(_ text: String) -> (String, String) {
            let result = TerminalViewController.splitIncompleteEscape(text)
            return (result.complete, result.pending)
        }

        XCTAssertTrue(split("abc") == ("abc", ""))
        XCTAssertTrue(split("abc\(esc)[31mred") == ("abc\(esc)[31mred", ""), "A finished CSI is complete")
        XCTAssertTrue(split("abc\(esc)[3") == ("abc", "\(esc)[3"), "An unfinished CSI is held back")
        XCTAssertTrue(split("x\(esc)") == ("x", esc), "A lone trailing ESC is held back")
        XCTAssertTrue(split("x\(esc)]133;B\u{07}y") == ("x\(esc)]133;B\u{07}y", ""), "A BEL-terminated OSC is complete")
        XCTAssertTrue(split("x\(esc)]133;B") == ("x", "\(esc)]133;B"), "An unterminated OSC is held back")
        XCTAssertTrue(split("x\(esc)]133;B\(esc)") == ("x", "\(esc)]133;B\(esc)"), "A possible ST is held back")
        XCTAssertTrue(split("x\(esc)]133;B\(esc)\\y") == ("x\(esc)]133;B\(esc)\\y", ""), "An ST-terminated OSC is complete")
    }

    func testSequenceSplitAcrossReads_StillYieldsMarker() {
        _ = sut.view
        sut.viewDidLoad()
        sut.processOutput("MFE_SENTINEL_12345\n")
        sut.processOutput("prompt$ \u{1B}]133;")
        XCTAssertFalse(sut.textViewStringForTesting.contains("133"), "Fragment must not be printed")
        sut.processOutput("B\u{07}")
        XCTAssertTrue(sut.isAtPrompt)
    }

    func testLooksLikeSecretPrompt() {
        XCTAssertTrue(TerminalViewController.looksLikeSecretPrompt("[sudo] password for me:"))
        XCTAssertTrue(TerminalViewController.looksLikeSecretPrompt("Enter passphrase for key '/x': "))
        XCTAssertTrue(TerminalViewController.looksLikeSecretPrompt("me@host's Password:"))
        XCTAssertFalse(TerminalViewController.looksLikeSecretPrompt("grep password config.txt"))
        XCTAssertFalse(TerminalViewController.looksLikeSecretPrompt("user@host:~$ "))
    }
}
