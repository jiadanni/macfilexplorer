import Foundation

enum AppConfig {
    static let animationDuration: TimeInterval = 0.2

    enum Limits {
        static let maxSearchHistorySize = 50
        static let maxHistorySize = 100
        static let maxAutoRenameAttempts = 1000
    }

    enum Storage {
        static let maxRecursionDepth = 100
        static let progressBatchSize = 100
    }

    enum Search {
        /// How often the recursive enumerator checks for cancellation.
        static let cancellationCheckInterval = 256
        /// Directory names skipped during recursive search — huge, rarely searched trees.
        static let skippedDirectoryNames: Set<String> = [".git", "node_modules", ".build", "DerivedData", ".Trash"]
        /// Path fragments skipped during recursive search.
        static let skippedPathFragments = ["/Library/Caches/"]
    }

    enum ColumnID {
        static let name = "NameColumn"
        static let size = "SizeColumn"
        static let dateModified = "DateModifiedColumn"
        static let dateCreated = "DateCreatedColumn"
        static let type = "TypeColumn"
    }

    enum Pasteboard {
        static let cutMarkerType = "com.macfileexplorer.cutMarker"
    }

    enum Paths {
        static let volumes = "/Volumes"
        static let applications = "/Applications"
        static let system = "/System"
        static let library = "/Library"
        static let applicationSupport = "/Library/Application Support"
        static let rootCandidates = ["/System", "/Library", "/Users", "/private", "/bin", "/sbin", "/usr", "/var", "/tmp", "/cores", "/dev", "/etc"]
        static let systemPrefixes = ["/System/", "/Library/", "/usr/", "/var/"]
        static let cachePrefixes = ["/Library/Caches/", "/Library/Logs/"]
    }

    enum GoogleDrive {
        static let groupIdentifier = "group.com.google.drive.fs"
        static let legacyVolumePath = "/Volumes/GoogleDrive"
        static let volumeNames = ["GoogleDrive", "Google Drive"]
        static let myDriveComponent = "My Drive"
        
        /// Standard home directory Google Drive path (modern default)
        static var homeDirectoryPath: URL? {
            let home = FileManager.default.homeDirectoryForCurrentUser
            return home.appendingPathComponent("Google Drive")
        }
        
        /// All possible Google Drive root paths to check
        static var possibleRootPaths: [URL] {
            var paths: [URL] = []
            
            // Home directory path (modern default)
            if let homePath = homeDirectoryPath {
                paths.append(homePath)
            }
            
            // Legacy volume mounts
            paths.append(URL(fileURLWithPath: legacyVolumePath))
            paths.append(contentsOf: volumeNames.map { URL(fileURLWithPath: "/Volumes").appendingPathComponent($0) })
            
            return paths
        }
    }

    enum Keychain {
        static let service = "com.macfileexplorer"
        static let grantedDirectoryBookmarksKey = "grantedDirectoryBookmarks"
    }

    enum SettingsKeys {
        static let filterCriteria = "filterCriteria"
        static let searchHistory = "searchHistory"
    }
}
