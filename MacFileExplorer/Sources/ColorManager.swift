import Cocoa

class ColorManager {
    static let shared = ColorManager()

    private let userDefaults = UserDefaults.standard
    private let colorKey = "GlobalFolderColors"
    private let globalColorKey = UserDefaults.Keys.globalFolderColor.rawValue

    private init() {}

    // MARK: - Public Methods

    func setColor(_ color: NSColor, forFolderName name: String) {
        var stored = loadColorDictionary()
        stored[name] = color.toHex()
        persistColorDictionary(stored)
        NotificationCenter.default.post(name: .globalFolderColorDidChangeNotification, object: nil)
    }

    func getColor(forFolderName name: String) -> NSColor? {
        guard let hex = loadColorDictionary()[name] else { return nil }
        return NSColor(hex: hex)
    }

    func getColor(for url: URL) -> NSColor? {
        if let nameColor = getColor(forFolderName: url.lastPathComponent) {
            return nameColor
        }
        return getGlobalFolderColor()
    }

    func getGlobalFolderColor() -> NSColor? {
        if let colorData = userDefaults.data(forKey: globalColorKey),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            return color
        }

        if let hex = userDefaults.string(forKey: globalColorKey) {
            return NSColor(hex: hex)
        }

        return nil
    }

    func setGlobalFolderColor(_ color: NSColor?) {
        if let color {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
                userDefaults.set(data, forKey: globalColorKey)
            } else {
                userDefaults.set(color.toHex(), forKey: globalColorKey)
            }
        } else {
            userDefaults.removeObject(forKey: globalColorKey)
        }
        NotificationCenter.default.post(name: .globalFolderColorDidChangeNotification, object: nil)
    }

    func removeColor(forFolderName name: String) {
        var stored = loadColorDictionary()
        stored.removeValue(forKey: name)
        persistColorDictionary(stored)
        NotificationCenter.default.post(name: .globalFolderColorDidChangeNotification, object: nil)
    }

    func clearAllColors() {
        userDefaults.removeObject(forKey: colorKey)
        userDefaults.removeObject(forKey: globalColorKey)
        NotificationCenter.default.post(name: .globalFolderColorDidChangeNotification, object: nil)
    }

    func getAllColoredFolderNames() -> [String] {
        return Array(loadColorDictionary().keys)
    }

    // MARK: - Private Helpers

    private func loadColorDictionary() -> [String: String] {
        return userDefaults.dictionary(forKey: colorKey) as? [String: String] ?? [:]
    }

    private func persistColorDictionary(_ dictionary: [String: String]) {
        userDefaults.set(dictionary, forKey: colorKey)
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

// MARK: - NSImage Grayscale Helper
// Grayscale helper now lives in NSImage+Grayscale.swift

extension NSImage {
    /// Returns a grayscale copy of the image. If conversion fails, returns original.
    func grayscale() -> NSImage {
        guard let tiff = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return self
        }

        let ciImage = CIImage(bitmapImageRep: bitmap)
        let filter = CIFilter(name: "CIPhotoEffectMono")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        guard let output = filter?.outputImage else { return self }

        let rep = NSCIImageRep(ciImage: output)
        let img = NSImage(size: rep.size)
        img.addRepresentation(rep)
        return img
    }
}
