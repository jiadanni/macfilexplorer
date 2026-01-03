import XCTest

class MacFileExplorerUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()
    }

    func testSidebarNavigation() throws {
        // Test clicking sidebar items
        // Test clicking sidebar items - Favorites are now in a TableView
        let favoritesTable = app.tables["FavoritesTable"]
        XCTAssertTrue(favoritesTable.exists)
        
        // Click "Applications"
        let applicationsRow = favoritesTable.tableRows.staticTexts["Applications"]
        if applicationsRow.exists {
             applicationsRow.click()
             // Verify window title or path control updates
             XCTAssertTrue(app.windows["Applications"].exists || app.staticTexts["Applications"].exists)
        }
    }

    func testPreviewPaneUpdates() throws {
        // Toggle preview pane if needed
        if !app.splitGroups.firstMatch.groups.containing(.staticText, identifier: "Preview").element.exists {
            app.toolbars.buttons["Toggle Preview Pane"].click()
        }
        
        let fileList = app.outlines["FileList"]
        XCTAssertTrue(fileList.exists)
        
        // Select first file
        let firstRow = fileList.cells.element(boundBy: 0)
        if firstRow.exists {
            firstRow.click()
            // Check preview pane content updates to match selection
            let previewTitle = app.staticTexts["PreviewTitle"] // Assuming identifier set in PreviewPane
            XCTAssertTrue(previewTitle.exists)
            XCTAssertEqual(previewTitle.label, firstRow.staticTexts.element(boundBy: 0).label)
        }
    }

    func testViewModeSwitching() throws {
        // Switch to Icon View
        app.toolbars.buttons["View Mode"].click()
        app.menuItems["Icons"].click()
        
        let collectionView = app.collectionViews["FileCollectionView"]
        XCTAssertTrue(collectionView.waitForExistence(timeout: 2))
        
        // Switch back to List View
        app.toolbars.buttons["View Mode"].click()
        app.menuItems["List"].click()
        
        let outlineView = app.outlines["FileList"]
        XCTAssertTrue(outlineView.waitForExistence(timeout: 2))
    }
}
