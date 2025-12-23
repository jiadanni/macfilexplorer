import AppKit

extension NSImage {
    static func mfeSymbol(named name: String, accessibilityDescription: String?) -> NSImage? {
        if #available(macOS 11.0, *) {
            return NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription)
        }
        return nil
    }
}
