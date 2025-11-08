import Cocoa

class ColorManager {
    static let shared = ColorManager()

    private let userDefaults = UserDefaults.standard
    private let colorKey = "FolderColors"

    private init() {}

    // MARK: - Public Methods

    func setColor(_ color: NSColor, for url: URL) {
        var colors = loadColors()
        colors[url.path] = color.toHex()
        saveColors(colors)
    }

    func getColor(for url: URL) -> NSColor? {
        let colors = loadColors()
        guard let hexString = colors[url.path] else { return nil }
        return NSColor(hex: hexString)
    }

    func removeColor(for url: URL) {
        var colors = loadColors()
        colors.removeValue(forKey: url.path)
        saveColors(colors)
    }

    func clearAllColors() {
        userDefaults.removeObject(forKey: colorKey)
    }

    // MARK: - Private Methods

    private func loadColors() -> [String: String] {
        guard let data = userDefaults.data(forKey: colorKey),
              let colors = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return colors
    }

    private func saveColors(_ colors: [String: String]) {
        if let data = try? JSONEncoder().encode(colors) {
            userDefaults.set(data, forKey: colorKey)
        }
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
