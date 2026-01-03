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

private actor StorageAnalyzerCache {
    private var cache: [URL: (item: StorageItem, timestamp: Date)] = [:]

    func cachedResult(for url: URL) -> (item: StorageItem, timestamp: Date)? {
        cache[url]
    }

    func store(item: StorageItem, for url: URL) {
        cache[url] = (item, Date())
    }

    func clear() {
        cache.removeAll()
    }

    func invalidate(for url: URL) {
        cache.removeValue(forKey: url)
    }
}

private actor ScanControl {
    private var isCancelled = false
    private var isPaused = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func reset() {
        isCancelled = false
        isPaused = false
        resumeAll()
    }

    func cancel() {
        isCancelled = true
        resumeAll()
    }

    func pause() {
        isPaused = true
    }

    func resume() {
        isPaused = false
        resumeAll()
    }

    func shouldCancel() -> Bool {
        isCancelled
    }

    func waitIfPaused() async {
        if isCancelled || !isPaused {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func resumeAll() {
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}

/// Engine for scanning and analyzing disk storage
class StorageAnalyzerEngine {
    // MARK: - Properties

    weak var delegate: StorageAnalyzerDelegate?

    private let control = ScanControl()
    private var scanTask: Task<Void, Never>?

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
        var maxDepth: Int = AppConfig.Storage.maxRecursionDepth // Prevent unbounded recursion

        static let `default` = ScanOptions()
    }

    private var options: ScanOptions = .default

    /// Cache for repeated scans
    private static let cacheStore = StorageAnalyzerCache()
    private static let cacheValidityDuration: TimeInterval = 300 // 5 minutes

    // MARK: - Public Methods

    /// Starts scanning a directory
    func startScan(url: URL, options: ScanOptions = .default, delegate: StorageAnalyzerDelegate? = nil) {
        self.rootURL = url
        self.options = options
        self.delegate = delegate
        scanTask?.cancel()

        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.control.reset()

            // Check cache first
            if let cached = await Self.cachedResult(for: url),
               Date().timeIntervalSince(cached.timestamp) < Self.cacheValidityDuration {
                await MainActor.run {
                    self.delegate?.analyzerDidComplete(rootItem: cached.item, duration: 0)
                }
                return
            }

            await self.performScan(url: url)
        }
    }

    /// Cancels the current scan
    func cancel() {
        scanTask?.cancel()
        Task { await control.cancel() }
    }

    /// Pauses the current scan
    func pause() {
        Task { await control.pause() }
    }

    /// Resumes a paused scan
    func resume() {
        Task { await control.resume() }
    }

    /// Clears the cache
    static func clearCache() {
        Task {
            await cacheStore.clear()
        }
    }

    /// Invalidates cache for a specific URL
    static func invalidateCache(for url: URL) {
        Task {
            await cacheStore.invalidate(for: url)
        }
    }

    // MARK: - Private Methods

    private static func cachedResult(for url: URL) async -> (item: StorageItem, timestamp: Date)? {
        await cacheStore.cachedResult(for: url)
    }

    private static func storeCache(item: StorageItem, for url: URL) async {
        await cacheStore.store(item: item, for: url)
    }

    private func performScan(url: URL) async {
        let startTime = Date()

        await MainActor.run {
            self.delegate?.analyzerDidStart(totalItems: 0)
        }

        do {
            // Create root file item
            let fileItem = FileItem(url: url)
            let root = StorageItem(fileItem: fileItem)

            var itemsScanned = 0
            var totalSize: Int64 = 0
            var visitedPaths = Set<String>()

            // Scan recursively with cycle detection
            try await scanDirectory(item: root, itemsScanned: &itemsScanned, totalSize: &totalSize, currentDepth: 0, visitedPaths: &visitedPaths)

            // Check if cancelled
            if await control.shouldCancel() {
                await MainActor.run {
                    self.delegate?.analyzerWasCancelled()
                }
                return
            }

            // Post-process: sort children by size
            root.sortChildrenBySize()
            root.recalculatePercentages()

            self.rootItem = root

            // Cache the result
            await Self.storeCache(item: root, for: url)

            let duration = Date().timeIntervalSince(startTime)

            await MainActor.run {
                self.delegate?.analyzerDidComplete(rootItem: root, duration: duration)
            }

        } catch {
            await MainActor.run {
                self.delegate?.analyzerDidFail(error: error.localizedDescription)
            }
        }
    }

    private func scanDirectory(item: StorageItem, itemsScanned: inout Int, totalSize: inout Int64, currentDepth: Int = 0, visitedPaths: inout Set<String>) async throws {
        // Check for cancellation
        if await control.shouldCancel() { return }

        // Handle pause
        await control.waitIfPaused()
        if await control.shouldCancel() { return }

        // Depth limit to prevent unbounded recursion
        guard currentDepth < options.maxDepth else {
            debugLog("Max recursion depth \(options.maxDepth) reached at \(item.url.path)")
            return
        }

        guard item.isDirectory else {
            // File - just count it
            itemsScanned += 1
            totalSize += item.totalSize
            await reportProgress(path: item.url.path, itemsScanned: itemsScanned, totalSize: totalSize)
            return
        }

        // Cycle detection using canonical paths
        let canonicalPath = item.url.standardizedFileURL.path
        guard !visitedPaths.contains(canonicalPath) else {
            debugLog("Cycle detected at \(canonicalPath), skipping")
            return
        }
        visitedPaths.insert(canonicalPath)

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

        while let fileURL = enumerator.nextObject() as? URL {
            // Check for cancellation
            if await control.shouldCancel() { return }

            // Handle pause
            await control.waitIfPaused()
            if await control.shouldCancel() { return }

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

                // Recurse if directory (with depth check and cycle detection)
                if childStorageItem.isDirectory {
                    try await scanDirectory(item: childStorageItem, itemsScanned: &itemsScanned, totalSize: &totalSize, currentDepth: currentDepth + 1, visitedPaths: &visitedPaths)
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
                if itemsScanned % AppConfig.Storage.progressBatchSize == 0 {
                    await reportProgress(path: fileURL.path, itemsScanned: itemsScanned, totalSize: totalSize)
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

    private func reportProgress(path: String, itemsScanned: Int, totalSize: Int64) async {
        await MainActor.run {
            self.delegate?.analyzerDidProgress(
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
