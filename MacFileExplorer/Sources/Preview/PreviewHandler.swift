import Cocoa

protocol PreviewHandler {
    /// Returns true if this handler can create a preview for the given file
    func canHandle(_ file: FileItem) -> Bool
    
    /// Creates and returns the view to be displayed in the preview pane
    func createView(for file: FileItem) -> NSView
    
    /// Returns whether this content supports specific actions
    var supportsRotation: Bool { get }
    
    /// Rotates the content if supported
    func rotate()
}

extension PreviewHandler {
    var supportsRotation: Bool { return false }
    func rotate() {}
}
