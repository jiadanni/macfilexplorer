import AppKit

extension NSImage {
    static func mfeSymbol(named name: String, accessibilityDescription: String? = nil, fallback: NSImage? = nil) -> NSImage? {
        if #available(macOS 11.0, *) {
            return NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription) ?? fallback
        }
        return fallback
    }
}
