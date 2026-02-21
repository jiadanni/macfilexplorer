import Foundation

/// Protocol for permissions management to enable dependency injection and testing.
///
/// Implementations provide:
/// - Security-scoped bookmark creation and resolution
/// - Directory access permission tracking
/// - System permission status checking
///
/// **Thread Safety:** Implementations must be thread-safe.
protocol PermissionsManaging: AnyObject {
    
    // MARK: - Granted Directories
    
    /// Returns all currently granted directory URLs.
    func grantedDirectories() -> [URL]
    
    /// Adds a directory to the granted list.
    ///
    /// - Parameter url: The directory URL to grant access to.
    func addGrantedDirectory(_ url: URL)
    
    /// Removes a directory from the granted list.
    ///
    /// - Parameter url: The directory URL to revoke access from.
    func removeGrantedDirectory(_ url: URL)
    
    /// Checks if a directory is in the granted list.
    ///
    /// - Parameter url: The directory URL to check.
    /// - Returns: `true` if the directory is granted, `false` otherwise.
    func hasGrantedDirectory(_ url: URL) -> Bool
    
    // MARK: - Security Scoped Access
    
    /// Starts accessing all granted security-scoped URLs.
    /// Call during app startup to restore access to previously granted directories.
    func startAccessingAllSecurityScoped()
    
    /// Stops accessing all security-scoped URLs.
    /// Call during app termination to properly release resources.
    func stopAccessingAllSecurityScoped()
    
    /// Ensures access to a security-scoped URL if it lies under a granted directory.
    ///
    /// - Parameter url: The URL to ensure access for.
    /// - Returns: `true` if access is granted or the app is not sandboxed, `false` otherwise.
    @discardableResult
    func ensureAccess(for url: URL) -> Bool
    
    // MARK: - Bookmark Management
    
    /// Replaces a granted directory with a new one.
    ///
    /// - Parameters:
    ///   - oldURL: The URL to remove.
    ///   - newURL: The URL to add.
    func replaceGrantedDirectory(oldURL: URL, with newURL: URL)
    
    /// Refreshes a stale bookmark for a URL.
    ///
    /// - Parameter url: The URL whose bookmark should be refreshed.
    func refreshBookmarkIfStale(for url: URL)
    
    // MARK: - Migration
    
    /// Migrates legacy path-based storage to security-scoped bookmarks if needed.
    func migratePathsToBookmarksIfNeeded()
    
    // MARK: - System Permissions
    
    /// Checks the current status of a system permission.
    ///
    /// - Parameter type: The permission type to check.
    /// - Returns: The current permission status.
    func checkPermissionStatus(for type: PermissionType) -> PermissionStatus
    
    /// Opens System Preferences to the appropriate pane for the permission.
    ///
    /// - Parameter type: The permission type to configure.
    func openSystemPreferences(for type: PermissionType)
}

/// Default implementation bridge for the singleton.
/// Allows gradual migration from `PermissionsManager.shared` to injected protocol.
extension PermissionsManager: PermissionsManaging {}
