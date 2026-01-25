import Cocoa

extension FileBrowserViewController: FileBrowserSelectionDelegate {
    func fileItemForColumn(_ column: Int) -> FileItem? {
        return columnCoordinator.fileItemForColumn(column)
    }
    
    func clearSelection() {
        selectionCoordinator.clearSelection()
        delegate?.fileBrowser(self, didSelectFile: nil)
    }
}
