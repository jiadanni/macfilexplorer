import Cocoa

/// Manages file system navigation including history and breadcrumb tracking.
///
/// Extracted from FileBrowserViewController to isolate navigation complexity.
protocol FileBrowserNavigationCoordinatorDelegate: AnyObject {
    var currentDirectory: URL { get }
    func navigationCoordinator(_ coordinator: FileBrowserNavigationCoordinator, didRequestLoad url: URL, isSearch: Bool)
    func navigationCoordinator(_ coordinator: FileBrowserNavigationCoordinator, didUpdateState state: NavigationState)
}

final class FileBrowserNavigationCoordinator: NSObject, NavigationManagerDelegate {
    weak var delegate: FileBrowserNavigationCoordinatorDelegate?

    private let navigationManager: NavigationManager

    init(navigationManager: NavigationManager = NavigationManager()) {
        self.navigationManager = navigationManager
        super.init()
        navigationManager.delegate = self
    }

    func loadDirectory(_ url: URL, addToHistory: Bool = true, isSearch: Bool = false) {
        navigationManager.navigate(to: url, addToHistory: addToHistory)
        delegate?.navigationCoordinator(self, didRequestLoad: url, isSearch: isSearch)
    }

    func navigateToParent() {
        guard let currentDirectory = delegate?.currentDirectory else { return }
        let parent = currentDirectory.deletingLastPathComponent()
        guard parent.path != currentDirectory.path else { return }
        loadDirectory(parent)
    }

    func goBack() {
        if let previousURL = navigationManager.goBack() {
            delegate?.navigationCoordinator(self, didRequestLoad: previousURL, isSearch: false)
        }
    }

    func goForward() {
        if let nextURL = navigationManager.goForward() {
            delegate?.navigationCoordinator(self, didRequestLoad: nextURL, isSearch: false)
        }
    }

    func navigateToHistoryIndex(_ index: Int) {
        if let url = navigationManager.navigateToHistoryIndex(index) {
            delegate?.navigationCoordinator(self, didRequestLoad: url, isSearch: false)
        }
    }

    func navigationManager(_ manager: NavigationManager, didUpdateState state: NavigationState) {
        delegate?.navigationCoordinator(self, didUpdateState: state)
    }

    func getBreadcrumbComponents() -> [FileBrowserBreadcrumb] {
        guard let currentDirectory = delegate?.currentDirectory else { return [] }
        var breadcrumbs: [FileBrowserBreadcrumb] = []
        var path = currentDirectory

        while path.path != "/" {
            let name = path.lastPathComponent
            breadcrumbs.insert(FileBrowserBreadcrumb(name: name, url: path), at: 0)
            path = path.deletingLastPathComponent()
        }

        breadcrumbs.insert(FileBrowserBreadcrumb(name: "Macintosh HD", url: URL(fileURLWithPath: "/")), at: 0)
        return breadcrumbs
    }

    func getHomeDirectory() -> URL {
        URL(fileURLWithPath: NSHomeDirectory())
    }

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
