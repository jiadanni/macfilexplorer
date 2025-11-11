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

    var isHidden: Bool = false

    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent

        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        self.isDirectory = isDir.boolValue
        self.isHidden = name.hasPrefix(".")

        // Get file attributes
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
            self.size = attributes[.size] as? Int64 ?? 0
            self.modificationDate = attributes[.modificationDate] as? Date
            self.creationDate = attributes[.creationDate] as? Date
            self.owner = attributes[.ownerAccountName] as? String ?? ""

            // Get permissions
            if let posixPermissions = attributes[.posixPermissions] as? NSNumber {
                self.permissions = String(format: "%o", posixPermissions.intValue)
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

    func loadChildren(showsHiddenFiles: Bool = false) {
        guard isDirectory else { return }

        let fileManager = FileManager.default
        do {
            var options: FileManager.DirectoryEnumerationOptions = []
            if !showsHiddenFiles {
                options.insert(.skipsHiddenFiles)
            }

            let urls = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: options
            )

            children = urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                .map { FileItem(url: $0) }

            // Only initialize children array for subdirectories, don't recursively load
            children?.forEach { child in
                if child.isDirectory && child.children == nil {
                    child.children = []
                }
            }
        } catch {
            print("Error loading children for \(url.path): \(error)")
            children = []
        }
    }

    // MARK: - Computed Properties

    var icon: NSImage {
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var formattedSize: String {
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
