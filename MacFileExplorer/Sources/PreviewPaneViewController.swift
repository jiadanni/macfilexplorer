import Cocoa
import AVKit
import PDFKit
import Quartz
import UniformTypeIdentifiers

enum PreviewPanePosition {
    case right
    case bottom
    case hidden
}

class PreviewPaneViewController: NSViewController {

    private var containerView: NSView!
    private var headerView: NSView!
    private var titleLabel: NSTextField!
    private var closeButton: NSButton!
    private var contentScrollView: NSScrollView!
    private var contentView: NSView!

    // Preview content views
    private var imageView: NSImageView?
    private var pdfView: PDFView?
    private var videoPlayerView: AVPlayerView?
    private var textView: NSTextView?
    private var metadataStackView: NSStackView?

    // Quick action buttons
    private var quickActionsView: NSView!
    private var rotateButton: NSButton!

    // Storage analyzer
    private var storageAnalyzerView: NSView!
    private var storageProgressIndicator: NSProgressIndicator!
    private var storageSizeLabel: NSTextField!
    private var storageItemsLabel: NSTextField!

    private var currentFileItem: FileItem?
    private var currentPlayer: AVPlayer?

    var position: PreviewPanePosition = .right {
        didSet {
            updateLayoutForPosition()
        }
    }

    override func loadView() {
        // Set initial size - this will be controlled by split view constraints
        view = NSView(frame: NSRect(x: 0, y: 0, width: 350, height: 600))
        view.translatesAutoresizingMaskIntoConstraints = false

        // Prevent the view from forcing window resize
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        setupUI()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Container view
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Header view
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        containerView.addSubview(headerView)

        // Title label
        titleLabel = NSTextField(labelWithString: "Preview")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        headerView.addSubview(titleLabel)

        // Close button
        closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .texturedSquare
        closeButton.isBordered = false
        closeButton.title = "×"
        closeButton.font = NSFont.systemFont(ofSize: 18)
        closeButton.target = self
        closeButton.action = #selector(closeButtonClicked)
        headerView.addSubview(closeButton)

        // Content scroll view
        contentScrollView = NSScrollView()
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.hasVerticalScroller = true
        contentScrollView.hasHorizontalScroller = true
        contentScrollView.autohidesScrollers = true
        contentScrollView.borderType = .noBorder
        containerView.addSubview(contentScrollView)

        // Content view
        contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.documentView = contentView

        // Quick actions view
        quickActionsView = NSView()
        quickActionsView.translatesAutoresizingMaskIntoConstraints = false
        quickActionsView.wantsLayer = true
        quickActionsView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        quickActionsView.isHidden = true
        containerView.addSubview(quickActionsView)

        setupQuickActions()

        // Storage analyzer view
        storageAnalyzerView = NSView()
        storageAnalyzerView.translatesAutoresizingMaskIntoConstraints = false
        storageAnalyzerView.wantsLayer = true
        storageAnalyzerView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        storageAnalyzerView.isHidden = true
        containerView.addSubview(storageAnalyzerView)

        setupStorageAnalyzer()

        // Setup constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            headerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 20),
            closeButton.heightAnchor.constraint(equalToConstant: 20),

            contentScrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            contentScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            contentScrollView.bottomAnchor.constraint(equalTo: quickActionsView.topAnchor),

            quickActionsView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            quickActionsView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            quickActionsView.bottomAnchor.constraint(equalTo: storageAnalyzerView.topAnchor),
            quickActionsView.heightAnchor.constraint(equalToConstant: 44),

            storageAnalyzerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            storageAnalyzerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            storageAnalyzerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            storageAnalyzerView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }

    private func setupQuickActions() {
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        quickActionsView.addSubview(stackView)

        rotateButton = createActionButton(title: "Rotate", action: #selector(rotateButtonClicked))

        stackView.addArrangedSubview(rotateButton)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: quickActionsView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: quickActionsView.trailingAnchor, constant: -8),
            stackView.centerYAnchor.constraint(equalTo: quickActionsView.centerYAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    private func createActionButton(title: String, action: Selector) -> NSButton {
        let button = NSButton()
        button.title = title
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
        return button
    }

    private func setupStorageAnalyzer() {
        storageProgressIndicator = NSProgressIndicator()
        storageProgressIndicator.translatesAutoresizingMaskIntoConstraints = false
        storageProgressIndicator.style = .bar
        storageProgressIndicator.isIndeterminate = false
        storageProgressIndicator.minValue = 0
        storageProgressIndicator.maxValue = 100
        storageAnalyzerView.addSubview(storageProgressIndicator)

        storageSizeLabel = NSTextField(labelWithString: "")
        storageSizeLabel.translatesAutoresizingMaskIntoConstraints = false
        storageSizeLabel.font = NSFont.boldSystemFont(ofSize: 12)
        storageAnalyzerView.addSubview(storageSizeLabel)

        storageItemsLabel = NSTextField(labelWithString: "")
        storageItemsLabel.translatesAutoresizingMaskIntoConstraints = false
        storageItemsLabel.font = NSFont.systemFont(ofSize: 11)
        storageItemsLabel.textColor = .secondaryLabelColor
        storageAnalyzerView.addSubview(storageItemsLabel)

        NSLayoutConstraint.activate([
            storageSizeLabel.topAnchor.constraint(equalTo: storageAnalyzerView.topAnchor, constant: 8),
            storageSizeLabel.leadingAnchor.constraint(equalTo: storageAnalyzerView.leadingAnchor, constant: 12),
            storageSizeLabel.trailingAnchor.constraint(equalTo: storageAnalyzerView.trailingAnchor, constant: -12),

            storageProgressIndicator.topAnchor.constraint(equalTo: storageSizeLabel.bottomAnchor, constant: 6),
            storageProgressIndicator.leadingAnchor.constraint(equalTo: storageAnalyzerView.leadingAnchor, constant: 12),
            storageProgressIndicator.trailingAnchor.constraint(equalTo: storageAnalyzerView.trailingAnchor, constant: -12),

            storageItemsLabel.topAnchor.constraint(equalTo: storageProgressIndicator.bottomAnchor, constant: 6),
            storageItemsLabel.leadingAnchor.constraint(equalTo: storageAnalyzerView.leadingAnchor, constant: 12),
            storageItemsLabel.trailingAnchor.constraint(equalTo: storageAnalyzerView.trailingAnchor, constant: -12)
        ])
    }

    private func updateLayoutForPosition() {
        // This can be customized based on position
        // For now, the layout stays the same, but you could adjust constraints
    }

    // MARK: - Public Methods

    func previewFile(_ fileItem: FileItem?) {
        clearPreview()
        currentFileItem = fileItem

        guard let fileItem = fileItem else {
            titleLabel.stringValue = "Preview"
            return
        }

        titleLabel.stringValue = fileItem.displayName

        if fileItem.isDirectory {
            showStorageAnalyzer(for: fileItem)
        } else {
            let fileExtension = fileItem.url.pathExtension.lowercased()

            switch fileExtension {
            case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp":
                showImagePreview(for: fileItem)
            case "pdf":
                showPDFPreview(for: fileItem)
            case "mp4", "mov", "m4v", "avi", "mkv":
                showVideoPreview(for: fileItem)
            case "mp3", "m4a", "wav", "aac", "flac":
                showAudioPreview(for: fileItem)
            default:
                // Try to preview as text if it's a known text format
                if isTextFile(extension: fileExtension) {
                    showTextPreview(for: fileItem)
                } else {
                    showGenericPreview(for: fileItem)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func isTextFile(extension fileExtension: String) -> Bool {
        let textExtensions: Set<String> = [
            // Plain text
            "txt", "text", "md", "markdown", "rst",

            // Programming languages
            "swift", "js", "ts", "jsx", "tsx", "py", "rb", "java", "kt", "kts",
            "c", "cpp", "cc", "cxx", "h", "hpp", "m", "mm", "go", "rs", "php",
            "scala", "clj", "cljs", "edn", "ex", "exs", "erl", "hrl", "hs", "lhs",
            "lua", "pl", "pm", "r", "R", "sh", "bash", "zsh", "fish",

            // Web
            "html", "htm", "css", "scss", "sass", "less", "xml", "svg",

            // Data/Config
            "json", "yaml", "yml", "toml", "ini", "cfg", "conf", "config",
            "env", "properties", "plist",

            // Build/Project
            "gradle", "maven", "cmake", "make", "makefile", "dockerfile",
            "gitignore", "gitattributes", "dockerignore",

            // Documentation
            "adoc", "asciidoc", "textile", "org",

            // Other
            "sql", "graphql", "gql", "proto", "thrift", "log",
            "csv", "tsv", "diff", "patch"
        ]

        return textExtensions.contains(fileExtension.lowercased())
    }

    private func clearPreview() {
        // Stop any playing video
        currentPlayer?.pause()
        currentPlayer = nil

        // Remove all preview views
        imageView?.removeFromSuperview()
        imageView = nil

        pdfView?.removeFromSuperview()
        pdfView = nil

        videoPlayerView?.removeFromSuperview()
        videoPlayerView = nil

        textView?.removeFromSuperview()
        textView = nil

        metadataStackView?.removeFromSuperview()
        metadataStackView = nil

        quickActionsView.isHidden = true
        storageAnalyzerView.isHidden = true
    }

    // Public wrapper to allow external controllers to clear the preview when selection is empty
    func resetPreview() {
        clearPreview()
    }

    private func showImagePreview(for fileItem: FileItem) {
        // Load image with size constraints to handle large images efficiently
        let image = loadImageWithSizeLimit(from: fileItem.url, maxDimension: 4096)
        guard let image = image else { return }

        let imgView = NSImageView()
        imgView.translatesAutoresizingMaskIntoConstraints = false
        imgView.image = image
        imgView.imageScaling = .scaleProportionallyDown
        imgView.imageAlignment = .alignCenter
        imgView.wantsLayer = true
        imgView.layer?.backgroundColor = NSColor.black.cgColor

        // Prevent image from expanding beyond bounds
        imgView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imgView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imgView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imgView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        contentView.addSubview(imgView)
        imageView = imgView

        // Set contentView size to match scroll view's visible area and enable scrolling
        NSLayoutConstraint.activate([
            imgView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imgView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imgView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imgView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // Make contentView match the scroll view's width but allow scrolling vertically
            contentView.widthAnchor.constraint(equalTo: contentScrollView.widthAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: contentScrollView.heightAnchor)
        ])

        // Show metadata (use original image size from file)
        showImageMetadata(image: image, url: fileItem.url)

        // Show quick actions for images
        quickActionsView.isHidden = false
        rotateButton.isEnabled = true
    }

    private func showPDFPreview(for fileItem: FileItem) {
        guard let document = PDFDocument(url: fileItem.url) else { return }

        let pdfViewer = PDFView()
        pdfViewer.translatesAutoresizingMaskIntoConstraints = false
        pdfViewer.document = document
        pdfViewer.autoScales = true
        pdfViewer.displayMode = .singlePageContinuous
        pdfViewer.displayDirection = .vertical
        contentView.addSubview(pdfViewer)
        pdfView = pdfViewer

        NSLayoutConstraint.activate([
            pdfViewer.topAnchor.constraint(equalTo: contentView.topAnchor),
            pdfViewer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            pdfViewer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            pdfViewer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // Make contentView match the scroll view's content size
            contentView.widthAnchor.constraint(equalTo: contentScrollView.widthAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: contentScrollView.heightAnchor)
        ])

        // Show PDF metadata
        showPDFMetadata(document: document, url: fileItem.url)

        quickActionsView.isHidden = true
    }

    private func showVideoPreview(for fileItem: FileItem) {
        let player = AVPlayer(url: fileItem.url)
        let playerView = AVPlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.player = player
        playerView.controlsStyle = .inline
        playerView.showsFullScreenToggleButton = true
        contentView.addSubview(playerView)

        videoPlayerView = playerView
        currentPlayer = player

        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // Make contentView match the scroll view's content size
            contentView.widthAnchor.constraint(equalTo: contentScrollView.widthAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: contentScrollView.heightAnchor)
        ])

        // Show video metadata
        showVideoMetadata(url: fileItem.url)

        quickActionsView.isHidden = true
    }

    private func showTextPreview(for fileItem: FileItem) {
        guard let content = try? String(contentsOf: fileItem.url, encoding: .utf8) else { return }

        let scrollView = NSTextView.scrollableTextView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.string = content
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

        // Enable word wrapping
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)

        // Disable horizontal scrolling
        scrollView.hasHorizontalScroller = false

        contentView.addSubview(scrollView)
        self.textView = textView

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // Make contentView match the scroll view's content size
            contentView.widthAnchor.constraint(equalTo: contentScrollView.widthAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: contentScrollView.heightAnchor)
        ])

        quickActionsView.isHidden = true
    }

    private func showAudioPreview(for fileItem: FileItem) {
        // For audio, show metadata and a simple player
        showAudioMetadata(url: fileItem.url)

        let player = AVPlayer(url: fileItem.url)
        currentPlayer = player

        // Create simple play/pause button
        let playButton = NSButton()
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.title = "▶"
        playButton.font = NSFont.systemFont(ofSize: 24)
        playButton.bezelStyle = .texturedSquare
        playButton.target = self
        playButton.action = #selector(playPauseAudio)
        contentView.addSubview(playButton)

        NSLayoutConstraint.activate([
            playButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            playButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            playButton.widthAnchor.constraint(equalToConstant: 60),
            playButton.heightAnchor.constraint(equalToConstant: 60)
        ])

        quickActionsView.isHidden = true
    }

    private func showGenericPreview(for fileItem: FileItem) {
        // Show file icon and metadata
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        contentView.addSubview(stackView)
        metadataStackView = stackView

        // Icon and name row
        let iconNameStack = NSStackView()
        iconNameStack.orientation = .horizontal
        iconNameStack.spacing = 12
        iconNameStack.alignment = .centerY

        let iconView = NSImageView()
        iconView.image = fileItem.icon
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 64).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 64).isActive = true
        iconNameStack.addArrangedSubview(iconView)

        let nameLabel = NSTextField(labelWithString: fileItem.displayName)
        nameLabel.font = NSFont.boldSystemFont(ofSize: 14)
        nameLabel.lineBreakMode = .byTruncatingTail
        iconNameStack.addArrangedSubview(nameLabel)

        stackView.addArrangedSubview(iconNameStack)

        // Add separator
        let separator1 = NSBox()
        separator1.boxType = .separator
        separator1.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(separator1)

        // File information section
        stackView.addArrangedSubview(createInfoLabel("General Information", isBold: true))

        // Kind
        let kind = getFileKind(for: fileItem.url)
        stackView.addArrangedSubview(createInfoRow(label: "Kind:", value: kind))

        // Size
        stackView.addArrangedSubview(createInfoRow(label: "Size:", value: fileItem.sizeString))

        // Location
        let location = fileItem.url.deletingLastPathComponent().path
        let locationLabel = createInfoRow(label: "Where:", value: location)
        stackView.addArrangedSubview(locationLabel)

        // Created
        if let created = try? fileItem.url.resourceValues(forKeys: [.creationDateKey]).creationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            stackView.addArrangedSubview(createInfoRow(label: "Created:", value: formatter.string(from: created)))
        }

        // Modified
        if let modified = try? fileItem.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            stackView.addArrangedSubview(createInfoRow(label: "Modified:", value: formatter.string(from: modified)))
        }

        // Last opened (if available)
        if let lastUsed = try? fileItem.url.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            stackView.addArrangedSubview(createInfoRow(label: "Last opened:", value: formatter.string(from: lastUsed)))
        }

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: contentScrollView.widthAnchor),

            separator1.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
        ])

        quickActionsView.isHidden = true
    }

    private func getFileKind(for url: URL) -> String {
        if let typeID = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier {
            if let description = UTType(typeID)?.localizedDescription {
                return description
            }
        }
        return url.pathExtension.uppercased() + " File"
    }

    private func createInfoLabel(_ text: String, isBold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = isBold ? NSFont.boldSystemFont(ofSize: 12) : NSFont.systemFont(ofSize: 11)
        label.textColor = isBold ? .labelColor : .secondaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        return label
    }

    private func createInfoRow(label: String, value: String) -> NSStackView {
        let rowStack = NSStackView()
        rowStack.orientation = .horizontal
        rowStack.spacing = 8
        rowStack.alignment = .firstBaseline

        let labelField = NSTextField(labelWithString: label)
        labelField.font = NSFont.systemFont(ofSize: 11)
        labelField.textColor = .secondaryLabelColor
        labelField.alignment = .right
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        rowStack.addArrangedSubview(labelField)

        let valueField = NSTextField(labelWithString: value)
        valueField.font = NSFont.systemFont(ofSize: 11)
        valueField.textColor = .labelColor
        valueField.lineBreakMode = .byTruncatingMiddle
        valueField.maximumNumberOfLines = 2
        rowStack.addArrangedSubview(valueField)

        return rowStack
    }

    // MARK: - Metadata Display

    private func showImageMetadata(image: NSImage, url: URL) {
        // Metadata is now shown in an overlay at the bottom of the image
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 4
        stackView.alignment = .leading
        stackView.wantsLayer = true
        stackView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        stackView.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        contentView.addSubview(stackView)
        metadataStackView = stackView

        // Get original image dimensions from file (not the potentially downsampled version)
        var width = Int(image.size.width)
        var height = Int(image.size.height)
        
        if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
           let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
           let pixelWidth = imageProperties[kCGImagePropertyPixelWidth] as? Int,
           let pixelHeight = imageProperties[kCGImagePropertyPixelHeight] as? Int {
            width = pixelWidth
            height = pixelHeight
        }
        
        let dimensionLabel = createMetadataLabel("Dimensions: \(width) × \(height)")
        dimensionLabel.textColor = .white
        stackView.addArrangedSubview(dimensionLabel)

        if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 {
            let formattedSize = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            let sizeLabel = createMetadataLabel("Size: \(formattedSize)")
            sizeLabel.textColor = .white
            stackView.addArrangedSubview(sizeLabel)
        }

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    private func showPDFMetadata(document: PDFDocument, url: URL) {
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 4
        stackView.alignment = .leading
        contentView.addSubview(stackView)
        metadataStackView = stackView

        stackView.addArrangedSubview(createMetadataLabel("Pages: \(document.pageCount)"))

        if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 {
            let formattedSize = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            stackView.addArrangedSubview(createMetadataLabel("Size: \(formattedSize)"))
        }

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: pdfView?.bottomAnchor ?? contentView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        ])
    }

    private func showVideoMetadata(url: URL) {
        let asset = AVAsset(url: url)
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 4
        stackView.alignment = .leading
        contentView.addSubview(stackView)
        metadataStackView = stackView
        // Load metadata asynchronously to avoid deprecated synchronous API warnings on macOS 13+
        if #available(macOS 13.0, *) {
            Task { [weak self, weak stackView] in
                do {
                    let duration = try await asset.load(.duration)
                    let durationText = String(format: "Duration: %.0f seconds", CMTimeGetSeconds(duration))
                    await MainActor.run { stackView?.addArrangedSubview(self?.createMetadataLabel(durationText) ?? NSTextField(labelWithString: "")) }

                    if let videoTrack = try await asset.loadTracks(withMediaType: .video).first {
                        let size = try await videoTrack.load(.naturalSize)
                        let res = "Resolution: \(Int(size.width)) × \(Int(size.height))"
                        await MainActor.run { stackView?.addArrangedSubview(self?.createMetadataLabel(res) ?? NSTextField(labelWithString: "")) }
                    }
                } catch {
                    await MainActor.run { stackView?.addArrangedSubview(self?.createMetadataLabel("Metadata unavailable") ?? NSTextField(labelWithString: "")) }
                }
            }
        } else {
            let duration = asset.duration
            let durationText = String(format: "Duration: %.0f seconds", CMTimeGetSeconds(duration))
            stackView.addArrangedSubview(createMetadataLabel(durationText))
            if let track = asset.tracks(withMediaType: .video).first {
                let size = track.naturalSize
                stackView.addArrangedSubview(createMetadataLabel("Resolution: \(Int(size.width)) × \(Int(size.height))"))
            }
        }

        if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 {
            let formattedSize = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            stackView.addArrangedSubview(createMetadataLabel("Size: \(formattedSize)"))
        }

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: videoPlayerView?.bottomAnchor ?? contentView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        ])
    }

    private func showAudioMetadata(url: URL) {
        let asset = AVAsset(url: url)
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 4
        stackView.alignment = .leading
        contentView.addSubview(stackView)
        metadataStackView = stackView
        if #available(macOS 13.0, *) {
            Task { [weak self, weak stackView] in
                do {
                    let duration = try await asset.load(.duration)
                    let durationText = String(format: "Duration: %.0f seconds", CMTimeGetSeconds(duration))
                    await MainActor.run { stackView?.addArrangedSubview(self?.createMetadataLabel(durationText) ?? NSTextField(labelWithString: "")) }

                    if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                        // Load format descriptions asynchronously if available
                        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
                                if let first = formatDescriptions.first,
                                    let streamDesc = CMAudioFormatDescriptionGetStreamBasicDescription(first)?.pointee {
                            let bitsPerChannel = Int(streamDesc.mBitsPerChannel)
                            if bitsPerChannel > 0 {
                                let bitrateLabel = "Bits/Channel: \(bitsPerChannel)"
                                await MainActor.run { stackView?.addArrangedSubview(self?.createMetadataLabel(bitrateLabel) ?? NSTextField(labelWithString: "")) }
                            }
                        }
                    }
                } catch {
                    await MainActor.run { stackView?.addArrangedSubview(self?.createMetadataLabel("Metadata unavailable") ?? NSTextField(labelWithString: "")) }
                }
            }
        } else {
            let duration = asset.duration
            let durationText = String(format: "Duration: %.0f seconds", CMTimeGetSeconds(duration))
            stackView.addArrangedSubview(createMetadataLabel(durationText))
            if let track = asset.tracks(withMediaType: .audio).first {
                if let formatDescriptions = track.formatDescriptions as? [CMFormatDescription],
                   let formatDescription = formatDescriptions.first {
                    let audioBitrate = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee.mBitsPerChannel ?? 0
                    if audioBitrate > 0 {
                        stackView.addArrangedSubview(createMetadataLabel("Bits/Channel: \(Int(audioBitrate))"))
                    }
                }
            }
        }

        if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 {
            let formattedSize = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            stackView.addArrangedSubview(createMetadataLabel("Size: \(formattedSize)"))
        }

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 100),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        ])
    }

    private func createMetadataLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        return label
    }

    // MARK: - Storage Analyzer

    private func showStorageAnalyzer(for fileItem: FileItem) {
        // Show folder metadata similar to file metadata
        showFolderMetadata(for: fileItem)

        storageAnalyzerView.isHidden = false

        // Calculate folder size asynchronously
        Task.detached(priority: .userInitiated) { [weak self] in
            let (totalSize, itemCount) = self?.calculateFolderSize(url: fileItem.url) ?? (0, 0)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
                self?.storageSizeLabel.stringValue = "Total Size: \(formattedSize)"
                self?.storageItemsLabel.stringValue = "\(itemCount) items"

                // Set progress based on available disk space
                if let values = try? fileItem.url.resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeTotalCapacityKey]),
                   let available = values.volumeAvailableCapacity,
                   let total = values.volumeTotalCapacity {
                    let used = Double(total - available)
                    let percentage = (used / Double(total)) * 100
                    self?.storageProgressIndicator.doubleValue = percentage
                }
            }
        }
    }

    private func showFolderMetadata(for fileItem: FileItem) {
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        contentView.addSubview(stackView)

        metadataStackView = stackView

        // Icon and name row
        let iconNameStack = NSStackView()
        iconNameStack.orientation = .horizontal
        iconNameStack.spacing = 12
        iconNameStack.alignment = .centerY

        let iconView = NSImageView()
        iconView.image = NSWorkspace.shared.icon(forFile: fileItem.url.path)
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 64).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 64).isActive = true
        iconNameStack.addArrangedSubview(iconView)

        let nameLabel = NSTextField(labelWithString: fileItem.displayName)
        nameLabel.font = NSFont.boldSystemFont(ofSize: 14)
        nameLabel.lineBreakMode = .byWordWrapping
        nameLabel.maximumNumberOfLines = 0
        iconNameStack.addArrangedSubview(nameLabel)

        stackView.addArrangedSubview(iconNameStack)

        // Add separator
        let separator1 = NSBox()
        separator1.boxType = .separator
        separator1.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(separator1)

        // Information section
        stackView.addArrangedSubview(createInfoLabel("General Information", isBold: true))

        // Kind
        stackView.addArrangedSubview(createInfoRow(label: "Kind:", value: "Folder"))

        // Location
        let location = fileItem.url.deletingLastPathComponent().path
        stackView.addArrangedSubview(createInfoRow(label: "Where:", value: location))

        // Get folder properties
        if let resourceValues = try? fileItem.url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey, .contentAccessDateKey]) {
            if let created = resourceValues.creationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                stackView.addArrangedSubview(createInfoRow(label: "Created:", value: formatter.string(from: created)))
            }

            if let modified = resourceValues.contentModificationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                stackView.addArrangedSubview(createInfoRow(label: "Modified:", value: formatter.string(from: modified)))
            }

            if let lastUsed = resourceValues.contentAccessDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                stackView.addArrangedSubview(createInfoRow(label: "Last opened:", value: formatter.string(from: lastUsed)))
            }
        }

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: contentScrollView.widthAnchor),

            separator1.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
        ])

        quickActionsView.isHidden = true
    }

    private func calculateFolderSize(url: URL) -> (Int64, Int) {
        var totalSize: Int64 = 0
        var itemCount = 0

        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                   let isDirectory = resourceValues.isDirectory,
                   !isDirectory {
                    if let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                    }
                    itemCount += 1
                }
            }
        }

        return (totalSize, itemCount)
    }

    // MARK: - Image Loading Helpers
    
    private func loadImageWithSizeLimit(from url: URL, maxDimension: CGFloat) -> NSImage? {
        // First, try to get the image source to check dimensions
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            // Fallback to regular loading if we can't create image source
            return NSImage(contentsOf: url)
        }
        
        // Get the original image properties without loading the full image
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let pixelWidth = imageProperties[kCGImagePropertyPixelWidth] as? CGFloat,
              let pixelHeight = imageProperties[kCGImagePropertyPixelHeight] as? CGFloat else {
            // Fallback to regular loading if we can't get dimensions
            return NSImage(contentsOf: url)
        }
        
        // Calculate if we need to downsample
        let maxOriginalDimension = max(pixelWidth, pixelHeight)
        
        if maxOriginalDimension <= maxDimension {
            // Image is small enough, load normally
            return NSImage(contentsOf: url)
        }
        
        // Image is too large, create downsampled version
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions as CFDictionary) else {
            // Fallback to regular loading if downsampling fails
            return NSImage(contentsOf: url)
        }
        
        // Convert CGImage to NSImage
        let size = NSSize(width: downsampledImage.width, height: downsampledImage.height)
        let image = NSImage(size: size)
        image.addRepresentation(NSBitmapImageRep(cgImage: downsampledImage))
        
        return image
    }

    // MARK: - Actions

    @objc private func closeButtonClicked() {
        NotificationCenter.default.post(name: .previewPaneCloseRequested, object: nil)
    }

    @objc private func rotateButtonClicked() {
        guard let imageView = imageView, let image = imageView.image else { return }

        // Rotate image 90 degrees clockwise
        let rotatedImage = NSImage(size: NSSize(width: image.size.height, height: image.size.width))
        rotatedImage.lockFocus()

        let transform = NSAffineTransform()
        transform.translateX(by: image.size.height, yBy: 0)
        transform.rotate(byDegrees: 90)
        transform.concat()

        image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
        rotatedImage.unlockFocus()

        imageView.image = rotatedImage

        // Save rotated image if user wants
        if let fileURL = currentFileItem?.url,
           let tiffData = rotatedImage.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let imageData = bitmapImage.representation(using: .jpeg, properties: [:]) {
            try? imageData.write(to: fileURL)
        }
    }

    @objc private func playPauseAudio() {
        guard let player = currentPlayer else { return }

        if player.rate == 0 {
            player.play()
        } else {
            player.pause()
        }
    }
}

extension Notification.Name {
    static let previewPaneCloseRequested = Notification.Name("previewPaneCloseRequested")
}
