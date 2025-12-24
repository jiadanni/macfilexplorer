import Foundation

/**
 * FileSystemHelpers provides secure file operations and identity validation
 * to prevent TOCTOU (Time of Check Time of Use) attacks and other security vulnerabilities.
 */

/**
 * FileID represents a unique file identity using device and inode numbers.
 * This provides strong identity validation that survives file moves but detects replacements.
 *
 * Platform and Filesystem Behavior:
 * 
 * Local Filesystems (APFS, HFS+):
 * - FileID remains stable across file moves within the same volume
 * - FileID changes when file is replaced (atomic write creates new inode)
 * - Reliable for TOCTOU protection on local storage
 * 
 * Network Filesystems (NFS, SMB):
 * - Device numbers may not be meaningful across network mounts
 * - Inode behavior varies by server implementation
 * - Some NFS servers reuse inodes, reducing reliability
 * - FileID validation may produce false positives/negatives
 * - Recommended to combine with additional validation (mtime, size) for critical operations
 *
 * Virtual Filesystems (FUSE, tmpfs):
 * - Behavior depends on FUSE implementation
 * - tmpfs generally provides stable inodes within session
 * - Some FUSE filesystems may not implement stable inodes
 * 
 * Mounted Volumes:
 * - Cross-volume moves change device ID, breaking FileID validation
 * - This is intentional behavior for security (prevents cross-volume TOCTOU)
 * - Applications should handle cross-volume operations separately
 *
 * Best Practices:
 * - Use FileID for same-volume identity validation
 * - For network filesystems, consider additional validation
 * - Always handle FileID validation failures gracefully
 * - Log FileID mismatches for security monitoring
 */
struct FileID: Hashable {
    let dev: UInt64
    let ino: UInt64
}

enum FileSystemError: Error {
    case statFailed(String)
    case invalidPath
    case permissionDenied
}

/// FileSystemHelpers provides secure file system operations with identity validation
/// and protection against TOCTOU attacks, symlink traversal, and other security vulnerabilities.
class FileSystemHelpers {
    
    // MARK: - File Identity Operations
    
    /// Get unique file identity using device and inode numbers.
    /// 
    /// - Parameter url: File URL to get identity for
    /// - Returns: FileID if successful, nil otherwise
    /// - Note: See FileID documentation for filesystem-specific behavior
    static func fileID(for url: URL) -> FileID? {
        return try? fileID(for: url.path)
    }
    
    /// Get unique file identity using device and inode numbers.
    /// 
    /// - Parameter path: File path to get identity for
    /// - Returns: FileID if successful
    /// - Throws: FileSystemError.statFailed if stat() fails
    /// - Note: See FileID documentation for filesystem-specific behavior
    static func fileID(for path: String) throws -> FileID {
        var statbuf = stat()
        if stat(path, &statbuf) == 0 {
            return FileID(dev: UInt64(statbuf.st_dev), ino: UInt64(statbuf.st_ino))
        } else {
            throw FileSystemError.statFailed(path)
        }
    }
    
    /// Validate that a file still has the expected FileID to detect TOCTOU attacks.
    /// 
    /// - Parameters:
    ///   - expectedID: The FileID that was previously captured
    ///   - url: File URL to validate
    /// - Returns: true if file identity matches, false otherwise
    /// - Note: Returns false for any error (file not found, permission denied, etc.)
    static func validateFileID(_ expectedID: FileID, for url: URL) -> Bool {
        return validateFileID(expectedID, for: url.path)
    }
    
    /// Validate that a file still has the expected FileID to detect TOCTOU attacks.
    /// 
    /// - Parameters:
    ///   - expectedID: The FileID that was previously captured  
    ///   - path: File path to validate
    /// - Returns: true if file identity matches, false otherwise
    /// - Note: Returns false for any error (file not found, permission denied, etc.)
    static func validateFileID(_ expectedID: FileID, for path: String) -> Bool {
        guard let currentID = try? fileID(for: path) else { return false }
        return currentID == expectedID
    }
    
    // MARK: - Symlink Operations
    
    /// Resolve symlink chain safely with depth and cycle detection.
    /// 
    /// - Parameter url: Starting URL that may be a symlink
    /// - Returns: Resolved URL or nil if resolution fails or cycle detected
    /// - Note: Limited to 10 levels of symlink traversal to prevent infinite loops
    static func resolveSymlinkSafe(at url: URL) -> URL? {
        guard let resolvedPath = resolveSymlinkSafe(at: url.path) else { return nil }
        return URL(fileURLWithPath: resolvedPath)
    }
    
    /// Resolve symlink chain safely with depth and cycle detection.
    /// 
    /// - Parameters:
    ///   - path: Starting path that may be a symlink
    ///   - maxDepth: Maximum symlink traversal depth (default: 10)
    /// - Returns: Resolved path or nil if resolution fails or cycle detected
    /// - Note: Uses FileID to detect cycles, preventing infinite loops
    static func resolveSymlinkSafe(at path: String, maxDepth: Int = 10) -> String? {
        var current = path
        var visited = Set<FileID>()

        for _ in 0..<maxDepth {
            do {
                let fid = try fileID(for: current)
                if visited.contains(fid) {
                    // Cycle detected
                    return nil
                }
                visited.insert(fid)
            } catch {
                return nil
            }

            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: current)
                if let fileType = attrs[.type] as? FileAttributeType, fileType == .typeSymbolicLink {
                    // read symlink destination
                    let dst = try FileManager.default.destinationOfSymbolicLink(atPath: current)
                    let next: String
                    if dst.hasPrefix("/") {
                        next = dst
                    } else {
                        let parent = (current as NSString).deletingLastPathComponent
                        next = URL(fileURLWithPath: parent).appendingPathComponent(dst).standardized.path
                    }
                    current = next
                } else {
                    // Not a symlink, resolved
                    return current
                }
            } catch {
                return nil
            }
        }

        // Exceeded max depth
        return nil
    }
    
    // MARK: - Path Security Operations
    
    /// Check if ancestor path contains descendant path using FileID comparison.
    /// This is more secure than string-based path comparison and resists symlink attacks.
    /// 
    /// - Parameters:
    ///   - ancestorURL: Potential ancestor directory URL
    ///   - descendantURL: Potential descendant file/directory URL  
    /// - Returns: true if ancestor contains descendant, false otherwise
    /// - Note: Traverses up the directory tree using FileID comparison
    static func isAncestorByFileID(ancestor ancestorURL: URL, descendant descendantURL: URL) -> Bool {
        return isAncestorByFileID(ancestorPath: ancestorURL.path, descendantPath: descendantURL.path)
    }
    
    /// Check if ancestor path contains descendant path using FileID comparison.
    /// This is more secure than string-based path comparison and resists symlink attacks.
    /// 
    /// - Parameters:
    ///   - ancestorPath: Potential ancestor directory path
    ///   - descendantPath: Potential descendant file/directory path
    /// - Returns: true if ancestor contains descendant, false otherwise  
    /// - Note: Traverses up the directory tree using FileID comparison, limited to 1000 levels
    static func isAncestorByFileID(ancestorPath: String, descendantPath: String) -> Bool {
        let ancestorCanon = URL(fileURLWithPath: ancestorPath).standardized.path
        var current = URL(fileURLWithPath: descendantPath).standardized

        guard let ancestorFID = try? fileID(for: ancestorCanon) else { return false }

        var depth = 0
        while true {
            let currentPath = current.path
            if currentPath == ancestorCanon { return true }

            // Stop at root
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent

            // Limit walking depth to avoid pathological loops
            depth += 1
            if depth > 1000 { break }

            if let fid = try? fileID(for: current.path), fid == ancestorFID {
                return true
            }
        }

        return false
    }
    
    // MARK: - Secure File Operations
    
    /// Safely open a file with O_NOFOLLOW to prevent symlink attacks.
    /// Returns file descriptor and FileID for subsequent validation.
    /// 
    /// - Parameter path: File path to open
    /// - Returns: Tuple of (file descriptor, FileID) or nil if failed
    /// - Note: Caller is responsible for closing the file descriptor
    /// - Warning: File descriptor must be closed to prevent resource leaks
    static func openSafeNoFollow(path: String) -> (fd: Int32, fileID: FileID)? {
        let fd = open(path, O_RDONLY | O_NOFOLLOW)
        if fd < 0 { return nil }
        
        var statbuf = stat()
        if fstat(fd, &statbuf) != 0 {
            close(fd)
            return nil
        }
        
        let fid = FileID(dev: UInt64(statbuf.st_dev), ino: UInt64(statbuf.st_ino))
        return (fd: fd, fileID: fid)
    }
}

// MARK: - Legacy function wrappers for backwards compatibility

func fileID(for path: String) throws -> FileID {
    return try FileSystemHelpers.fileID(for: path)
}

/// Resolve symlink chain safely with depth and cycle detection.
/// Returns the resolved path or nil if resolution fails or cycle detected.
func resolveSymlinkSafe(startingAt path: String, maxDepth: Int = 10) -> String? {
    return FileSystemHelpers.resolveSymlinkSafe(at: path, maxDepth: maxDepth)
}

/// Returns true if `ancestorPath` is an ancestor directory of `descendantPath` by comparing
/// file IDs up the parent chain. This is more robust than string path comparison and resists
/// symlink/.. trickery.
func isAncestorByFileID(ancestorPath: String, descendantPath: String) -> Bool {
    return FileSystemHelpers.isAncestorByFileID(ancestorPath: ancestorPath, descendantPath: descendantPath)
}

/// Safely open a file with O_NOFOLLOW and return file descriptor and FileID.
/// Returns nil if file doesn't exist, is a symlink when O_NOFOLLOW is used, or other error.
func openSafeNoFollow(path: String) -> (fd: Int32, fileID: FileID)? {
    return FileSystemHelpers.openSafeNoFollow(path: path)
}

/// Validate that a file still has the expected FileID (no TOCTOU race).
func validateFileID(path: String, expectedID: FileID) -> Bool {
    return FileSystemHelpers.validateFileID(expectedID, for: path)
}

