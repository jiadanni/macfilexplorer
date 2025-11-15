import Cocoa

class FileItem: Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    var children: [FileItem]?
    private(set) var size: Int64 = 0
    private(set) var modificationDate: Date?
    private(set) var creationDate: Date?
    private(set) var fileType: String = ""
    private(set) var kind: String = ""
    private(set) var permissions: String = ""
    private(set) var owner: String = ""
    private(set) var tags: [String] = []

    var isHidden: Bool = false

    // Display name with or without extension based on user preference
    var displayName: String {
        let showExtensions = UserDefaults.standard.object(forKey: UserDefaults.Keys.showFileExtensions.rawValue) as? Bool ?? true

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
                if let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: url.path) {
                    var symlinkIsDir: ObjCBool = false
                    let destinationPath = (destination as NSString).hasPrefix("/") ? destination : url.deletingLastPathComponent().appendingPathComponent(destination).path
                    FileManager.default.fileExists(atPath: destinationPath, isDirectory: &symlinkIsDir)
                    detectedAsDirectory = symlinkIsDir.boolValue
                }
            }
            
            // Packages are treated as files unless they're also directories
            if let isPackage = resourceValues.isPackage, isPackage {
                // Only override if we're certain it's not a directory
                if !detectedAsDirectory {
                    detectedAsDirectory = false
                }
            }
            if let tagNames = resourceValues.tagNames {
                self.tags = tagNames
            }
        }
        
        self.isDirectory = detectedAsDirectory
        self.isHidden = name.hasPrefix(".")

        // Debug logging for cloud storage directories
        if url.path.contains("Google Drive") {
            print("🔍 FileItem init: \(name)")
            print("   Path: \(url.path)")
            print("   isDirectory: \(detectedAsDirectory)")
            if let rv = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentTypeKey]) {
                print("   Resource isDirectory: \(rv.isDirectory ?? false)")
                print("   Resource isSymlink: \(rv.isSymbolicLink ?? false)")
                print("   Content Type: \(rv.contentType?.identifier ?? "nil")")
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

    // MARK: - Public Methods

    @discardableResult
    func loadChildren(showsHiddenFiles: Bool = false, recursive: Bool = false, errorHandler: ((String) -> Void)? = nil) -> Bool {
        guard isDirectory else { return false }

        let fileManager = FileManager.default

        // Debug logging for Google Drive
        if url.path.contains("Google Drive") {
            print("📂 loadChildren called for: \(url.path)")
            print("   showsHiddenFiles: \(showsHiddenFiles)")
        }

        do {
            var options: FileManager.DirectoryEnumerationOptions = []
            if !showsHiddenFiles {
                options.insert(.skipsHiddenFiles)
            }

            if recursive {
                let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isReadableKey], options: options)
                var urls: [URL] = []
                while let fileURL = enumerator?.nextObject() as? URL {
                    urls.append(fileURL)
                }
                children = urls.map { FileItem(url: $0) }
                return true
            }


            // Try to get contents - for cloud storage like Google Drive, this might need special handling
            let urls = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isReadableKey],
                options: options
            )

            if url.path.contains("Google Drive") {
                print("   ✅ Got \(urls.count) items from contentsOfDirectory")
            }

            children = urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                .map { FileItem(url: $0) }

            // Only initialize children array for subdirectories, don't recursively load
            children?.forEach { child in
                if child.isDirectory && child.children == nil {
                    child.children = []
                }
            }

            if url.path.contains("Google Drive") {
                print("   Final children count: \(children?.count ?? 0)")
            }
            return true
        } catch let error as NSError {
            // Log the error with more detail for debugging
            print("❌ Error loading children for \(url.path):")
            print("  Error code: \(error.code)")
            print("  Error domain: \(error.domain)")
            print("  Error description: \(error.localizedDescription)")
            print("  User info: \(error.userInfo)")

            // For Google Drive and other cloud storage, try alternative approach
            if error.domain == NSCocoaErrorDomain && (error.code == 257 || error.code == 260) {
                print("  🔄 Trying enumerator fallback...")
                // Permission denied or file not found - might be cloud storage issue
                // Try using FileManager enumerator instead
                if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: showsHiddenFiles ? [] : [.skipsHiddenFiles]) {
                    var foundURLs: [URL] = []
                    for case let fileURL as URL in enumerator {
                        // Only get immediate children, not recursive
                        if fileURL.deletingLastPathComponent() == url {
                            foundURLs.append(fileURL)
                        } else {
                            enumerator.skipDescendants()
                        }
                    }
                    print("  ✅ Enumerator found \(foundURLs.count) items")
                    children = foundURLs.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                        .map { FileItem(url: $0) }

                    children?.forEach { child in
                        if child.isDirectory && child.children == nil {
                            child.children = []
                        }
                    }
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
            print("❌ Unexpected error loading children for \(url.path): \(error)")
            errorHandler?("An unexpected error occurred while opening '\(name)'.")
            children = []
            return false
        }
    }

    // MARK: - Computed Properties

    var icon: NSImage {
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var isImage: Bool {
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "heic"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }

    var sizeString: String {
        guard !isDirectory else { return "--" }
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
