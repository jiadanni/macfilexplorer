import Cocoa
import Photos
import AVFoundation

enum PermissionType: String, CaseIterable {
    case fullDiskAccess = "Full Disk Access"
    case photos = "Photos"
    case camera = "Camera"
    case microphone = "Microphone"

    var icon: String {
        switch self {
        case .fullDiskAccess:
            return "internaldrive"
        case .photos:
            return "photo"
        case .camera:
            return "camera"
        case .microphone:
            return "mic"
        }
    }

    var description: String {
        switch self {
        case .fullDiskAccess:
            return "Access to all files on your Mac"
        case .photos:
            return "Access to your Photos library"
        case .camera:
            return "Access to your camera"
        case .microphone:
            return "Access to your microphone"
        }
    }
}

enum PermissionStatus {
    case granted
    case denied
    case notDetermined
    case notApplicable

    var displayText: String {
        switch self {
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Requested"
        case .notApplicable:
            return "N/A"
        }
    }

    var color: NSColor {
        switch self {
        case .granted:
            return NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        case .denied:
            return NSColor(red: 1.0, green: 0.27, blue: 0.23, alpha: 1.0)
        case .notDetermined:
            return NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)
        case .notApplicable:
            return .secondaryLabelColor
        }
    }
}

class PermissionsManager {
    static let shared = PermissionsManager()

    private init() {}

    // MARK: - Granted Directories Storage
    private let grantedDirectoriesKey = UserDefaults.Keys.grantedDirectoriesPaths.rawValue
    private let grantedDirectoryBookmarksKey = UserDefaults.Keys.grantedDirectoryBookmarks.rawValue
    private let migrationFlagKey = UserDefaults.Keys.grantedDirectoryBookmarksMigrated.rawValue
    private var activeSecurityScopedURLs: Set<URL> = []

    struct ResolvedGrantedDirectoryEntry {
        let url: URL?
        let path: String
        let isStale: Bool
        let isValid: Bool
    }

    // MARK: Migration
    func migratePathsToBookmarksIfNeeded() {
        // Only meaningful in sandboxed context; skip otherwise
        guard isSandboxed() else { return }
        let migrated = UserDefaults.standard.bool(forKey: migrationFlagKey)
        guard !migrated else { return }
        guard let paths = UserDefaults.standard.array(forKey: grantedDirectoriesKey) as? [String], !paths.isEmpty else {
            UserDefaults.standard.set(true, forKey: migrationFlagKey)
            return
        }
        var bookmarkDatas: [Data] = []
        for path in paths {
            let url = URL(fileURLWithPath: path)
            do {
                let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                bookmarkDatas.append(data)
            } catch {
                NSLog("[PermissionsManager] Failed to create bookmark for migration: \(path) error: \(error)")
            }
        }
        if !bookmarkDatas.isEmpty {
            UserDefaults.standard.set(bookmarkDatas, forKey: grantedDirectoryBookmarksKey)
        }
        UserDefaults.standard.set(true, forKey: migrationFlagKey)
    }

    func grantedDirectories() -> [URL] {
        // Prefer bookmarks if present
        if isSandboxed() {
            if let datas = UserDefaults.standard.array(forKey: grantedDirectoryBookmarksKey) as? [Data], !datas.isEmpty {
                return datas.compactMap { resolveBookmarkData($0).url }
            }
        }
        guard let paths = UserDefaults.standard.array(forKey: grantedDirectoriesKey) as? [String] else { return [] }
        return paths.compactMap { URL(fileURLWithPath: $0) }
    }

    func addGrantedDirectory(_ url: URL) {
        debugLog("[PermissionsManager] Adding granted directory: \(url.path)")
        debugLog("[PermissionsManager] Is sandboxed: \(isSandboxed())")
        
        // In non-sandboxed builds we only store path strings.
        guard isSandboxed() else {
            var existing = UserDefaults.standard.array(forKey: grantedDirectoriesKey) as? [String] ?? []
            debugLog("[PermissionsManager] Existing paths: \(existing)")
            if !existing.contains(url.path) {
                existing.append(url.path)
                UserDefaults.standard.set(existing, forKey: grantedDirectoriesKey)
                debugLog("[PermissionsManager] Added path: \(url.path)")
                debugLog("[PermissionsManager] Updated paths: \(existing)")
            } else {
                debugLog("[PermissionsManager] Path already exists: \(url.path)")
            }
            return
        }
        do {
            let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            var existingDatas = UserDefaults.standard.array(forKey: grantedDirectoryBookmarksKey) as? [Data] ?? []
            if !existingDatas.contains(where: { resolveBookmarkData($0).path == url.path }) {
                existingDatas.append(data)
                UserDefaults.standard.set(existingDatas, forKey: grantedDirectoryBookmarksKey)
            }
            // Immediately begin accessing so the user isn't prompted again in this session.
            var stale = false
            if let resolvedURL = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale),
               resolvedURL.startAccessingSecurityScopedResource() {
                activeSecurityScopedURLs.insert(resolvedURL)
            }
        } catch {
            NSLog("[PermissionsManager] Bookmark creation failed in sandbox for \(url.path): \(error)")
        }
    }

    func removeGrantedDirectory(_ url: URL) {
        if var datas = UserDefaults.standard.array(forKey: grantedDirectoryBookmarksKey) as? [Data], !datas.isEmpty {
            datas.removeAll { resolveBookmarkData($0).path == url.path }
            UserDefaults.standard.set(datas, forKey: grantedDirectoryBookmarksKey)
        }
        if activeSecurityScopedURLs.contains(url) {
            url.stopAccessingSecurityScopedResource()
            activeSecurityScopedURLs.remove(url)
        }
        var existing = UserDefaults.standard.array(forKey: grantedDirectoriesKey) as? [String] ?? []
        existing.removeAll { $0 == url.path }
        UserDefaults.standard.set(existing, forKey: grantedDirectoriesKey)
    }

    func hasGrantedDirectory(_ url: URL) -> Bool {
        if isSandboxed() {
            if let datas = UserDefaults.standard.array(forKey: grantedDirectoryBookmarksKey) as? [Data], !datas.isEmpty {
                return datas.contains { resolveBookmarkData($0).path == url.path }
            }
        }
        let existing = UserDefaults.standard.array(forKey: grantedDirectoriesKey) as? [String] ?? []
        return existing.contains(url.path)
    }

    // MARK: - Bookmark Resolution
    private func resolveBookmarkData(_ data: Data) -> ResolvedGrantedDirectoryEntry {
        var stale = false
        do {
            let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
            let exists = FileManager.default.fileExists(atPath: url.path)
            return ResolvedGrantedDirectoryEntry(url: url, path: url.path, isStale: stale, isValid: exists)
        } catch {
            return ResolvedGrantedDirectoryEntry(url: nil, path: "<unresolved>", isStale: false, isValid: false)
        }
    }

    func resolvedGrantedDirectoryEntries() -> [ResolvedGrantedDirectoryEntry] {
        debugLog("[PermissionsManager] resolvedGrantedDirectoryEntries called")
        debugLog("[PermissionsManager] Is sandboxed: \(isSandboxed())")
        
        if isSandboxed() {
            if let datas = UserDefaults.standard.array(forKey: grantedDirectoryBookmarksKey) as? [Data] {
                debugLog("[PermissionsManager] Found \(datas.count) bookmarks")
                return datas.map { resolveBookmarkData($0) }
            }
        }
        // Fallback to paths
        let urls = grantedDirectories()
        debugLog("[PermissionsManager] Found \(urls.count) granted directories (from paths)")
        let entries = urls.map { ResolvedGrantedDirectoryEntry(url: $0, path: $0.path, isStale: false, isValid: FileManager.default.fileExists(atPath: $0.path)) }
        debugLog("[PermissionsManager] Returning \(entries.count) entries")
        for entry in entries {
            debugLog("[PermissionsManager]   - \(entry.path) (valid: \(entry.isValid))")
        }
        return entries
    }

    // MARK: - Security Scoped Lifecycle
    func startAccessingAllSecurityScoped() {
        guard isSandboxed() else { return }
        for entry in resolvedGrantedDirectoryEntries() {
            if let url = entry.url, entry.isValid, !activeSecurityScopedURLs.contains(url) {
                if url.startAccessingSecurityScopedResource() {
                    activeSecurityScopedURLs.insert(url)
                }
            }
        }
    }

    func stopAccessingAllSecurityScoped() {
        for url in activeSecurityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        activeSecurityScopedURLs.removeAll()
    }

    /// Ensure an accessible security-scoped URL for the given path if it lies under a granted directory.
    @discardableResult
    func ensureAccess(for url: URL) -> Bool {
        guard isSandboxed() else { return true }
        let path = url.path
        for entry in resolvedGrantedDirectoryEntries() {
            guard let grantedURL = entry.url, entry.isValid else { continue }
            if path == grantedURL.path || path.hasPrefix(grantedURL.path + "/") {
                if !activeSecurityScopedURLs.contains(grantedURL) && grantedURL.startAccessingSecurityScopedResource() {
                    activeSecurityScopedURLs.insert(grantedURL)
                }
                return true
            }
        }
        return false
    }

    // MARK: - Refresh / Replace
    func replaceGrantedDirectory(oldURL: URL, with newURL: URL) {
        removeGrantedDirectory(oldURL)
        addGrantedDirectory(newURL)
    }

    func refreshBookmarkIfStale(for url: URL) {
        guard isSandboxed() else { return }
        guard let datas = UserDefaults.standard.array(forKey: grantedDirectoryBookmarksKey) as? [Data] else { return }
        var updated: [Data] = []
        for data in datas {
            let entry = resolveBookmarkData(data)
            if entry.path == url.path {
                if entry.isStale {
                    do {
                        let newData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                        updated.append(newData)
                        continue
                    } catch {
                        NSLog("[PermissionsManager] Failed to refresh stale bookmark for \(url.path): \(error)")
                    }
                }
            }
            updated.append(data)
        }
        UserDefaults.standard.set(updated, forKey: grantedDirectoryBookmarksKey)
    }

    func checkPermissionStatus(for type: PermissionType) -> PermissionStatus {
        switch type {
        case .fullDiskAccess:
            return checkFullDiskAccess()
        case .photos:
            return checkPhotosAccess()
        case .camera:
            return checkCameraAccess()
        case .microphone:
            return checkMicrophoneAccess()
        }
    }

    private func checkFullDiskAccess() -> PermissionStatus {
        // A reliable way to check for Full Disk Access is to try to access a protected folder's contents.
        // We use the user's Documents directory for this check.
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // This is unlikely to fail, but if it does, we can't determine the status.
            return .notDetermined
        }

        do {
            // Attempt to list the contents of the Documents directory.
            // If this succeeds, we have the necessary permissions.
            _ = try FileManager.default.contentsOfDirectory(atPath: documentsURL.path)
            return .granted
        } catch {
            // If an error occurs, it's very likely due to lack of permissions, so we can infer a 'denied' state.
            return .denied
        }
    }

    private func checkPhotosAccess() -> PermissionStatus {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized, .limited:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notApplicable
        }
    }

    private func checkCameraAccess() -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notApplicable
        }
    }

    private func checkMicrophoneAccess() -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notApplicable
        }
    }



    func openSystemPreferences(for type: PermissionType) {
        var urlString = "x-apple.systempreferences:com.apple.preference.security?"

        switch type {
        case .fullDiskAccess:
            urlString += "Privacy_AllFiles"
        case .photos:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos"
        case .camera:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Environment
    private func isSandboxed() -> Bool {
        return ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }
}
