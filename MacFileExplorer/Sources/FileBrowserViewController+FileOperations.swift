import Cocoa

extension FileBrowserViewController {
    func performFileOperation(_ operation: FileOperationType, items: [URL], destination: URL?, sourcePane: FileBrowserViewController? = nil) {
        fileOperationsManager.perform(operation, items: items, destination: destination, sourcePane: sourcePane, currentDirectory: currentDirectory)
    }
}

extension FileBrowserViewController: FileOperationsManagerDelegate {
    func fileOperationsManager(_ manager: FileOperationsManager, didRequestPresentSheet viewController: NSViewController) {
        presentAsSheet(viewController)
    }

    func fileOperationsManager(_ manager: FileOperationsManager, didRequestPresentError message: String) {
        showError(message)
    }

    func fileOperationsManagerDidRequestRefresh(_ manager: FileOperationsManager) {
        refreshCurrentDirectory()
    }

    func fileOperationsManagerDidRequestRefreshSource(_ manager: FileOperationsManager, sourcePane: FileBrowserViewController) {
        sourcePane.refreshCurrentDirectory()
    }

    var window: NSWindow? { view.window }
}
