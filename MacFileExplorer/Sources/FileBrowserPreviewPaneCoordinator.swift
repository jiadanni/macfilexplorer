import Cocoa
import Quartz

/// Coordinates preview pane visibility, positioning, and content updates.
///
/// Extracted from FileBrowserViewController to isolate preview pane concerns.
/// Manages:
/// - Preview pane visibility toggling
/// - Split view layout with preview pane
/// - File preview updates
/// - Preview pane sizing and persistence
protocol FileBrowserPreviewPaneDelegate: AnyObject {
    func previewPaneShouldClose()
    func previewPaneDidResize(width: CGFloat)
}

class FileBrowserPreviewPaneCoordinator: NSObject, NSSplitViewDelegate {
    weak var delegate: FileBrowserPreviewPaneDelegate?
    
    private var settings: SettingsStoreProtocol
    private weak var parentSplitView: NSSplitView?
    private(set) var previewPaneViewController: PreviewPaneViewController?
    private(set) var isVisible: Bool = false
    
    init(settings: SettingsStoreProtocol = SettingsStore.shared) {
        self.settings = settings
        super.init()
    }
    
    /// Initializes preview pane with parent split view reference.
    func setup(in parentSplitView: NSSplitView) {
        self.parentSplitView = parentSplitView
        parentSplitView.delegate = self
    }
    
    /// Shows or hides the preview pane.
    func setPreviewPaneVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        
        if visible {
            showPreviewPane()
        } else {
            hidePreviewPane()
        }
    }
    
    /// Toggles preview pane visibility.
    func togglePreviewPane() {
        setPreviewPaneVisible(!isVisible)
    }
    
    /// Updates preview pane content with selected file.
    func updatePreviewPane(with file: FileItem?) {
        guard isVisible, let previewVC = previewPaneViewController else { return }
        if let file {
            previewVC.previewFile(file)
        } else {
            previewVC.resetPreview()
        }
    }
    
    /// Shows the preview pane if not already visible.
    private func showPreviewPane() {
        guard let parentSplitView = parentSplitView else { return }
        guard previewPaneViewController == nil else { return }
        
        let previewVC = PreviewPaneViewController()
        previewPaneViewController = previewVC
        
        let previewItem = NSSplitViewItem(viewController: previewVC)
        previewItem.collapseBehavior = .preferResizingSiblingsWithFixedSplitView
        
        if let width = settings.previewPaneWidth as CGFloat?, width > 100 {
            previewItem.minimumThickness = 100
            previewItem.maximumThickness = CGFloat.greatestFiniteMagnitude
            let preferredWidth = width
            
            Task { @MainActor in
                previewVC.view.frame.size.width = preferredWidth
            }
        }
        
        parentSplitView.addArrangedSubview(previewVC.view)
    }
    
    /// Hides the preview pane.
    private func hidePreviewPane() {
        guard let previewVC = previewPaneViewController else { return }
        previewVC.view.removeFromSuperview()
        previewVC.removeFromParent()
        previewPaneViewController = nil
    }
    
    // MARK: - NSSplitViewDelegate
    
    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard isVisible, let pv = previewPaneViewController?.view else { return }
        let width = pv.bounds.width
        if width > 100 { // persist only reasonable widths
            settings.previewPaneWidth = width
            delegate?.previewPaneDidResize(width: width)
        }
    }
}
