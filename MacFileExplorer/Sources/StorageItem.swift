//
//  StorageItem.swift
//  MacFileExplorer
//
//  Data model for storage analysis with hierarchical size calculations
//

import Foundation

/// Represents a file or folder in the storage analysis tree
class StorageItem {
    let fileItem: FileItem
    let url: URL
    let name: String
    let isDirectory: Bool

    /// Size of this item only (file size, or 0 for directories)
    private(set) var ownSize: Int64

    /// Total size including all children (for directories)
    private(set) var totalSize: Int64

    /// Number of files contained (0 for files, count for directories)
    private(set) var fileCount: Int

    /// Number of subdirectories (0 for files, count for directories)
    private(set) var folderCount: Int

    /// Percentage of parent's total size (0-100)
    var percentage: Double = 0.0

    /// File category for visualization
    let category: StorageCategory

    /// Child items (only populated for directories)
    var children: [StorageItem] = []

    /// Parent item (nil for root)
    weak var parent: StorageItem?

    /// Modification date
    let modificationDate: Date?

    /// Whether this item was scanned (children loaded)
    var isScanned: Bool = false

    init(fileItem: FileItem) {
        self.fileItem = fileItem
        self.url = fileItem.url
        self.name = fileItem.name
        self.isDirectory = fileItem.isDirectory
        self.ownSize = fileItem.isDirectory ? 0 : fileItem.size
        self.totalSize = self.ownSize
        self.fileCount = fileItem.isDirectory ? 0 : 1
        self.folderCount = 0
        self.category = StorageCategory.categorize(fileItem: fileItem)
        self.modificationDate = fileItem.modificationDate
    }

    /// Convenience initializer for direct URL
    convenience init(url: URL) throws {
        let fileItem = FileItem(url: url)
        self.init(fileItem: fileItem)
    }

    /// Adds a child item and updates size calculations
    func addChild(_ child: StorageItem) {
        children.append(child)
        child.parent = self
        updateSizeFromChild(child)
    }

    /// Updates this item's total size based on a child's size
    private func updateSizeFromChild(_ child: StorageItem) {
        totalSize += child.totalSize
        fileCount += child.fileCount
        folderCount += (child.isDirectory ? 1 : 0) + child.folderCount

        // Update percentage for the child
        if totalSize > 0 {
            child.percentage = (Double(child.totalSize) / Double(totalSize)) * 100.0
        }

        // Propagate up the tree
        parent?.updateSizeFromChild(child)
    }

    /// Recalculates percentages for all children
    func recalculatePercentages() {
        guard totalSize > 0 else { return }

        for child in children {
            child.percentage = (Double(child.totalSize) / Double(totalSize)) * 100.0
            child.recalculatePercentages()
        }
    }

    /// Sorts children by size (descending)
    func sortChildrenBySize() {
        children.sort { $0.totalSize > $1.totalSize }
        for child in children {
            child.sortChildrenBySize()
        }
    }

    /// Returns the top N largest children
    func largestChildren(limit: Int) -> [StorageItem] {
        return Array(children.sorted { $0.totalSize > $1.totalSize }.prefix(limit))
    }

    /// Formatted size string
    var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    /// Formatted percentage string
    var formattedPercentage: String {
        return String(format: "%.1f%%", percentage)
    }

    /// Relative path from a given root
    func relativePath(from root: URL) -> String {
        guard url.path.hasPrefix(root.path) else { return url.path }
        let rootPath = root.path
        let fullPath = url.path

        if fullPath == rootPath {
            return "/"
        }

        let relativePath = String(fullPath.dropFirst(rootPath.count))
        return relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
    }

    /// Returns all descendants flattened into an array
    func flattenedDescendants() -> [StorageItem] {
        var result: [StorageItem] = []
        for child in children {
            result.append(child)
            result.append(contentsOf: child.flattenedDescendants())
        }
        return result
    }

    /// Searches for items matching a predicate
    func search(matching predicate: (StorageItem) -> Bool) -> [StorageItem] {
        var results: [StorageItem] = []

        if predicate(self) {
            results.append(self)
        }

        for child in children {
            results.append(contentsOf: child.search(matching: predicate))
        }

        return results
    }

    /// Returns items by category breakdown
    func categoryBreakdown() -> [StorageCategory: Int64] {
        var breakdown: [StorageCategory: Int64] = [:]

        func traverse(_ item: StorageItem) {
            if !item.isDirectory || item.children.isEmpty {
                // Leaf node - count its size toward its category
                breakdown[item.category, default: 0] += item.totalSize
            } else {
                // Directory - traverse children
                for child in item.children {
                    traverse(child)
                }
            }
        }

        traverse(self)
        return breakdown
    }

    /// Checks if this item is a cache/temporary file
    var isCacheOrTemp: Bool {
        return category == .cache ||
               url.path.contains("/Caches/") ||
               url.path.contains("/tmp/") ||
               url.path.contains("/.Trash/")
    }

    /// Checks if file hasn't been modified in over a year
    var isOld: Bool {
        guard let modDate = modificationDate else { return false }
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        return modDate < oneYearAgo
    }

    /// Debug description
    var debugDescription: String {
        return "\(name): \(formattedSize) (\(formattedPercentage)), \(fileCount) files, \(folderCount) folders"
    }
}

// MARK: - Hashable & Equatable
extension StorageItem: Hashable {
    static func == (lhs: StorageItem, rhs: StorageItem) -> Bool {
        return lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

// MARK: - Comparable (for sorting)
extension StorageItem: Comparable {
    static func < (lhs: StorageItem, rhs: StorageItem) -> Bool {
        return lhs.totalSize < rhs.totalSize
    }
}
