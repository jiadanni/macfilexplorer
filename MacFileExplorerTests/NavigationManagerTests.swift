import XCTest
@testable import MacFileExplorer

final class NavigationManagerTests: XCTestCase {
    var navigationManager: NavigationManager!
    var mockDelegate: MockNavigationManagerDelegate!

    override func setUp() {
        super.setUp()
        navigationManager = NavigationManager()
        mockDelegate = MockNavigationManagerDelegate()
        navigationManager.delegate = mockDelegate
    }

    override func tearDown() {
        navigationManager = nil
        mockDelegate = nil
        super.tearDown()
    }

    func testGoBackSuccess() {
        let url1 = URL(fileURLWithPath: "/test/1")
        let url2 = URL(fileURLWithPath: "/test/2")

        navigationManager.navigate(to: url1)
        navigationManager.navigate(to: url2)

        XCTAssertEqual(navigationManager.currentIndex, 1)
        XCTAssertTrue(navigationManager.canGoBack)

        let initialNotificationCount = mockDelegate.notificationCount

        let resultURL = navigationManager.goBack()

        XCTAssertEqual(resultURL, url1)
        XCTAssertEqual(navigationManager.currentIndex, 0)
        XCTAssertEqual(navigationManager.currentURL, url1)
        XCTAssertEqual(mockDelegate.notificationCount, initialNotificationCount + 1)
        XCTAssertEqual(mockDelegate.lastState?.currentURL, url1)
    }

    func testGoBackFailure() {
        let url1 = URL(fileURLWithPath: "/test/1")
        navigationManager.navigate(to: url1)

        XCTAssertEqual(navigationManager.currentIndex, 0)
        XCTAssertFalse(navigationManager.canGoBack)

        let initialNotificationCount = mockDelegate.notificationCount

        let resultURL = navigationManager.goBack()

        XCTAssertNil(resultURL)
        XCTAssertEqual(navigationManager.currentIndex, 0)
        XCTAssertEqual(mockDelegate.notificationCount, initialNotificationCount)
    }

    func testGoBackMultipleSteps() {
        let urls = [
            URL(fileURLWithPath: "/test/1"),
            URL(fileURLWithPath: "/test/2"),
            URL(fileURLWithPath: "/test/3")
        ]

        urls.forEach { navigationManager.navigate(to: $0) }

        XCTAssertEqual(navigationManager.currentIndex, 2)

        // Go back to second URL
        var resultURL = navigationManager.goBack()
        XCTAssertEqual(resultURL, urls[1])
        XCTAssertEqual(navigationManager.currentIndex, 1)

        // Go back to first URL
        resultURL = navigationManager.goBack()
        XCTAssertEqual(resultURL, urls[0])
        XCTAssertEqual(navigationManager.currentIndex, 0)

        // Try going back further
        resultURL = navigationManager.goBack()
        XCTAssertNil(resultURL)
        XCTAssertEqual(navigationManager.currentIndex, 0)
    }
}

class MockNavigationManagerDelegate: NavigationManagerDelegate {
    var lastState: NavigationState?
    var notificationCount = 0

    func navigationManager(_ manager: NavigationManager, didUpdateState state: NavigationState) {
        lastState = state
        notificationCount += 1
    }
}
