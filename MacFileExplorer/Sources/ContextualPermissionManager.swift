//
//  ContextualPermissionManager.swift
//  MacFileExplorer
//
//  Permission UX helper with contextual explanations
//

import Cocoa

class ContextualPermissionManager {

    static let shared = ContextualPermissionManager()

    private init() {}

    /// Request access to a specific folder with contextual explanation
    func requestFolderAccess(folder: URL, reason: String, completion: @escaping (Bool) -> Void) {
        // Show explanation alert
        let alert = NSAlert()
        alert.messageText = "Access \(folder.lastPathComponent) Folder"
        alert.informativeText = "\(reason)\n\nFounder does not access your files without your direct instruction."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Grant Access")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            // Open folder selection dialog
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.directoryURL = folder
            panel.prompt = "Grant Access"
            panel.message = "Select \(folder.lastPathComponent) to grant access"

            panel.begin { response in
                if response == .OK, let selectedURL = panel.url {
                    // Store security-scoped bookmark
                    PermissionsManager.shared.addGrantedDirectory(selectedURL)
                    completion(true)
                } else {
                    completion(false)
                }
            }
        } else {
            completion(false)
        }
    }

    /// Request custom folder with explanation
    func requestCustomFolder(completion: @escaping (URL?) -> Void) {
        // Show explanation
        let alert = NSAlert()
        alert.messageText = "Add a Favorite Folder"
        alert.informativeText = "To monitor and quickly open this favorite folder, Founder needs permission to access it."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            // Open folder selection
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Add Favorite"

            panel.begin { response in
                if response == .OK, let selectedURL = panel.url {
                    PermissionsManager.shared.addGrantedDirectory(selectedURL)
                    completion(selectedURL)
                } else {
                    completion(nil)
                }
            }
        } else {
            completion(nil)
        }
    }

    /// Show guide for Full Disk Access
    func showFullDiskAccessGuide(completion: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "Full Disk Access Required"
        alert.informativeText = """
        To enable advanced features like Storage Analyzer, you need to grant Full Disk Access.

        Steps:
        1. Click "Open System Preferences"
        2. Find "Founder" in the list
        3. Toggle the switch to ON
        4. Restart Founder

        This allows the app to scan your entire disk to find what's taking up space.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            PermissionsManager.shared.openSystemPreferences(for: .fullDiskAccess)
        }

        completion()
    }

    /// Check if we should ask for permission (not too frequently)
    func shouldAskForPermission(type: String) -> Bool {
        let key = "LastAsked_\(type)"
        if let lastAsked = UserDefaults.standard.object(forKey: key) as? Date {
            // Don't ask more than once per day
            return Date().timeIntervalSince(lastAsked) > 86400
        }
        return true
    }

    /// Mark that we asked for permission
    func markAskedForPermission(type: String) {
        let key = "LastAsked_\(type)"
        UserDefaults.standard.set(Date(), forKey: key)
    }
}
