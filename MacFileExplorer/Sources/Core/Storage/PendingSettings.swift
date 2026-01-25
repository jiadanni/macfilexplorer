import Foundation

// MARK: - Pending Settings Storage

final class PendingSettings {
    static let shared = PendingSettings()
    private var pendingChanges: [String: Any] = [:]
    private let settingsStore: SettingsStoreProtocol

    private init(settingsStore: SettingsStoreProtocol = SettingsStore.shared) {
        self.settingsStore = settingsStore
    }

    func setValue(_ value: Any?, forKey key: String) {
        pendingChanges[key] = value
        // Notify listeners that pending settings have changed so UI (Apply button) can enable
        // Use notification for UI-only state that doesn't affect settings persistence
        NotificationCenter.default.post(name: .pendingSettingsDidChange, object: nil)
    }

    func getValue(forKey key: String) -> Any? {
        pendingChanges[key]
    }

    func bool(forKey key: String) -> Bool {
        if let pending = pendingChanges[key] as? Bool {
            return pending
        }
        return settingsStore.value(forKey: key) as? Bool ?? false
    }

    func string(forKey key: String) -> String? {
        if let pending = pendingChanges[key] as? String {
            return pending
        }
        return settingsStore.value(forKey: key) as? String
    }

    func applyChanges() {
        let changedKeys = Set(pendingChanges.keys)

        for (key, value) in pendingChanges {
            settingsStore.setValue(value, forKey: key)
        }
        pendingChanges.removeAll()

        // Note: All settings-related notifications are now handled through the SettingsStore delegate pattern
        // SettingsStore automatically notifies delegates of changes. See SettingsStore.swift for delegation methods.
        // Legacy notifications are kept for backward compatibility but should be migrated to delegates.
        
        // For UI-critical settings that need immediate updates, SettingsStore delegates are preferred:
        // - showFileExtensions → settingsStore(_:showFileExtensionsDidChange:)
        // - enableEasySelect → settingsStore(_:easySelectDidChange:)
        // - accentColor → settingsStoreDidUpdateAccentColor(_:)
        // - windowControls → Consider adding delegate method for appearance changes
        // - folderColor → settingsStoreDidUpdateGlobalFolderColor(_:)
        // - toolbar settings → Consider adding delegate method or using ToolbarCoordinator
        
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
