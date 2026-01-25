import Cocoa

/// Manages gesture recognition and free-form icon dragging in the file browser.
/// Extracted from FileBrowserViewController to reduce complexity.
final class FileBrowserGestureHandler: NSObject, NSGestureRecognizerDelegate {
    weak var delegate: FileBrowserGestureHandlerDelegate?
    
    private var draggedItemsInitialPositions: [IndexPath: CGPoint] = [:]
    
    /// Delegate for interaction callbacks.
    protocol FileBrowserGestureHandlerDelegate: AnyObject {
        var currentViewMode: ViewMode { get }
        var isFreeFormEnabled: Bool { get set }
        var collectionView: NSCollectionView? { get }
        var freeFormLayout: FreeFormCollectionViewLayout? { get }
        func recordInteractionClick(row: Int)
        func handleInteractionDoubleClick()
    }
    
    // MARK: - NSGestureRecognizerDelegate
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        // Only allow pan gesture if dragging a selected item in free-form mode
        guard let panGesture = gestureRecognizer as? NSPanGestureRecognizer,
              let delegate = delegate,
              delegate.currentViewMode == .icons,
              delegate.isFreeFormEnabled,
              let collectionView = delegate.collectionView else { return false }
        
        let location = panGesture.location(in: collectionView)
        guard let hitIndexPath = collectionView.indexPathForItem(at: location) else { return false }
        return collectionView.selectionIndexPaths.contains(hitIndexPath)
    }
    
    // MARK: - Gesture Handlers
    
    func handleIconDrag(_ sender: NSPanGestureRecognizer) {
        guard let delegate = delegate,
              delegate.currentViewMode == .icons,
              delegate.isFreeFormEnabled,
              let collectionView = delegate.collectionView,
              let layout = delegate.freeFormLayout else { return }
        
        let location = sender.location(in: collectionView)
        
        switch sender.state {
        case .began:
            if collectionView.indexPathForItem(at: location) != nil {
                draggedItemsInitialPositions.removeAll()
                for indexPath in collectionView.selectionIndexPaths {
                    if let pos = layout.position(for: indexPath) {
                        draggedItemsInitialPositions[indexPath] = pos
                    }
                }
                sender.setTranslation(.zero, in: collectionView)
            }
            
        case .changed:
            let translation = sender.translation(in: collectionView)
            
            for indexPath in collectionView.selectionIndexPaths {
                if let initialPos = draggedItemsInitialPositions[indexPath],
                   let item = collectionView.item(at: indexPath) {
                    let newPos = CGPoint(x: initialPos.x + translation.x,
                                        y: initialPos.y + translation.y)
                    
                    var newFrame = item.view.frame
                    newFrame.origin = newPos
                    item.view.frame = newFrame
                }
            }
            
        case .ended:
            let translation = sender.translation(in: collectionView)
            
            for indexPath in collectionView.selectionIndexPaths {
                if let initialPos = draggedItemsInitialPositions[indexPath] {
                    let finalPos = CGPoint(x: initialPos.x + translation.x,
                                          y: initialPos.y + translation.y)
                    layout.setPositionWithoutInvalidation(finalPos, for: indexPath)
                }
            }
            
            layout.invalidateLayout()
            draggedItemsInitialPositions.removeAll()
            
        case .cancelled:
            layout.invalidateLayout()
            draggedItemsInitialPositions.removeAll()
            
        default:
            break
        }
    }
    
    func handleCollectionViewDoubleClick(_ sender: NSClickGestureRecognizer) {
        guard let delegate = delegate,
              let collectionView = delegate.collectionView else { return }
        
        let point = sender.location(in: collectionView)
        
        if let indexPath = collectionView.indexPathForItem(at: point) {
            delegate.recordInteractionClick(row: indexPath.item)
            delegate.handleInteractionDoubleClick()
        }
    }
    
    func handleBrowserDoubleClick(_ sender: NSBrowser, rowInColumn: Int, column: Int) {
        guard let delegate = delegate else { return }
        delegate.recordInteractionClick(row: rowInColumn)
        delegate.handleInteractionDoubleClick()
    }
}
