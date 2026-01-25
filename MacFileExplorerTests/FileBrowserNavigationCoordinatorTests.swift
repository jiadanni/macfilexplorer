import XCTest
@testable import MacFileExplorer

final class FileBrowserNavigationCoordinatorTests: XCTestCase {
    var coordinator: FileBrowserNavigationCoordinator!
    var mockDelegate: MockNavigationDelegate!
    var navigationManager: NavigationManager!

    override func setUp() {
        super.setUp()
        navigationManager = NavigationManager()
        coordinator = FileBrowserNavigationCoordinator(navigationManager: navigationManager)
        mockDelegate = MockNavigationDelegate()
        coordinator.delegate = mockDelegate
    }

    override func tearDown() {
        coordinator = nil
        mockDelegate = nil
        navigationManager = nil
        super.tearDown()
    }

    func testLoadDirectory() {
        let url = URL(fileURLWithPath: "/Users/test/Documents")
        coordinator.loadDirectory(url)

        XCTAssertEqual(mockDelegate.requestedURL, url)
        XCTAssertEqual(navigationManager.currentURL, url)
        XCTAssertTrue(mockDelegate.didUpdateStateCalled)
    }

    func testNavigateToParent() {
        let currentURL = URL(fileURLWithPath: "/Users/test/Documents")
        mockDelegate.currentDirectory = currentURL
        
        coordinator.navigateToParent()
        
        let expectedParent = URL(fileURLWithPath: "/Users/test")
        XCTAssertEqual(mockDelegate.requestedURL?.path, expectedParent.path)
    }

    func testGoBackAndForward() {
        let url1 = URL(fileURLWithPath: "/Users/test/1")
        let url2 = URL(fileURLWithPath: "/Users/test/2")
        
        coordinator.loadDirectory(url1)
        coordinator.loadDirectory(url2)
        
        XCTAssertTrue(navigationManager.canGoBack)
        
        coordinator.goBack()
        XCTAssertEqual(mockDelegate.requestedURL, url1)
        
        coordinator.goForward()
        XCTAssertEqual(mockDelegate.requestedURL, url2)
    }

    func testGetBreadcrumbs() {
        mockDelegate.currentDirectory = URL(fileURLWithPath: "/Users/test/Documents")
        
        let breadcrumbs = coordinator.getBreadcrumbComponents()
        
        XCTAssertEqual(breadcrumbs.count, 4) // /, Users, test, Documents
        XCTAssertEqual(breadcrumbs[0].name, "Macintosh HD")
        XCTAssertEqual(breadcrumbs[1].name, "Users")
        XCTAssertEqual(breadcrumbs[2].name, "test")
        XCTAssertEqual(breadcrumbs[3].name, "Documents")
    }
}

class MockNavigationDelegate: FileBrowserNavigationCoordinatorDelegate {
    var currentDirectory: URL = URL(fileURLWithPath: "/Users/test")
    var requestedURL: URL?
    var didUpdateStateCalled = false
    var lastState: NavigationState?

    func navigationCoordinator(_ coordinator: FileBrowserNavigationCoordinator, didRequestLoad url: URL, isSearch: Bool) {
        requestedURL = url
    }

    func navigationCoordinator(_ coordinator: FileBrowserNavigationCoordinator, didUpdateState state: NavigationState) {
        didUpdateStateCalled = true
        lastState = state
    }
}
