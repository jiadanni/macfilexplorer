import Foundation
@testable import MacFileExplorer

/// Mock implementation of PermissionsManaging for testing
class MockPermissionsManager: PermissionsManaging {
    var grantedDirectoriesURLs: [URL] = []
    var ensureAccessCalls: [URL] = []
    var isSandboxedValue: Bool = false
    var permissionStatuses: [PermissionType: PermissionStatus] = [:]
    
    func grantedDirectories() -> [URL] {
        return grantedDirectoriesURLs
    }
    
    func addGrantedDirectory(_ url: URL) {
        if !grantedDirectoriesURLs.contains(url) {
            grantedDirectoriesURLs.append(url)
        }
    }
    
    func removeGrantedDirectory(_ url: URL) {
        grantedDirectoriesURLs.removeAll { $0 == url }
    }
    
    func hasGrantedDirectory(_ url: URL) -> Bool {
        return grantedDirectoriesURLs.contains(url)
    }
    
    func resolvedGrantedDirectoryEntries() -> [PermissionsManager.ResolvedGrantedDirectoryEntry] {
        return grantedDirectoriesURLs.map {
            PermissionsManager.ResolvedGrantedDirectoryEntry(url: $0, path: $0.path, isStale: false, isValid: true)
        }
    }
    
    func startAccessingAllSecurityScoped() {
        // No-op for tests
    }
    
    func stopAccessingAllSecurityScoped() {
        // No-op for tests
    }
    
    @discardableResult
    func ensureAccess(for url: URL) -> Bool {
        ensureAccessCalls.append(url)
        // Return true if the URL is under any granted directory
        for granted in grantedDirectoriesURLs {
            if url.path.hasPrefix(granted.path) {
                return true
            }
        }
        return !isSandboxedValue || grantedDirectoriesURLs.isEmpty
    }
    
    func replaceGrantedDirectory(oldURL: URL, with newURL: URL) {
        removeGrantedDirectory(oldURL)
        addGrantedDirectory(newURL)
    }
    
    func refreshBookmarkIfStale(for url: URL) {
        // No-op for tests
    }
    
    func migratePathsToBookmarksIfNeeded() {
        // No-op for tests
    }
    
    func checkPermissionStatus(for type: PermissionType) -> PermissionStatus {
        return permissionStatuses[type] ?? .granted
    }
    
    func openSystemPreferences(for type: PermissionType) {
        // No-op for tests
    }
    
    func isSandboxed() -> Bool {
        return isSandboxedValue
    }
    
    func reset() {
        grantedDirectoriesURLs.removeAll()
        ensureAccessCalls.removeAll()
        isSandboxedValue = false
        permissionStatuses.removeAll()
    }
}
