import Cocoa

// Shim to bridge legacy contextMenu* calls to the new FileBrowserContextMenuProvider
extension FileBrowserViewController {
    
    func contextMenuNewFolder(_ sender: Any) {
        contextMenuProvider.handleNewFolder(sender)
    }
    
    func contextMenuCut(_ sender: Any) {
        contextMenuProvider.handleCut(sender)
    }
    
    func contextMenuCopy(_ sender: Any) {
        contextMenuProvider.handleCopy(sender)
    }
    
    func contextMenuPaste(_ sender: Any) {
        contextMenuProvider.handlePaste(sender)
    }
    
    func contextMenuDelete(_ sender: Any) {
        contextMenuProvider.handleDelete(sender)
    }
    
    func contextMenuRename(_ item: FileItem) {
        contextMenuProvider.handleRename(item)
    }
    
    func contextMenuGetInfo(_ sender: Any) {
        contextMenuProvider.handleGetInfo(sender)
    }
    
    func contextMenuOpen(_ sender: Any) {
        contextMenuProvider.handleOpen(sender)
    }
}
