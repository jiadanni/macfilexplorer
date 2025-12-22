import Cocoa

/// Handles view-mode setup and switching for FileBrowserViewController.
final class FileBrowserViewModeCoordinator {
    private weak var owner: FileBrowserViewController?

    /// Browser setup state machine to prevent concurrent initialization.
    private enum BrowserSetupState { case idle, preparing, creatingBrowser, ready, failed }
    private var browserSetupState: BrowserSetupState = .idle {
        didSet {
#if DEBUG
            debugLog("DEBUG: browserSetupState -> \(browserSetupState)")
#endif
        }
    }

    private let browserSerialQueue = DispatchQueue(label: "com.macfileexplorer.browserSetup")
    private var suppressedDisplayCalls = 0

    init(owner: FileBrowserViewController) {
        self.owner = owner
    }

    func displayFiles(for viewMode: ViewMode) {
        guard let owner = owner else { return }
        assert(Thread.isMainThread, "displayFiles must run on main thread")
        if browserSetupState == .preparing || browserSetupState == .creatingBrowser {
            suppressedDisplayCalls += 1
#if DEBUG
            debugLog("DEBUG: displayFiles blocked (state=\(browserSetupState)) count=\(suppressedDisplayCalls)")
#endif
            return
        }
        debugLog("Displaying files for view mode: \(viewMode)")

        NSLayoutConstraint.deactivate(owner.activeConstraints)
        owner.activeConstraints.removeAll()

        owner.scrollView.isHidden = true
        owner.collectionViewScrollView?.isHidden = true
        owner.browserView?.isHidden = true

        switch viewMode {
        case .list:
            displayListView()
        case .icons, .windowsList:
            displayCollectionView(for: viewMode)
        case .columns:
            displayColumnsView()
        }

        if owner.previewVisible {
            owner.ensureContentInPreviewSplit()
        }
    }

    private func displayListView() {
        guard let owner = owner else { return }
        if owner.scrollView.superview == nil {
            owner.containerView.addSubview(owner.scrollView)
        }
        owner.scrollView.isHidden = false

        if !owner.previewVisible {
            owner.activeConstraints = [
                owner.scrollView.topAnchor.constraint(equalTo: owner.containerView.topAnchor),
                owner.scrollView.leadingAnchor.constraint(equalTo: owner.containerView.leadingAnchor),
                owner.scrollView.trailingAnchor.constraint(equalTo: owner.containerView.trailingAnchor),
                owner.scrollView.bottomAnchor.constraint(equalTo: owner.containerView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(owner.activeConstraints)
        }
        owner.outlineView.reloadData()

        DispatchQueue.main.async { [weak owner] in
            guard let owner else { return }
            owner.view.window?.makeFirstResponder(owner.view)
        }
    }

    private func displayCollectionView(for viewMode: ViewMode) {
        guard let owner = owner else { return }

        if owner.collectionView == nil {
            setupCollectionView()
        }

        guard let collectionView = owner.collectionView,
              let collectionViewScrollView = owner.collectionViewScrollView else {
            debugLog("Error: CollectionView not properly initialized")
            owner.currentViewMode = .list
            displayFiles(for: .list)
            return
        }

        if collectionViewScrollView.superview == nil && !owner.previewVisible {
            owner.containerView.addSubview(collectionViewScrollView)
        }
        collectionViewScrollView.isHidden = false

        if !owner.previewVisible {
            owner.activeConstraints = [
                collectionViewScrollView.topAnchor.constraint(equalTo: owner.containerView.topAnchor),
                collectionViewScrollView.leadingAnchor.constraint(equalTo: owner.containerView.leadingAnchor),
                collectionViewScrollView.trailingAnchor.constraint(equalTo: owner.containerView.trailingAnchor),
                collectionViewScrollView.bottomAnchor.constraint(equalTo: owner.containerView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(owner.activeConstraints)
        }

        configureCollectionViewLayout(for: viewMode, collectionView: collectionView)

        collectionView.reloadData()

        DispatchQueue.main.async { [weak owner] in
            guard let owner else { return }
            owner.view.window?.makeFirstResponder(owner.view)
        }
    }

    private func configureCollectionViewLayout(for viewMode: ViewMode, collectionView: NSCollectionView) {
        guard let owner = owner else { return }
        if viewMode == .windowsList {
            let flowLayout = NSCollectionViewFlowLayout()
            let baseWidth: CGFloat = 150
            let baseHeight: CGFloat = 20
            let baseLineSpacing: CGFloat = 2
            let baseInteritemSpacing: CGFloat = 10
            flowLayout.itemSize = NSSize(width: baseWidth * owner.zoomLevel, height: baseHeight * owner.zoomLevel)
            flowLayout.sectionInset = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            flowLayout.minimumLineSpacing = baseLineSpacing * owner.zoomLevel
            flowLayout.minimumInteritemSpacing = baseInteritemSpacing * owner.zoomLevel
            flowLayout.scrollDirection = .horizontal
            collectionView.collectionViewLayout = flowLayout
            owner.freeFormLayout = nil
        } else {
            if let freeFormLayout = owner.freeFormLayout {
                let baseWidth: CGFloat = 110
                let baseHeight: CGFloat = 130
                let baseSpacing: CGFloat = 10
                freeFormLayout.itemSize = NSSize(width: baseWidth * owner.zoomLevel, height: baseHeight * owner.zoomLevel)
                freeFormLayout.gridSpacing = baseSpacing * owner.zoomLevel
                freeFormLayout.invalidateLayout()
            } else {
                let flowLayout = NSCollectionViewFlowLayout()
                let baseWidth: CGFloat = 110
                let baseHeight: CGFloat = 130
                let baseSpacing: CGFloat = 10
                flowLayout.itemSize = NSSize(width: baseWidth * owner.zoomLevel, height: baseHeight * owner.zoomLevel)
                flowLayout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
                flowLayout.minimumLineSpacing = baseSpacing * owner.zoomLevel
                flowLayout.minimumInteritemSpacing = baseSpacing * owner.zoomLevel
                flowLayout.scrollDirection = .vertical
                collectionView.collectionViewLayout = flowLayout
            }
        }
    }

    private func displayColumnsView() {
        withBrowserReady { [weak self] browserView in
            guard let self, let owner = self.owner else { return }

            if browserView.superview == nil && !owner.previewVisible {
                owner.containerView.addSubview(browserView)
            }
            browserView.isHidden = false

            if !owner.previewVisible {
                owner.activeConstraints = [
                    browserView.topAnchor.constraint(equalTo: owner.containerView.topAnchor),
                    browserView.leadingAnchor.constraint(equalTo: owner.containerView.leadingAnchor),
                    browserView.trailingAnchor.constraint(equalTo: owner.containerView.trailingAnchor),
                    browserView.bottomAnchor.constraint(equalTo: owner.containerView.bottomAnchor)
                ]
                NSLayoutConstraint.activate(owner.activeConstraints)
            }

            debugLog("displayFiles: Setting up browser view, rootItem has \(owner.rootItem?.children?.count ?? 0) children")
            browserView.layoutSubtreeIfNeeded()
            browserView.loadColumnZero()
            browserView.setNeedsDisplay(browserView.bounds)

            owner.view.window?.makeFirstResponder(owner.view)
        }
    }

    private func setupCollectionView() {
        guard let owner = owner else { return }
        if owner.collectionView != nil {
            debugLog("CollectionView already initialized, skipping setup")
            return
        }

        let newCollectionView = NSCollectionView()
        newCollectionView.translatesAutoresizingMaskIntoConstraints = false
        newCollectionView.isSelectable = true
        newCollectionView.allowsMultipleSelection = true
        newCollectionView.allowsEmptySelection = true
        newCollectionView.backgroundColors = [.clear]
        newCollectionView.setAccessibilityElement(true)
        newCollectionView.setAccessibilityRole(.group)
        newCollectionView.setAccessibilityLabel(L10n.text("Icon grid"))
        newCollectionView.delegate = owner
        newCollectionView.dataSource = owner

        newCollectionView.registerForDraggedTypes([.fileURL])
        newCollectionView.setDraggingSourceOperationMask([.copy, .move], forLocal: false)
        newCollectionView.setDraggingSourceOperationMask([.copy, .move], forLocal: true)

        setupCollectionViewGestures(newCollectionView)

        let newScrollView = NSScrollView()
        newScrollView.translatesAutoresizingMaskIntoConstraints = false
        newScrollView.hasVerticalScroller = true
        newScrollView.hasHorizontalScroller = true
        newScrollView.autohidesScrollers = true
        newScrollView.borderType = .noBorder
        newScrollView.documentView = newCollectionView

        owner.collectionView = newCollectionView
        owner.collectionViewScrollView = newScrollView
    }

    private func setupCollectionViewGestures(_ collectionView: NSCollectionView) {
        guard let owner = owner else { return }
        let doubleClickGesture = NSClickGestureRecognizer(target: owner, action: #selector(FileBrowserViewController.handleCollectionViewDoubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        collectionView.addGestureRecognizer(doubleClickGesture)

        let panGesture = NSPanGestureRecognizer(target: owner, action: #selector(FileBrowserViewController.handleIconDrag(_:)))
        panGesture.delegate = owner
        panGesture.delaysPrimaryMouseButtonEvents = false
        collectionView.addGestureRecognizer(panGesture)
    }

    private func setupBrowserView() {
        assert(Thread.isMainThread, "setupBrowserView must run on main thread")
        guard let owner = owner else { return }
        if owner.browserView != nil {
            debugLog("BrowserView already initialized, skipping setup")
            return
        }

        guard let token = beginBrowserSetup() else { return }
        token.markCreating()

        let newBrowser = createBrowserControl()
        owner.browserView = newBrowser

        owner.browserView.delegate = owner
        debugLog("BrowserView setup completed with minColumnWidth: 180")
        token.markReady()
    }

    private func createBrowserControl() -> NSBrowser {
        let newBrowser = NSBrowser()
        newBrowser.translatesAutoresizingMaskIntoConstraints = false
        newBrowser.allowsMultipleSelection = true
        newBrowser.allowsEmptySelection = true
        newBrowser.takesTitleFromPreviousColumn = false
        newBrowser.separatesColumns = true
        newBrowser.hasHorizontalScroller = true
        newBrowser.autohidesScroller = true
        newBrowser.minColumnWidth = 180
        newBrowser.maxVisibleColumns = 4
        newBrowser.doubleAction = #selector(FileBrowserViewController.handleBrowserDoubleClick(_:))
        if let owner = owner {
            newBrowser.target = owner
            newBrowser.menu = owner.createContextMenu()
        }
        newBrowser.setCellClass(NSBrowserCell.self)
        return newBrowser
    }

    private class BrowserSetupToken {
        weak var owner: FileBrowserViewModeCoordinator?
        init(owner: FileBrowserViewModeCoordinator) {
            self.owner = owner
            owner.browserSetupState = .preparing
        }
        func markCreating() { owner?.browserSetupState = .creatingBrowser }
        func markReady() { owner?.browserSetupState = .ready }
        func markFailed() { owner?.browserSetupState = .failed }
        deinit {
            guard let owner = owner else { return }
            if owner.browserSetupState == .preparing || owner.browserSetupState == .creatingBrowser {
                owner.browserSetupState = .failed
            }
        }
    }

    private func beginBrowserSetup() -> BrowserSetupToken? {
        guard browserSetupState == .idle || browserSetupState == .failed else {
#if DEBUG
            debugLog("DEBUG: beginBrowserSetup blocked; state=\(browserSetupState)")
#endif
            return nil
        }
        return BrowserSetupToken(owner: self)
    }

    private func enqueueBrowserSetupIfNeeded() {
        guard let owner = owner else { return }
        if owner.browserView == nil {
            browserSerialQueue.async { [weak self] in
                DispatchQueue.main.async {
                    self?.setupBrowserView()
                }
            }
        }
    }

    private func withBrowserReady(_ completion: @escaping (NSBrowser) -> Void) {
        guard let owner = owner else { return }
        if let browserView = owner.browserView, browserSetupState == .ready {
            completion(browserView)
            return
        }

        enqueueBrowserSetupIfNeeded()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, let owner = self.owner,
                  let browserView = owner.browserView, self.browserSetupState == .ready else { return }
            completion(browserView)
        }
    }
}
