import Cocoa

final class PermissionsSettingsViewController: NSViewController {

    private var stackView: NSStackView!
    private var permissionViews: [PermissionType: NSView] = [:]
    private var directoryListStack: NSStackView!

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.view = scrollView

        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        contentView.translatesAutoresizingMaskIntoConstraints = false

        stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 15
        contentView.addSubview(stackView)

        scrollView.documentView = contentView

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        stackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        addPermissionsSection()
        addGrantedDirectoriesSection()
    }

    private func addPermissionsSection() {
        let titleLabel = NSTextField(labelWithString: "App Permissions")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 2)
        stackView.addArrangedSubview(titleLabel)

        let descriptionLabel = NSTextField(labelWithString: "Manage permissions for MacFileExplorer. Click 'Open Settings' to change permissions in System Preferences.")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.maximumNumberOfLines = 0
        descriptionLabel.preferredMaxLayoutWidth = 500
        stackView.addArrangedSubview(descriptionLabel)

        // Add spacing
        let spacer1 = NSView()
        spacer1.translatesAutoresizingMaskIntoConstraints = false
        spacer1.heightAnchor.constraint(equalToConstant: 10).isActive = true
        stackView.addArrangedSubview(spacer1)

        // Add permission rows (only surface permissions the app might use)
        let visiblePermissions: [PermissionType] = [.fullDiskAccess]
        for permissionType in visiblePermissions {
            let permissionRow = createPermissionRow(for: permissionType)
            stackView.addArrangedSubview(permissionRow)
            permissionViews[permissionType] = permissionRow
        }

        // Add refresh button
        let spacer2 = NSView()
        spacer2.translatesAutoresizingMaskIntoConstraints = false
        spacer2.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacer2)

        let refreshButton = NSButton(title: "Refresh Permissions", target: self, action: #selector(refreshPermissions(_:)))
        refreshButton.bezelStyle = .rounded
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(refreshButton)
    }

    private func createPermissionRow(for type: PermissionType) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let iconImage = NSImage.mfeSymbol(named: type.icon, accessibilityDescription: type.rawValue)
        let iconView = NSImageView(image: iconImage ?? NSImage())
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentTintColor = .labelColor
        container.addSubview(iconView)

        // Permission name and description stack
        let textStack = NSStackView()
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let nameLabel = NSTextField(labelWithString: type.rawValue)
        nameLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        nameLabel.textColor = .labelColor
        textStack.addArrangedSubview(nameLabel)

        let descLabel = NSTextField(labelWithString: type.description)
        descLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descLabel.textColor = .secondaryLabelColor
        textStack.addArrangedSubview(descLabel)

        container.addSubview(textStack)

        // Status label
        let status = PermissionsManager.shared.checkPermissionStatus(for: type)
        let statusLabel = NSTextField(labelWithString: status.displayText)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize)
        statusLabel.textColor = status.color
        statusLabel.alignment = .right
        statusLabel.tag = 1000 // Tag to identify status label
        container.addSubview(statusLabel)

        // Open Settings button
        let settingsButton = NSButton(title: "Open Settings", target: self, action: #selector(openSystemPreferences(_:)))
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.bezelStyle = .rounded
        settingsButton.tag = type.hashValue
        container.addSubview(settingsButton)

        // Separator
        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator
        container.addSubview(separator)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),

            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -5),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -12),

            settingsButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            settingsButton.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -5),
            settingsButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

            statusLabel.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -5),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),

            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    @objc private func openSystemPreferences(_ sender: NSButton) {
        // Find the permission type from the button's tag
        if let permissionType = PermissionType.allCases.first(where: { $0.hashValue == sender.tag }) {
            PermissionsManager.shared.openSystemPreferences(for: permissionType)
        }
    }

    @objc private func refreshPermissions(_ sender: NSButton) {
        // Refresh all permission statuses
        for (permissionType, permissionView) in permissionViews {
            if let statusLabel = permissionView.viewWithTag(1000) as? NSTextField {
                let status = PermissionsManager.shared.checkPermissionStatus(for: permissionType)
                statusLabel.stringValue = status.displayText
                statusLabel.textColor = status.color
            }
        }
        refreshGrantedDirectories()
    }

    // MARK: - Granted Directories

    private func addGrantedDirectoriesSection() {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stackView.addArrangedSubview(spacer)

        let titleLabel = NSTextField(labelWithString: "Granted Directory Access")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 2)
        stackView.addArrangedSubview(titleLabel)

        let descLabel = NSTextField(labelWithString: "These are folders you have explicitly granted MacFileExplorer access to. You can reveal them in Finder or revoke access.")
        descLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descLabel.textColor = .secondaryLabelColor
        descLabel.maximumNumberOfLines = 0
        descLabel.preferredMaxLayoutWidth = 500
        stackView.addArrangedSubview(descLabel)

        directoryListStack = NSStackView()
        directoryListStack.translatesAutoresizingMaskIntoConstraints = false
        directoryListStack.orientation = .vertical
        directoryListStack.alignment = .leading
        directoryListStack.spacing = 6
        stackView.addArrangedSubview(directoryListStack)

        let buttonsRow = NSStackView()
        buttonsRow.translatesAutoresizingMaskIntoConstraints = false
        buttonsRow.orientation = .horizontal
        buttonsRow.alignment = .centerY
        buttonsRow.spacing = 8

        let addButton = NSButton(title: "Add Directory…", target: self, action: #selector(addDirectoryAccess(_:)))
        addButton.bezelStyle = .rounded
        buttonsRow.addArrangedSubview(addButton)

        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshGrantedDirectoriesAction(_:)))
        refreshButton.bezelStyle = .rounded
        buttonsRow.addArrangedSubview(refreshButton)

        let exportButton = NSButton(title: "Export List", target: self, action: #selector(exportGrantedDirectories(_:)))
        exportButton.bezelStyle = .rounded
        buttonsRow.addArrangedSubview(exportButton)

        let helpButton = NSButton(title: "How to revoke", target: self, action: #selector(showRevokeHelp(_:)))
        helpButton.bezelStyle = .rounded
        buttonsRow.addArrangedSubview(helpButton)

        stackView.addArrangedSubview(buttonsRow)

        refreshGrantedDirectories()
    }

    private func directoryRow(for url: URL) -> NSView {
        let entry = PermissionsManager.shared.resolvedGrantedDirectoryEntries().first { $0.path == url.path }
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let pathLabel = NSTextField(labelWithString: url.path)
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        container.addSubview(pathLabel)

        let statusText: String
        let statusColor: NSColor
        if let e = entry {
            if !e.isValid { statusText = "Missing"; statusColor = NSColor.systemRed }
            else if e.isStale { statusText = "Stale"; statusColor = NSColor.systemOrange }
            else { statusText = "Valid"; statusColor = NSColor.systemGreen }
        } else {
            statusText = "Valid"
            statusColor = NSColor.systemGreen
        }

        let statusLabel = NSTextField(labelWithString: statusText)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize)
        statusLabel.textColor = statusColor
        container.addSubview(statusLabel)

        let revealButton = NSButton(title: "Reveal", target: self, action: #selector(revealDirectory(_:)))
        revealButton.translatesAutoresizingMaskIntoConstraints = false
        revealButton.bezelStyle = .rounded
        revealButton.identifier = NSUserInterfaceItemIdentifier(url.path)
        container.addSubview(revealButton)

        let fixNeeded = statusText == "Missing" || statusText == "Stale"
        var fixButton: NSButton? = nil
        if fixNeeded {
            let btn = NSButton(title: "Fix…", target: self, action: #selector(fixDirectoryAccess(_:)))
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.bezelStyle = .rounded
            btn.identifier = NSUserInterfaceItemIdentifier(url.path)
            container.addSubview(btn)
            fixButton = btn
        }

        let removeButton = NSButton(title: "Remove", target: self, action: #selector(removeDirectoryAccess(_:)))
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.bezelStyle = .rounded
        removeButton.identifier = NSUserInterfaceItemIdentifier(url.path)
        container.addSubview(removeButton)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(separator)

        var constraints: [NSLayoutConstraint] = [
            pathLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            pathLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: pathLabel.trailingAnchor, constant: 12),
            statusLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ]

        if let fixButton = fixButton {
            constraints += [
                fixButton.leadingAnchor.constraint(equalTo: statusLabel.trailingAnchor, constant: 8),
                fixButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                revealButton.leadingAnchor.constraint(equalTo: fixButton.trailingAnchor, constant: 8)
            ]
        } else {
            constraints += [
                revealButton.leadingAnchor.constraint(equalTo: statusLabel.trailingAnchor, constant: 8)
            ]
        }

        constraints += [
            revealButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            removeButton.leadingAnchor.constraint(equalTo: revealButton.trailingAnchor, constant: 8),
            removeButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            removeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ]

        NSLayoutConstraint.activate(constraints)
        return container
    }

    @objc private func addDirectoryAccess(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Grant Access"
        panel.message = "Choose a folder to grant the app persistent access."
        if panel.runModal() == .OK, let url = panel.url {
            PermissionsManager.shared.addGrantedDirectory(url)
            refreshGrantedDirectories()
        }
    }

    @objc private func refreshGrantedDirectoriesAction(_ sender: NSButton) {
        refreshGrantedDirectories()
    }

    @objc private func exportGrantedDirectories(_ sender: NSButton) {
        let entries = PermissionsManager.shared.resolvedGrantedDirectoryEntries()
        var lines: [String] = []
        for entry in entries {
            if let url = entry.url {
                lines.append(url.path)
            } else {
                lines.append(entry.path)
            }
        }
        let text = lines.joined(separator: "\n")
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let outURL = desktop.appendingPathComponent("granted_directories.txt")
        do {
            try text.write(to: outURL, atomically: true, encoding: .utf8)
            let alert = NSAlert()
            alert.messageText = "Export Complete"
            alert.informativeText = "Exported \(lines.count) entries to \(outURL.path)"
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    @objc private func showRevokeHelp(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "How to Revoke Directory Access"
        alert.informativeText = "To revoke a granted folder:\n\n1) Open Settings → Permissions → Granted Directory Access.\n2) Find the folder and click 'Remove' to revoke access.\n\nAlternatively, you can remove saved entries by deleting the keys in your preferences plist (not recommended unless you know what you're doing):\ndefaults write com.macfileexplorer.app grantedDirectoriesPaths -array\ndefaults write com.macfileexplorer.app grantedDirectoryBookmarks -array\n\nAfter removing entries, restart the app to apply changes."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func refreshGrantedDirectories() {
        directoryListStack.arrangedSubviews.forEach { directoryListStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        let entries = PermissionsManager.shared.resolvedGrantedDirectoryEntries()
        if entries.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "No directories granted yet. Use 'Add Directory…' to grant persistent access to a folder. You can revoke access later with 'Remove'.")
            emptyLabel.textColor = .secondaryLabelColor
            emptyLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            emptyLabel.maximumNumberOfLines = 0
            emptyLabel.preferredMaxLayoutWidth = 500
            directoryListStack.addArrangedSubview(emptyLabel)
        } else {
            for entry in entries {
                if let url = entry.url ?? (entry.isValid ? URL(fileURLWithPath: entry.path) : URL(fileURLWithPath: entry.path)) as URL? {
                    directoryListStack.addArrangedSubview(directoryRow(for: url))
                }
            }
        }
    }

    private func urlFromButton(_ sender: NSButton) -> URL? {
        guard let raw = sender.identifier?.rawValue, !raw.isEmpty else { return nil }
        return URL(fileURLWithPath: raw)
    }

    @objc private func revealDirectory(_ sender: NSButton) {
        if let url = urlFromButton(sender) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
        }
    }

    @objc private func removeDirectoryAccess(_ sender: NSButton) {
        if let url = urlFromButton(sender) {
            PermissionsManager.shared.removeGrantedDirectory(url)
            refreshGrantedDirectories()
        }
    }

    @objc private func fixDirectoryAccess(_ sender: NSButton) {
        guard let oldURL = urlFromButton(sender) else { return }
        // Try automatic refresh if stale and still exists
        if FileManager.default.fileExists(atPath: oldURL.path) {
            PermissionsManager.shared.refreshBookmarkIfStale(for: oldURL)
            refreshGrantedDirectories()
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Replace"
        panel.message = "Select the new location to replace missing directory access."
        if panel.runModal() == .OK, let newURL = panel.url {
            PermissionsManager.shared.replaceGrantedDirectory(oldURL: oldURL, with: newURL)
            refreshGrantedDirectories()
        }
    }
}

