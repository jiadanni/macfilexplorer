import Cocoa

/// Manages switching between different file browser view modes (list, icons, columns).
///
/// Extracted from FileBrowserViewController to isolate view mode complexity.
/// Handles:
/// - View mode transitions
/// - Layout constraint management
/// - View-specific initialization
/// - Zoom level management per view mode

protocol FileBrowserViewModeDelegate: AnyObject {
    var currentViewMode: ViewMode { get set }
    var outlineView: NSOutlineView! { get }
    var collectionView: NSCollectionView! { get }
    var browserView: NSBrowser! { get }
    var containerView: NSView! { get }
    func updateStatusBar()
    func updateZoomControlVisibility()
}

class FileBrowserViewModeCoordinator: NSObject {
    weak var delegate: FileBrowserViewModeDelegate?
    
    private var activeConstraints: [NSLayoutConstraint] = []
    
    /// Switches to the specified view mode with animation if needed.
    func switchViewMode(to mode: ViewMode, animated: Bool = true) {
        guard let delegate = delegate else { return }
        guard mode != delegate.currentViewMode else { return }
        
        let oldMode = delegate.currentViewMode
        delegate.currentViewMode = mode
        
        // Remove old constraints
        NSLayoutConstraint.deactivate(activeConstraints)
        activeConstraints.removeAll()
        
        // Hide all views
        delegate.outlineView.isHidden = true
        delegate.collectionView.isHidden = true
        delegate.browserView.isHidden = true
        
        // Show new view
        switch mode {
        case .list:
            showListView(animated: animated)
        case .icons:
            showIconsView(animated: animated)
        case .columns:
            showColumnsView(animated: animated)
        case .windowsList:
            showWindowsListView(animated: animated)
        }
        
        delegate.updateStatusBar()
        delegate.updateZoomControlVisibility()
    }
    
    /// Configures constraints for list view (outline view).
    private func showListView(animated: Bool) {
        guard let delegate = delegate else { return }
        
        delegate.outlineView.isHidden = false
        activeConstraints = [
            delegate.outlineView.leadingAnchor.constraint(equalTo: delegate.containerView.leadingAnchor),
            delegate.outlineView.trailingAnchor.constraint(equalTo: delegate.containerView.trailingAnchor),
            delegate.outlineView.topAnchor.constraint(equalTo: delegate.containerView.topAnchor),
            delegate.outlineView.bottomAnchor.constraint(equalTo: delegate.containerView.bottomAnchor)
        ]
        
        NSLayoutConstraint.activate(activeConstraints)
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                delegate.containerView.animator().layoutSubtreeIfNeeded()
            }
        } else {
            delegate.containerView.layoutSubtreeIfNeeded()
        }
    }
    
    /// Configures constraints for icons view (collection view).
    private func showIconsView(animated: Bool) {
        guard let delegate = delegate else { return }
        
        // Icons view is typically in a scroll view
        delegate.collectionView.isHidden = false
        activeConstraints = [
            delegate.collectionView.leadingAnchor.constraint(equalTo: delegate.containerView.leadingAnchor),
            delegate.collectionView.trailingAnchor.constraint(equalTo: delegate.containerView.trailingAnchor),
            delegate.collectionView.topAnchor.constraint(equalTo: delegate.containerView.topAnchor),
            delegate.collectionView.bottomAnchor.constraint(equalTo: delegate.containerView.bottomAnchor)
        ]
        
        NSLayoutConstraint.activate(activeConstraints)
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                delegate.containerView.animator().layoutSubtreeIfNeeded()
            }
        } else {
            delegate.containerView.layoutSubtreeIfNeeded()
        }
    }
    
    /// Configures constraints for columns view (browser).
    private func showColumnsView(animated: Bool) {
        guard let delegate = delegate else { return }
        
        delegate.browserView.isHidden = false
        activeConstraints = [
            delegate.browserView.leadingAnchor.constraint(equalTo: delegate.containerView.leadingAnchor),
            delegate.browserView.trailingAnchor.constraint(equalTo: delegate.containerView.trailingAnchor),
            delegate.browserView.topAnchor.constraint(equalTo: delegate.containerView.topAnchor),
            delegate.browserView.bottomAnchor.constraint(equalTo: delegate.containerView.bottomAnchor)
        ]
        
        NSLayoutConstraint.activate(activeConstraints)
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                delegate.containerView.animator().layoutSubtreeIfNeeded()
            }
        } else {
            delegate.containerView.layoutSubtreeIfNeeded()
        }
    }
    
    /// Configures constraints for Windows-style list view (alternative to outline view).
    private func showWindowsListView(animated: Bool) {
        // Windows list view typically uses outline view with different styling
        showListView(animated: animated)
    }
}
