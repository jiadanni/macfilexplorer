import XCTest
@testable import MacFileExplorer

class NewSettingsViewControllerTests: XCTestCase {

    func testGeneralSettings() {
        let generalVC = GeneralSettingsViewController()
        let button = NSButton()
        button.tag = UserDefaults.Keys.warnOnExtensionChange.rawValue.hashValue
        button.state = .on
        generalVC.checkboxChanged(button)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: UserDefaults.Keys.warnOnExtensionChange.rawValue))
    }

    func testTabsSettings() {
        let tabsVC = TabsSettingsViewController()
        let button = NSButton()
        button.tag = UserDefaults.Keys.restoreTabsOnReopen.rawValue.hashValue
        button.state = .on
        tabsVC.checkboxChanged(button)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: UserDefaults.Keys.restoreTabsOnReopen.rawValue))
    }

    func testSidebarSettings() {
        let sidebarVC = SidebarSettingsViewController()
        let button = NSButton()
        button.tag = UserDefaults.Keys.showFavorites.rawValue.hashValue
        button.state = .off
        sidebarVC.checkboxChanged(button)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: UserDefaults.Keys.showFavorites.rawValue))

        let segmentedControl = NSSegmentedControl()
        segmentedControl.selectedSegment = 1
        sidebarVC.sidebarOrderChanged(segmentedControl)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: UserDefaults.Keys.sidebarOrder.rawValue), 1)
    }

    func testTerminalSettings() {
        let terminalVC = TerminalSettingsViewController()
        let button = NSButton()
        button.tag = UserDefaults.Keys.openTerminalByDefault.rawValue.hashValue
        button.state = .on
        terminalVC.checkboxChanged(button)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: UserDefaults.Keys.openTerminalByDefault.rawValue))
    }
}
