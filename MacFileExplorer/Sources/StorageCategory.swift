//
//  StorageCategory.swift
//  MacFileExplorer
//
//  Storage file type categorization and color mapping
//

import Cocoa

/// Represents different categories of files for storage analysis
enum StorageCategory: String, CaseIterable {
    case applications = "Applications"
    case videos = "Videos"
    case images = "Images"
    case audio = "Audio"
    case documents = "Documents"
    case archives = "Archives"
    case code = "Code"
    case cache = "Cache & Temporary"
    case system = "System Files"
    case other = "Other"

    /// Color associated with this category for visualization
    var color: NSColor {
        switch self {
        case .applications:
            return NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0) // Blue
        case .videos:
            return NSColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0) // Red
        case .images:
            return NSColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1.0) // Green
        case .audio:
            return NSColor(red: 0.8, green: 0.4, blue: 0.8, alpha: 1.0) // Purple
        case .documents:
            return NSColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1.0) // Orange
        case .archives:
            return NSColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0) // Brown
        case .code:
            return NSColor(red: 0.2, green: 0.8, blue: 0.8, alpha: 1.0) // Cyan
        case .cache:
            return NSColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0) // Gray
        case .system:
            return NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0) // Dark Gray
        case .other:
            return NSColor(red: 0.8, green: 0.8, blue: 0.6, alpha: 1.0) // Beige
        }
    }

    /// Darker variant for hover states and selection
    var darkColor: NSColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        color.usingColorSpace(.deviceRGB)?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return NSColor(hue: hue, saturation: saturation, brightness: brightness * 0.8, alpha: alpha)
    }

    /// Determines the category for a given file
    static func categorize(fileItem: FileItem) -> StorageCategory {
        // Directories are categorized by path
        if fileItem.isDirectory {
            return categorizeDirectory(url: fileItem.url)
        }

        // Files are categorized by extension
        let pathExtension = fileItem.url.pathExtension.lowercased()
        return categorizeByExtension(pathExtension)
    }

    /// Categorizes a directory based on its path
    private static func categorizeDirectory(url: URL) -> StorageCategory {
        let path = url.path

        // Cache and temporary files
        if path.contains("/Caches/") || path.contains("/tmp/") || path.contains("/.Trash/") {
            return .cache
        }

        // System directories
        if path.hasPrefix("/System/") || path.hasPrefix("/Library/") || path.hasPrefix("/usr/") || path.hasPrefix("/var/") {
            return .system
        }

        // Applications
        if path.hasSuffix(".app") || path.contains("/Applications/") {
            return .applications
        }

        // User library cache
        if path.contains("/Library/Caches/") || path.contains("/Library/Logs/") {
            return .cache
        }

        return .other
    }

    /// Categorizes a file based on its extension
    private static func categorizeByExtension(_ ext: String) -> StorageCategory {
        switch ext {
        // Applications
        case "app", "dmg", "pkg", "prefpane", "plugin":
            return .applications

        // Videos
        case "mp4", "mov", "avi", "mkv", "m4v", "flv", "wmv", "webm", "mpeg", "mpg", "3gp", "m2ts", "mts":
            return .videos

        // Images
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "svg", "webp", "ico", "heic", "heif", "raw", "cr2", "nef", "psd":
            return .images

        // Audio
        case "mp3", "m4a", "aac", "wav", "flac", "ogg", "wma", "aiff", "aif", "opus", "alac":
            return .audio

        // Documents
        case "pdf", "doc", "docx", "txt", "rtf", "pages", "odt", "xls", "xlsx", "numbers", "ods", "ppt", "pptx", "key", "odp":
            return .documents

        // Archives
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "iso", "sit", "sitx":
            return .archives

        // Code
        case "swift", "m", "h", "mm", "cpp", "c", "hpp", "java", "py", "js", "ts", "jsx", "tsx", "html", "css", "scss",
             "json", "xml", "yaml", "yml", "sh", "rb", "go", "rs", "php", "sql", "kt", "cs", "md", "gradle", "xcodeproj", "xcworkspace":
            return .code

        // Cache/Temporary
        case "tmp", "temp", "cache", "log":
            return .cache

        default:
            return .other
        }
    }

    /// Returns all extensions belonging to this category
    var extensions: [String] {
        switch self {
        case .applications:
            return ["app", "dmg", "pkg", "prefpane", "plugin"]
        case .videos:
            return ["mp4", "mov", "avi", "mkv", "m4v", "flv", "wmv", "webm", "mpeg", "mpg", "3gp", "m2ts", "mts"]
        case .images:
            return ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "svg", "webp", "ico", "heic", "heif", "raw", "cr2", "nef", "psd"]
        case .audio:
            return ["mp3", "m4a", "aac", "wav", "flac", "ogg", "wma", "aiff", "aif", "opus", "alac"]
        case .documents:
            return ["pdf", "doc", "docx", "txt", "rtf", "pages", "odt", "xls", "xlsx", "numbers", "ods", "ppt", "pptx", "key", "odp"]
        case .archives:
            return ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "iso", "sit", "sitx"]
        case .code:
            return ["swift", "m", "h", "mm", "cpp", "c", "hpp", "java", "py", "js", "ts", "jsx", "tsx", "html", "css", "scss",
                    "json", "xml", "yaml", "yml", "sh", "rb", "go", "rs", "php", "sql", "kt", "cs", "md"]
        case .cache:
            return ["tmp", "temp", "cache", "log"]
        case .system, .other:
            return []
        }
    }
}
