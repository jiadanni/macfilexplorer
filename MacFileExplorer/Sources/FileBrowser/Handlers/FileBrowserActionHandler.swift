import Cocoa

/// Dedicated handler for user actions, keyboard shortcuts, and gestures.
/// Consolidates interaction logic and reduces FileBrowserViewController protocol surface.
final class FileBrowserActionHandler: NSObject, FileBrowserInteractionDelegate, FileBrowserQuickLookDelegate, FileBrowserKeyboardHandler.FileBrowserKeyboardHandlerDelegate, FileBrowserGestureHandler.FileBrowserGestureHandlerDelegate {
    
    private weak var viewController: FileBrowserViewController?
    
    init(viewController: FileBrowserViewController) {
        self.viewController = viewController
        super.init()
    }
    
    // MARK: - FileBrowserKeyboardHandlerDelegate
    
    var deleteWithBackspaceOnly: Bool {
        return viewController?.settings.deleteWithBackspaceOnly ?? false
    }
    
    func handleCut() {
        viewController?.cutSelection()
    }
    
    func handleCopy() {
        viewController?.copySelection()
    }
    
    func handlePaste() {
        viewController?.pasteSelection()
    }
    
    func handleGetInfo() {
        viewController?.contextMenuGetInfo(viewController!)
    }
    
    func handleNewFolder() {
        viewController?.contextMenuNewFolder(viewController!)
    }
    
    func handleDuplicate() {
        viewController?.duplicateSelection()
    }
    
    func handleNavigateToParent() {
        viewController?.navigationCoordinator.navigateToParent()
    }
    
    func handleOpenSelection() {
        viewController?.openSelection()
    }
    
    func handleDelete() {
        viewController?.contextMenuDelete(viewController!)
    }
    
    func handleToggleQuickLook() {
        viewController?.toggleQuickLook()
    }
    
    func handleClearSelection() {
        viewController?.selectionCoordinator.clearSelection()
    }
    
    func handleRenameFirstSelected() {
        let items = viewController?.selectionCoordinator.selectedItems() ?? []
        if let item = items.first, items.count == 1 {
            viewController?.contextMenuRename(item)
        }
    }
    
    // MARK: - FileBrowserInteractionDelegate
    
    func openSelection() {
        viewController?.openSelection()
    }
    
    func contextMenuRename(_ item: FileItem) {
        viewController?.contextMenuRename(item)
    }
    
    func showError(_ message: String) {
        viewController?.showError(message)
    }
    
    // MARK: - FileBrowserGestureHandlerDelegate
    
    func recordInteractionClick(row: Int) {
        viewController?.interactionCoordinator.recordClick(row: row)
    }
    
    func handleInteractionDoubleClick() {
        viewController?.interactionCoordinator.handleDoubleClick()
    }
    
    // MARK: - FileBrowserQuickLookDelegate
    
    func selectedItemsForQuickLook() -> [FileItem] {
        return viewController?.selectionCoordinator.selectedItems() ?? []
    }
    
    // MARK: - FileBrowserGestureHandlerDelegate
    
    var currentViewMode: ViewMode {
        return viewController?.currentViewMode ?? .list
    }
    
    var isFreeFormEnabled: Bool {
        get { return viewController?.isFreeFormEnabled ?? false }
        set { viewController?.isFreeFormEnabled = newValue }
    }
    
    var collectionView: NSCollectionView? {
        return viewController?.collectionView
    }
    
    var freeFormLayout: FreeFormCollectionViewLayout? {
        return viewController?.freeFormLayout
    }
}
