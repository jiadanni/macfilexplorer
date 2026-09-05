import Cocoa

protocol FileBrowserInteractionDelegate: AnyObject {
    func openSelection()
    func openItem(_ item: FileItem)
    func contextMenuRename(_ item: FileItem)
    func showError(_ message: String)
}

final class FileBrowserInteractionCoordinator: NSObject {
    weak var delegate: FileBrowserInteractionDelegate?
    
    // Click tracking for delayed rename - protected by clickTrackingLock
    private let clickTrackingLock = NSLock()
    private var lastClickedRow: Int = -1
    private var lastClickTime: TimeInterval = 0
    private var previousClickTime: TimeInterval = 0
    private let renameClickDelay: TimeInterval = 0.5
    
    // MARK: - Click Tracking State Management
    
    func recordClick(row: Int) {
        clickTrackingLock.lock()
        defer { clickTrackingLock.unlock() }
        let now = Date().timeIntervalSince1970
        previousClickTime = lastClickTime
        lastClickTime = now
        lastClickedRow = row
    }
    
    func isRenameEligibleClick(row: Int) -> Bool {
        clickTrackingLock.lock()
        defer { clickTrackingLock.unlock() }
        
        guard lastClickedRow == row else { return false }
        // Need two recorded clicks to compute interval between them
        guard previousClickTime > 0 else { return false }

        let interval = lastClickTime - previousClickTime

        // Ensure a sensible window: interval must be greater than zero and less than the rename delay.
        // If renameClickDelay is configured incorrectly relative to system double-click settings, bail out.
        let minAllowed = 0.0
        let maxAllowed = renameClickDelay
        guard maxAllowed > minAllowed else { return false }

        return interval > minAllowed && interval < maxAllowed
    }
    
    func clearClickTracking() {
        clickTrackingLock.lock()
        defer { clickTrackingLock.unlock() }
        lastClickedRow = -1
        lastClickTime = 0
        previousClickTime = 0
    }
    
    // MARK: - Action Handlers
    
    func handleDoubleClick() {
        delegate?.openSelection()
        clearClickTracking()
    }

    func handleDoubleClick(on item: FileItem) {
        delegate?.openItem(item)
        clearClickTracking()
    }
}
