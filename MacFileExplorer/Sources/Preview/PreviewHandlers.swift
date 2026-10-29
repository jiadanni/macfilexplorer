import Cocoa
import AVKit
import PDFKit
import Quartz
import UniformTypeIdentifiers

/// Shared settings accessor for preview handlers.
/// Can be overridden in tests by setting `PreviewHandlerSettings.store`.
enum PreviewHandlerSettings {
    static var store: SettingsStoreProtocol = SettingsStore.shared
}

// MARK: - Image Handler

class ImagePreviewHandler: PreviewHandler {
    private weak var currentImageView: NSImageView?

    func canHandle(_ file: FileItem) -> Bool {
        let ext = file.url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"].contains(ext)
    }

    func createView(for file: FileItem) -> NSView {
         // Load image logic (simplified or extracted)
        // One CGImageSource serves both the thumbnail and the metadata overlay.
        let imageSource = CGImageSourceCreateWithURL(file.url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
        let image = imageSource.flatMap { loadImageWithSizeLimit(from: $0, maxDimension: 2048) } ?? NSImage()
        
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let imgView = NSImageView()
        imgView.translatesAutoresizingMaskIntoConstraints = false
        imgView.image = image
        // Reset rotation
        imgView.frameCenterRotation = 0
        
        self.currentImageView = imgView
        
        imgView.imageScaling = .scaleProportionallyDown
        imgView.imageScaling = .scaleProportionallyDown
        imgView.imageAlignment = .alignCenter
        imgView.wantsLayer = true
        imgView.layer?.backgroundColor = NSColor.black.cgColor
        
        container.addSubview(imgView)
        
        // Metadata overlay
        let metadataView = createMetadataOverlay(image: image, source: imageSource, fileSize: file.size)
        container.addSubview(metadataView)
        
        NSLayoutConstraint.activate([
            imgView.topAnchor.constraint(equalTo: container.topAnchor),
            imgView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imgView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imgView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            metadataView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            metadataView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -12),
            metadataView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
        
        return container
    }
    
    var supportsRotation: Bool { return true }
    
    func rotate() {
        guard let imgView = currentImageView else { return }
        imgView.frameCenterRotation -= 90
    }
    
    private func createMetadataOverlay(image: NSImage, source: CGImageSource?, fileSize: Int64) -> NSView {
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 4
        stackView.alignment = .leading
        stackView.wantsLayer = true
        stackView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        stackView.layer?.cornerRadius = 4
        stackView.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        
        var width = Int(image.size.width)
        var height = Int(image.size.height)
        
        if let imageSource = source,
           let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
           let pixelWidth = imageProperties[kCGImagePropertyPixelWidth] as? Int,
           let pixelHeight = imageProperties[kCGImagePropertyPixelHeight] as? Int {
            width = pixelWidth
            height = pixelHeight
        }
        
        let dimLabel = NSTextField(labelWithString: "Dimensions: \(width) × \(height)")
        dimLabel.font = NSFont.systemFont(ofSize: 11)
        dimLabel.textColor = .white
        stackView.addArrangedSubview(dimLabel)
        
        if fileSize > 0 {
            let formattedSize = FileBrowserActionHelper.formatFileSize(fileSize)
            let sizeLabel = NSTextField(labelWithString: "Size: \(formattedSize)")
            sizeLabel.font = NSFont.systemFont(ofSize: 11)
            sizeLabel.textColor = .white
            stackView.addArrangedSubview(sizeLabel)
        }
        
        return stackView
    }
    
    // Helper to avoid large image memory issues
    private func loadImageWithSizeLimit(from imageSource: CGImageSource, maxDimension: CGFloat) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: false,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
            return NSImage(cgImage: cgImage, size: NSZeroSize)
        }
        return nil
    }
}

// MARK: - PDF Handler

class PDFPreviewHandler: PreviewHandler {
    func canHandle(_ file: FileItem) -> Bool {
        return file.url.pathExtension.lowercased() == "pdf"
    }
    
    func createView(for file: FileItem) -> NSView {
        guard let document = PDFDocument(url: file.url) else { return NSView() }
        
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(pdfView)
        
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: container.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // Only adding metadata if needed, maybe handled outside
        return container
    }
}

// MARK: - AV Handler

class AVPreviewHandler: PreviewHandler {
    func canHandle(_ file: FileItem) -> Bool {
        let ext = file.url.pathExtension.lowercased()
        let videoExts = ["mp4", "mov", "m4v", "avi", "mkv"]
        let audioExts = ["mp3", "m4a", "wav", "aac", "flac"]
        return videoExts.contains(ext) || audioExts.contains(ext)
    }
    
    func createView(for file: FileItem) -> NSView {
        let player = AVPlayer(url: file.url)
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = .inline
        playerView.translatesAutoresizingMaskIntoConstraints = false
        // Autoplay? Maybe not for preview.
        
        return playerView
    }
}

// MARK: - Text Handler

class TextPreviewHandler: PreviewHandler {
    func canHandle(_ file: FileItem) -> Bool {
        // Reuse logic or simplify
        let ext = file.url.pathExtension.lowercased()
        let textExtensions = ["txt", "md", "swift", "js", "json", "xml", "html", "css", "py", "sh"]
        return textExtensions.contains(ext)
    }
    
    static let maxPreviewBytes = 1_000_000 // 1MB limit

    func createView(for file: FileItem) -> NSView {
        // The cap is enforced on the bytes actually read from an opened descriptor, never
        // on the size cached at listing time: that value is wrong for special files
        // (FIFOs, devices reached through symlinks) and for files that have since grown.
        guard let prefix = Self.readBoundedPrefix(of: file.url, limit: Self.maxPreviewBytes) else {
            return Self.messageView(L10n.text("Preview unavailable: this item is not a regular, readable file."))
        }
        guard var content = Self.decodeText(prefix.data, truncated: prefix.truncated) else {
            return Self.messageView(L10n.text("Preview unavailable: this file is not UTF-8 text."))
        }
        if prefix.truncated {
            content += "\n\n[Preview truncated due to file size]"
        }

        let scrollView = NSTextView.scrollableTextView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        guard let textView = scrollView.documentView as? NSTextView else { return NSView() }
        textView.string = content
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        
        return scrollView
    }

    /// Reads at most `limit` bytes from `url`, and only if it is a regular file.
    /// Opens non-blocking so a FIFO cannot hang the caller, and checks the *opened*
    /// descriptor with `fstat` so a symlink to a device (e.g. `/dev/zero`) is refused.
    static func readBoundedPrefix(of url: URL, limit: Int) -> (data: Data, truncated: Bool)? {
        let fd = open(url.path, O_RDONLY | O_NONBLOCK)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var info = stat()
        guard fstat(fd, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { return nil }

        var data = Data()
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        while data.count <= limit {
            let wanted = min(chunk.count, limit + 1 - data.count)
            let count = read(fd, &chunk, wanted)
            if count < 0 {
                if errno == EINTR { continue }
                return nil
            }
            if count == 0 { break }
            data.append(contentsOf: chunk[0..<count])
        }
        if data.count > limit {
            return (Data(data.prefix(limit)), true)
        }
        return (data, false)
    }

    /// Strict UTF-8 (or BOM-marked UTF-16) decoding. A truncated prefix may end in the
    /// middle of a multi-byte sequence, so it is decoded leniently.
    static func decodeText(_ data: Data, truncated: Bool) -> String? {
        if data.contains(0) && !(data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF])) {
            return nil // binary content
        }
        if truncated { return String(decoding: data, as: UTF8.self) }
        if let text = String(data: data, encoding: .utf8) { return text }
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16)
        }
        return nil
    }

    private static func messageView(_ message: String) -> NSView {
        let label = NSTextField(wrappingLabelWithString: message)
        label.alignment = .center
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20)
        ])
        return container
    }
}

// MARK: - Generic Handler

class GenericPreviewHandler: PreviewHandler {
    func canHandle(_ file: FileItem) -> Bool {
        return true // Fallback
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("dMMMyjmm")
        return formatter
    }()

    /// Centered info card: large icon, name, "Kind · Size", then a
    /// Modified / Where grid under a hairline.
    func createView(for file: FileItem) -> NSView {
        let settings = PreviewHandlerSettings.store

        let iconView = NSImageView()
        iconView.image = file.icon(useGrayscale: settings.useGrayscaleIcons)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 72).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let nameLabel = NSTextField(wrappingLabelWithString: file.displayName(showExtensions: settings.showFileExtensions))
        nameLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        nameLabel.alignment = .center
        nameLabel.maximumNumberOfLines = 3

        // sizeString uses "--" for folders without a computed size
        let sizeText = file.sizeString == "--" ? "—" : file.sizeString
        let summaryLabel = NSTextField(labelWithString: "\(file.kind) · \(sizeText)")
        summaryLabel.font = AppDesignSystem.Typography.caption
        summaryLabel.textColor = .secondaryLabelColor
        summaryLabel.alignment = .center
        summaryLabel.lineBreakMode = .byTruncatingTail

        let titleStack = NSStackView(views: [nameLabel, summaryLabel])
        titleStack.orientation = .vertical
        titleStack.alignment = .centerX
        titleStack.spacing = 2

        let divider = HairlineView()

        let whereText = (file.url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
        let modifiedText = file.modificationDate.map { Self.dateFormatter.string(from: $0) } ?? "—"
        let grid = NSGridView(views: [
            [Self.metadataKey(L10n.text("Modified")), Self.metadataValue(modifiedText)],
            [Self.metadataKey(L10n.text("Where")), Self.metadataValue(whereText)]
        ])
        grid.rowSpacing = 6
        grid.columnSpacing = 12
        grid.column(at: 1).xPlacement = .trailing

        let stackView = NSStackView(views: [iconView, titleStack, divider, grid])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = 16
        stackView.edgeInsets = NSEdgeInsets(top: 32, left: 20, bottom: 20, right: 20)
        stackView.setCustomSpacing(12, after: divider)

        NSLayoutConstraint.activate([
            titleStack.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40),
            divider.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40),
            grid.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40)
        ])
        return stackView
    }

    private static func metadataKey(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = AppDesignSystem.Typography.caption
        label.textColor = .secondaryLabelColor
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    private static func metadataValue(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = AppDesignSystem.Typography.caption
        label.alignment = .right
        label.lineBreakMode = .byTruncatingMiddle
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }
}
