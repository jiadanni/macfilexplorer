import Foundation

enum URLValidationError: Error {
    case pathTraversal
    case outOfScope
    case invalidURL
}

struct URLValidation {
    /// Resolve symlinks, prevent basic path traversal (../), and check sandbox permissions via PermissionsManager.
    /// Returns a resolved, safe URL or throws on validation failure.
    static func validateUserBrowsingURL(_ url: URL) throws -> URL {
        // Ensure the URL is file URL
        guard url.isFileURL else { throw URLValidationError.invalidURL }

        // Resolve symlinks
        let resolved = url.resolvingSymlinksInPath()

        // Basic path traversal check
        let path = resolved.path
        if path.contains("/../") || path.hasPrefix("..") {
            throw URLValidationError.pathTraversal
        }

        // If sandboxed, ensure PermissionsManager has access (if available)
        let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        if isSandboxed {
            guard PermissionsManager.shared.hasGrantedDirectory(resolved) else {
                throw URLValidationError.outOfScope
            }
        }

        return resolved
    }
}
