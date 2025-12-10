import Foundation

/// Centralized access to user-facing settings so state is not scattered across controllers.
final class SettingsStore {
    static let shared = SettingsStore()

    enum Key: String {
        case showHiddenFiles
        case showFileExtensions
        case useGrayscaleIcons
        case previewPaneVisible
        case defaultViewMode
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var showHiddenFiles: Bool {
        get { defaults.bool(forKey: Key.showHiddenFiles.rawValue) }
        set { defaults.set(newValue, forKey: Key.showHiddenFiles.rawValue) }
    }

    var showFileExtensions: Bool {
        get { defaults.object(forKey: Key.showFileExtensions.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.showFileExtensions.rawValue) }
    }

    var useGrayscaleIcons: Bool {
        get { defaults.bool(forKey: Key.useGrayscaleIcons.rawValue) }
        set { defaults.set(newValue, forKey: Key.useGrayscaleIcons.rawValue) }
    }

    var previewPaneVisible: Bool {
        get { defaults.bool(forKey: Key.previewPaneVisible.rawValue) }
        set { defaults.set(newValue, forKey: Key.previewPaneVisible.rawValue) }
    }

    var defaultViewMode: ViewMode {
        get {
            if let raw = defaults.string(forKey: Key.defaultViewMode.rawValue),
               let mode = ViewMode(rawValue: raw) {
                return mode
            }
            return .list
        }
        set { defaults.set(newValue.rawValue, forKey: Key.defaultViewMode.rawValue) }
    }
}
