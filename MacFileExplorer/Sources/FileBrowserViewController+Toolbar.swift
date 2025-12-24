import Cocoa

extension FileBrowserViewController {
    func toolbarDidRequestBack() {
        navigationCoordinator.goBack()
    }

    func toolbarDidRequestForward() {
        navigationCoordinator.goForward()
    }

    func toolbarDidRequestNavigate(to url: URL) {
        navigationCoordinator.loadDirectory(url)
    }

    func toolbarDidChangeSortColumn(_ column: String, ascending: Bool) {
        sortColumn = column
        sortAscending = ascending
        toolbarViewController.updateSortDisplay(column: column, ascending: ascending)
        sortItems()
        outlineView.reloadData()

        var prefs = settings.folderSortPreferences
        prefs[currentDirectory.path] = "\(column)|\(ascending ? "asc" : "desc")"
        settings.folderSortPreferences = prefs
    }

    func toolbarDidRequestNavigateToHistoryIndex(_ index: Int) {
        navigationCoordinator.navigateToHistoryIndex(index)
    }

    func toolbarDidRequestNewFolder() {
        contextMenuNewFolder(self)
    }

    func toolbarDidToggleHiddenFiles(show: Bool) {
        showsHiddenFiles = show
        settings.hiddenFilesState = show
        refreshCurrentDirectory()
    }

    func toolbarDidChangeViewMode(_ viewMode: ViewMode) {
        currentViewMode = viewMode
        toolbarViewController?.updateViewModeDisplay(for: viewMode)
        updateZoomControlVisibility()
        viewModeCoordinator.displayFiles(for: viewMode)
    }

    func toolbarDidRequestSplitVertically() {
        delegate?.fileBrowserDidRequestSplit(self, orientation: .vertical)
    }

    func toolbarDidRequestSplitHorizontally() {
        delegate?.fileBrowserDidRequestSplit(self, orientation: .horizontal)
    }

    func toolbarDidRequestClosePane() {
        delegate?.fileBrowserDidRequestClosePane(self)
    }

    func toolbarDidSearchTextChange(_ searchText: String) {
        searchFilter = searchText
        refreshCurrentDirectory()
    }

    func toolbarDidTogglePreviewPane() {
        previewPaneCoordinator.togglePreviewPane()
        settings.previewPaneVisible = previewPaneCoordinator.isVisible
        toolbarViewController.updatePreviewPaneDisplay(showing: previewPaneCoordinator.isVisible)
    }

    func toolbarDidRequestShowFilter() {
        showFilterPanel()
    }

    func toolbarDidRequestOpenInTerminal() {
        delegate?.toolbarDidRequestOpenInTerminal(from: self)
    }
}
