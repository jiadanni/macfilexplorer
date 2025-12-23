import Cocoa

/// Helper class for common file browser actions.
/// Extracted to reduce FileBrowserViewController complexity.
/// Handles file operations that don't require view state.

class FileBrowserActionHelper {
    
    /// Returns a ByteCountFormatter for consistent file size formatting.
    static let fileSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter
    }()
    
    /// Formats a file size in bytes to a human-readable string.
    static func formatFileSize(_ bytes: Int64) -> String {
        return fileSizeFormatter.string(fromByteCount: bytes)
    }
    
    /// Formats file size from UInt64.
    static func formatFileSize(_ bytes: UInt64) -> String {
        return formatFileSize(Int64(bytes))
    }
    
    /// Creates a standard date formatter for file metadata.
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    /// Formats a date for display.
    static func formatDate(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }
    
    /// Checks if a URL is a directory.
    static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }
    
    /// Gets the display name for a URL.
    static func displayName(for url: URL) -> String {
        let fileManager = FileManager.default
        let name = fileManager.displayName(atPath: url.path)
        return name.isEmpty ? url.lastPathComponent : name
    }
    
    /// Opens a file with the default application.
    static func openFile(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    /// Opens a file with a specific application.
    static func openFile(_ url: URL, withApplication appURL: URL) {
        if #available(macOS 11.0, *) {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { _, error in
                if let error = error {
                    debugLog("Failed to open file with app: \(error)")
                }
            }
        } else {
            let success = NSWorkspace.shared.openFile(url.path, withApplication: appURL.path)
            if !success {
                debugLog("Failed to open file with app: \(appURL.path)")
            }
        }
    }
    
    /// Reveals a file in Finder.
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }
    
    /// Opens Terminal at a directory.
    static func openTerminal(at directory: URL) {
        let script = """
        tell application "Terminal"
            do script "cd '\(directory.path)' && clear"
            activate
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                debugLog("AppleScript error: \(error)")
            }
        }
    }
    
    /// Returns the available disk space for a directory.
    static func getAvailableDiskSpace(for url: URL) -> UInt64? {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
        
        if let available = values.volumeAvailableCapacity {
            return UInt64(available)
        }
        
        return nil
    }
    
    /// Formats disk space for status bar display.
    static func formatDiskSpace(_ bytes: UInt64?) -> String? {
        guard let bytes = bytes else { return nil }
        return formatFileSize(bytes)
    }
}

// MARK: - File Operations

extension FileBrowserActionHelper {
    
    /// Duplicates a file or folder.
    static func duplicate(_ url: URL) throws -> URL {
        let fileManager = FileManager.default
        let parentURL = url.deletingLastPathComponent()
        let originalName = url.lastPathComponent
        let ext = (originalName as NSString).pathExtension
        let nameWithoutExt = (originalName as NSString).deletingPathExtension
        
        var counter = 1
        var newURL: URL
        repeat {
            let newName = "\(nameWithoutExt) copy\(counter > 1 ? " \(counter)" : "")\(!ext.isEmpty ? ".\(ext)" : "")"
            newURL = parentURL.appendingPathComponent(newName)
            counter += 1
        } while fileManager.fileExists(atPath: newURL.path)
        
        try fileManager.copyItem(at: url, to: newURL)
        return newURL
    }
    
    /// Gets file system attributes for status bar display.
    static func getFileInfo(_ url: URL) -> (count: Int, size: UInt64) {
        guard url != URL(fileURLWithPath: "/dev/null") else { return (0, 0) }
        
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) else {
            return (0, 0)
        }
        
        var totalSize: UInt64 = 0
        for item in contents {
            if let resourceValues = try? item.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
               let size = resourceValues.fileSize {
                totalSize += UInt64(size)
            }
        }
        
        return (contents.count, totalSize)
    }
}
