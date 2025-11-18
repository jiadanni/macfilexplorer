import Cocoa

class ColorManager {
    static let shared = ColorManager()

    private let userDefaults = UserDefaults.standard
    private let colorKey = "GlobalFolderColors"

    private init() {
        // Disabled: no-op
    }

    // MARK: - Public Methods (no-op/stubbed)

    func setColor(_ color: NSColor, forFolderName name: String) {
        // No-op: custom folder coloring disabled
    }

    func getColor(forFolderName name: String) -> NSColor? {
        return nil
    }

    func getColor(for url: URL) -> NSColor? {
        return nil
    }

    func getGlobalFolderColor() -> NSColor? {
        return nil
    }

    func removeColor(forFolderName name: String) {
        // No-op
    }

    func clearAllColors() {
        // No-op
    }

    func getAllColoredFolderNames() -> [String] {
        return []
    }
}

// MARK: - NSColor Extension

extension NSColor {
    func toHex() -> String {
        guard let rgbColor = usingColorSpace(.deviceRGB) else {
            return "#000000"
        }

        let red = Int(rgbColor.redComponent * 255.0)
        let green = Int(rgbColor.greenComponent * 255.0)
        let blue = Int(rgbColor.blueComponent * 255.0)

        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
