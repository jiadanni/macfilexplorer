import Cocoa
import Quartz

protocol FileBrowserQuickLookDelegate: AnyObject {
    func selectedItemsForQuickLook() -> [FileItem]
}

final class FileBrowserQuickLookCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    weak var delegate: FileBrowserQuickLookDelegate?
    
    func toggleQuickLook() {
        if QLPreviewPanel.shared()?.isVisible == true {
            QLPreviewPanel.shared()?.orderOut(nil)
        } else if let panel = QLPreviewPanel.shared() {
            panel.dataSource = self
            panel.delegate = self
            panel.makeKeyAndOrderFront(nil)
        }
    }
    
    func refreshQuickLook() {
        if QLPreviewPanel.shared()?.isVisible == true {
            QLPreviewPanel.shared()?.reloadData()
        }
    }

    // MARK: - QLPreviewPanelDataSource
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return delegate?.selectedItemsForQuickLook().count ?? 0
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        let items = delegate?.selectedItemsForQuickLook() ?? []
        guard index < items.count else { return nil }
        return items[index].url as QLPreviewItem
    }
    
    // MARK: - QLPreviewPanelDelegate
    
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        return false
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        return .zero
    }
}
