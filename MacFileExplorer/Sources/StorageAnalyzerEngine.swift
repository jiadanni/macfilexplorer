//
//  StorageAnalyzerEngine.swift
//  MacFileExplorer
//
//  Background scanning engine for disk storage analysis
//

import Foundation

/// Delegate protocol for storage analyzer progress updates
protocol StorageAnalyzerDelegate: AnyObject {
    func analyzerDidStart(totalItems: Int)
    func analyzerDidProgress(currentPath: String, itemsScanned: Int, totalSize: Int64)
    func analyzerDidComplete(rootItem: StorageItem, duration: TimeInterval)
    func analyzerDidFail(error: String)
    func analyzerWasCancelled()
}

/// Engine for scanning and analyzing disk storage
class StorageAnalyzerEngine {
    // MARK: - Properties

    weak var delegate: StorageAnalyzerDelegate?

    private let scanQueue = DispatchQueue(label: "com.macfileexplorer.storageanalyzer", qos: .userInitiated)
    private var isCancelled = false
    private var isPaused = false

    /// Root URL being scanned
    private(set) var rootURL: URL?

    /// Root storage item (result of scan)
    private(set) var rootItem: StorageItem?

    /// Scan options
    struct ScanOptions {
        var includeHiddenFiles: Bool = false
        var followSymlinks: Bool = false
        var skipPackages: Bool = false
        var minimumSize: Int64 = 0 // Skip items smaller than this

        static let `default` = ScanOptions()
    }

    private var options: ScanOptions = .default

    /// Cache for repeated scans
    private static var cache: [URL: (item: StorageItem, timestamp: Date)] = [:]
    private static let cacheValidityDuration: TimeInterval = 300 // 5 minutes

    // MARK: - Public Methods

    /// Starts scanning a directory
    func startScan(url: URL, options: ScanOptions = .default, delegate: StorageAnalyzerDelegate? = nil) {
        self.rootURL = url
        self.options = options
        self.delegate = delegate
        self.isCancelled = false
        self.isPaused = false

        // Check cache first
        if let cached = Self.cache[url], Date().timeIntervalSince(cached.timestamp) < Self.cacheValidityDuration {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.analyzerDidComplete(rootItem: cached.item, duration: 0)
            }
            return
        }

        scanQueue.async { [weak self] in
            self?.performScan(url: url)
        }
    }

    /// Cancels the current scan
    func cancel() {
        isCancelled = true
    }

    /// Pauses the current scan
    func pause() {
        isPaused = true
    }

    /// Resumes a paused scan
    func resume() {
        isPaused = false
    }

    /// Clears the cache
    static func clearCache() {
        cache.removeAll()
    }

    /// Invalidates cache for a specific URL
    static func invalidateCache(for url: URL) {
        cache.removeValue(forKey: url)
    }

    // MARK: - Private Methods

    private func performScan(url: URL) {
        let startTime = Date()

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.analyzerDidStart(totalItems: 0)
        }

        do {
            // Create root file item
            let fileItem = FileItem(url: url)
            let root = StorageItem(fileItem: fileItem)

            var itemsScanned = 0
            var totalSize: Int64 = 0

            // Scan recursively
            try scanDirectory(item: root, itemsScanned: &itemsScanned, totalSize: &totalSize)

            // Check if cancelled
            if isCancelled {
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.analyzerWasCancelled()
                }
                return
            }

            // Post-process: sort children by size
            root.sortChildrenBySize()
            root.recalculatePercentages()

            self.rootItem = root

            // Cache the result
            Self.cache[url] = (root, Date())

            let duration = Date().timeIntervalSince(startTime)

            DispatchQueue.main.async { [weak self] in
                self?.delegate?.analyzerDidComplete(rootItem: root, duration: duration)
            }

        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.analyzerDidFail(error: error.localizedDescription)
            }
        }
    }

    private func scanDirectory(item: StorageItem, itemsScanned: inout Int, totalSize: inout Int64) throws {
        // Check for cancellation
        if isCancelled { return }

        // Handle pause
        while isPaused && !isCancelled {
            Thread.sleep(forTimeInterval: 0.1)
        }

        guard item.isDirectory else {
            // File - just count it
            itemsScanned += 1
            totalSize += item.totalSize
            reportProgress(path: item.url.path, itemsScanned: itemsScanned, totalSize: totalSize)
            return
        }

        // Directory - enumerate contents
        let fileManager = FileManager.default

        // Check if we have permission to read this directory
        guard fileManager.isReadableFile(atPath: item.url.path) else {
            // Skip inaccessible directories silently
            return
        }

        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .isHiddenKey,
            .isPackageKey,
            .isSymbolicLinkKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: item.url,
            includingPropertiesForKeys: keys,
            options: [.skipsSubdirectoryDescendants] // We'll recurse manually for better control
        ) else {
            return
        }

        var childItems: [StorageItem] = []

        for case let fileURL as URL in enumerator {
            // Check for cancellation
            if isCancelled { return }

            // Handle pause
            while isPaused && !isCancelled {
                Thread.sleep(forTimeInterval: 0.1)
            }

            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(keys))

                // Skip hidden files if option is set
                if !options.includeHiddenFiles, resourceValues.isHidden == true {
                    continue
                }

                // Skip packages if option is set
                if options.skipPackages, resourceValues.isPackage == true {
                    continue
                }

                // Skip symlinks if option is set
                if !options.followSymlinks, resourceValues.isSymbolicLink == true {
                    continue
                }

                // Create file item
                let childFileItem = FileItem(url: fileURL)
                let childStorageItem = StorageItem(fileItem: childFileItem)

                // Recurse if directory
                if childStorageItem.isDirectory {
                    try scanDirectory(item: childStorageItem, itemsScanned: &itemsScanned, totalSize: &totalSize)
                } else {
                    itemsScanned += 1
                    totalSize += childStorageItem.totalSize
                }

                // Skip if below minimum size threshold
                if childStorageItem.totalSize < options.minimumSize {
                    continue
                }

                childItems.append(childStorageItem)

                // Report progress every 100 items
                if itemsScanned % 100 == 0 {
                    reportProgress(path: fileURL.path, itemsScanned: itemsScanned, totalSize: totalSize)
                }

            } catch {
                // Skip files we can't read
                continue
            }
        }

        // Add all children to parent
        for child in childItems {
            item.addChild(child)
        }

        item.isScanned = true
    }

    private func reportProgress(path: String, itemsScanned: Int, totalSize: Int64) {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.analyzerDidProgress(
                currentPath: path,
                itemsScanned: itemsScanned,
                totalSize: totalSize
            )
        }
    }
}

// MARK: - Smart Filters
extension StorageAnalyzerEngine {
    /// Finds large files (>500MB by default)
    static func findLargeFiles(in item: StorageItem, threshold: Int64 = 500 * 1024 * 1024) -> [StorageItem] {
        return item.search { !$0.isDirectory && $0.totalSize >= threshold }
    }

    /// Finds duplicate files by name and size
    static func findDuplicates(in item: StorageItem) -> [[StorageItem]] {
        let allFiles = item.search { !$0.isDirectory }

        var filesBySignature: [String: [StorageItem]] = [:]

        for file in allFiles {
            let signature = "\(file.name)_\(file.totalSize)"
            filesBySignature[signature, default: []].append(file)
        }

        return filesBySignature.values.filter { $0.count > 1 }
    }

    /// Finds old files (not modified in >1 year)
    static func findOldFiles(in item: StorageItem) -> [StorageItem] {
        return item.search { $0.isOld }
    }

    /// Finds cache and temporary files
    static func findCacheFiles(in item: StorageItem) -> [StorageItem] {
        return item.search { $0.isCacheOrTemp }
    }

    /// Finds items in Downloads folder
    static func findDownloads(in item: StorageItem) -> [StorageItem] {
        return item.search { $0.url.path.contains("/Downloads/") }
    }
}
