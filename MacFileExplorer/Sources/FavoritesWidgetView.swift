//
//  FavoritesWidgetView.swift
//  MacFileExplorer
//
//  Favorites widget for Start Page showing device name and root folder
//

import Cocoa

class FavoritesWidgetView: StartWidgetView {

    private var addButton: NSView!

    private var defaultFolders: [(name: String, icon: String, url: URL?)] = []

    init() {
        // Get device name/hostname
        let deviceName = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        super.init(title: deviceName, icon: StartDesignSystem.Icons.folder, dismissible: false)
        setupDefaultFolders()
        setupContent()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDefaultFolders()
        setupContent()
        // Update title with device name after initialization
        let deviceName = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        widgetTitle = deviceName
    }

    private func setupDefaultFolders() {
        // Load saved favorite folders from UserDefaults
        if let savedPaths = UserDefaults.standard.array(forKey: "FavoriteWidgetFolders") as? [String] {
            defaultFolders = savedPaths.compactMap { path in
                let url = URL(fileURLWithPath: path)
                let name = url.lastPathComponent.isEmpty ? "/" : url.lastPathComponent
                return (name, StartDesignSystem.Icons.folder, url)
            }
        }

        // If no saved folders, use root as default
        if defaultFolders.isEmpty {
            defaultFolders = [
                ("/", StartDesignSystem.Icons.folder, URL(fileURLWithPath: "/"))
            ]
        }
    }

    func addFolder(url: URL) {
        debugLog("FavoritesWidget: addFolder called with url: \(url.path)")
        // Add to the folders array
        let name = url.lastPathComponent.isEmpty ? "/" : url.lastPathComponent
        let newFolder = (name, StartDesignSystem.Icons.folder, url as URL?)
        defaultFolders.append(newFolder)
        debugLog("FavoritesWidget: defaultFolders count after append: \(defaultFolders.count)")

        // Save to UserDefaults
        let paths = defaultFolders.compactMap { $0.url?.path }
        UserDefaults.standard.set(paths, forKey: "FavoriteWidgetFolders")
        debugLog("FavoritesWidget: Saved paths to UserDefaults: \(paths)")

        // Rebuild the widget UI
        debugLog("FavoritesWidget: About to rebuild content")
        rebuildContent()
        debugLog("FavoritesWidget: Rebuild complete")
    }

    private func rebuildContent() {
        // Clear existing content
        contentView.subviews.forEach { $0.removeFromSuperview() }

        // Rebuild
        setupContent()
    }

    override func setupContent() {
        // Use stack view for better layout control
        let containerStack = NSStackView()
        containerStack.orientation = .horizontal
        containerStack.spacing = StartDesignSystem.Spacing.md
        containerStack.alignment = .top
        containerStack.distribution = .fill
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerStack)
        
        // Create folder cards
        for folder in defaultFolders {
            let card = createFolderCard(name: folder.name, icon: folder.icon, url: folder.url)
            containerStack.addArrangedSubview(card)
        }
        
        // Add "Add Favorite" button
        addButton = createAddFavoriteCard()
        containerStack.addArrangedSubview(addButton)

        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func createFolderCard(name: String, icon: String, url: URL?) -> NSView {
        let card = NSView()
        // Layer-backing disabled to allow button clicks to work properly
        card.wantsLayer = false

        // Icon
        let iconView = NSImageView()
        if let sysImage = NSImage(systemSymbolName: icon, accessibilityDescription: name) {
            let useGrayscale = UserDefaults.standard.bool(forKey: UserDefaults.Keys.useGrayscaleIcons.rawValue)
            iconView.image = useGrayscale ? sysImage.grayscale() : sysImage
            iconView.contentTintColor = useGrayscale ? NSColor.secondaryLabelColor : StartDesignSystem.Colors.accent
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // Label
        let label = StartDesignSystem.createLabel(text: name, style: .body)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        // Button overlay for click handling
        let button = NSButton()
        button.title = ""
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.setButtonType(.momentaryPushIn)
        button.target = self
        button.action = #selector(folderCardTapped(_:))
        button.tag = defaultFolders.firstIndex(where: { $0.name == name }) ?? 0
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setAccessibilityLabel(name)
        button.setAccessibilityRole(.button)

        card.addSubview(iconView)
        card.addSubview(label)
        card.addSubview(button)

        // Keep the cards flexible so the window can resize horizontally
        card.setContentHuggingPriority(.defaultLow, for: .horizontal)
        card.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: StartDesignSystem.Spacing.md),
            iconView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: StartDesignSystem.Spacing.sm),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: StartDesignSystem.Spacing.sm),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -StartDesignSystem.Spacing.sm),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -StartDesignSystem.Spacing.md),

            button.topAnchor.constraint(equalTo: card.topAnchor),
            button.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            // Fixed height only; width must flex with window resizing
            card.heightAnchor.constraint(equalToConstant: 100)
        ])

        // Hover effect
        let trackingArea = NSTrackingArea(
            rect: card.bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: card,
            userInfo: ["button": button]
        )
        card.addTrackingArea(trackingArea)

        return card
    }

    private func createAddFavoriteCard() -> NSView {
        let card = NSView()
        // Layer-backing disabled to allow button clicks to work properly
        card.wantsLayer = false

        // Plus icon
        let iconView = NSImageView()
        if let sysImage = NSImage(systemSymbolName: StartDesignSystem.Icons.addFolder, accessibilityDescription: "Add Folder") {
            let useGrayscale = UserDefaults.standard.bool(forKey: UserDefaults.Keys.useGrayscaleIcons.rawValue)
            iconView.image = useGrayscale ? sysImage.grayscale() : sysImage
        }
        iconView.contentTintColor = StartDesignSystem.Colors.accent
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // Label
        let label = StartDesignSystem.createLabel(text: L10n.text("Add to Folder"), style: .body)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        // Button
        let button = NSButton()
        button.title = ""
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.setButtonType(.momentaryPushIn)
        button.target = self
        button.action = #selector(addFavoriteTapped)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setAccessibilityLabel(L10n.text("Add favorite folder"))
        button.setAccessibilityRole(.button)

        card.addSubview(iconView)
        card.addSubview(label)
        card.addSubview(button)

        // Keep the cards flexible so the window can resize horizontally
        card.setContentHuggingPriority(.defaultLow, for: .horizontal)
        card.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: StartDesignSystem.Spacing.md),
            iconView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: StartDesignSystem.Spacing.sm),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: StartDesignSystem.Spacing.sm),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -StartDesignSystem.Spacing.sm),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -StartDesignSystem.Spacing.md),

            button.topAnchor.constraint(equalTo: card.topAnchor),
            button.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            // Fixed height only; width must flex with window resizing
            card.heightAnchor.constraint(equalToConstant: 100)
        ])

        return card
    }

    @objc private func folderCardTapped(_ sender: NSButton) {
        let index = sender.tag
        guard index < defaultFolders.count else { return }

        let folder = defaultFolders[index]
        guard let url = folder.url else { return }

        // Check if we have permission
        let hasPermission = FileManager.default.isReadableFile(atPath: url.path)

        if hasPermission {
            // Open immediately
            delegate?.widgetDidRequestAction(.openFolder(url), widget: self)
        } else {
            // Request permission with explanation
            delegate?.widgetDidRequestAction(.requestPermission(folder: url), widget: self)
        }
    }

    @objc private func addFavoriteTapped() {
        debugLog("FavoritesWidget: addFavoriteTapped called")
        debugLog("FavoritesWidget: delegate is \(delegate == nil ? "nil" : "set")")
        delegate?.widgetDidRequestAction(.addFavorite, widget: self)
    }
}
