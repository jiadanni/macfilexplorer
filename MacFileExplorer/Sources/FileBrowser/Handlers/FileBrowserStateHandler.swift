import Cocoa

/// Dedicated handler to manage state changes from SettingsStore, HiddenFiles, and Preview Pane.
/// This reduces the protocol surface of FileBrowserViewController.
final class FileBrowserStateHandler: NSObject, SettingsStoreDelegate, @preconcurrency HiddenFilesVisibilityDelegate, FileBrowserPreviewPaneObserver {
    
    private weak var viewController: FileBrowserViewController?
    
    init(viewController: FileBrowserViewController) {
        self.viewController = viewController
        super.init()
    }
    
    // MARK: - SettingsStoreDelegate
    
    func settingsStore(_ settingsStore: SettingsStoreProtocol, previewPaneVisibilityDidChange isVisible: Bool) {
        viewController?.previewPaneCoordinator.setPreviewPaneVisible(isVisible)
    }
    
    func settingsStore(_ settingsStore: SettingsStoreProtocol, hiddenFilesStateDidChange isVisible: Bool) {
        viewController?.hiddenFilesCoordinator.setVisibility(isVisible)
    }
    
    func settingsStoreDidUpdateGlobalFolderColor(_ settingsStore: SettingsStoreProtocol) {
        viewController?.refreshCurrentDirectory()
    }
    
    func settingsStore(_ settingsStore: SettingsStoreProtocol, showFileExtensionsDidChange show: Bool) {
        viewController?.refreshCurrentDirectory()
    }
    
    func settingsStore(_ settingsStore: SettingsStoreProtocol, easySelectDidChange enabled: Bool) {
        viewController?.refreshCurrentDirectory()
    }
    
    // MARK: - HiddenFilesVisibilityDelegate
    
    @MainActor func hiddenFilesVisibilityDidChange(isVisible: Bool) {
        // Update dataSource to trigger reload
        viewController?.dataSource.showsHiddenFiles = isVisible
        
        // Update toolbar to reflect current state
        viewController?.toolbarViewController?.updateHiddenFilesDisplay(showing: isVisible)
    }
    
    // MARK: - FileBrowserPreviewPaneObserver
    
    func previewPaneVisibilityDidChange(_ isVisible: Bool) {
        // Update toolbar to reflect current state
        viewController?.toolbarViewController?.updatePreviewPaneDisplay(showing: isVisible)
    }
    
    func previewPanePositionDidChange(_ position: String) {
        // No-op in VC currently
    }
    
    func previewPaneWidthDidChange(_ width: CGFloat) {
        // No-op in VC currently
    }
}
