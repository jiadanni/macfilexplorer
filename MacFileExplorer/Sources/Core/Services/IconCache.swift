import Cocoa

/// Finder-style icon cache.
///
/// `NSWorkspace.shared.icon(forFile:)` hits the file system and the icon services
/// daemon on every call; the grayscale path additionally does a TIFF round-trip plus a
/// CoreImage `CIPhotoEffectMono` pass. Both were previously run per cell per scroll frame
/// (P2 in the 2026 review). This cache collapses that to one lookup per distinct icon.
///
/// Keying:
/// - Directories share a single folder icon (`dir` key), grayscale variant separate.
/// - Regular files with a plain extension are keyed by lowercased extension — every
///   `.swift`, `.png`, … renders the same system icon, exactly like Finder.
/// - Packages, apps, and extension-less files are keyed by full path: their icons can be
///   bespoke (app bundles carry their own `.icns`).
///
/// Thread-safe: `NSCache` is thread-safe, and the class is a stateless singleton around it.
final class IconCache {
    static let shared = IconCache()

    private let colorCache = NSCache<NSString, NSImage>()
    private let grayscaleCache = NSCache<NSString, NSImage>()

    private init() {
        colorCache.countLimit = 512
        grayscaleCache.countLimit = 512
    }

    /// Look up (or compute and store) the icon for a file.
    ///
    /// - Parameters:
    ///   - url: file URL.
    ///   - isDirectory: whether `url` is a real directory (not a package presented as a file).
    ///   - isPackage: whether `url` is a package/bundle (`.app`, `.bundle`, …).
    ///   - useGrayscale: whether to return the monochrome variant.
    ///   - folderSymbol: for grayscale directories, the SF Symbol folder image to tint
    ///     (supplied by the caller so this file stays UI-agnostic). Ignored otherwise.
    func icon(for url: URL,
              isDirectory: Bool,
              isPackage: Bool,
              useGrayscale: Bool,
              folderSymbol: @autoclosure () -> NSImage?) -> NSImage {
        let cache = useGrayscale ? grayscaleCache : colorCache
        let key = cacheKey(for: url, isDirectory: isDirectory, isPackage: isPackage) as NSString

        if let hit = cache.object(forKey: key) {
            return hit
        }

        let image: NSImage
        if useGrayscale {
            if isDirectory, let folder = folderSymbol() {
                image = folder.grayscale()
            } else {
                image = NSWorkspace.shared.icon(forFile: url.path).grayscale()
            }
        } else {
            image = NSWorkspace.shared.icon(forFile: url.path)
        }

        cache.setObject(image, forKey: key)
        return image
    }

    /// Drop all cached icons. Call when the icon set may have changed wholesale
    /// (e.g. a system appearance switch that affects folder tinting).
    func clear() {
        colorCache.removeAllObjects()
        grayscaleCache.removeAllObjects()
    }

    private func cacheKey(for url: URL, isDirectory: Bool, isPackage: Bool) -> String {
        if isDirectory {
            return "dir"
        }
        let ext = url.pathExtension.lowercased()
        if isPackage || ext.isEmpty {
            // Bespoke icon — key by path.
            return "path:\(url.path)"
        }
        return "ext:\(ext)"
    }
}
