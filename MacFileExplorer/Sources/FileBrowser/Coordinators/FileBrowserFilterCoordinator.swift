import Cocoa

/// Manages file filtering and search functionality.
///
/// Extracted from FileBrowserViewController to isolate filter/search complexity.
/// Handles:
/// - Search text input
/// - Filter criteria management
/// - Real-time filtering
/// - Filter persistence
/// - Search history

protocol FileBrowserFilterDelegate: AnyObject {
    func reloadBrowserData()
    func setFilterCriteria(_ criteria: FilterCriteria)
}

class FileBrowserFilterCoordinator: NSObject {
    weak var delegate: FileBrowserFilterDelegate?
    private var settingsStore: SettingsStoreProtocol
    
    private var currentFilterCriteria = FilterCriteria()
    private var searchHistory: [String] = []
    private let maxSearchHistorySize = AppConfig.Limits.maxSearchHistorySize
    
    /// Initializes filter coordinator.
    init(settingsStore: SettingsStoreProtocol) {
        self.settingsStore = settingsStore
        super.init()
    }
    
    /// Loads persisted filters and initializes state.
    func initialize() {
        loadFilterCriteria()
        loadSearchHistory()
    }
    
    /// Loads persisted filter criteria from settings.
    private func loadFilterCriteria() {
        if let savedCriteria = settingsStore.filterCriteriaData {
            if let decoded = try? JSONDecoder().decode(FilterCriteria.self, from: savedCriteria) {
                currentFilterCriteria = decoded
            }
        }
    }
    
    /// Saves current filter criteria to settings.
    private func saveFilterCriteria() {
        if let encoded = try? JSONEncoder().encode(currentFilterCriteria) {
            settingsStore.filterCriteriaData = encoded
        }
    }
    
    /// Loads search history from settings.
    private func loadSearchHistory() {
        searchHistory = settingsStore.searchHistory
    }
    
    /// Saves search history to settings.
    private func saveSearchHistory() {
        settingsStore.searchHistory = searchHistory
    }
    
    /// Applies a search filter with the given text.
    func applySearchFilter(_ text: String) {
        currentFilterCriteria.searchText = text
        saveFilterCriteria()
        addToSearchHistory(text)
        
        guard let delegate = delegate else { return }
        delegate.setFilterCriteria(currentFilterCriteria)
        delegate.reloadBrowserData()
    }

    /// Applies a full filter criteria update and persists it.
    func applyFilterCriteria(_ criteria: FilterCriteria) {
        currentFilterCriteria = criteria
        saveFilterCriteria()

        guard let delegate = delegate else { return }
        delegate.setFilterCriteria(currentFilterCriteria)
        delegate.reloadBrowserData()
    }
    
    /// Clears all filters and reloads data.
    func clearFilters() {
        currentFilterCriteria = FilterCriteria()
        saveFilterCriteria()
        
        guard let delegate = delegate else { return }
        delegate.setFilterCriteria(currentFilterCriteria)
        delegate.reloadBrowserData()
    }
    
    /// Sets file type filter.
    func setFileTypeFilter(_ fileTypes: [String]) {
        currentFilterCriteria.fileTypes = Set(fileTypes)
        saveFilterCriteria()
        
        guard let delegate = delegate else { return }
        delegate.setFilterCriteria(currentFilterCriteria)
        delegate.reloadBrowserData()
    }
    
    /// Sets date range filter.
    func setDateRangeFilter(from: Date?, to: Date?) {
        currentFilterCriteria.dateMin = from
        currentFilterCriteria.dateMax = to
        saveFilterCriteria()
        
        guard let delegate = delegate else { return }
        delegate.setFilterCriteria(currentFilterCriteria)
        delegate.reloadBrowserData()
    }
    
    /// Sets file size range filter.
    func setSizeRangeFilter(minSize: UInt64?, maxSize: UInt64?) {
        currentFilterCriteria.sizeMin = minSize.map { Int64($0) }
        currentFilterCriteria.sizeMax = maxSize.map { Int64($0) }
        saveFilterCriteria()
        
        guard let delegate = delegate else { return }
        delegate.setFilterCriteria(currentFilterCriteria)
        delegate.reloadBrowserData()
    }
    
    /// Returns the current filter criteria.
    func getFilterCriteria() -> FilterCriteria {
        return currentFilterCriteria
    }
    
    /// Returns whether any filters are currently active.
    func hasActiveFilters() -> Bool {
        return currentFilterCriteria.isActive
    }
    
    /// Adds search term to history.
    private func addToSearchHistory(_ term: String) {
        guard !term.isEmpty else { return }
        
        // Remove if already exists
        searchHistory.removeAll { $0 == term }
        
        // Add to beginning
        searchHistory.insert(term, at: 0)
        
        // Limit size
        if searchHistory.count > maxSearchHistorySize {
            searchHistory.removeLast()
        }
        
        saveSearchHistory()
    }
    
    /// Returns search history for display.
    func getSearchHistory() -> [String] {
        return searchHistory
    }
}

/// Represents search and filter criteria.
