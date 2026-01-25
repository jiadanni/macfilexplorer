import Cocoa

/// Manages the status bar display showing file/folder information.
///
/// Extracted from FileBrowserViewController to isolate status bar complexity.
/// Handles:
/// - Status message updates
/// - Selection count display
/// - File size/path information
/// - Status bar visibility
/// - Selection statistics

protocol FileBrowserStatusBarDelegate: AnyObject {
    var statusBar: NSTextField! { get }
}

class FileBrowserStatusBarManager: NSObject {
    weak var delegate: FileBrowserStatusBarDelegate?
    
    private var selectedItemCount: Int = 0
    private var selectedItemSize: UInt64 = 0
    
    /// Updates the status bar with current selection information.
    func updateStatusBar(itemCount: Int, totalSize: UInt64) {
        guard let delegate = delegate else { return }
        
        self.selectedItemCount = itemCount
        self.selectedItemSize = totalSize
        
        let statusText = formatStatusMessage(itemCount: itemCount, totalSize: totalSize)
        delegate.statusBar.stringValue = statusText
    }
    
    /// Updates status bar to show a custom message.
    func setStatusMessage(_ message: String) {
        guard let delegate = delegate else { return }
        delegate.statusBar.stringValue = message
    }
    
    /// Clears the status bar message.
    func clearStatusMessage() {
        guard let delegate = delegate else { return }
        delegate.statusBar.stringValue = ""
    }
    
    /// Returns formatted status message based on selection.
    private func formatStatusMessage(itemCount: Int, totalSize: UInt64) -> String {
        if itemCount == 0 {
            return "No selection"
        }
        
        let itemText = itemCount == 1 ? "item" : "items"
        let sizeText = formatFileSize(totalSize)
        
        if itemCount == 1 {
            return "1 \(itemText) • \(sizeText)"
        } else {
            return "\(itemCount) \(itemText) • \(sizeText)"
        }
    }
    
    /// Formats a byte count as human-readable file size.
    private func formatFileSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// Returns current selection statistics.
    func getSelectionStats() -> (count: Int, size: UInt64) {
        return (selectedItemCount, selectedItemSize)
    }
}
