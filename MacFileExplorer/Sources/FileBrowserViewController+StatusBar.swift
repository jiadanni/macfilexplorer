import Cocoa

extension FileBrowserViewController {
    func setZoomControlsVisible(_ visible: Bool) {
        zoomControlsAllowedByPane = visible
        updateZoomControlVisibility()
    }

    func setZoomLevel(_ level: Double) {
        zoomLevel = max(0.5, min(2.0, level))
        statusBarViewController?.setZoomLevel(zoomLevel)
        applyZoomToCurrentView()
    }

    private func isZoomableViewMode(_ mode: ViewMode) -> Bool {
        return mode == .icons || mode == .windowsList
    }

    func updateZoomControlVisibility() {
        let shouldShow = zoomControlsAllowedByPane && isZoomableViewMode(currentViewMode)
        statusBarViewController?.setZoomControlsVisible(shouldShow)
    }

    // MARK: - StatusBarDelegate

    func zoomLevelDidChange(to level: Double) {
        setZoomLevel(level)
    }

    func setClosePaneButtonVisible(_ visible: Bool) {
        toolbarViewController?.setClosePaneButtonVisible(visible)
    }

    func updateSplitButtonsState(_ canAddMore: Bool) {
        toolbarViewController?.updateSplitButtonsState(canAddMore: canAddMore)
    }

    private func applyZoomToCurrentView() {
        switch currentViewMode {
        case .icons, .windowsList:
            guard let collectionView = collectionView else { return }

            if currentViewMode == .windowsList {
                let flowLayout = NSCollectionViewFlowLayout()
                let baseWidth: CGFloat = 150
                let baseHeight: CGFloat = 20
                let baseLineSpacing: CGFloat = 2
                let baseInteritemSpacing: CGFloat = 10
                flowLayout.itemSize = NSSize(width: baseWidth * zoomLevel, height: baseHeight * zoomLevel)
                flowLayout.sectionInset = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
                flowLayout.minimumLineSpacing = baseLineSpacing * zoomLevel
                flowLayout.minimumInteritemSpacing = baseInteritemSpacing * zoomLevel
                flowLayout.scrollDirection = .horizontal
                collectionView.collectionViewLayout = flowLayout
                freeFormLayout = nil
            } else {
                if let freeFormLayout = freeFormLayout {
                    let baseWidth: CGFloat = 110
                    let baseHeight: CGFloat = 130
                    let baseSpacing: CGFloat = 10
                    freeFormLayout.itemSize = NSSize(width: baseWidth * zoomLevel, height: baseHeight * zoomLevel)
                    freeFormLayout.gridSpacing = baseSpacing * zoomLevel
                    freeFormLayout.invalidateLayout()
                } else {
                    let flowLayout = NSCollectionViewFlowLayout()
                    let baseWidth: CGFloat = 110
                    let baseHeight: CGFloat = 130
                    let baseSpacing: CGFloat = 10
                    flowLayout.itemSize = NSSize(width: baseWidth * zoomLevel, height: baseHeight * zoomLevel)
                    flowLayout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
                    flowLayout.minimumLineSpacing = baseSpacing * zoomLevel
                    flowLayout.minimumInteritemSpacing = baseSpacing * zoomLevel
                    flowLayout.scrollDirection = .vertical
                    collectionView.collectionViewLayout = flowLayout
                }
            }

            collectionView.reloadData()

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.view.window?.makeFirstResponder(self.view)
            }

        case .columns:
            break
        case .list:
            break
        }
    }
}
