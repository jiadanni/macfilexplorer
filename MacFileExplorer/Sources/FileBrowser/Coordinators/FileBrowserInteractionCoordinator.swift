import Cocoa

protocol FileBrowserInteractionDelegate: AnyObject {
    func openSelection()
    func contextMenuRename(_ item: FileItem)
    func showError(_ message: String)
}

final class FileBrowserInteractionCoordinator: NSObject {
    weak var delegate: FileBrowserInteractionDelegate?
    
    // Click tracking for delayed rename - protected by clickTrackingLock
    private let clickTrackingLock = NSLock()
    private var lastClickedRow: Int = -1
    private var lastClickTime: TimeInterval = 0
    private let renameClickDelay: TimeInterval = 0.5
    
    // MARK: - Click Tracking State Management
    
    func recordClick(row: Int) {
        clickTrackingLock.lock()
        defer { clickTrackingLock.unlock() }
        lastClickedRow = row
        lastClickTime = Date().timeIntervalSince1970
    }
    
    func isRenameEligibleClick(row: Int) -> Bool {
        clickTrackingLock.lock()
        defer { clickTrackingLock.unlock() }
        
        guard lastClickedRow == row else { return false }
        
        let timeSinceLastClick = Date().timeIntervalSince1970 - lastClickTime
        let isWithinWindow = timeSinceLastClick > 0 && timeSinceLastClick < renameClickDelay
        
        return isWithinWindow
    }
    
    func clearClickTracking() {
        clickTrackingLock.lock()
        defer { clickTrackingLock.unlock() }
        lastClickedRow = -1
        lastClickTime = 0
    }
    
    // MARK: - Action Handlers
    
    func handleDoubleClick() {
        delegate?.openSelection()
        clearClickTracking()
    }
}
