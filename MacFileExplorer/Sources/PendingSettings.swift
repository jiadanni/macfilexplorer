import Foundation

// MARK: - Pending Settings Storage

final class PendingSettings {
    static let shared = PendingSettings()
    private var pendingChanges: [String: Any] = [:]

    private init() {}

    func setValue(_ value: Any?, forKey key: String) {
        pendingChanges[key] = value
        // Notify listeners that pending settings have changed so UI (Apply button) can enable
        NotificationCenter.default.post(name: .pendingSettingsDidChange, object: nil)
    }

    func getValue(forKey key: String) -> Any? {
        pendingChanges[key]
    }

    func bool(forKey key: String) -> Bool {
        if let pending = pendingChanges[key] as? Bool {
            return pending
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    func string(forKey key: String) -> String? {
        if let pending = pendingChanges[key] as? String {
            return pending
        }
        return UserDefaults.standard.string(forKey: key)
    }

    func applyChanges() {
        let changedKeys = Set(pendingChanges.keys)

        for (key, value) in pendingChanges {
            UserDefaults.standard.set(value, forKey: key)
        }
        pendingChanges.removeAll()

        // Post notifications for settings that need immediate UI updates
        if changedKeys.contains(UserDefaults.Keys.showFileExtensions.rawValue) {
            NotificationCenter.default.post(name: .showFileExtensionsDidChangeNotification, object: nil)
        }
        if changedKeys.contains(UserDefaults.Keys.enableEasySelect.rawValue) {
            NotificationCenter.default.post(name: .easySelectDidChangeNotification, object: nil)
        }
        if changedKeys.contains(UserDefaults.Keys.accentColor.rawValue) {
            NotificationCenter.default.post(name: .accentColorDidChangeNotification, object: nil)
        }
        if changedKeys.contains(UserDefaults.Keys.useGrayscaleWindowControls.rawValue) {
            NotificationCenter.default.post(name: .didChangeWindowControlAppearance, object: nil)
        }
        if changedKeys.contains(UserDefaults.Keys.globalFolderColor.rawValue) {
            NotificationCenter.default.post(name: .globalFolderColorDidChangeNotification, object: nil)
        }
        if changedKeys.intersection([
            UserDefaults.Keys.showBackForwardButtons.rawValue,
            UserDefaults.Keys.showViewModeButton.rawValue,
            UserDefaults.Keys.showHiddenFilesButton.rawValue,
            UserDefaults.Keys.showSplitButtons.rawValue,
            UserDefaults.Keys.showPreviewPaneButton.rawValue,
            UserDefaults.Keys.showNewFolderButton.rawValue,
            UserDefaults.Keys.showSortButton.rawValue,
        ]).isEmpty == false {
            NotificationCenter.default.post(name: .toolbarSettingsDidChangeNotification, object: nil)
        }
    }

    func cancelChanges() {
        pendingChanges.removeAll()
    }

    func hasChanges() -> Bool {
        !pendingChanges.isEmpty
    }
}

