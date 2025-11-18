import Cocoa

struct BrowserFactory {
    static func makeBrowser(target: FileBrowserViewController) -> NSBrowser {
        let browser = NSBrowser()
        browser.translatesAutoresizingMaskIntoConstraints = false
        browser.allowsMultipleSelection = true
        browser.allowsEmptySelection = true
        browser.takesTitleFromPreviousColumn = false
        browser.separatesColumns = true
        browser.rowHeight = 22.0
        browser.hasHorizontalScroller = true
        browser.autohidesScroller = true
        browser.minColumnWidth = 180
        browser.maxVisibleColumns = 4
        browser.doubleAction = #selector(FileBrowserViewController.handleBrowserDoubleClick(_:))
        browser.target = target
        browser.setCellClass(NSBrowserCell.self)
        browser.menu = target.createContextMenu()
        // Intentionally do NOT set delegate here; controller will assign after setup completes.
        return browser
    }
}
import Cocoa
import Cocoa

struct BrowserFactory {
    static func makeBrowser(target: FileBrowserViewController) -> NSBrowser {
        let browser = NSBrowser()
        browser.translatesAutoresizingMaskIntoConstraints = false
        browser.allowsMultipleSelection = true
        browser.allowsEmptySelection = true
        browser.takesTitleFromPreviousColumn = false
        browser.separatesColumns = true
        browser.rowHeight = 22.0
        browser.hasHorizontalScroller = true
        browser.autohidesScroller = true
        browser.minColumnWidth = 180
        browser.maxVisibleColumns = 4
        browser.doubleAction = #selector(FileBrowserViewController.handleBrowserDoubleClick(_:))
        browser.target = target
        browser.setCellClass(NSBrowserCell.self)
        browser.menu = target.createContextMenu()
        // Intentionally do NOT set delegate here; controller will assign after setup completes.
        return browser
    }
}
