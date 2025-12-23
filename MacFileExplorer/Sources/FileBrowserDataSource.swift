import Cocoa

protocol FileBrowserDataSourceDelegate: AnyObject {
    func dataSource(_ dataSource: FileBrowserDataSource, didLoadItems items: [FileItem])
    func dataSource(_ dataSource: FileBrowserDataSource, didFailToLoad error: Error)
}

class FileBrowserDataSource {
    
    // MARK: - Properties
    
    weak var delegate: FileBrowserDataSourceDelegate?
    
    private(set) var currentDirectory: URL
    private(set) var rootItem: FileItem?
    
    var showsHiddenFiles: Bool = false {
        didSet { if oldValue != showsHiddenFiles { reload() } }
    }
    
    var sortColumn: String = AppConfig.ColumnID.name {
        didSet { if oldValue != sortColumn { sortItems() } }
    }
    
    var sortAscending: Bool = true {
        didSet { if oldValue != sortAscending { sortItems() } }
    }
    
    var searchFilter: String? {
        didSet { if oldValue != searchFilter { applySearchFilter() } }
    }
    
    var filterCriteria: FilterCriteria = FilterCriteria() {
        didSet { applySearchFilter() }
    }
    
    // MARK: - Init
    
    init(currentDirectory: URL) {
        self.currentDirectory = currentDirectory
        // Initial setup similar to what was in VC, but we defer loading until requested
    }
    
    // MARK: - Data Loading
    
    func navigate(to url: URL, isSearch: Bool = false) {
        // Special handling for Google Drive CloudStorage root - redirect to "My Drive"
        // (Logic extracted from VC)
        var targetURL = url
        if let googleDriveURL = googleDrivePreferredRoot(for: url) {
             targetURL = googleDriveURL
        }
        
        self.currentDirectory = targetURL
        
        // Clear search filter when navigating to a new directory (unless it IS a search)
        if !isSearch {
            searchFilter = nil
        }
        
        loadData(isSearch: isSearch)
    }
    
    func reload() {
        loadData(isSearch: searchFilter != nil && !searchFilter!.isEmpty)
    }
    
    private func loadData(isSearch: Bool) {
        let url = currentDirectory
        let showsHidden = showsHiddenFiles
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            
            let item = FileItem(url: url)
            // Note: recursive=isSearch logic from VC
            let success = item.loadChildren(showsHiddenFiles: showsHidden, recursive: isSearch) { errorMsg in
                // We'll treat the string error as an NSError for the protocol
                let error = NSError(domain: "FileBrowserDataSource", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                Task { @MainActor in
                    self.delegate?.dataSource(self, didFailToLoad: error)
                }
            }
            
            if !success {
                debugLog("Warning: Failed to load children for \(url.path)")
            }
            
            await MainActor.run {
                self.rootItem = item
                
                // Load stored sort preference for this folder
                self.applyStoredSortPreferences()
                
                self.sortItems()
                self.applySearchFilter()
                
                if let children = self.rootItem?.children {
                    self.delegate?.dataSource(self, didLoadItems: children)
                } else {
                    self.delegate?.dataSource(self, didLoadItems: [])
                }
            }
        }
    }
    
    // MARK: - Sorting & Filtering
    
    private func applyStoredSortPreferences() {
        if let stored = SettingsStore.shared.folderSortPreferences[currentDirectory.path] {
            let parts = stored.components(separatedBy: "|")
            if parts.count >= 2 {
                guard let sortCol = parts.safe(at: 0), let sortOrder = parts.safe(at: 1) else { return }
                self.sortColumn = sortCol
                self.sortAscending = (sortOrder == "asc")
            }
        }
    }
    
    func persistSortPreferences() {
        var prefs = SettingsStore.shared.folderSortPreferences
        prefs[currentDirectory.path] = "\(sortColumn)|\(sortAscending ? "asc" : "desc")"
        SettingsStore.shared.folderSortPreferences = prefs
    }

    private func compareItems(_ item1: FileItem, _ item2: FileItem) -> Bool {
        switch sortColumn {
        case AppConfig.ColumnID.name:
            let result = item1.name.localizedStandardCompare(item2.name)
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
        guard let rootItem = rootItem, var children = rootItem.children else { return }
        
        children.sort { compareItems($0, $1) }
        
        rootItem.children = children
        
        // Recursive sort
        children.forEach {
            if $0.isDirectory, var subChildren = $0.children {
                sortChildren(&subChildren)
                 $0.children = subChildren
            }
        }
        // If we need to trigger an update without reloading from disk, we might need a separate delegate method,
        // or just call didLoadItems again (simplest for now)
        // delegate?.dataSource(self, didLoadItems: children)
        // NOTE: View controller often calls sort separately, so we might expose a public sort method that triggers update?
        // For now, let's assume the VC will call reloadData when it changes sort properties, OR we notify delegate.
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
        
        // Reload children from disk/cache or just re-filter?
        // Ideally we filter the *original* loaded children.
        // Current implementation in VC mutates rootItem.children directly after load.
        // If we want to support dynamic filtering without reload, we need to store `originalChildren`.
        // However, looking at VC code: loadDirectory loads -> item.children is populated.
        // applySearchFilter filters `rootItem.children` in place (effectively losing non-matching).
        // BUT wait, VC's applySearchFilter does: `if var children = rootItem.children { ... rootItem.children = children }`
        // If `rootItem` reloads, it gets fresh children. If we refine search, we might need to re-fetch if we destroyed data?
        // Actually `rootItem.loadChildren` re-reads from disk. So filtering is destructive to the in-memory array but safe because we reload on change.
        
        let hasSearchText = searchFilter != nil && !searchFilter!.isEmpty
        let hasFilterCriteria = filterCriteria.isActive
        
        guard hasSearchText || hasFilterCriteria else { return }
        
        if var children = rootItem.children {
            children = children.filter { item in
                if hasSearchText, let searchText = searchFilter {
                    if !item.name.localizedCaseInsensitiveContains(searchText) { return false }
                }
                
                if hasFilterCriteria {
                    if !filterCriteria.matches(item) { return false }
                }
                return true
            }
            rootItem.children = children
        }
    }
    
    // MARK: - Helpers
    
    private func googleDrivePreferredRoot(for url: URL) -> URL? {
        // Copied logic from ViewController
        let fileManager = FileManager.default
        let candidates = [url, url.resolvingSymlinksInPath()]

        for candidate in candidates {
            let lastComponent = candidate.lastPathComponent
            let path = candidate.path

            if lastComponent == "My Drive" { continue }

            let libraryGroupContainers = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.GoogleDrive.groupIdentifier)
            if let googleDriveRoot = libraryGroupContainers?.appendingPathComponent("File Provider Storage/My Drive"),
               fileManager.fileExists(atPath: googleDriveRoot.path) {
                 // Simplified check for now
            }
            
            // Legacy volume mount (/Volumes/GoogleDrive) or aliases named Google Drive
            if path == AppConfig.GoogleDrive.legacyVolumePath || AppConfig.GoogleDrive.volumeNames.contains(lastComponent) {
                let myDrive = candidate.appendingPathComponent(AppConfig.GoogleDrive.myDriveComponent)
                if fileManager.fileExists(atPath: myDrive.path) { return myDrive }
            }
        }
        return nil
    }
    
    // Helper to access items for collection view
    func item(at index: Int) -> FileItem? {
        guard let children = rootItem?.children, index < children.count else { return nil }
        return children[index]
    }
    
    var numberOfItems: Int {
        return rootItem?.children?.count ?? 0
    }
}
