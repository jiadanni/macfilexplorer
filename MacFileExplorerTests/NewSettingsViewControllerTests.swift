import XCTest
@testable import MacFileExplorer

class NewSettingsViewControllerTests: XCTestCase {

    override func tearDown() {
        PendingSettings.shared.cancelChanges()
        super.tearDown()
    }

    func testGeneralSettings() {
        let generalVC = GeneralSettingsViewController()
        let button = NSButton()
        let key = UserDefaults.Keys.warnOnExtensionChange.rawValue
        button.tag = key.hashValue
        button.state = .on
        generalVC.checkboxChanged(button)
        XCTAssertEqual(PendingSettings.shared.getValue(forKey: key) as? Bool, true)
    }

    func testTabsSettings() {
        let tabsVC = TabsSettingsViewController()
        let button = NSButton()
        let key = UserDefaults.Keys.restoreTabsOnReopen.rawValue
        button.tag = key.hashValue
        button.state = .on
        tabsVC.checkboxChanged(button)
        XCTAssertEqual(PendingSettings.shared.getValue(forKey: key) as? Bool, true)
    }

    func testSidebarSettings() {
        let sidebarVC = SidebarSettingsViewController()
        let button = NSButton()
        let favoritesKey = UserDefaults.Keys.showFavorites.rawValue
        button.tag = favoritesKey.hashValue
        button.state = .off
        sidebarVC.checkboxChanged(button)
        XCTAssertEqual(PendingSettings.shared.getValue(forKey: favoritesKey) as? Bool, false)

        let segmentedControl = NSSegmentedControl()
        segmentedControl.selectedSegment = 1
        sidebarVC.sidebarOrderChanged(segmentedControl)
        XCTAssertEqual(PendingSettings.shared.getValue(forKey: UserDefaults.Keys.sidebarOrder.rawValue) as? Int, 1)
    }

    func testTerminalSettings() {
        let terminalVC = TerminalSettingsViewController()
        let button = NSButton()
        let key = UserDefaults.Keys.openTerminalByDefault.rawValue
        button.tag = key.hashValue
        button.state = .on
        terminalVC.checkboxChanged(button)
        XCTAssertEqual(PendingSettings.shared.getValue(forKey: key) as? Bool, true)
    }
}
