import Cocoa

extension FileBrowserViewController: FileBrowserNavigationCoordinatorDelegate {
    func navigationCoordinator(_ coordinator: FileBrowserNavigationCoordinator, didRequestLoad url: URL, isSearch: Bool) {
        debugLog("FileBrowserViewController: loadDirectory - Loading URL: \(url.path)")
        dataSource.navigate(to: url, isSearch: isSearch)
    }

    func navigationCoordinator(_ coordinator: FileBrowserNavigationCoordinator, didUpdateState state: NavigationState) {
        toolbarViewController?.updatePath(
            state.currentURL,
            canGoBack: state.canGoBack,
            canGoForward: state.canGoForward,
            history: state.history,
            currentIndex: state.currentIndex
        )
    }
}
