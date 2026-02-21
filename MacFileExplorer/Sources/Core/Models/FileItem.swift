import Cocoa

/// Represents a file system item (file or directory) with metadata and lazy-loading support.
///
/// `FileItem` provides a hierarchical representation of the file system with:
/// - Lazy loading of directory contents for performance
/// - Cloud storage support (Google Drive, iCloud)
/// - Symlink resolution
/// - Extended file attributes (tags, permissions, owner)
///
/// **Usage:**
/// ```swift
/// let item = FileItem(url: URL(fileURLWithPath: "/Users/username/Documents"))
/// item.loadChildren()  // Load subdirectories and files
/// for child in item.children ?? [] {
///     print(child.displayName(showExtensions: settings.showFileExtensions))
/// }
/// ```
///
/// **Performance:** Directory contents are loaded on-demand via `loadChildren()`.
/// The `hasLoadedChildren` flag prevents redundant filesystem queries.
class FileItem: Hashable {
    /// The file system URL for this item.
    let url: URL

    /// The file or directory name (last path component).
    let name: String

    /// Whether this item represents a directory.
    let isDirectory: Bool

    /// Child items if this is a directory. `nil` if not loaded, empty array if directory is empty.
    /// **Thread-safe**: Protected by childrenLock for concurrent access.
    private var _children: [FileItem]?
    private let childrenLock = NSLock()

    var children: [FileItem]? {
        get {
            childrenLock.lock()
            defer { childrenLock.unlock() }
            return _children
        }
        set {
            childrenLock.lock()
            defer { childrenLock.unlock() }
            _children = newValue
        }
    }
    
    /// Tracks whether we've enumerated children from the filesystem.
    /// An empty `children` array alone is ambiguous (could mean not-loaded or empty directory).
    private(set) var hasLoadedChildren = false
    
    /// File size in bytes. For directories, this is typically 0 unless explicitly calculated.
    private(set) var size: Int64 = 0
    
    /// File modification date from filesystem attributes.
    private(set) var modificationDate: Date?
    
    /// File creation date from filesystem attributes.
    private(set) var creationDate: Date?
    
    /// File type identifier (e.g., "public.plain-text").
    private(set) var fileType: String = ""
    
    /// Localized file kind description (e.g., "Folder", "Plain Text Document").
    private(set) var kind: String = ""
    
    /// POSIX permissions string (e.g., "drwxr-xr-x").
    private(set) var permissions: String = ""
    
    /// File owner's account name.
    private(set) var owner: String = ""
    
    /// macOS Finder tags associated with this file.
    private(set) var tags: [String] = []

    /// Whether this item is hidden (name starts with '.').
    var isHidden: Bool = false
    
    /// Whether this directory needs its children loaded.
    /// Returns `true` for directories that haven't been enumerated yet.
    var needsChildLoading: Bool {
        return isDirectory && !hasLoadedChildren
    }

    /// Returns display name with explicitly provided extension visibility preference.
    ///
    /// This method avoids circular dependency on SettingsStore and enables testability
    /// by passing the extension preference directly.
    ///
    /// - Parameter showExtensions: Whether to show file extensions
    /// - Returns: The display name for this file item
    func displayName(showExtensions: Bool) -> String {
        if showExtensions || isDirectory {
            return name
        } else {
            // Hide extension for files
            return (name as NSString).deletingPathExtension
        }
    }

    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent

        // Check if it's a directory - use multiple methods for cloud storage support
        var isDir: ObjCBool = false
        let _ = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        
        // For cloud storage (like Google Drive), also check resource values and symlink targets
        var detectedAsDirectory = isDir.boolValue
        
        if let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .contentTypeKey, .tagNamesKey]) {
            // If content type is public.folder, it's a directory
            if let contentType = resourceValues.contentType, contentType.conforms(to: .folder) {
                detectedAsDirectory = true
            }
            
            // Check if it's a directory
            if let isDirectory = resourceValues.isDirectory {
                detectedAsDirectory = isDirectory
            }
            
            // If it's a symbolic link (Google Drive File Stream uses symlinks), resolve it
            if let isSymlink = resourceValues.isSymbolicLink, isSymlink {
                // Resolve symlink using standardized URL resolution
                let resolvedURL = url.resolvingSymlinksInPath()
                var symlinkIsDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: resolvedURL.path, isDirectory: &symlinkIsDir) {
                    detectedAsDirectory = symlinkIsDir.boolValue
                } else {
                    // Fallback: single-level resolution only
                    do {
                        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: url.path)
                        var symlinkIsDir: ObjCBool = false

                        let resolvedPath: String
                        if destination.hasPrefix("/") {
                            resolvedPath = destination
                        } else {
                            let parentURL = url.deletingLastPathComponent()
                            let resolvedURL = parentURL.appendingPathComponent(destination).standardizedFileURL
                            resolvedPath = resolvedURL.path
                        }

                        // Only check if resolved path exists, don't follow further symlinks
                        FileManager.default.fileExists(atPath: resolvedPath, isDirectory: &symlinkIsDir)
                        detectedAsDirectory = symlinkIsDir.boolValue
                    } catch {
                        debugLog("Warning: Failed to resolve symlink at \(url.path): \(error)")
                    }
                }
            }
            
            // Packages are treated as files unless they're also directories
            if let isPackage = resourceValues.isPackage,
               isPackage,
               resourceValues.isDirectory != true {
                detectedAsDirectory = false
            }
            if let tagNames = resourceValues.tagNames {
                self.tags = tagNames
            }
        }
        
        self.isDirectory = detectedAsDirectory
        self.isHidden = name.hasPrefix(".")

        // Debug logging for cloud storage directories
        if url.path.contains("Google Drive") {
            debugLog("🔍 FileItem init: \(name)")
            debugLog("   Path: \(url.path)")
            debugLog("   isDirectory: \(detectedAsDirectory)")
            if let rv = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentTypeKey]) {
                debugLog("   Resource isDirectory: \(rv.isDirectory ?? false)")
                debugLog("   Resource isSymlink: \(rv.isSymbolicLink ?? false)")
                debugLog("   Content Type: \(rv.contentType?.identifier ?? "nil")")
            }
        }

        // Get file attributes - with error handling for cloud storage
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            self.size = attributes[.size] as? Int64 ?? 0
            self.modificationDate = attributes[.modificationDate] as? Date
            self.creationDate = attributes[.creationDate] as? Date
            self.owner = attributes[.ownerAccountName] as? String ?? ""

            // Get permissions
            if let posixPermissions = attributes[.posixPermissions] as? NSNumber {
                self.permissions = String(format: "%o", posixPermissions.intValue)
            }
        } catch {
            // For cloud storage files that might not be downloaded yet, use defaults
            // Try to get resource values instead
            if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .creationDateKey]) {
                self.size = Int64(resourceValues.fileSize ?? 0)
                self.modificationDate = resourceValues.contentModificationDate
                self.creationDate = resourceValues.creationDate
            }
        }

        // Get file type and kind
        if isDirectory {
            self.fileType = "Folder"
            self.kind = "Folder"
            children = []
        } else {
            self.fileType = url.pathExtension.uppercased()
            // Get localized kind description from system
            if let values = try? url.resourceValues(forKeys: [.localizedTypeDescriptionKey]),
               let kindDescription = values.localizedTypeDescription {
                self.kind = kindDescription
            } else if !url.pathExtension.isEmpty {
                self.kind = "\(url.pathExtension.uppercased()) File"
            } else {
                self.kind = "File"
            }
        }
    }

    // MARK: - Dependency Injection
    
    /// Permissions manager for security-scoped resource access.
    /// Override this in tests to provide a mock implementation.
    static var permissionsManager: PermissionsManaging = PermissionsManager.shared

    // MARK: - Public Methods

    @discardableResult
    func loadChildren(showsHiddenFiles: Bool = false, recursive: Bool = false, errorHandler: ((String) -> Void)? = nil) -> Bool {
        guard isDirectory else { return false }
        var didLoadChildren = false
        defer {
            if didLoadChildren {
                hasLoadedChildren = true
            }
        }

        // Ensure security-scoped access for sandboxed builds when folder is already granted.
        _ = FileItem.permissionsManager.ensureAccess(for: url)

        let fileManager = FileManager.default
        let resolvedURL = url.resolvingSymlinksInPath()
        let isGoogleDrive = FileItem.isGoogleDrivePath(resolvedURL.path)

        // Debug logging for all directories
        debugLog("📂 loadChildren called for: \(url.path)")
        debugLog("   resolvedURL: \(resolvedURL.path)")
        debugLog("   showsHiddenFiles: \(showsHiddenFiles)")
        debugLog("   isReadable: \(fileManager.isReadableFile(atPath: resolvedURL.path))")

        // Special handling for root directory "/" to avoid permission dialogs
        if resolvedURL.path == "/" {
            debugLog("📂 Special handling for root directory /")
            
            // For root, only show /Volumes and maybe /Users/<username>
            var safeRootItems: [URL] = []
            
            // Always add /Volumes (mounted drives)
            let volumesURL = URL(fileURLWithPath: AppConfig.Paths.volumes)
            if fileManager.fileExists(atPath: volumesURL.path) {
                safeRootItems.append(volumesURL)
            }
            
            // Add user's home directory
            let homeURL = URL(fileURLWithPath: NSHomeDirectory())
            if fileManager.fileExists(atPath: homeURL.path) {
                safeRootItems.append(homeURL)
            }
            
            // Add /Applications if accessible
            let applicationsURL = URL(fileURLWithPath: AppConfig.Paths.applications)
            if fileManager.fileExists(atPath: applicationsURL.path) {
                safeRootItems.append(applicationsURL)
            }
            
            // Only add other root folders if they're already granted permission
            // This prevents triggering permission dialogs
            let potentialRootFolders = AppConfig.Paths.rootCandidates
            for folderPath in potentialRootFolders {
                let folderURL = URL(fileURLWithPath: folderPath)
                // Only add if we can read it without triggering permission dialog
                if fileManager.isReadableFile(atPath: folderPath) {
                    safeRootItems.append(folderURL)
                }
            }
            
            // Use non-localized comparison during initialization to avoid ICU crashes
            children = safeRootItems.sorted { $0.lastPathComponent.caseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
                .map { FileItem(url: $0) }
            didLoadChildren = true
            
            children?.forEach { child in
                if child.isDirectory && child.children == nil {
                    child.children = []
                }
            }
            
            debugLog("   ✅ Root directory loaded with \(children?.count ?? 0) safe items")
            return true
        }

        do {
            var options: FileManager.DirectoryEnumerationOptions = []
            if !showsHiddenFiles {
                options.insert(.skipsHiddenFiles)
            }

            if recursive {
                let enumerator = fileManager.enumerator(at: resolvedURL, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isReadableKey], options: options)
                var urls: [URL] = []
                while let fileURL = enumerator?.nextObject() as? URL {
                    urls.append(fileURL)
                }
                children = urls.map { FileItem(url: $0) }
                didLoadChildren = true
                return true
            }


            // Try to get contents - for cloud storage like Google Drive, this might need special handling
            let urls = try fileManager.contentsOfDirectory(
                at: resolvedURL,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isReadableKey],
                options: options
            )

            debugLog("   ✅ Got \(urls.count) items from contentsOfDirectory")
            for (index, fileURL) in urls.prefix(5).enumerated() {
                debugLog("      [\(index)] \(fileURL.lastPathComponent)")
            }
            if urls.count > 5 {
                debugLog("      ... and \(urls.count - 5) more")
            }

            // Use non-localized comparison during initialization to avoid ICU crashes
            children = urls.sorted { $0.lastPathComponent.caseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
                .map { FileItem(url: $0) }

            // Only initialize children array for subdirectories, don't recursively load
            children?.forEach { child in
                if child.isDirectory && child.children == nil {
                    child.children = []
                }
            }

            debugLog("   Final children count: \(children?.count ?? 0)")
            didLoadChildren = true
            return true
        } catch let error as NSError {
            // Log the error with more detail for debugging
            debugLog("❌ Error loading children for \(url.path):")
            debugLog("  Error code: \(error.code)")
            debugLog("  Error domain: \(error.domain)")
            debugLog("  Error description: \(error.localizedDescription)")
            debugLog("  User info: \(error.userInfo)")

            // For Google Drive and other cloud storage, try alternative approach
            if isGoogleDrive {
                debugLog("  🔄 Trying Google Drive enumerator fallback...")
                if let fallback = loadChildrenWithEnumerator(fileManager: fileManager, baseURL: url, resolvedURL: resolvedURL, showsHiddenFiles: showsHiddenFiles) {
                    children = fallback
                    didLoadChildren = true
                    return true
                }
            } else if error.domain == NSCocoaErrorDomain && (error.code == 257 || error.code == 260) {
                debugLog("  🔄 Trying enumerator fallback...")
                if let fallback = loadChildrenWithEnumerator(fileManager: fileManager, baseURL: url, resolvedURL: resolvedURL, showsHiddenFiles: showsHiddenFiles) {
                    children = fallback
                    didLoadChildren = true
                    return true
                }
            }

            // Notify caller of the error
            let userMessage: String
            if error.code == 257 {
                userMessage = "Access denied to '\(name)'. You may not have permission to view this folder."
            } else if error.code == 260 {
                userMessage = "The folder '\(name)' could not be found or is unavailable."
            } else {
                userMessage = "Unable to open '\(name)': \(error.localizedDescription)"
            }
            errorHandler?(userMessage)

            children = []
            return false
        } catch {
            debugLog("❌ Unexpected error loading children for \(url.path): \(error)")
            errorHandler?("An unexpected error occurred while opening '\(name)'.")
            children = []
            return false
        }
    }

    private func loadChildrenWithEnumerator(fileManager: FileManager, baseURL: URL, resolvedURL: URL, showsHiddenFiles: Bool) -> [FileItem]? {
        let urls = enumeratorChildren(fileManager: fileManager, at: baseURL, showsHiddenFiles: showsHiddenFiles)
            ?? enumeratorChildren(fileManager: fileManager, at: resolvedURL, showsHiddenFiles: showsHiddenFiles)

        guard let foundURLs = urls else { return nil }
        let items = foundURLs.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { FileItem(url: $0) }

        items.forEach { child in
            if child.isDirectory && child.children == nil {
                child.children = []
            }
        }
        return items
    }

    private func enumeratorChildren(fileManager: FileManager, at baseURL: URL, showsHiddenFiles: Bool) -> [URL]? {
        guard let enumerator = fileManager.enumerator(at: baseURL, includingPropertiesForKeys: [.isDirectoryKey], options: showsHiddenFiles ? [] : [.skipsHiddenFiles]) else {
            return nil
        }

        var foundURLs: [URL] = []
        for case let fileURL as URL in enumerator {
            // Only gather immediate children
            if fileURL.deletingLastPathComponent() == baseURL {
                foundURLs.append(fileURL)
            } else {
                enumerator.skipDescendants()
            }
        }
        debugLog("  ✅ Enumerator found \(foundURLs.count) items at \(baseURL.path)")
        return foundURLs
    }

    private static func isGoogleDrivePath(_ path: String) -> Bool {
        let lowercased = path.lowercased()
        return lowercased.contains("google drive") || lowercased.contains("googledrive")
    }

    // MARK: - Computed Properties

    /// Get icon with explicit grayscale preference.
    /// - Parameter useGrayscale: Whether to render icon in grayscale
    /// - Returns: Icon for this file item
    func icon(useGrayscale: Bool) -> NSImage {
        if useGrayscale {
            // Grayscale mode: use monochrome SF Symbol for folders, grayscale file icons otherwise
            if isDirectory, let folderIcon = NSImage.mfeSymbol(named: "folder", accessibilityDescription: "Folder") {
                return folderIcon.grayscale()
            }
            return NSWorkspace.shared.icon(forFile: url.path).grayscale()
        } else {
            // Default (Finder-style color icons)
            return NSWorkspace.shared.icon(forFile: url.path)
        }
    }

    @available(*, deprecated, message: "Use icon(useGrayscale:) with explicit preference for better testability")
    var icon: NSImage {
        return icon(useGrayscale: SettingsStore.shared.useGrayscaleIcons)
    }

    var isImage: Bool {
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "heic"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }

    // MARK: - Folder Size Calculation

    /// Asynchronously calculate the total size of a folder
    func calculateFolderSize(completion: @escaping (Int64) -> Void) {
        Task {
            let totalSize = await calculateFolderSize()
            completion(totalSize)
        }
    }

    /// Asynchronously calculate the total size of a folder.
    func calculateFolderSize() async -> Int64 {
        guard isDirectory else {
            return size
        }

        let targetURL = url
        let totalSize = await Task.detached(priority: .utility) {
            FileItem.calculateDirectorySize(at: targetURL)
        }.value

        await MainActor.run {
            self.size = totalSize
        }

        return totalSize
    }

    private static func calculateDirectorySize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(at: url,
                                                       includingPropertiesForKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey],
                                                       options: [.skipsHiddenFiles]) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey])
                
                // Only count regular files
                if resourceValues.isRegularFile == true {
                    // Use allocated size for better accuracy
                    if let allocatedSize = resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize {
                        totalSize += Int64(allocatedSize)
                    }
                }
            } catch {
                // Skip files we can't read
                continue
            }
        }
        
        return totalSize
    }

    var sizeString: String {
        if isDirectory {
            // Check if user has enabled folder size calculation
            let showFolderSizes = SettingsStore.shared.showFolderSizes
            if showFolderSizes && size > 0 {
                return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
            return "--"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDate: String {
        guard let date = modificationDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var formattedCreationDate: String {
        guard let date = creationDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var formattedPermissions: String {
        guard !permissions.isEmpty else { return "--" }
        return permissions
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        return lhs.url == rhs.url
    }
}
