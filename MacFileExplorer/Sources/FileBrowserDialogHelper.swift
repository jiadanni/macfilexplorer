import Cocoa

/// Helper for common dialog operations and user interactions.
/// Extracted to reduce FileBrowserViewController complexity.

class FileBrowserDialogHelper {
    
    /// Presents a text input dialog.
    static func showTextInputDialog(title: String, message: String, defaultValue: String = "") -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = defaultValue
        alert.accessoryView = textField
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            return textField.stringValue
        }
        return nil
    }
    
    /// Presents a folder selection dialog.
    static func showFolderSelectionDialog(title: String = "Select Folder") -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.title = title
        openPanel.prompt = "Select"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        
        let response = openPanel.runModal()
        if response == .OK {
            return openPanel.url
        }
        return nil
    }
    
    /// Presents a file selection dialog.
    static func showFileSelectionDialog(title: String = "Select File", allowsMultiple: Bool = false) -> [URL]? {
        let openPanel = NSOpenPanel()
        openPanel.title = title
        openPanel.prompt = "Select"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = allowsMultiple
        
        let response = openPanel.runModal()
        if response == .OK {
            return openPanel.urls.isEmpty ? nil : openPanel.urls
        }
        return nil
    }
    
    /// Presents a save dialog.
    static func showSaveDialog(defaultFilename: String = "Untitled") -> URL? {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = defaultFilename
        
        let response = savePanel.runModal()
        if response == .OK {
            return savePanel.url
        }
        return nil
    }
    
    /// Presents a confirmation dialog.
    static func showConfirmationDialog(title: String, message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        return response == .alertFirstButtonReturn
    }
    
    /// Presents an error dialog.
    static func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Presents a warning dialog.
    static func showWarning(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Presents an info dialog.
    static func showInfo(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Presents a multi-option dialog.
    static func showOptionsDialog(title: String, message: String, options: [String], defaultOption: Int = 0) -> Int? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        
        for option in options {
            alert.addButton(withTitle: option)
        }
        
        let response = alert.runModal()
        let buttonIndex = response.rawValue - 1000 // NSAlertFirstButtonReturn = 1000
        
        if buttonIndex >= 0 && buttonIndex < options.count {
            return buttonIndex
        }
        return nil
    }
    
    /// Presents a rename dialog with validation.
    static func showRenameDialog(currentName: String) -> String? {
        guard let newName = showTextInputDialog(
            title: "Rename Item",
            message: "Enter the new name:",
            defaultValue: currentName
        ) else {
            return nil
        }
        
        // Validate new name
        if newName.isEmpty {
            showError(title: "Invalid Name", message: "The file name cannot be empty.")
            return showRenameDialog(currentName: currentName)
        }
        
        if newName.contains("/") {
            showError(title: "Invalid Name", message: "The file name cannot contain forward slashes.")
            return showRenameDialog(currentName: currentName)
        }
        
        if newName == "." || newName == ".." {
            showError(title: "Invalid Name", message: "The name '\(newName)' is reserved.")
            return showRenameDialog(currentName: currentName)
        }
        
        return newName
    }
    
    /// Presents a new folder name dialog with validation.
    static func showNewFolderDialog() -> String? {
        guard let folderName = showTextInputDialog(
            title: "New Folder",
            message: "Enter the folder name:",
            defaultValue: "New Folder"
        ) else {
            return nil
        }
        
        // Validate folder name
        if folderName.isEmpty {
            showError(title: "Invalid Name", message: "The folder name cannot be empty.")
            return showNewFolderDialog()
        }
        
        if folderName.contains("/") {
            showError(title: "Invalid Name", message: "The folder name cannot contain forward slashes.")
            return showNewFolderDialog()
        }
        
        return folderName
    }
    
    /// Presents a new file name dialog with validation.
    static func showNewFileDialog() -> String? {
        guard let fileName = showTextInputDialog(
            title: "New File",
            message: "Enter the file name:",
            defaultValue: "untitled"
        ) else {
            return nil
        }
        
        // Validate file name
        if fileName.isEmpty {
            showError(title: "Invalid Name", message: "The file name cannot be empty.")
            return showNewFileDialog()
        }
        
        if fileName.contains("/") {
            showError(title: "Invalid Name", message: "The file name cannot contain forward slashes.")
            return showNewFileDialog()
        }
        
        return fileName
    }
}
