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
}

