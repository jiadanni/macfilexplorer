import Cocoa

// MARK: - FileBrowserOutlineCoordinatorDelegate
extension FileBrowserViewController {
    func fileBrowserDidBecomeActive() {
        delegate?.fileBrowserDidBecomeActive(self)
    }
    
    func didSelectFile(_ item: FileItem?) {
        delegate?.fileBrowser(self, didSelectFile: item)
    }
}

// MARK: - FileBrowserCollectionCoordinatorDelegate
extension FileBrowserViewController {
    // Already has currentViewMode, rootItem, zoomLevel
}

// MARK: - FileBrowserColumnCoordinatorDelegate
extension FileBrowserViewController {
    // Already has rootItem, showsHiddenFiles, browserView
}

// MARK: - FileBrowserQuickLookDelegate
extension FileBrowserViewController {
    func selectedItemsForQuickLook() -> [FileItem] {
        return selectionCoordinator.selectedItems()
    }
}

// MARK: - FileBrowserInteractionDelegate
extension FileBrowserViewController {
    // Already has openSelection(), contextMenuRename(_:), showError(_:)
}

// MARK: - FileBrowserStatusBarCoordinatorDelegate
extension FileBrowserViewController {
    func setZoomLevel(_ level: Double) {
        self.zoomLevel = max(0.5, min(2.0, level))
        statusBarViewController?.setZoomLevel(self.zoomLevel)
        displayController.updateCollectionViewForZoom()
    }
    
    func updateZoomControlVisibility() {
        statusBarCoordinator.updateZoomControlVisibility()
    }
    
    func setZoomControlsVisible(_ visible: Bool) {
        zoomControlsAllowedByPane = visible
        updateZoomControlVisibility()
    }
    
    // StatusBarDelegate conformance
    func zoomLevelDidChange(to level: Double) {
        setZoomLevel(level)
    }
}
