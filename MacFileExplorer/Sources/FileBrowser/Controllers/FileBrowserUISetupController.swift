import Cocoa

/// Handles one-time UI initialization and setup for the file browser.
/// Single responsibility: Initial setup of UI components (toolbar, status bar, outline view configuration)
final class FileBrowserUISetupController {
    
    // MARK: - Properties
    
    weak var viewController: FileBrowserViewController?
    
    // MARK: - Initialization
    
    init(viewController: FileBrowserViewController) {
        self.viewController = viewController
    }
    
    // MARK: - Main Setup
    
    /// Performs all UI setup operations
    func setupUI() {
        setupContainerAndOutlineView()
        setupToolbar()
        setupStatusBar()
        setupConstraints()
    }
    
    // MARK: - Toolbar Setup
    
    private func setupToolbar() {
        guard let vc = viewController else { return }
        
        let toolbar = ToolbarViewController(settings: vc.settings)
        toolbar.delegate = vc
        vc.addChild(toolbar)
        vc.view.addSubview(toolbar.view)
        vc.toolbarViewController = toolbar
    }
    
    // MARK: - Status Bar Setup
    
    private func setupStatusBar() {
        guard let vc = viewController else { return }
        
        let statusBar = StatusBarViewController()
        statusBar.delegate = vc
        vc.addChild(statusBar)
        vc.view.addSubview(statusBar.view)
        vc.statusBarViewController = statusBar
    }
    
    // MARK: - Container and Outline View Setup
    
    private func setupContainerAndOutlineView() {
        guard let vc = viewController else { return }
        
        // Create split view for preview pane support
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        vc.previewSplitView = splitView
        vc.view.addSubview(splitView)
        
        // Create container view for switching between view modes
        let container = RootFileBrowserView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.dropDelegate = vc.dragDropCoordinator
        vc.containerView = container

        // Add container to split view (it will be the first item)
        splitView.addArrangedSubview(container)

        // Configure the preview coordinator after the container is in place so a
        // preview pane restored at launch lands to the right of the file list.
        vc.previewPaneCoordinator.setup(in: splitView, owner: vc)
        
        // Create outline view and scroll view
        let outline = InsetOutlineView()
        outline.leadingContentInset = 8
        outline.dataSource = vc.outlineCoordinator
        outline.delegate = vc.outlineCoordinator
        outline.autoresizesOutlineColumn = false
        outline.allowsMultipleSelection = true
        outline.allowsColumnReordering = true
        outline.allowsColumnResizing = true
        // Stripes and selection are drawn by RoundedSelectionRowView
        outline.usesAlternatingRowBackgroundColors = false
        outline.style = .fullWidth
        outline.backgroundColor = AppDesignSystem.Chrome.contentBackground
        outline.intercellSpacing = NSSize(width: 0, height: 0)
        outline.gridStyleMask = []
        outline.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        
        let scroll = NSScrollView()
        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = AppDesignSystem.Chrome.contentBackground
        scroll.translatesAutoresizingMaskIntoConstraints = false
        
        vc.outlineView = outline
        vc.scrollView = scroll
        
        // Setup columns
        setupOutlineViewColumns()
        
        // Setup behavior
        setupOutlineViewBehavior()
    }
    
    // MARK: - Outline View Columns
    
    private func setupOutlineViewColumns() {
        guard let vc = viewController else { return }
        
        let outline = vc.outlineView
        
        // Name column
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(AppConfig.ColumnID.name))
        nameColumn.title = "Name"
        nameColumn.minWidth = 100
        nameColumn.width = 200
        nameColumn.resizingMask = .userResizingMask
        outline?.addTableColumn(nameColumn)
        outline?.outlineTableColumn = nameColumn
        
        // Date Modified column
        let dateModifiedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(AppConfig.ColumnID.dateModified))
        dateModifiedColumn.title = "Date Modified"
        dateModifiedColumn.minWidth = 80
        dateModifiedColumn.width = 170
        dateModifiedColumn.resizingMask = .userResizingMask
        outline?.addTableColumn(dateModifiedColumn)
        
        // Type column
        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(AppConfig.ColumnID.type))
        typeColumn.title = "Kind"
        typeColumn.minWidth = 60
        typeColumn.width = 110
        typeColumn.resizingMask = .userResizingMask
        outline?.addTableColumn(typeColumn)
        
        // Size column
        let sizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(AppConfig.ColumnID.size))
        sizeColumn.title = "Size"
        sizeColumn.minWidth = 60
        sizeColumn.width = 90
        sizeColumn.resizingMask = .userResizingMask
        sizeColumn.headerCell.alignment = .right
        outline?.addTableColumn(sizeColumn)
        
        // Date Created column
        let dateCreatedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(AppConfig.ColumnID.dateCreated))
        dateCreatedColumn.title = "Date Created"
        dateCreatedColumn.minWidth = 80
        dateCreatedColumn.width = 120
        dateCreatedColumn.resizingMask = .userResizingMask
        outline?.addTableColumn(dateCreatedColumn)
        
        // Tags column
        let tagsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TagsColumn"))
        tagsColumn.title = "Tags"
        tagsColumn.minWidth = 60
        tagsColumn.width = 100
        tagsColumn.resizingMask = .userResizingMask
        outline?.addTableColumn(tagsColumn)

        // Flat header styling (keeps each column's title and alignment)
        for column in outline?.tableColumns ?? [] {
            let headerCell = ChromeTableHeaderCell(textCell: column.title)
            headerCell.alignment = column.headerCell.alignment
            column.headerCell = headerCell
        }
        outline?.cornerView = nil
    }
    
    // MARK: - Outline View Behavior
    
    private func setupOutlineViewBehavior() {
        guard let vc = viewController else { return }
        
        let outline = vc.outlineView
        
        // Double-click action
        outline?.target = vc
        outline?.doubleAction = #selector(FileBrowserViewController.outlineViewDoubleClicked(_:))
        
        // Drag & drop
        outline?.registerForDraggedTypes([.fileURL])
        outline?.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
        outline?.setDraggingSourceOperationMask([.copy, .move], forLocal: false)
        
        // Accessibility
        outline?.setAccessibilityRole(.outline)
        outline?.setAccessibilityLabel("File Browser")
        outline?.setAccessibilityIdentifier("FileList")
    }
    
    // MARK: - Constraints Setup
    
    private func setupConstraints() {
        guard let vc = viewController else { return }

        let toolbarView = vc.toolbarViewController.view
        let splitView = vc.previewSplitView!
        let statusBarView = vc.statusBarViewController.view

        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        splitView.translatesAutoresizingMaskIntoConstraints = false
        statusBarView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Toolbar at top
            toolbarView.topAnchor.constraint(equalTo: vc.view.topAnchor),
            toolbarView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            toolbarView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            toolbarView.heightAnchor.constraint(equalToConstant: ToolbarViewController.height),

            // SplitView (Container + Preview) in middle
            splitView.topAnchor.constraint(equalTo: toolbarView.bottomAnchor),
            splitView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: statusBarView.topAnchor),

            // Status bar at bottom
            statusBarView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            statusBarView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            statusBarView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
            statusBarView.heightAnchor.constraint(equalToConstant: StatusBarViewController.height)
        ])
    }
}
