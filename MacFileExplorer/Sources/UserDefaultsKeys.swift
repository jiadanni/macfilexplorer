import Foundation

extension UserDefaults {
    struct Keys: CaseIterable {
        static var allCases: [UserDefaults.Keys] {
            return [
                .hideOpenWith, .hideGetInfo, .hideCopy, .hideCut, .hidePaste, .hideRename,
                .hideMoveToTrash, .hideNewFolder, .hideChangeFolderColor, .hideShowInFinder,
                .expandSidebarToCurrentDirectory, .showStatusBar
            ]
        }

        // General Settings
        static let hideOpenWith = "hideOpenWith"
        static let hideGetInfo = "hideGetInfo"
        static let hideCopy = "hideCopy"
        static let hideCut = "hideCut"
        static let hidePaste = "hidePaste"
        static let hideRename = "hideRename"
        static let hideMoveToTrash = "hideMoveToTrash"
        static let hideNewFolder = "hideNewFolder"
        static let hideChangeFolderColor = "hideChangeFolderColor"
        static let hideShowInFinder = "hideShowInFinder"

        // Sidebar Settings
        static let expandSidebarToCurrentDirectory = "expandSidebarToCurrentDirectory"

        // Status Bar Settings
        static let showStatusBar = "showStatusBar"
    }
}
