//
//  StorageAnalyzerEngine.swift
//  MacFileExplorer
//
//  Background scanning engine for disk storage analysis
//

import Foundation

/// Delegate protocol for storage analyzer progress updates
@MainActor
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

    /// Results are large trees; keep only the few most recent scans.
    private static let maxEntries = 4

    func store(item: StorageItem, for url: URL) {
        cache[url] = (item, Date())
        while cache.count > Self.maxEntries,
              let oldest = cache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key {
            cache.removeValue(forKey: oldest)
        }
    }

    func clear() {
        cache.removeAll()
    }

    func invalidate(for url: URL) {
        cache.removeValue(forKey: url)
    }
}

private actor ScanControl {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var isPaused = false

    func reset() {
        isPaused = false
        resumeAll()
    }

    func pause() {
        isPaused = true
    }

    func resume() {
        isPaused = false
        resumeAll()
    }

    func cancel() {
        isPaused = false
        resumeAll()
    }

    /// Suspends only while paused. Because the paused state lives here, a `resume()` or
    /// `cancel()` that runs before the scanner reaches `wait()` can no longer be lost.
    func wait() async {
        guard isPaused else { return }
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

    @Atomic private var isCancelled = false
    @Atomic private var isPaused = false
    /// Identifies the current scan. A new scan (or cancel) bumps it, which stops any older
    /// scan still running, instead of sharing one resettable flag between them.
    @Atomic private var scanGeneration = 0
    @Atomic private var lastProgressTime: CFAbsoluteTime = 0

    /// Mount points that are never descended into unless the scan root is inside them:
    /// firmlink duplicates, other/network volumes and device nodes.
    private static let excludedMountPoints = ["/dev", "/System/Volumes", "/Volumes", "/Network", "/private/var/vm", "/.Spotlight-V100", "/.fseventsd"]

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

        // Supersede any running scan synchronously, before the new task exists.
        let generation = $scanGeneration.update { value -> Int in
            value += 1
            return value
        }
        isCancelled = false
        isPaused = false

        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.control.reset()

            // Check cache first
            if let cached = await Self.cachedResult(for: url),
               Date().timeIntervalSince(cached.timestamp) < Self.cacheValidityDuration {
                guard !self.isStale(generation) else { return }
                await MainActor.run {
                    self.delegate?.analyzerDidComplete(rootItem: cached.item, duration: 0)
                }
                return
            }

            await self.performScan(url: url, generation: generation)
        }
    }

    /// True once this scan was cancelled or replaced by a newer one.
    private func isStale(_ generation: Int) -> Bool {
        isCancelled || scanGeneration != generation
    }

    /// Cancels the current scan
    func cancel() {
        isCancelled = true
        $scanGeneration.update { $0 += 1 }
        scanTask?.cancel()
        Task { await control.cancel() }
    }

    /// Pauses the current scan
    func pause() {
        isPaused = true
        Task { await control.pause() }
    }

    /// Resumes a paused scan
    func resume() {
        isPaused = false
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

    private func performScan(url: URL, generation: Int) async {
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
            try await scanDirectory(item: root, itemsScanned: &itemsScanned, totalSize: &totalSize, currentDepth: 0, visitedPaths: &visitedPaths, generation: generation)

            // Superseded by a newer scan: that scan owns the delegate now.
            if scanGeneration != generation { return }

            // Check if cancelled
            if isCancelled {
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

    private func scanDirectory(item: StorageItem, itemsScanned: inout Int, totalSize: inout Int64, currentDepth: Int = 0, visitedPaths: inout Set<String>, generation: Int) async throws {
        // Check for cancellation
        if isStale(generation) { return }

        // Handle pause
        if isPaused {
            await control.wait()
        }
        if isStale(generation) { return }

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

        // Don't wander into firmlink duplicates, other volumes or device nodes unless the
        // user explicitly chose a root inside them.
        let canonicalPath = item.url.standardizedFileURL.path
        let rootPath = rootURL?.standardizedFileURL.path ?? ""
        if Self.excludedMountPoints.contains(canonicalPath), !rootPath.hasPrefix(canonicalPath) {
            return
        }

        // Cycle detection by file identity (device + inode): symlink and bind-mount loops
        // present as ever-new paths, so comparing path strings cannot catch them.
        let visitKey: String
        if let identity = FileSystemHelpers.fileID(for: item.url) {
            visitKey = "\(identity.dev):\(identity.ino)"
        } else {
            visitKey = canonicalPath
        }
        guard !visitedPaths.contains(visitKey) else {
            debugLog("Cycle detected at \(canonicalPath), skipping")
            return
        }
        visitedPaths.insert(visitKey)

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
            if isStale(generation) { return }

            // Handle pause
            if isPaused {
                await control.wait()
            }
            if isStale(generation) { return }

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
                    try await scanDirectory(item: childStorageItem, itemsScanned: &itemsScanned, totalSize: &totalSize, currentDepth: currentDepth + 1, visitedPaths: &visitedPaths, generation: generation)
                } else {
                    itemsScanned += 1
                    totalSize += childStorageItem.totalSize
                }

                // Skip if below minimum size threshold
                if childStorageItem.totalSize < options.minimumSize {
                    continue
                }

                childItems.append(childStorageItem)

                // Report progress at most every 100 ms (a count-based check re-fired for
                // every directory entry while the file count sat on a multiple of 100).
                if shouldReportProgress() {
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

    private func shouldReportProgress() -> Bool {
        let now = CFAbsoluteTimeGetCurrent()
        return $lastProgressTime.update { last -> Bool in
            guard now - last >= 0.1 else { return false }
            last = now
            return true
        }
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
