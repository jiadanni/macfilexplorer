import Cocoa

/// Handles view-mode setup and switching for FileBrowserViewController.
/// Uses a serial dispatch queue to ensure thread-safe, ordered view mode transitions
/// without blocking the main thread.
final class FileBrowserViewModeCoordinator {
    private weak var owner: FileBrowserViewController?
    
    /// Serial queue for coordinating display operations to prevent concurrent initialization races.
    /// All view mode changes flow through this queue to ensure sequential, reliable transitions.
    private let displayQueue = DispatchQueue(label: "com.macfilexplorer.viewmode.display", qos: .userInitiated)

    init(owner: FileBrowserViewController) {
        self.owner = owner
    }

    /// Display files in the specified view mode.
    /// Uses a serial queue to ensure view mode transitions are thread-safe and non-concurrent.
    func displayFiles(for viewMode: ViewMode) {
        guard let owner = owner else { return }
        
        debugLog("Displaying files for view mode: \(viewMode)")
        
        // Queue the display operation on the serial queue
        displayQueue.async { [weak self, weak owner] in
            guard let self = self, let owner = owner else { return }

            // Perform setup on main thread
            DispatchQueue.main.async {
                owner.currentViewMode = viewMode
                
                // Handle view mode switching based on mode type
                switch viewMode {
                case .list:
                    self.displayListView()
                case .icons, .windowsList:
                    self.displayCollectionView(for: viewMode)
                case .columns:
                    self.displayColumnsView()
                }

                // Set first responder
                owner.view.window?.makeFirstResponder(owner.view)
            }
        }
    }

    private func displayListView() {
        guard let owner = owner else { return }

        guard let scrollView = owner.scrollView else { return }
        
        // Ensure the scroll view is added to container
        if let containerView = owner.containerView, scrollView.superview == nil {
            containerView.addSubview(scrollView)
        }

        // Hide other views
        owner.collectionViewScrollView?.isHidden = true
        owner.browserView?.isHidden = true
        scrollView.isHidden = false

        // Setup constraints for list view
        NSLayoutConstraint.deactivate(owner.activeConstraints)
        owner.activeConstraints.removeAll()

        // Content is pinned to the container, which is a sibling of the preview
        // pane in the split view — constraints apply regardless of preview visibility.
        if let containerView = owner.containerView {
            owner.activeConstraints = [
                scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ]
            NSLayoutConstraint.activate(owner.activeConstraints)
        }

        // Reload data
        owner.outlineView?.reloadData()
    }

    private func displayCollectionView(for viewMode: ViewMode) {
        guard let owner = owner else { return }

        if owner.collectionView == nil {
            setupCollectionView()
        }

        guard let collectionView = owner.collectionView,
              let _ = owner.collectionViewScrollView else {
            debugLog("Error: CollectionView not properly initialized")
            return
        }

        NSLayoutConstraint.deactivate(owner.activeConstraints)
        owner.activeConstraints.removeAll()

        owner.scrollView?.isHidden = true
        owner.browserView?.isHidden = true

        if let collectionViewScrollView = owner.collectionViewScrollView,
           let containerView = owner.containerView {
            if collectionViewScrollView.superview == nil {
                containerView.addSubview(collectionViewScrollView)
            }
            collectionViewScrollView.isHidden = false

            owner.activeConstraints = [
                collectionViewScrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
                collectionViewScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                collectionViewScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                collectionViewScrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(owner.activeConstraints)
        }

        configureCollectionViewLayout(for: viewMode, collectionView: collectionView)

        collectionView.reloadData()

        Task { @MainActor [weak owner] in
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
        guard let owner = owner else { return }
        
        // Setup browser view if needed
        if owner.browserView == nil {
            setupBrowserView()
        }
        
        guard let browserView = owner.browserView else {
            debugLog("Error: BrowserView not properly initialized, falling back to list view")
            return
        }

        NSLayoutConstraint.deactivate(owner.activeConstraints)
        owner.activeConstraints.removeAll()

        if let scrollView = owner.scrollView {
            scrollView.isHidden = true
        }
        if let collectionViewScrollView = owner.collectionViewScrollView {
            collectionViewScrollView.isHidden = true
        }

        if let containerView = owner.containerView {
            if browserView.superview == nil {
                containerView.addSubview(browserView)
            }
            browserView.isHidden = false

            owner.activeConstraints = [
                browserView.topAnchor.constraint(equalTo: containerView.topAnchor),
                browserView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                browserView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                browserView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(owner.activeConstraints)
        }

        debugLog("displayFiles: Setting up browser view, rootItem has \(owner.rootItem?.children?.count ?? 0) children")
        browserView.layoutSubtreeIfNeeded()
        browserView.loadColumnZero()
        browserView.setNeedsDisplay(browserView.bounds)

        owner.view.window?.makeFirstResponder(owner.view)
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
        newCollectionView.setAccessibilityIdentifier("FileCollectionView")
        newCollectionView.delegate = owner.collectionCoordinator
        newCollectionView.dataSource = owner.collectionCoordinator

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
        guard let owner = owner else { return }
        if owner.browserView != nil {
            debugLog("BrowserView already initialized, skipping setup")
            return
        }

        let newBrowser = createBrowserControl()
        owner.browserView = newBrowser
        owner.browserView?.delegate = owner.columnCoordinator
        debugLog("BrowserView setup completed with minColumnWidth: 180")
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
}
