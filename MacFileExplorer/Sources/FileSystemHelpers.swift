import Foundation

struct FileID: Hashable {
    let dev: UInt64
    let ino: UInt64
}

enum FileSystemError: Error {
    case statFailed(String)
}

func fileID(for path: String) throws -> FileID {
    var statbuf = stat()
    if stat(path, &statbuf) == 0 {
        return FileID(dev: UInt64(statbuf.st_dev), ino: UInt64(statbuf.st_ino))
    } else {
        throw FileSystemError.statFailed(path)
    }
}

/// Resolve symlink chain safely with depth and cycle detection.
/// Returns the resolved path or nil if resolution fails or cycle detected.
func resolveSymlinkSafe(startingAt path: String, maxDepth: Int = 10) -> String? {
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
                continue
            } else {
                // Not a symlink, done
                return current
            }
        } catch {
            return nil
        }
    }

    // Exceeded max depth
    return nil
}

/// Returns true if `ancestorPath` is an ancestor directory of `descendantPath` by comparing
/// file IDs up the parent chain. This is more robust than string path comparison and resists
/// symlink/.. trickery.
func isAncestorByFileID(ancestorPath: String, descendantPath: String) -> Bool {
    let fm = FileManager.default
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

