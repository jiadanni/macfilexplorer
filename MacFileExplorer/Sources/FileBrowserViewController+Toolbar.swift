import Cocoa

// MARK: - ToolbarDelegate

extension FileBrowserViewController: ToolbarDelegate {

    // MARK: - Navigation
    
    func toolbarDidRequestBack() {
        navigationCoordinator.goBack()
    }

    func toolbarDidRequestForward() {
        navigationCoordinator.goForward()
    }

    func toolbarDidRequestNavigate(to url: URL) {
        navigationCoordinator.loadDirectory(url)
    }

    func toolbarDidRequestNavigateToHistoryIndex(_ index: Int) {
        navigationCoordinator.navigateToHistoryIndex(index)
    }

    // MARK: - View Options

    func toolbarDidChangeViewMode(_ viewMode: ViewMode) {
        currentViewMode = viewMode
        toolbarViewController?.updateViewModeDisplay(for: viewMode)
        updateZoomControlVisibility()
        viewModeCoordinator.displayFiles(for: viewMode)
    }

    func toolbarDidChangeSortColumn(_ column: String, ascending: Bool) {
        sortColumn = column
        sortAscending = ascending
        toolbarViewController.updateSortDisplay(column: column, ascending: ascending)

        var prefs = settings.folderSortPreferences
        prefs[currentDirectory.path] = "\(column)|\(ascending ? "asc" : "desc")"
        settings.folderSortPreferences = prefs
    }

    func toolbarDidToggleHiddenFiles(show: Bool) {
        // Route through coordinator as SSOT - coordinator will notify observer
        hiddenFilesCoordinator.setVisibility(show)
    }

    func toolbarDidTogglePreviewPane() {
        previewPaneCoordinator.togglePreviewPane()
        settings.previewPaneVisible = previewPaneCoordinator.isVisible
        toolbarViewController.updatePreviewPaneDisplay(showing: previewPaneCoordinator.isVisible)
    }

    // MARK: - Actions

    func toolbarDidRequestNewFolder() {
        contextMenuNewFolder(self)
    }

    func toolbarDidRequestOpenInTerminal() {
        delegate?.toolbarDidRequestOpenInTerminal(from: self)
    }

    // MARK: - Search & Filter

    func toolbarDidSearchTextChange(_ searchText: String) {
        searchFilter = searchText
    }

    func toolbarDidRequestShowFilter() {
        showFilterPanel()
    }

    // MARK: - Layout

    func toolbarDidRequestSplitVertically() {
        delegate?.fileBrowserDidRequestSplit(self, orientation: .vertical)
    }

    func toolbarDidRequestSplitHorizontally() {
        delegate?.fileBrowserDidRequestSplit(self, orientation: .horizontal)
    }

    func toolbarDidRequestClosePane() {
        delegate?.fileBrowserDidRequestClosePane(self)
    }
}
