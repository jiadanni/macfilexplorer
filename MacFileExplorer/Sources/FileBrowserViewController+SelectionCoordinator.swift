import Cocoa

extension FileBrowserViewController: FileBrowserSelectionDelegate {
    func clearSelection() {
        selectionCoordinator.clearSelection()
        delegate?.fileBrowser(self, didSelectFile: nil)
    }
}
