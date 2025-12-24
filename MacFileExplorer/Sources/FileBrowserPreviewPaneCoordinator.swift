import Cocoa
import Quartz

/// Enhanced delegate protocol for preview pane coordinator changes.
/// Notifies observers when visibility, position, or width changes.
protocol FileBrowserPreviewPaneObserver: AnyObject {
    /// Called when preview pane visibility changes
    func previewPaneVisibilityDidChange(_ isVisible: Bool)
    
    /// Called when preview pane position changes
    func previewPanePositionDidChange(_ position: String)
    
    /// Called when preview pane width changes
    func previewPaneWidthDidChange(_ width: CGFloat)
}

/// Legacy delegate protocol (kept for backward compatibility)
protocol FileBrowserPreviewPaneDelegate: AnyObject {
    func previewPaneShouldClose()
    func previewPaneDidResize(width: CGFloat)
}

/// Single Source of Truth coordinator for preview pane state.
///
/// This coordinator owns all preview pane state:
/// - isVisible: Boolean visibility state
/// - position: "right" or "bottom" positioning
/// - width: Saved pane width for restoration
///
/// All changes flow through this coordinator and automatically
/// synchronize to SettingsStore for persistence.
class FileBrowserPreviewPaneCoordinator: NSObject, NSSplitViewDelegate {
    weak var delegate: FileBrowserPreviewPaneDelegate?
    weak var observer: FileBrowserPreviewPaneObserver?
    
    private var settings: SettingsStoreProtocol
    private weak var parentSplitView: NSSplitView?
    private(set) var previewPaneViewController: PreviewPaneViewController?
    
    /// SSOT: Preview pane visibility
    private(set) var isVisible: Bool = false {
        didSet {
            guard oldValue != isVisible else { return }
            updateSettingsStore()
            observer?.previewPaneVisibilityDidChange(isVisible)
        }
    }
    
    /// SSOT: Preview pane position ("right" or "bottom")
    private(set) var position: String = "right" {
        didSet {
            guard oldValue != position else { return }
            updateSettingsStore()
            observer?.previewPanePositionDidChange(position)
        }
    }
    
    /// SSOT: Preview pane width (saved on resize)
    private(set) var width: CGFloat = 300 {
        didSet {
            guard oldValue != width && width > 100 else { return }
            updateSettingsStore()
            observer?.previewPaneWidthDidChange(width)
        }
    }
    
    init(settings: SettingsStoreProtocol = SettingsStore.shared) {
        self.settings = settings
        super.init()
        
        // Initialize from persisted settings
        self.position = settings.previewPanePosition
        self.width = settings.previewPaneWidth
        self.isVisible = settings.previewPaneVisible
    }
    
    /// Initializes preview pane with parent split view reference.
    func setup(in parentSplitView: NSSplitView) {
        self.parentSplitView = parentSplitView
        parentSplitView.delegate = self
    }
    
    /// Updates SettingsStore with current state (called on every change).
    /// Ensures single source of truth between coordinator and persistence layer.
    private func updateSettingsStore() {
        settings.previewPaneVisible = isVisible
        settings.previewPanePosition = position
        if width > 100 {
            settings.previewPaneWidth = width
        }
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
    
    /// Sets preview pane position ("right" or "bottom").
    func setPosition(_ newPosition: String) {
        guard newPosition == "right" || newPosition == "bottom" else { return }
        position = newPosition
    }
    
    /// Sets preview pane width.
    func setWidth(_ newWidth: CGFloat) {
        guard newWidth > 100 else { return }
        width = newWidth
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
        
        if width > 100 {
            previewItem.minimumThickness = 100
            previewItem.maximumThickness = CGFloat.greatestFiniteMagnitude
            
            Task { @MainActor in
                previewVC.view.frame.size.width = self.width
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
        let newWidth = pv.bounds.width
        if newWidth > 100 && newWidth != width {
            width = newWidth
            delegate?.previewPaneDidResize(width: newWidth)
        }
    }
}
