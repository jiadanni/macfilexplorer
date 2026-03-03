import Cocoa

class SidebarViewController: NSViewController {

    weak var delegate: SidebarDelegate?

    // Child View Controllers
    private var favoritesVC: FavoritesViewController!
    private var locationsVC: LocationsViewController!
    private var folderOutlineVC: FolderOutlineViewController!
    
    private let settings: SettingsStoreProtocol

    init(settings: SettingsStoreProtocol = SettingsStore.shared) {
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.settings = SettingsStore.shared
        super.init(coder: coder)
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 600))
        setupUI()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Create the top-level split view
        let mainSplitView = NSSplitView()
        mainSplitView.isVertical = false
        mainSplitView.dividerStyle = .thin
        mainSplitView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainSplitView)

        NSLayoutConstraint.activate([
            mainSplitView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mainSplitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainSplitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainSplitView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Create the nested split view for the bottom sections
        let bottomSplitView = NSSplitView()
        bottomSplitView.isVertical = false
        bottomSplitView.dividerStyle = .thin

        // Favorites section
        favoritesVC = FavoritesViewController(settings: settings)
        favoritesVC.delegate = self
        addChild(favoritesVC)
        
        let favoritesContainer = NSView()
        let favoritesHeader = createSectionHeader(title: "FAVORITES")
        favoritesVC.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Ensure favoritesVC view has a minimum height
        favoritesVC.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true

        let favoritesStack = NSStackView(views: [favoritesHeader, favoritesVC.view])
        favoritesStack.orientation = .vertical
        favoritesStack.spacing = 0
        favoritesStack.translatesAutoresizingMaskIntoConstraints = false
        favoritesContainer.addSubview(favoritesStack)
        
        NSLayoutConstraint.activate([
            favoritesStack.topAnchor.constraint(equalTo: favoritesContainer.topAnchor),
            favoritesStack.leadingAnchor.constraint(equalTo: favoritesContainer.leadingAnchor),
            favoritesStack.trailingAnchor.constraint(equalTo: favoritesContainer.trailingAnchor),
            favoritesStack.bottomAnchor.constraint(equalTo: favoritesContainer.bottomAnchor),
        ])
        
        mainSplitView.addArrangedSubview(favoritesContainer)

        // Locations section
        locationsVC = LocationsViewController(settings: settings)
        locationsVC.delegate = self
        addChild(locationsVC)
        
        let locationsContainer = NSView()
        let locationsHeader = createSectionHeader(title: "LOCATIONS")
        locationsVC.view.translatesAutoresizingMaskIntoConstraints = false
        locationsVC.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        
        let locationsStack = NSStackView(views: [locationsHeader, locationsVC.view])
        locationsStack.orientation = .vertical
        locationsStack.spacing = 0
        locationsStack.translatesAutoresizingMaskIntoConstraints = false
        locationsContainer.addSubview(locationsStack)
        
        NSLayoutConstraint.activate([
            locationsStack.topAnchor.constraint(equalTo: locationsContainer.topAnchor),
            locationsStack.leadingAnchor.constraint(equalTo: locationsContainer.leadingAnchor),
            locationsStack.trailingAnchor.constraint(equalTo: locationsContainer.trailingAnchor),
            locationsStack.bottomAnchor.constraint(equalTo: locationsContainer.bottomAnchor),
        ])
        
        bottomSplitView.addArrangedSubview(locationsContainer)

        // Folder Explorer section
        folderOutlineVC = FolderOutlineViewController(settings: settings)
        folderOutlineVC.delegate = self
        addChild(folderOutlineVC)
        
        let folderContainer = NSView()
        let folderHeader = createSectionHeader(title: "FOLDER EXPLORER")
        folderOutlineVC.view.translatesAutoresizingMaskIntoConstraints = false
        folderOutlineVC.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        
        let folderStack = NSStackView(views: [folderHeader, folderOutlineVC.view])
        folderStack.orientation = .vertical
        folderStack.spacing = 0
        folderStack.translatesAutoresizingMaskIntoConstraints = false
        folderContainer.addSubview(folderStack)
        
        NSLayoutConstraint.activate([
            folderStack.topAnchor.constraint(equalTo: folderContainer.topAnchor),
            folderStack.leadingAnchor.constraint(equalTo: folderContainer.leadingAnchor),
            folderStack.trailingAnchor.constraint(equalTo: folderContainer.trailingAnchor),
            folderStack.bottomAnchor.constraint(equalTo: folderContainer.bottomAnchor),
        ])
        
        bottomSplitView.addArrangedSubview(folderContainer)
        mainSplitView.addArrangedSubview(bottomSplitView)

        // Set equal proportions logic
        mainSplitView.setHoldingPriority(.defaultLow, forSubviewAt: 0) // Favorites
        mainSplitView.setHoldingPriority(.defaultLow, forSubviewAt: 1) // Bottom Split (Locations + Folder)
        
        bottomSplitView.setHoldingPriority(.defaultLow, forSubviewAt: 0) // Locations
        bottomSplitView.setHoldingPriority(.defaultLow, forSubviewAt: 1) // Folder Explorer
    }

    private var initialLayoutDone = false

    override func viewDidLayout() {
        super.viewDidLayout()
        
        // Only perform initial layout once to avoid fighting user resizing
        guard !initialLayoutDone else { return }
        
        if let mainSplitView = view.subviews.first as? NSSplitView,
           let bottomSplitView = mainSplitView.arrangedSubviews.safe(at: 1) as? NSSplitView {

            let totalHeight = mainSplitView.bounds.height
            guard totalHeight > 0 else { return }
            
            let mainDividerThickness = mainSplitView.dividerThickness
            let bottomDividerThickness = bottomSplitView.dividerThickness
            let headerHeight: CGFloat = 20.0
            
            // Calculate ideal heights based on content
            let favoritesContentHeight = favoritesVC.contentHeight + headerHeight
            let locationsContentHeight = locationsVC.contentHeight + headerHeight
            
            // Minimum heights to ensure visibility
            let minSectHeight: CGFloat = 100.0
            let targetSectHeight = totalHeight / 3.0
            
            // Calculate Favorites height: at least content height (if small), 
            // but not more than 1/3 if it's large, unless there is plenty of space.
            // If favorites is tiny (e.g. 2 items = ~64px), we don't want to give it 1/3 of the screen.
            let favoritesHeight = max(minSectHeight, min(targetSectHeight, favoritesContentHeight + 10))
            
            mainSplitView.setPosition(favoritesHeight, ofDividerAt: 0)
            
            // Now distribute the rest between Locations and Folder Explorer
            let remainingHeight = totalHeight - favoritesHeight - mainDividerThickness
            let locationsHeight = max(minSectHeight, min(remainingHeight / 2.0, locationsContentHeight + 10))
            
            bottomSplitView.setPosition(locationsHeight, ofDividerAt: 0)
            
            initialLayoutDone = true
        }
    }

    private func createSectionHeader(title: String) -> NSView {
        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 20),
            headerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 0)
        ])

        return headerView
    }

    // Public method forwarding
    /// Expands the folder outline to show the specified directory.
    /// - Parameters:
    ///   - url: The directory URL to expand to
    ///   - force: If true, bypasses the expandSidebarToCurrentDirectory setting check
    func expandToCurrentDirectory(url: URL, force: Bool = false) {
        folderOutlineVC.expandToCurrentDirectory(url: url, force: force)
    }
    
    // Forwarding addFavorite (if used externally)
    func addFavorite(item: FileItem) {
        favoritesVC.addFavorite(item: item)
    }
}

// Conform to SidebarDelegate to pass events up
extension SidebarViewController: SidebarDelegate {
    func sidebarDidSelectLocation(_ url: URL) {
        delegate?.sidebarDidSelectLocation(url)
    }
}
