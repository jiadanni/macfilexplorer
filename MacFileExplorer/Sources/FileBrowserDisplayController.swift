import Cocoa

/// Handles view mode switching, layout management, and constraint updates for the file browser.
/// Single responsibility: Display and visual layout of different view modes (list, icons, columns)
final class FileBrowserDisplayController {
    
    // MARK: - Properties
    
    weak var viewController: FileBrowserViewController?
    
    private var activeConstraints: [NSLayoutConstraint] = []
    
    // MARK: - Initialization
    
    init(viewController: FileBrowserViewController) {
        self.viewController = viewController
    }
    
    // MARK: - View Mode Display
    
    /// Switches the active view to display the specified view mode
    func displayViewMode(_ viewMode: ViewMode) {
        guard let vc = viewController else { return }
        
        switch viewMode {
        case .list:
            displayListView()
        case .icons, .windowsList:
            displayCollectionView(for: viewMode)
        case .columns:
            displayColumnsView()
        }
        
        // Update preview pane if visible
        if vc.previewVisible {
            vc.previewPaneCoordinator.setPreviewPaneVisible(true)
        }
    }
    
    // MARK: - List View
    
    private func displayListView() {
        guard let vc = viewController else { return }
        
        // Ensure the scroll view is added to container
        if vc.scrollView.superview == nil {
            vc.containerView.addSubview(vc.scrollView)
        }
        
        // Hide other views
        vc.collectionViewScrollView?.removeFromSuperview()
        vc.browserView?.removeFromSuperview()
        
        // Setup constraints for list view
        setupListViewConstraints()
        
        // Reload data
        vc.outlineView.reloadData()
    }
    
    private func setupListViewConstraints() {
        guard let vc = viewController else { return }
        
        NSLayoutConstraint.deactivate(activeConstraints)
        activeConstraints.removeAll()
        
        vc.scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        activeConstraints = [
            vc.scrollView.topAnchor.constraint(equalTo: vc.containerView.topAnchor),
            vc.scrollView.bottomAnchor.constraint(equalTo: vc.containerView.bottomAnchor),
            vc.scrollView.leadingAnchor.constraint(equalTo: vc.containerView.leadingAnchor),
            vc.scrollView.trailingAnchor.constraint(equalTo: vc.containerView.trailingAnchor)
        ]
        
        NSLayoutConstraint.activate(activeConstraints)
    }
    
    // MARK: - Collection View (Icons/Windows List)
    
    private func displayCollectionView(for viewMode: ViewMode) {
        guard let vc = viewController else { return }
        
        // Create collection view if needed
        if vc.collectionView == nil {
            createCollectionView(for: viewMode)
        }
        
        // Update layout for current mode
        updateCollectionViewLayout(for: viewMode)
        
        // Ensure scroll view is in hierarchy
        if vc.collectionViewScrollView.superview == nil {
            vc.containerView.addSubview(vc.collectionViewScrollView)
        }
        
        // Hide other views
        vc.scrollView.removeFromSuperview()
        vc.browserView?.removeFromSuperview()
        
        // Setup constraints
        setupCollectionViewConstraints()
        
        // Reload data
        vc.collectionView?.reloadData()
    }
    
    private func createCollectionView(for viewMode: ViewMode) {
        guard let vc = viewController else { return }
        
        let collectionView = NSCollectionView()
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true
        collectionView.backgroundColors = [.clear]
        
        // Register item class
        collectionView.register(
            FileIconItem.self,
            forItemWithIdentifier: NSUserInterfaceItemIdentifier("FileIconItem")
        )
        
        // Create scroll view
        let scrollView = NSScrollView()
        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        
        // Set data source and delegate
        collectionView.dataSource = vc
        collectionView.delegate = vc
        
        // Configure drag & drop
        collectionView.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
        collectionView.setDraggingSourceOperationMask([.copy, .move], forLocal: false)
        collectionView.registerForDraggedTypes([.fileURL])
        
        vc.collectionView = collectionView
        vc.collectionViewScrollView = scrollView
        
        // Setup layout
        updateCollectionViewLayout(for: viewMode)
    }
    
    private func updateCollectionViewLayout(for viewMode: ViewMode) {
        guard let vc = viewController,
              let collectionView = vc.collectionView else { return }
        
        let layout: NSCollectionViewLayout
        
        if viewMode == .windowsList {
            // List-style layout for Windows List mode
            let flowLayout = NSCollectionViewFlowLayout()
            flowLayout.itemSize = NSSize(width: 400, height: 20)
            flowLayout.minimumInteritemSpacing = 0
            flowLayout.minimumLineSpacing = 2
            flowLayout.scrollDirection = .vertical
            layout = flowLayout
        } else {
            // Grid layout for Icons mode
            if vc.settings.freeFormIconPositioning {
                let freeFormLayout = FreeFormCollectionViewLayout()
                vc.freeFormLayout = freeFormLayout
                layout = freeFormLayout
            } else {
                let flowLayout = NSCollectionViewFlowLayout()
                let iconSize = CGFloat(vc.zoomLevel)
                flowLayout.itemSize = NSSize(width: iconSize + 40, height: iconSize + 60)
                flowLayout.minimumInteritemSpacing = 10
                flowLayout.minimumLineSpacing = 10
                layout = flowLayout
            }
        }
        
        collectionView.collectionViewLayout = layout
    }
    
    private func setupCollectionViewConstraints() {
        guard let vc = viewController else { return }
        
        NSLayoutConstraint.deactivate(activeConstraints)
        activeConstraints.removeAll()
        
        vc.collectionViewScrollView.translatesAutoresizingMaskIntoConstraints = false
        
        activeConstraints = [
            vc.collectionViewScrollView.topAnchor.constraint(equalTo: vc.containerView.topAnchor),
            vc.collectionViewScrollView.bottomAnchor.constraint(equalTo: vc.containerView.bottomAnchor),
            vc.collectionViewScrollView.leadingAnchor.constraint(equalTo: vc.containerView.leadingAnchor),
            vc.collectionViewScrollView.trailingAnchor.constraint(equalTo: vc.containerView.trailingAnchor)
        ]
        
        NSLayoutConstraint.activate(activeConstraints)
    }
    
    // MARK: - Columns View (Browser)
    
    private func displayColumnsView() {
        guard let vc = viewController else { return }
        
        // Create browser view if needed
        if vc.browserView == nil {
            createBrowserView()
        }
        
        // Ensure browser is in hierarchy
        if vc.browserView?.superview == nil, let browser = vc.browserView {
            vc.containerView.addSubview(browser)
        }
        
        // Hide other views
        vc.scrollView.removeFromSuperview()
        vc.collectionViewScrollView?.removeFromSuperview()
        
        // Setup constraints
        setupBrowserViewConstraints()
        
        // Reload data
        vc.browserView?.reloadColumn(0)
    }
    
    private func createBrowserView() {
        guard let vc = viewController else { return }
        
        let browser = NSBrowser()
        browser.maxVisibleColumns = 10
        browser.separatesColumns = true
        browser.allowsMultipleSelection = true
        browser.allowsEmptySelection = false
        browser.columnsAutosaveName = "FileBrowserColumns"
        browser.prefersAllColumnUserResizing = true
        
        browser.delegate = vc
        browser.target = vc
        browser.doubleAction = #selector(FileBrowserViewController.handleBrowserDoubleClick(_:))
        
        // Configure drag & drop
        browser.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
        browser.setDraggingSourceOperationMask([.copy, .move], forLocal: false)
        browser.registerForDraggedTypes([.fileURL])
        
        vc.browserView = browser
    }
    
    private func setupBrowserViewConstraints() {
        guard let vc = viewController,
              let browser = vc.browserView else { return }
        
        NSLayoutConstraint.deactivate(activeConstraints)
        activeConstraints.removeAll()
        
        browser.translatesAutoresizingMaskIntoConstraints = false
        
        activeConstraints = [
            browser.topAnchor.constraint(equalTo: vc.containerView.topAnchor),
            browser.bottomAnchor.constraint(equalTo: vc.containerView.bottomAnchor),
            browser.leadingAnchor.constraint(equalTo: vc.containerView.leadingAnchor),
            browser.trailingAnchor.constraint(equalTo: vc.containerView.trailingAnchor)
        ]
        
        NSLayoutConstraint.activate(activeConstraints)
    }
    
    // MARK: - Constraint Management
    
    /// Returns the currently active content view based on view mode
    func currentActiveContentView() -> NSView? {
        guard let vc = viewController else { return nil }
        
        switch vc.currentViewMode {
        case .list:
            return vc.scrollView
        case .icons, .windowsList:
            return vc.collectionViewScrollView
        case .columns:
            return vc.browserView
        }
    }
    
    /// Deactivates all active constraints
    func deactivateAllConstraints() {
        NSLayoutConstraint.deactivate(activeConstraints)
        activeConstraints.removeAll()
    }
    
    // MARK: - View Updates
    
    /// Refreshes all active views
    func refreshViews() {
        guard let vc = viewController else { return }
        
        switch vc.currentViewMode {
        case .list:
            vc.outlineView.reloadData()
        case .icons, .windowsList:
            vc.collectionView?.reloadData()
        case .columns:
            vc.browserView?.reloadColumn(0)
        }
    }
    
    /// Updates the collection view layout for zoom level changes
    func updateCollectionViewForZoom() {
        guard let vc = viewController,
              vc.currentViewMode == .icons || vc.currentViewMode == .windowsList else { return }
        
        updateCollectionViewLayout(for: vc.currentViewMode)
        vc.collectionView?.reloadData()
    }
}
