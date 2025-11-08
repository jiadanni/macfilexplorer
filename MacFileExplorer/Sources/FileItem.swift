import Cocoa

class FileItem: Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    var children: [FileItem]?
    private(set) var size: Int64 = 0
    private(set) var modificationDate: Date?

    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent

        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        self.isDirectory = isDir.boolValue

        // Get file attributes
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
            self.size = attributes[.size] as? Int64 ?? 0
            self.modificationDate = attributes[.modificationDate] as? Date
        }

        if isDirectory {
            children = []
        }
    }

    // MARK: - Public Methods

    func loadChildren() {
        guard isDirectory else { return }

        let fileManager = FileManager.default
        do {
            let urls = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            children = urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                .map { FileItem(url: $0) }

            // Load children for subdirectories (one level only for performance)
            children?.forEach { child in
                if child.isDirectory {
                    child.loadChildren()
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

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        return lhs.url == rhs.url
    }
}
