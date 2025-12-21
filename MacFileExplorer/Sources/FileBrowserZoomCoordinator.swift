import Cocoa

/// Manages zoom level controls and persistence for the file browser.
///
/// Extracted from FileBrowserViewController to isolate zoom control complexity.
/// Handles:
/// - Zoom slider management
/// - Zoom level persistence
/// - Icon size scaling
/// - Font size scaling per view mode
/// - Zoom keyboard shortcuts

protocol FileBrowserZoomDelegate: AnyObject {
    var currentViewMode: ViewMode { get }
    var outlineView: NSOutlineView! { get }
    var collectionView: NSCollectionView! { get }
    var zoomSlider: NSSlider! { get }
    var settingsStore: SettingsStore! { get }
    func updateViewForZoomLevel()
}

class FileBrowserZoomCoordinator: NSObject {
    weak var delegate: FileBrowserZoomDelegate?
    
    private let minZoomLevel: Double = 50.0
    private let maxZoomLevel: Double = 200.0
    private let defaultZoomLevel: Double = 100.0
    
    private var currentZoomLevel: Double = 100.0
    
    /// Initializes zoom coordinator and loads persisted zoom level.
    func initialize() {
        loadZoomLevel()
        setupZoomSlider()
    }
    
    /// Loads the persisted zoom level for the current view mode.
    private func loadZoomLevel() {
        guard let delegate = delegate else { return }
        
        let key = getZoomLevelKey()
        if let saved = delegate.settingsStore.doubleValue(forKey: key) {
            currentZoomLevel = saved
        } else {
            currentZoomLevel = defaultZoomLevel
        }
    }
    
    /// Saves the current zoom level for the current view mode.
    private func saveZoomLevel() {
        guard let delegate = delegate else { return }
        
        let key = getZoomLevelKey()
        delegate.settingsStore.setValue(currentZoomLevel, forKey: key)
    }
    
    /// Returns the settings key for the current view mode's zoom level.
    private func getZoomLevelKey() -> String {
        guard let delegate = delegate else { return "zoom_default" }
        return "zoom_\(delegate.currentViewMode.rawValue)"
    }
    
    /// Configures the zoom slider with appropriate range and value.
    private func setupZoomSlider() {
        guard let delegate = delegate else { return }
        
        delegate.zoomSlider.minValue = minZoomLevel
        delegate.zoomSlider.maxValue = maxZoomLevel
        delegate.zoomSlider.doubleValue = currentZoomLevel
        delegate.zoomSlider.target = self
        delegate.zoomSlider.action = #selector(zoomSliderChanged(_:))
    }
    
    /// Handles zoom slider value changes.
    @objc func zoomSliderChanged(_ sender: NSSlider) {
        currentZoomLevel = sender.doubleValue
        saveZoomLevel()
        
        guard let delegate = delegate else { return }
        delegate.updateViewForZoomLevel()
    }
    
    /// Increases zoom level by one step (5%).
    func zoomIn() {
        adjustZoom(by: 5.0)
    }
    
    /// Decreases zoom level by one step (5%).
    func zoomOut() {
        adjustZoom(by: -5.0)
    }
    
    /// Resets zoom level to default.
    func resetZoom() {
        currentZoomLevel = defaultZoomLevel
        saveZoomLevel()
        updateSlider()
        
        guard let delegate = delegate else { return }
        delegate.updateViewForZoomLevel()
    }
    
    /// Adjusts zoom level by the specified amount and updates views.
    private func adjustZoom(by amount: Double) {
        currentZoomLevel = max(minZoomLevel, min(maxZoomLevel, currentZoomLevel + amount))
        saveZoomLevel()
        updateSlider()
        
        guard let delegate = delegate else { return }
        delegate.updateViewForZoomLevel()
    }
    
    /// Updates slider to match current zoom level.
    private func updateSlider() {
        guard let delegate = delegate else { return }
        delegate.zoomSlider.doubleValue = currentZoomLevel
    }
    
    /// Returns the current zoom level (0.5 to 2.0 scale).
    func getZoomScale() -> CGFloat {
        return CGFloat(currentZoomLevel / defaultZoomLevel)
    }
    
    /// Returns the zoom percentage (50 to 200).
    func getZoomPercentage() -> Int {
        return Int(currentZoomLevel)
    }
    
    /// Sets zoom level to specific percentage (validated within bounds).
    func setZoomLevel(_ percentage: Double) {
        currentZoomLevel = max(minZoomLevel, min(maxZoomLevel, percentage))
        saveZoomLevel()
        updateSlider()
        
        guard let delegate = delegate else { return }
        delegate.updateViewForZoomLevel()
    }
}
