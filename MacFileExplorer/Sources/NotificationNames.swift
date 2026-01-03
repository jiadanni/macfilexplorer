import Foundation

extension Notification.Name {
    static let previewPaneToggled = Notification.Name("previewPaneToggled")
    static let hiddenFilesToggled = Notification.Name("hiddenFilesToggled")
    static let globalFolderColorDidChangeNotification = Notification.Name("globalFolderColorDidChangeNotification")
    static let accentColorDidChangeNotification = Notification.Name("accentColorDidChangeNotification")
    static let showFileExtensionsDidChangeNotification = Notification.Name("showFileExtensionsDidChangeNotification")
    static let easySelectDidChangeNotification = Notification.Name("easySelectDidChangeNotification")
    static let toolbarSettingsDidChangeNotification = Notification.Name("toolbarSettingsDidChangeNotification")
    static let pendingSettingsDidChange = Notification.Name("pendingSettingsDidChange")
    static let didChangeWindowControlAppearance = Notification.Name("didChangeWindowControlAppearance")
    static let zoomDidChangeNotification = Notification.Name("zoomDidChangeNotification")
    static let tabDidChangeNotification = Notification.Name("tabDidChangeNotification")
}

import Cocoa
