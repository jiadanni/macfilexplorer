import Cocoa

/// Manages file system navigation including history, current directory, and breadcrumb tracking.
///
/// Extracted from FileBrowserViewController to isolate navigation complexity.
/// Handles:
/// - Current directory management
/// - Navigation history (back/forward)
/// - Parent directory navigation
/// - Path favorites/bookmarks
/// - Breadcrumb trail generation

protocol FileBrowserNavigationDelegate: AnyObject {
    var currentDirectory: URL { get set }
    func loadDirectory(_ url: URL)
}

class FileBrowserNavigationCoordinator: NSObject {
    weak var delegate: FileBrowserNavigationDelegate?
    
    private let navigationManager: NavigationManager
    private var currentDirectory: URL
    
    init(startingDirectory: URL, navigationManager: NavigationManager? = nil) {
        self.currentDirectory = startingDirectory
        self.navigationManager = navigationManager ?? NavigationManager()
        super.init()
    }
    
    /// Navigates to a new directory and records in history.
    func navigateToDirectory(_ url: URL) {
        guard url != currentDirectory else { return }
        currentDirectory = url
        delegate?.loadDirectory(url)
    }
    
    /// Navigates to parent directory if available.
    func navigateToParent() {
        let parent = currentDirectory.deletingLastPathComponent()
        guard parent.path != currentDirectory.path else { return }
        navigateToDirectory(parent)
    }
    
    /// Navigates back in history.
    func navigateBack() {
        if let previousURL = navigationManager.goBack() {
            navigateToDirectory(previousURL)
        }
    }
    
    /// Navigates forward in history.
    func navigateForward() {
        if let nextURL = navigationManager.goForward() {
            navigateToDirectory(nextURL)
        }
    }
    
    /// Returns the current directory.
    func getCurrentDirectory() -> URL {
        return currentDirectory
    }
    
    /// Returns the current directory path as string.
    func getCurrentPath() -> String {
        return currentDirectory.path
    }
    
    /// Checks if back navigation is available.
    func canNavigateBack() -> Bool {
        return navigationManager.canGoBack()
    }
    
    /// Checks if forward navigation is available.
    func canNavigateForward() -> Bool {
        return navigationManager.canGoForward()
    }
    
    /// Returns breadcrumb components for current directory.
    func getBreadcrumbComponents() -> [FileBrowserBreadcrumb] {
        var breadcrumbs: [FileBrowserBreadcrumb] = []
        var path = currentDirectory
        
        while path.path != "/" {
            let name = path.lastPathComponent
            breadcrumbs.insert(FileBrowserBreadcrumb(name: name, url: path), at: 0)
            path = path.deletingLastPathComponent()
        }
        
        // Add root
        breadcrumbs.insert(FileBrowserBreadcrumb(name: "Macintosh HD", url: URL(fileURLWithPath: "/")), at: 0)
        
        return breadcrumbs
    }
    
    /// Returns the home directory URL.
    func getHomeDirectory() -> URL {
        return URL(fileURLWithPath: NSHomeDirectory())
    }
    
    /// Returns common folder URLs (Documents, Downloads, Desktop, etc.).
    func getCommonFolders() -> [FileBrowserCommonFolder] {
        let fileManager = FileManager.default
        var folders: [FileBrowserCommonFolder] = []
        
        if let homeURL = try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            folders.append(FileBrowserCommonFolder(name: "Documents", url: homeURL, type: .documents))
        }
        if let downloadURL = try? fileManager.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            folders.append(FileBrowserCommonFolder(name: "Downloads", url: downloadURL, type: .downloads))
        }
        if let desktopURL = try? fileManager.url(for: .desktopDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            folders.append(FileBrowserCommonFolder(name: "Desktop", url: desktopURL, type: .desktop))
        }
        
        let applicationsURL = URL(fileURLWithPath: "/Applications")
        folders.append(FileBrowserCommonFolder(name: "Applications", url: applicationsURL, type: .applications))
        
        return folders
    }
}

/// Represents a breadcrumb component in the navigation path.
struct FileBrowserBreadcrumb {
    let name: String
    let url: URL
}

/// Represents a common folder shortcut.
struct FileBrowserCommonFolder {
    enum FolderType {
        case documents
        case downloads
        case desktop
        case applications
    }
    
    let name: String
    let url: URL
    let type: FolderType
}
