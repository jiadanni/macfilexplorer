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
        let image = loadImageWithSizeLimit(from: file.url, maxDimension: 4096) ?? NSImage()
        
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
        let metadataView = createMetadataOverlay(image: image, url: file.url)
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
    
    private func createMetadataOverlay(image: NSImage, url: URL) -> NSView {
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
        
        if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
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
        
        if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 {
            let formattedSize = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            let sizeLabel = NSTextField(labelWithString: "Size: \(formattedSize)")
            sizeLabel.font = NSFont.systemFont(ofSize: 11)
            sizeLabel.textColor = .white
            stackView.addArrangedSubview(sizeLabel)
        }
        
        return stackView
    }
    
    // Helper to avoid large image memory issues
    private func loadImageWithSizeLimit(from url: URL, maxDimension: CGFloat) -> NSImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
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
    
    func createView(for file: FileItem) -> NSView {
        let maxPreviewBytes = 1_000_000 // 1MB limit
        var content: String?

        if file.size > Int64(maxPreviewBytes) {
            // Read only prefix to avoid DoS on large files
            do {
                let handle = try FileHandle(forReadingFrom: file.url)
                defer { try? handle.close() }
                if let data = try handle.read(upToCount: maxPreviewBytes) {
                    content = String(decoding: data, as: UTF8.self) + "\n\n[Preview truncated due to file size]"
                }
            } catch {
                debugLog("Error reading partial file: \(error)")
            }
        } else {
            content = try? String(contentsOf: file.url, encoding: .utf8)
        }

        guard let finalContent = content else { return NSView() }
        
        let scrollView = NSTextView.scrollableTextView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        guard let textView = scrollView.documentView as? NSTextView else { return NSView() }
        textView.string = finalContent
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        
        return scrollView
    }
}

// MARK: - Generic Handler

class GenericPreviewHandler: PreviewHandler {
    func canHandle(_ file: FileItem) -> Bool {
        return true // Fallback
    }
    
    func createView(for file: FileItem) -> NSView {
         let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        // Icon and name row
        let iconNameStack = NSStackView()
        iconNameStack.orientation = .horizontal
        iconNameStack.spacing = 12
        iconNameStack.alignment = .centerY

        let iconView = NSImageView()
        iconView.image = file.icon(useGrayscale: PreviewHandlerSettings.store.useGrayscaleIcons)
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 64).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 64).isActive = true
        iconNameStack.addArrangedSubview(iconView)

        let nameLabel = NSTextField(labelWithString: file.displayName(showExtensions: PreviewHandlerSettings.store.showFileExtensions))
        nameLabel.font = NSFont.boldSystemFont(ofSize: 14)
        nameLabel.lineBreakMode = .byTruncatingTail
        iconNameStack.addArrangedSubview(nameLabel)

        stackView.addArrangedSubview(iconNameStack)

        // Separator
        let separator = NSBox()
        separator.boxType = .separator
        stackView.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40).isActive = true
        
        // Info
        stackView.addArrangedSubview(NSTextField(labelWithString: "Kind: \(file.url.pathExtension.uppercased())"))
        stackView.addArrangedSubview(NSTextField(labelWithString: "Size: \(file.sizeString)"))
        
        return stackView
    }
}
