import Cocoa

/// Handles keyboard shortcuts and key events for the file browser.
/// Extracted from FileBrowserViewController to reduce complexity.
final class FileBrowserKeyboardHandler {
    weak var delegate: FileBrowserKeyboardHandlerDelegate?
    
    /// Delegate for keyboard action callbacks.
    protocol FileBrowserKeyboardHandlerDelegate: AnyObject {
        var deleteWithBackspaceOnly: Bool { get }
        func handleCut()
        func handleCopy()
        func handlePaste()
        func handleGetInfo()
        func handleNewFolder()
        func handleDuplicate()
        func handleNavigateToParent()
        func handleOpenSelection()
        func handleDelete()
        func handleToggleQuickLook()
        func handleClearSelection()
        func handleRenameFirstSelected()
    }
    
    /// Processes keyboard events and dispatches to appropriate handlers.
    /// Returns true if event was handled, false to pass to next responder.
    func handleKeyDown(_ event: NSEvent) -> Bool {
        let deleteWithBackspaceOnly = delegate?.deleteWithBackspaceOnly ?? false
        
        // Cmd+X: Cut
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "x" {
            delegate?.handleCut()
            return true
        }
        
        // Cmd+C: Copy
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "c" {
            delegate?.handleCopy()
            return true
        }
        
        // Cmd+V: Paste
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            delegate?.handlePaste()
            return true
        }
        
        // Cmd+I: Get Info
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "i" {
            delegate?.handleGetInfo()
            return true
        }
        
        // Cmd+N: New Folder
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "n" {
            delegate?.handleNewFolder()
            return true
        }
        
        // Cmd+D: Duplicate
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "d" {
            delegate?.handleDuplicate()
            return true
        }
        
        // Cmd+Up Arrow: Navigate to parent
        if event.modifierFlags.contains(.command) && event.keyCode == 126 {
            delegate?.handleNavigateToParent()
            return true
        }
        
        // Cmd+Down Arrow: Open selection
        if event.modifierFlags.contains(.command) && event.keyCode == 125 {
            delegate?.handleOpenSelection()
            return true
        }
        
        // Return/Enter: Open selection
        if event.keyCode == 36 || event.keyCode == 76 {
            delegate?.handleOpenSelection()
            return true
        }
        
        // Spacebar: Toggle Quick Look
        if event.keyCode == 49 {
            delegate?.handleToggleQuickLook()
            return true
        }
        
        // Escape: Clear selection
        if event.keyCode == 53 {
            delegate?.handleClearSelection()
            return true
        }
        
        // F2: Rename first selected item
        if event.keyCode == 120 {
            delegate?.handleRenameFirstSelected()
            return true
        }
        
        // Backspace/Delete key
        if event.keyCode == 51 {
            if deleteWithBackspaceOnly {
                // Delete with backspace only (no modifier needed)
                delegate?.handleDelete()
                return true
            } else if event.modifierFlags.contains(.command) {
                // Default behavior: Command+Delete
                delegate?.handleDelete()
                return true
            }
        }
        
        return false
    }
}
