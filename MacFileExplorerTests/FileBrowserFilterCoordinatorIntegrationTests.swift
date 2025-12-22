import XCTest
@testable import MacFileExplorer

class FileBrowserFilterCoordinatorIntegrationTests: XCTestCase {

    private var tempDirectoryURL: URL!
    private var settingsStore: SettingsStore!
    private var defaultsSuiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()

        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileBrowserFilterCoordinatorTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)

        defaultsSuiteName = "com.macfileexplorer.tests.filter.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuiteName)!
        settingsStore = SettingsStore(defaults: defaults)
        settingsStore.startupFolder = tempDirectoryURL.path
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL, FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            try FileManager.default.removeItem(at: tempDirectoryURL)
        }
        if let defaultsSuiteName {
            UserDefaults(suiteName: defaultsSuiteName)?.removePersistentDomain(forName: defaultsSuiteName)
        }

        tempDirectoryURL = nil
        settingsStore = nil
        defaultsSuiteName = nil

        try super.tearDownWithError()
    }

    func testLoadsPersistedFilterCriteriaOnInit() throws {
        let criteria = FilterCriteria(
            searchText: "",
            fileTypes: ["pdf", "txt"],
            sizeMin: 1024,
            sizeMax: 2048,
            dateMin: Date(timeIntervalSince1970: 1_700_000_000),
            dateMax: Date(timeIntervalSince1970: 1_700_100_000),
            includeHidden: true
        )
        settingsStore.filterCriteriaData = try JSONEncoder().encode(criteria)

        let viewController = FileBrowserViewController(settings: settingsStore)
        _ = viewController.view

        assertCriteriaEqual(viewController.filterCriteria, criteria)
    }

    func testApplyFilterPersistsCriteria() throws {
        let viewController = FileBrowserViewController(settings: settingsStore)
        _ = viewController.view

        let criteria = FilterCriteria(
            searchText: "",
            fileTypes: ["png"],
            sizeMin: 512,
            sizeMax: nil,
            dateMin: nil,
            dateMax: nil,
            includeHidden: false
        )

        viewController.setFilter(criteria)

        let persisted = try XCTUnwrap(decodedCriteria())
        assertCriteriaEqual(persisted, criteria)
        assertCriteriaEqual(viewController.filterCriteria, criteria)
    }

    func testClearFiltersResetsCriteria() throws {
        let viewController = FileBrowserViewController(settings: settingsStore)
        _ = viewController.view

        let criteria = FilterCriteria(
            searchText: "",
            fileTypes: ["jpg"],
            sizeMin: 256,
            sizeMax: nil,
            dateMin: nil,
            dateMax: nil,
            includeHidden: false
        )

        viewController.setFilter(criteria)
        viewController.clearFilters()

        let persisted = try XCTUnwrap(decodedCriteria())
        XCTAssertFalse(persisted.isActive)
        XCTAssertFalse(viewController.filterCriteria.isActive)
    }

    private func decodedCriteria() -> FilterCriteria? {
        guard let data = settingsStore.filterCriteriaData else { return nil }
        return try? JSONDecoder().decode(FilterCriteria.self, from: data)
    }

    private func assertCriteriaEqual(_ lhs: FilterCriteria, _ rhs: FilterCriteria, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lhs.searchText, rhs.searchText, file: file, line: line)
        XCTAssertEqual(lhs.fileTypes, rhs.fileTypes, file: file, line: line)
        XCTAssertEqual(lhs.sizeMin, rhs.sizeMin, file: file, line: line)
        XCTAssertEqual(lhs.sizeMax, rhs.sizeMax, file: file, line: line)
        XCTAssertEqual(lhs.dateMin, rhs.dateMin, file: file, line: line)
        XCTAssertEqual(lhs.dateMax, rhs.dateMax, file: file, line: line)
        XCTAssertEqual(lhs.includeHidden, rhs.includeHidden, file: file, line: line)
    }
}
