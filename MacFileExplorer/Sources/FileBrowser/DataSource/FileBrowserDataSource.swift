import Cocoa

protocol FileBrowserDataSourceDelegate: AnyObject {
    func dataSource(_ dataSource: FileBrowserDataSource, didLoadItems items: [FileItem])
    func dataSource(_ dataSource: FileBrowserDataSource, didFailToLoad error: Error)
}

@MainActor
class FileBrowserDataSource {
    
    // MARK: - Properties
    
    weak var delegate: FileBrowserDataSourceDelegate?
    
    /// Injected settings store for folder sort preferences
    private let settings: SettingsStoreProtocol
    
    private(set) var currentDirectory: URL
    private(set) var rootItem: FileItem?
    private var loadGeneration: Int = 0
    private var loadTask: Task<Void, Never>?
    private var unfilteredItems: [FileItem] = []
    private var isUpdatingSilently = false

    var showsHiddenFiles: Bool = false {
        didSet { 
            if !isUpdatingSilently && oldValue != showsHiddenFiles { reload() } 
        }
    }
    
    var sortColumn: String = AppConfig.ColumnID.name {
        didSet { 
            if !isUpdatingSilently && oldValue != sortColumn { sortItems() } 
        }
    }
    
    var sortAscending: Bool = true {
        didSet { 
            if !isUpdatingSilently && oldValue != sortAscending { sortItems() } 
        }
    }
    
    var searchFilter: String? {
        didSet { 
            if !isUpdatingSilently && oldValue != searchFilter { applySearchFilter() } 
        }
    }
    
    var filterCriteria: FilterCriteria = FilterCriteria() {
        didSet { 
            if !isUpdatingSilently { applySearchFilter() } 
        }
    }
    
    // MARK: - Init
    
    init(currentDirectory: URL, settings: SettingsStoreProtocol = SettingsStore.shared) {
        self.currentDirectory = currentDirectory
        self.settings = settings
    }
    
    // MARK: - Data Loading

    /// Applies persisted hidden-files state without triggering a reload.
    /// Used during controller setup, before the initial directory load happens.
    func applyInitialHiddenFilesState(_ showsHidden: Bool) {
        isUpdatingSilently = true
        showsHiddenFiles = showsHidden
        isUpdatingSilently = false
    }

    func navigate(to url: URL, isSearch: Bool = false) {
        var targetURL = url
        if let googleDriveURL = googleDrivePreferredRoot(for: url) {
             targetURL = googleDriveURL
        }
        
        self.currentDirectory = targetURL
        
        if !isSearch {
            isUpdatingSilently = true
            self.searchFilter = nil
            isUpdatingSilently = false
        }
        
        loadData(isSearch: isSearch)
    }
    
    func reload() {
        loadData(isSearch: searchFilter != nil && !searchFilter!.isEmpty)
    }
    
    private func loadData(isSearch: Bool) {
        let url = currentDirectory
        let showsHidden = showsHiddenFiles
        
        // Cancel any previous load and bump generation atomically
        loadTask?.cancel()
        let generation = nextLoadGeneration()
        
        loadTask = Task {
            let result = await Task.detached(priority: .userInitiated) {
                let item = FileItem(url: url)
                var errorToReport: Error?
                
                let success = item.loadChildren(showsHiddenFiles: showsHidden, recursive: isSearch) { errorMsg in
                    errorToReport = NSError(domain: "FileBrowserDataSource", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                }
                
                if !success && errorToReport == nil {
                    let exists = FileManager.default.fileExists(atPath: url.path)
                    let message = exists
                        ? "Unable to open '\(url.lastPathComponent)'."
                        : "The folder '\(url.lastPathComponent)' could not be found or is unavailable."
                    errorToReport = NSError(domain: "FileBrowserDataSource", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
                }
                
                return (item, errorToReport)
            }.value
            
            if Task.isCancelled { return }
            guard self.isCurrentLoad(generation) else { return }
            
            let (item, error) = result
            if let error = error {
                self.delegate?.dataSource(self, didFailToLoad: error)
                return
            }

            self.rootItem = item
            self.unfilteredItems = item.children ?? []

            isUpdatingSilently = true
            self.applyStoredSortPreferences()
            isUpdatingSilently = false

            self.sortItems() // This will call applySearchFilter and notify delegate ONCE
        }
    }
    
    // MARK: - Sorting & Filtering
    
    private func applyStoredSortPreferences() {
        if let stored = settings.folderSortPreferences[currentDirectory.path] {
            let parts = stored.components(separatedBy: "|")
            if parts.count >= 2, !parts[0].isEmpty {
                self.sortColumn = parts[0]
                self.sortAscending = (parts[1] == "asc")
            }
        }
    }
    
    func persistSortPreferences() {
        var prefs = settings.folderSortPreferences
        prefs[currentDirectory.path] = "\(sortColumn)|\(sortAscending ? "asc" : "desc")"
        settings.folderSortPreferences = prefs
    }

    private func compareItems(_ item1: FileItem, _ item2: FileItem) -> Bool {
        switch sortColumn {
        case AppConfig.ColumnID.name:
            let result = item1.name.safeLocalizedCompare(item2.name)
            return sortAscending ? (result == .orderedAscending) : (result == .orderedDescending)
        case AppConfig.ColumnID.size:
            if item1.isDirectory != item2.isDirectory { return item1.isDirectory }
            return sortAscending ? item1.size < item2.size : item1.size > item2.size
        case AppConfig.ColumnID.dateModified:
            guard let date1 = item1.modificationDate, let date2 = item2.modificationDate else { return false }
            return sortAscending ? date1 < date2 : date1 > date2
        case AppConfig.ColumnID.dateCreated:
            guard let date1 = item1.creationDate, let date2 = item2.creationDate else { return false }
            return sortAscending ? date1 < date2 : date1 > date2
        case AppConfig.ColumnID.type:
            return sortAscending ? item1.kind < item2.kind : item1.kind > item2.kind
        default:
            return false
        }
    }

    private func sortItems() {
        measureTime("DataSource: sortItems") {
            unfilteredItems.sort { compareItems($0, $1) }
            
            // Recursive sort subfolders (these are shared between lists)
            unfilteredItems.forEach {
                if $0.isDirectory, var subChildren = $0.children {
                    sortChildren(&subChildren)
                     $0.children = subChildren
                }
            }
        }
        
        // Re-apply filter since source order changed
        applySearchFilter()
    }
    
    private func sortChildren(_ children: inout [FileItem]) {
        children.sort { compareItems($0, $1) }

        children.forEach {
            if $0.isDirectory, var subChildren = $0.children {
                sortChildren(&subChildren)
                $0.children = subChildren
            }
        }
    }
    
    private func applySearchFilter() {
        guard let rootItem = rootItem else { return }
        
        measureTime("DataSource: applySearchFilter") {
            let hasSearchText = searchFilter != nil && !searchFilter!.isEmpty
            let hasFilterCriteria = filterCriteria.isActive
            
            if !(hasSearchText || hasFilterCriteria) {
                rootItem.children = unfilteredItems
            } else {
                rootItem.children = unfilteredItems.filter { item in
                    if hasSearchText, let searchText = searchFilter {
                        if !item.name.localizedCaseInsensitiveContains(searchText) { return false }
                    }
                    
                    if hasFilterCriteria {
                        if !filterCriteria.matches(item) { return false }
                    }
                    return true
                }
            }
        }
        
        // Notify delegate about the change in visible items
        if let children = rootItem.children {
            delegate?.dataSource(self, didLoadItems: children)
        }
    }
    
    // MARK: - Helpers
    
    private func googleDrivePreferredRoot(for url: URL) -> URL? {
        let fileManager = FileManager.default
        let candidates = [url, url.resolvingSymlinksInPath()]

        for candidate in candidates {
            let lastComponent = candidate.lastPathComponent
            let path = candidate.path

            // If already at "My Drive", don't redirect
            if lastComponent == AppConfig.GoogleDrive.myDriveComponent { continue }

            // Check if this is a Google Drive path that needs redirection
            let isGoogleDriveCandidate = path.contains("Google Drive") ||
                                         path.contains("GoogleDrive") ||
                                         path == AppConfig.GoogleDrive.legacyVolumePath ||
                                         AppConfig.GoogleDrive.volumeNames.contains(lastComponent)
            
            guard isGoogleDriveCandidate else { continue }

            // Strategy 1: Try to find "My Drive" as a subdirectory
            let myDrive = candidate.appendingPathComponent(AppConfig.GoogleDrive.myDriveComponent)
            if fileManager.fileExists(atPath: myDrive.path) {
                debugLog("✅ Found My Drive at: \(myDrive.path)")
                return myDrive
            }

            // Strategy 2: Check if the candidate itself is a valid Google Drive mount
            // (some versions mount directly without subdirectories)
            if fileManager.fileExists(atPath: candidate.path) {
                // Verify it's actually accessible
                let isReadable = fileManager.isReadableFile(atPath: candidate.path)
                if isReadable {
                    debugLog("✅ Found Google Drive mount at: \(candidate.path)")
                    return candidate
                }
            }
        }
        
        return nil
    }

    private func nextLoadGeneration() -> Int {
        loadGeneration += 1
        return loadGeneration
    }

    private func isCurrentLoad(_ generation: Int) -> Bool {
        return generation == loadGeneration
    }
    
    // Helper to access items for collection view
    func item(at index: Int) -> FileItem? {
        guard let children = rootItem?.children,
              index >= 0, index < children.count else { return nil }
        return children[index]
    }
    
    var numberOfItems: Int {
        return rootItem?.children?.count ?? 0
    }
}
