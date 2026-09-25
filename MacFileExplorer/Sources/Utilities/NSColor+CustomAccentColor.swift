import Cocoa

// NOTE: Custom accent color functionality removed in favor of system accent color.
// Keep this helper for backward compatibility but return the system accent color.
extension NSColor {
    static var customAccentColor: NSColor {
        .controlAccentColor
    }
}

