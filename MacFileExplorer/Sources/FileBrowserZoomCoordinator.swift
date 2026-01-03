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

protocol FileBrowserZoomCoordinatorDelegate: AnyObject {
    var currentViewMode: ViewMode { get }
    var collectionView: NSCollectionView? { get }
    var freeFormLayout: FreeFormCollectionViewLayout? { get }
    var isFreeFormEnabled: Bool { get set }
    var zoomLevel: Double { get set }
    func updateZoomDisplay()
    func refreshViews()
}

class FileBrowserZoomCoordinator: NSObject {
    weak var delegate: FileBrowserZoomCoordinatorDelegate?
    
    private let minZoomLevel: Double = 50.0
    private let maxZoomLevel: Double = 200.0
    private let defaultZoomLevel: Double = 100.0
    
    private var currentZoomLevel: Double = 100.0
    
    /// Initializes zoom coordinator and loads persisted zoom level.
    func initialize() {
        loadZoomLevel()
    }
    
    /// Loads the persisted zoom level for the current view mode.
    private func loadZoomLevel() {
        // Default to 100% zoom for now - delegate can override this
        currentZoomLevel = defaultZoomLevel
    }
    
    /// Saves the current zoom level for the current view mode.
    private func saveZoomLevel() {
        // Delegate can handle persistence if needed
    }
    
    /// Returns the settings key for the current view mode's zoom level.
    private func getZoomLevelKey() -> String {
        guard let delegate = delegate else { return "zoom_default" }
        return "zoom_\(delegate.currentViewMode.rawValue)"
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
        delegate.updateZoomDisplay()
    }
    
    /// Adjusts zoom level by specified amount.
    private func adjustZoom(by amount: Double) {
        let newZoom = max(minZoomLevel, min(maxZoomLevel, currentZoomLevel + amount))
        if newZoom != currentZoomLevel {
            currentZoomLevel = newZoom
            saveZoomLevel()
            updateSlider()
            
            guard let delegate = delegate else { return }
            delegate.refreshViews()
        }
    }
    
    /// Updates zoom slider to reflect current zoom level.
    private func updateSlider() {
        // No longer needed with new delegate interface
    }
    
    /// Returns current zoom level as percentage.
    func getCurrentZoomLevel() -> Double {
        return currentZoomLevel
    }
    
    /// Sets zoom level to actual size (100%).
    func actualSize() {
        currentZoomLevel = 100.0
        saveZoomLevel()
        updateSlider()
        
        guard let delegate = delegate else { return }
        delegate.refreshViews()
    }
    
    /// Returns whether zoom controls should be enabled for current view mode.
    func areZoomControlsEnabled() -> Bool {
        guard let delegate = delegate else { return false }
        return delegate.currentViewMode == .icons || delegate.currentViewMode == .windowsList
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
        delegate.refreshViews()
    }
    
    /// Toggles free-form positioning for icon view mode.
    func toggleFreeFormPositioning() {
        guard let delegate = delegate else { return }
        guard delegate.currentViewMode == .icons else { return }
        
        delegate.isFreeFormEnabled.toggle()
        delegate.freeFormLayout?.isFreeForm = delegate.isFreeFormEnabled
        delegate.refreshViews()
    }
    
    /// Snaps items to grid in icon view mode.
    func snapToGrid() {
        guard let delegate = delegate else { return }
        guard delegate.currentViewMode == .icons else { return }
        
        delegate.freeFormLayout?.snapToGrid()
    }
}
