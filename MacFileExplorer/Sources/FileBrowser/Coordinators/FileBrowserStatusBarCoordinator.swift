import Cocoa

protocol FileBrowserStatusBarCoordinatorDelegate: AnyObject {
    var currentViewMode: ViewMode { get }
    var zoomControlsAllowedByPane: Bool { get }
    func setZoomLevel(_ level: Double)
    func updateZoomControlVisibility()
    func updateStatusBarDisplay(selectedCount: Int, totalSize: Int64)
}

final class FileBrowserStatusBarCoordinator: NSObject, StatusBarDelegate {
    weak var delegate: FileBrowserStatusBarCoordinatorDelegate?
    weak var statusBarViewController: StatusBarViewController?
    
    func zoomLevelDidChange(to level: Double) {
        delegate?.setZoomLevel(level)
    }
    
    func updateZoomControlVisibility() {
        guard let delegate = delegate, let statusBarViewController = statusBarViewController else { return }
        let isZoomableViewMode = delegate.currentViewMode == .icons || delegate.currentViewMode == .windowsList
        let shouldShow = delegate.zoomControlsAllowedByPane && isZoomableViewMode
        statusBarViewController.setZoomControlsVisible(shouldShow)
    }
    
    func updateFileInformation(selectedCount: Int, totalSize: Int64, diskSpace: String) {
        statusBarViewController?.updateFileInformation(selectedCount: selectedCount, totalSize: totalSize, diskSpace: diskSpace)
    }
}
