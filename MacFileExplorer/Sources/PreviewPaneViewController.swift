import Cocoa
import AVKit
import PDFKit

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
    private var quickActionsView: NSView!
    private var rotateButton: NSButton!
    
    // Handler Management
    private var handlers: [PreviewHandler] = [
        ImagePreviewHandler(),
        PDFPreviewHandler(),
        AVPreviewHandler(),
        TextPreviewHandler(),
        GenericPreviewHandler()
    ]
    
    private var currentHandler: PreviewHandler?
    
    var position: PreviewPanePosition = .right {
        didSet { updateLayoutForPosition() }
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 350, height: 600))
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // Prevent layout issues
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        setupUI()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Header
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        containerView.addSubview(headerView)

        titleLabel = NSTextField(labelWithString: "Preview")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        titleLabel.setAccessibilityIdentifier("PreviewTitle")
        headerView.addSubview(titleLabel)

        closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .texturedSquare
        closeButton.isBordered = false
        closeButton.title = "×"
        closeButton.font = NSFont.systemFont(ofSize: 18)
        closeButton.target = self
        closeButton.action = #selector(closeButtonClicked)
        headerView.addSubview(closeButton)

        // Quick Actions (keep layout but hide by default)
        quickActionsView = NSView()
        quickActionsView.translatesAutoresizingMaskIntoConstraints = false
        quickActionsView.wantsLayer = true
        quickActionsView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        quickActionsView.isHidden = true
        containerView.addSubview(quickActionsView)
        setupQuickActions()

        // Content Scroll View
        contentScrollView = NSScrollView()
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.hasVerticalScroller = true
        contentScrollView.hasHorizontalScroller = true
        contentScrollView.autohidesScrollers = true
        contentScrollView.borderType = .noBorder
        containerView.addSubview(contentScrollView)
        
        contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.documentView = contentView

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
            
            quickActionsView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            quickActionsView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            quickActionsView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor), // Anchored to bottom
            quickActionsView.heightAnchor.constraint(equalToConstant: 44),

            contentScrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            contentScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            contentScrollView.bottomAnchor.constraint(equalTo: quickActionsView.topAnchor)
        ])
    }
    
    private func setupQuickActions() {
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        quickActionsView.addSubview(stackView)
        
        rotateButton = NSButton()
        rotateButton.title = "Rotate"
        rotateButton.bezelStyle = .rounded
        rotateButton.target = self
        rotateButton.action = #selector(rotateButtonClicked)
        stackView.addArrangedSubview(rotateButton)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: quickActionsView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: quickActionsView.trailingAnchor, constant: -8),
            stackView.centerYAnchor.constraint(equalTo: quickActionsView.centerYAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    func previewFile(_ fileItem: FileItem?) {
        resetPreview()
        
        guard let fileItem = fileItem else {
            titleLabel.stringValue = "Preview"
            return
        }
        
        titleLabel.stringValue = fileItem.displayName(showExtensions: SettingsStore.shared.showFileExtensions)
        
        // Find handler
        guard let handler = handlers.first(where: { $0.canHandle(fileItem) }) else { return }
        currentHandler = handler
        
        let previewView = handler.createView(for: fileItem)
        previewView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.subviews.forEach { $0.removeFromSuperview() }
        contentView.addSubview(previewView)
        
        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: contentView.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Constrain content view
             contentView.widthAnchor.constraint(equalTo: contentScrollView.widthAnchor),
             contentView.heightAnchor.constraint(greaterThanOrEqualTo: contentScrollView.heightAnchor)
        ])
        
        // Configure actions
        quickActionsView.isHidden = !handler.supportsRotation
        rotateButton.isEnabled = handler.supportsRotation
    }
    
    func resetPreview() {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        quickActionsView.isHidden = true
        titleLabel.stringValue = "Preview"
        currentHandler = nil
    }
    
    private func updateLayoutForPosition() {
        // ...
    }
    
    @objc private func closeButtonClicked() {
        // Handle close
        view.isHidden = true
        // Logic to notify parent split view controller might be needed here to actually collapse
    }
    
    @objc private func rotateButtonClicked() {
        currentHandler?.rotate()
    }
}
