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
    var filterPanel: FilterPanelViewController! { get }
    var settingsStore: SettingsStore! { get }
    func reloadBrowserData()
    func setFilterCriteria(_ criteria: FilterCriteria)
}

class FileBrowserFilterCoordinator: NSObject {
    weak var delegate: FileBrowserFilterDelegate?
    
    private var currentFilterCriteria = FilterCriteria()
    private var searchHistory: [String] = []
    private let maxSearchHistorySize = 50
    
    /// Initializes filter coordinator and loads persisted filters.
    func initialize() {
        loadFilterCriteria()
        loadSearchHistory()
        setupFilterPanel()
    }
    
    /// Loads persisted filter criteria from settings.
    private func loadFilterCriteria() {
        guard let delegate = delegate else { return }
        
        if let savedCriteria = delegate.settingsStore.data(forKey: "filterCriteria") {
            if let decoded = try? JSONDecoder().decode(FilterCriteria.self, from: savedCriteria) {
                currentFilterCriteria = decoded
            }
        }
    }
    
    /// Saves current filter criteria to settings.
    private func saveFilterCriteria() {
        guard let delegate = delegate else { return }
        
        if let encoded = try? JSONEncoder().encode(currentFilterCriteria) {
            delegate.settingsStore.setValue(encoded, forKey: "filterCriteria")
        }
    }
    
    /// Loads search history from settings.
    private func loadSearchHistory() {
        guard let delegate = delegate else { return }
        
        if let history = delegate.settingsStore.value(forKey: "searchHistory") as? [String] {
            searchHistory = history
        }
    }
    
    /// Saves search history to settings.
    private func saveSearchHistory() {
        guard let delegate = delegate else { return }
        delegate.settingsStore.setValue(searchHistory, forKey: "searchHistory")
    }
    
    /// Configures the filter panel with current criteria.
    private func setupFilterPanel() {
        guard let delegate = delegate else { return }
        
        // Configure filter panel with current criteria
        delegate.filterPanel.filterCriteria = currentFilterCriteria
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
        currentFilterCriteria.fileTypes = fileTypes
        saveFilterCriteria()
        
        guard let delegate = delegate else { return }
        delegate.setFilterCriteria(currentFilterCriteria)
        delegate.reloadBrowserData()
    }
    
    /// Sets date range filter.
    func setDateRangeFilter(from: Date?, to: Date?) {
        currentFilterCriteria.dateFrom = from
        currentFilterCriteria.dateTo = to
        saveFilterCriteria()
        
        guard let delegate = delegate else { return }
        delegate.setFilterCriteria(currentFilterCriteria)
        delegate.reloadBrowserData()
    }
    
    /// Sets file size range filter.
    func setSizeRangeFilter(minSize: UInt64?, maxSize: UInt64?) {
        currentFilterCriteria.minSize = minSize
        currentFilterCriteria.maxSize = maxSize
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
        return !currentFilterCriteria.searchText.isEmpty ||
               !currentFilterCriteria.fileTypes.isEmpty ||
               currentFilterCriteria.dateFrom != nil ||
               currentFilterCriteria.dateTo != nil ||
               currentFilterCriteria.minSize != nil ||
               currentFilterCriteria.maxSize != nil
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
struct FilterCriteria: Codable {
    var searchText: String = ""
    var fileTypes: [String] = []
    var dateFrom: Date?
    var dateTo: Date?
    var minSize: UInt64?
    var maxSize: UInt64?
    var includeHidden: Bool = false
    
    /// Checks if a file matches the filter criteria.
    func matches(_ item: FileItem) -> Bool {
        // Check search text
        if !searchText.isEmpty {
            if !item.name.localizedCaseInsensitiveContains(searchText) &&
               !item.path.localizedCaseInsensitiveContains(searchText) {
                return false
            }
        }
        
        // Check file types
        if !fileTypes.isEmpty {
            let ext = (item.path as NSString).pathExtension.lowercased()
            if !ext.isEmpty && !fileTypes.contains(ext) {
                return false
            }
        }
        
        // Check date range
        if let dateFrom = dateFrom, item.modificationDate < dateFrom {
            return false
        }
        if let dateTo = dateTo, item.modificationDate > dateTo {
            return false
        }
        
        // Check size range
        if let minSize = minSize, item.size < minSize {
            return false
        }
        if let maxSize = maxSize, item.size > maxSize {
            return false
        }
        
        // Check hidden files
        if !includeHidden && item.isHidden {
            return false
        }
        
        return true
    }
}
