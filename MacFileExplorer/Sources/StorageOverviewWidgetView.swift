//
//  StorageOverviewWidgetView.swift
//  MacFileExplorer
//
//  Storage overview widget for Start Page
//

import Cocoa

class StorageOverviewWidgetView: StartWidgetView {

    private var statusLabel: NSTextField!
    private var actionButton: NSButton!
    private var hasFullDiskAccess: Bool = false

    init() {
        super.init(title: "Storage Overview", icon: StartDesignSystem.Icons.storage, dismissible: false)
        checkPermissions()
        setupContent()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        checkPermissions()
        setupContent()
    }

    private func checkPermissions() {
        // Check Full Disk Access by attempting to read a protected directory
        // This avoids triggering permission dialogs unless actually needed
        let protectedPath = AppConfig.Paths.applicationSupport
        hasFullDiskAccess = FileManager.default.isReadableFile(atPath: protectedPath)
    }

    override func setupContent() {
        if hasFullDiskAccess {
            setupGrantedView()
        } else {
            setupPlaceholderView()
        }
    }

    private func setupPlaceholderView() {
        // Placeholder icon
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: StartDesignSystem.Icons.storage, accessibilityDescription: "Storage")
        iconView.contentTintColor = StartDesignSystem.Colors.inactive
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        // Status message
        statusLabel = StartDesignSystem.createLabel(
            text: "Enable Full Disk Access to see a detailed breakdown of your storage",
            style: .body
        )
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentView.addSubview(statusLabel)

        // Grant access button
        actionButton = StartDesignSystem.createButton(title: "Enable Full Disk Access", style: .primary)
        actionButton.target = self
        actionButton.action = #selector(grantAccessTapped)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(actionButton)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor),
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),

            statusLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: StartDesignSystem.Spacing.md),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            actionButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: StartDesignSystem.Spacing.lg),
            actionButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            actionButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func setupGrantedView() {
        // Show loading state first
        let loadingLabel = StartDesignSystem.createLabel(
            text: "Calculating storage...",
            style: .body
        )
        loadingLabel.alignment = .center
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.textColor = .secondaryLabelColor
        contentView.addSubview(loadingLabel)

        NSLayoutConstraint.activate([
            loadingLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            loadingLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loadingLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])

        // Calculate storage in background
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let storageInfo = self.getDiskStorageInfo()

            // Update UI on main thread
            DispatchQueue.main.async {
                // Remove loading label
                loadingLabel.removeFromSuperview()

                // Build the actual UI
                self.buildStorageUI(with: storageInfo)
            }
        }
    }

    private func buildStorageUI(with storageInfo: StorageInfo) {
        // Title and usage label
        let titleLabel = StartDesignSystem.createLabel(
            text: storageInfo.volumeName,
            style: .title
        )
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        let usageLabel = StartDesignSystem.createLabel(
            text: storageInfo.usageText,
            style: .body
        )
        usageLabel.textColor = .secondaryLabelColor
        usageLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(usageLabel)

        // Storage bar
        let storageBar = createStorageBar(categories: storageInfo.categories, totalSize: storageInfo.totalSize)
        storageBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(storageBar)

        // Legend
        let legend = createLegend(categories: storageInfo.categories)
        legend.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(legend)

        // Free space label (in gray box)
        let freeSpaceBox = createFreeSpaceBox(text: storageInfo.freeSpaceText)
        freeSpaceBox.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(freeSpaceBox)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),

            usageLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            usageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            storageBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: StartDesignSystem.Spacing.md),
            storageBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            storageBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            storageBar.heightAnchor.constraint(equalToConstant: 28),

            legend.topAnchor.constraint(equalTo: storageBar.bottomAnchor, constant: StartDesignSystem.Spacing.sm),
            legend.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),

            freeSpaceBox.centerYAnchor.constraint(equalTo: legend.centerYAnchor),
            freeSpaceBox.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            legend.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    @objc private func grantAccessTapped() {
        // Show explanation alert
        let alert = NSAlert()
        alert.messageText = "Full Disk Access Required"
        alert.informativeText = "The Storage Analyzer works by scanning your entire disk to find what's taking up space. This requires the 'Full Disk Access' permission.\n\nClick 'Open System Preferences' to grant this permission."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            PermissionsManager.shared.openSystemPreferences(for: .fullDiskAccess)
        }
    }

    @objc private func openAnalyzerTapped() {
        delegate?.widgetDidRequestAction(.openStorageAnalyzer, widget: self)
    }

    override func refresh() {
        // Clear and rebuild based on current permissions
        contentView.subviews.forEach { $0.removeFromSuperview() }
        checkPermissions()
        setupContent()
    }

    // MARK: - Storage Data

    private struct StorageCategory {
        let name: String
        let size: Int64
        let color: NSColor
    }

    private struct StorageInfo {
        let volumeName: String
        let usageText: String
        let freeSpaceText: String
        let categories: [StorageCategory]
        let totalSize: Int64
    }

    private func getDiskStorageInfo() -> StorageInfo {
        let fileManager = FileManager.default
        let homeURL = fileManager.homeDirectoryForCurrentUser

        // Get volume stats
        do {
            let values = try homeURL.resourceValues(forKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            let volumeName = values.volumeName ?? "Macintosh HD"
            let totalCapacity = Int64(values.volumeTotalCapacity ?? 0)
            let availableCapacity = Int64(values.volumeAvailableCapacity ?? 0)
            let usedCapacity = totalCapacity - availableCapacity

            // Estimate categories (simplified - a real implementation would scan directories)
            let categories = estimateStorageCategories(totalUsed: usedCapacity)

            let usageText = "\(formatBytes(usedCapacity)) of \(formatBytes(totalCapacity)) used"
            let freeSpaceText = formatBytes(availableCapacity)

            return StorageInfo(
                volumeName: volumeName,
                usageText: usageText,
                freeSpaceText: freeSpaceText,
                categories: categories,
                totalSize: totalCapacity
            )
        } catch {
            // Fallback
            return StorageInfo(
                volumeName: "Macintosh HD",
                usageText: "Unable to read disk info",
                freeSpaceText: "—",
                categories: [],
                totalSize: 0
            )
        }
    }

    private func estimateStorageCategories(totalUsed: Int64) -> [StorageCategory] {
        // Calculate actual sizes for major directories
        let fileManager = FileManager.default
        let homeURL = fileManager.homeDirectoryForCurrentUser

        var categories: [StorageCategory] = []

        // Documents
        let documentsSize = calculateDirectorySize(homeURL.appendingPathComponent("Documents"))
        categories.append(StorageCategory(name: "Documents", size: documentsSize, color: NSColor.systemRed))

        // Applications (both /Applications and ~/Applications)
        let appsSize = calculateDirectorySize(URL(fileURLWithPath: "/Applications")) +
                      calculateDirectorySize(homeURL.appendingPathComponent("Applications"))
        categories.append(StorageCategory(name: "Applications", size: appsSize, color: NSColor.systemOrange))

        // Developer (common dev folders)
        let devSize = calculateDirectorySize(homeURL.appendingPathComponent("Developer")) +
                     calculateDirectorySize(homeURL.appendingPathComponent("Library/Developer")) +
                     calculateDirectorySize(homeURL.appendingPathComponent(".npm")) +
                     calculateDirectorySize(homeURL.appendingPathComponent(".cargo"))
        categories.append(StorageCategory(name: "Developer", size: devSize, color: NSColor.systemYellow))

        // System Data (Library, caches, etc)
        let librarySize = calculateDirectorySize(homeURL.appendingPathComponent("Library"))
        categories.append(StorageCategory(name: "System Data", size: librarySize, color: NSColor.systemGray))

        // macOS System
        let systemSize = calculateDirectorySize(URL(fileURLWithPath: AppConfig.Paths.system)) +
                        calculateDirectorySize(URL(fileURLWithPath: AppConfig.Paths.library))
        categories.append(StorageCategory(name: "macOS", size: systemSize, color: NSColor.darkGray))

        // Filter out zero-size categories
        return categories.filter { $0.size > 0 }
    }

    private func calculateDirectorySize(_ url: URL) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0

        // Check if we can read the directory
        guard fileManager.isReadableFile(atPath: url.path) else {
            return 0
        }

        // Use a simple directory enumerator with shallow traversal
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .totalFileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return 0
        }

        var itemCount = 0
        let maxItems = 10000 // Limit to prevent UI freeze

        for case let fileURL as URL in enumerator {
            itemCount += 1
            if itemCount > maxItems {
                break // Stop scanning if taking too long
            }

            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .totalFileSizeKey, .isDirectoryKey])

                // Use totalFileSize for directories (includes contents), fileSize for files
                if let isDirectory = resourceValues.isDirectory, isDirectory {
                    if let dirSize = resourceValues.totalFileSize {
                        totalSize += Int64(dirSize)
                    }
                } else if let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            } catch {
                // Skip files we can't read
                continue
            }
        }

        return totalSize
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - UI Components

    private func createStorageBar(categories: [StorageCategory], totalSize: Int64) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 4
        container.layer?.masksToBounds = true

        var previousAnchor: NSLayoutXAxisAnchor? = nil

        for category in categories {
            let segment = NSView()
            segment.wantsLayer = true
            segment.layer?.backgroundColor = category.color.cgColor
            segment.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(segment)

            let widthMultiplier = totalSize > 0 ? CGFloat(category.size) / CGFloat(totalSize) : 0

            NSLayoutConstraint.activate([
                segment.topAnchor.constraint(equalTo: container.topAnchor),
                segment.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                segment.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: widthMultiplier)
            ])

            if let previous = previousAnchor {
                segment.leadingAnchor.constraint(equalTo: previous).isActive = true
            } else {
                segment.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true
            }

            previousAnchor = segment.trailingAnchor
        }

        return container
    }

    private func createLegend(categories: [StorageCategory]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .centerY

        for category in categories {
            let item = createLegendItem(name: category.name, color: category.color)
            stack.addArrangedSubview(item)
        }

        return stack
    }

    private func createLegendItem(name: String, color: NSColor) -> NSView {
        let container = NSView()

        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.backgroundColor = color.cgColor
        dot.layer?.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(dot)

        let label = StartDesignSystem.createLabel(text: name, style: .caption)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),

            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func createFreeSpaceBox(text: String) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.3).cgColor
        container.layer?.cornerRadius = 4

        let label = StartDesignSystem.createLabel(text: text, style: .body)
        label.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])

        return container
    }
}
