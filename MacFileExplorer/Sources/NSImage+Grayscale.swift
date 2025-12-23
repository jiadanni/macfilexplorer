import Cocoa

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

extension NSImage {
    static func mfeSymbol(named name: String, accessibilityDescription: String?) -> NSImage? {
        if #available(macOS 11.0, *) {
            return NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription)
        }
        return nil
    }
}
