//
//  FavoritesWidgetView.swift
//  MacFileExplorer
//
//  Favorites widget for Start Page showing device name and root folder
//

import Cocoa

class FavoritesWidgetView: StartWidgetView {

    private var gridView: NSGridView!
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
        // Default configuration: just root folder
        defaultFolders = [
            ("/", StartDesignSystem.Icons.folder, URL(fileURLWithPath: "/"))
        ]
    }

    override func setupContent() {
        // Grid for folder buttons
        gridView = NSGridView()
        gridView.rowSpacing = StartDesignSystem.Spacing.md
        gridView.columnSpacing = StartDesignSystem.Spacing.md
        gridView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(gridView)

        // Create folder cards in grid (3 columns)
        var row = 0
        var col = 0
        let columnsPerRow = 3

        for folder in defaultFolders {
            let card = createFolderCard(name: folder.name, icon: folder.icon, url: folder.url)

            if col == 0 {
                let newRow = [card]
                gridView.addRow(with: newRow)
            } else {
                gridView.cell(atColumnIndex: 0, rowIndex: row).xPlacement = .fill
                gridView.addColumn(with: [card])
            }

            col += 1
            if col >= columnsPerRow {
                col = 0
                row += 1
            }
        }

        // Add "Add Favorite" button
        addButton = createAddFavoriteCard()
        if col == 0 {
            gridView.addRow(with: [addButton])
        } else {
            gridView.addColumn(with: [addButton])
        }

        NSLayoutConstraint.activate([
            gridView.topAnchor.constraint(equalTo: contentView.topAnchor),
            gridView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            gridView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            gridView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func createFolderCard(name: String, icon: String, url: URL?) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.backgroundColor = NSColor.controlColor.cgColor

        // Icon
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: name)
        iconView.contentTintColor = StartDesignSystem.Colors.accent
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
        button.target = self
        button.action = #selector(folderCardTapped(_:))
        button.tag = defaultFolders.firstIndex(where: { $0.name == name }) ?? 0
        button.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconView)
        card.addSubview(label)
        card.addSubview(button)

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

            card.widthAnchor.constraint(equalToConstant: 100),
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
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.backgroundColor = NSColor.controlColor.cgColor
        card.layer?.borderWidth = 2
        card.layer?.borderColor = StartDesignSystem.Colors.accent.withAlphaComponent(0.3).cgColor

        // Plus icon
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: StartDesignSystem.Icons.addFolder, accessibilityDescription: "Add Folder")
        iconView.contentTintColor = StartDesignSystem.Colors.accent
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // Label
        let label = StartDesignSystem.createLabel(text: "Add to Folder", style: .body)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        // Button
        let button = NSButton()
        button.title = ""
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.target = self
        button.action = #selector(addFavoriteTapped)
        button.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconView)
        card.addSubview(label)
        card.addSubview(button)

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

            card.widthAnchor.constraint(equalToConstant: 100),
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
        delegate?.widgetDidRequestAction(.addFavorite, widget: self)
    }
}
