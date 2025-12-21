import Cocoa

/// Manages folder icon colors and global folder color preferences.
///
/// `ColorManager` provides centralized management of:
/// - Per-folder custom colors (stored by folder name)
/// - Global folder color applied to all folders
/// - Color persistence via SettingsStore
///
/// **Usage:**
/// ```swift
/// // Set global folder color
/// ColorManager.setGlobalFolderColor(NSColor.blue)
///
/// // Get color for specific folder
/// let color = ColorManager.shared.getColor(forFolderName: "Documents")
///
/// // Set color for specific folder name
/// ColorManager.shared.setColor(NSColor.red, forFolderName: "Documents")
/// ```
///
/// **Color Priority:**
/// 1. Per-folder custom color (if set)
/// 2. Global folder color (if set)
/// 3. System default
final class ColorManager {
    static let shared = ColorManager()

    private init() {}

    // MARK: - Public Methods

    /// Sets a custom color for a specific folder name.
    ///
    /// - Parameters:
    ///   - color: The color to apply to folders with this name.
    ///   - name: The folder name (last path component).
    ///
    /// Persists to SettingsStore and posts a global notification (handled by SettingsStore).
    func setColor(_ color: NSColor, forFolderName name: String) {
        var stored = SettingsStore.shared.folderColors
        stored[name] = color.toHex()
        SettingsStore.shared.folderColors = stored
    }

    func getColor(forFolderName name: String) -> NSColor? {
        guard let hex = SettingsStore.shared.folderColors[name] else { return nil }
        return NSColor(hex: hex)
    }

    /// Returns the folder icon color for a given URL.
    ///
    /// - Returns: Custom color if set for this folder name, otherwise global folder color, or nil.
    static func getGlobalFolderColor() -> NSColor? {
        // Try to read Data first (new format)
        if let colorData = SettingsStore.shared.globalFolderColor,
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            return color
        }

        // Fallback to Hex string (legacy format)
        if let hex = SettingsStore.shared.globalFolderColorHex {
            return NSColor(hex: hex)
        }
        
        return nil
    }

    static func setGlobalFolderColor(_ color: NSColor?) {
        if let color {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
                SettingsStore.shared.globalFolderColor = data
            } else {
                SettingsStore.shared.globalFolderColorHex = color.toHex()
            }
        } else {
            SettingsStore.shared.globalFolderColor = nil
        }
    }

    func removeColor(forFolderName name: String) {
        var stored = SettingsStore.shared.folderColors
        stored.removeValue(forKey: name)
        SettingsStore.shared.folderColors = stored
    }

    func clearAllColors() {
        SettingsStore.shared.folderColors = [:]
        SettingsStore.shared.globalFolderColor = nil
    }

    func getAllColoredFolderNames() -> [String] {
        return Array(SettingsStore.shared.folderColors.keys)
    }
}

extension NSColor {
    /// Converts this color to a hexadecimal string representation.
    ///
    /// - Returns: A hex string in the format "#RRGGBB".
    var hexString: String {
        guard let rgbColor = usingColorSpace(.deviceRGB) else {
            return "#000000"
        }

        let red = Int(rgbColor.redComponent * 255.0)
        let green = Int(rgbColor.greenComponent * 255.0)
        let blue = Int(rgbColor.blueComponent * 255.0)

        return String(format: "#%02X%02X%02X", red, green, blue)
    }
    
    /// Legacy method - use hexString property instead.
    func toHex() -> String {
        return hexString
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
