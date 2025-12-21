import Foundation

// MARK: - Settings Sidebar Delegate

protocol SettingsSidebarDelegate: AnyObject {
    func settingsSidebarDidSelectSection(_ section: SettingsSection)
}

// MARK: - Settings Change Delegate

protocol SettingsChangeDelegate: AnyObject {
    func settingsDidChange()
}

protocol SettingsApplyable: AnyObject {
    func applyChanges()
    func cancelChanges()
}

// MARK: - Settings Sections Enum

enum SettingsSection: String, CaseIterable {
    case general = "General"
    case appearance = "Appearance"
    case tabs = "Tabs"
    case toolbar = "Toolbar"
    case storage = "Storage"
    case fileOperations = "File Operations"
    case goMenu = "Go Menu"
    case terminal = "Terminal"
    case permissions = "Permissions"
    case advanced = "Advanced"
    case sidebar = "Sidebar"
    case contextMenu = "Context Menu"
}

