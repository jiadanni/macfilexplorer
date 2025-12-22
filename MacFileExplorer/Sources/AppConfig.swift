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
