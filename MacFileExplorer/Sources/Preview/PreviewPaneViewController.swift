import Cocoa
import AVKit
import PDFKit

enum PreviewPanePosition {
    case right
    case bottom
    case hidden
}

class PreviewPaneViewController: NSViewController {

    /// Injected settings store for display preferences
    var settings: SettingsStoreProtocol = SettingsStore.shared

    private var containerView: NSView!
    private var headerView: NSView!
    private var titleLabel: NSTextField!
    private var closeButton: NSButton!
    private final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }
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

    /// Invoked by the header close button; the owning coordinator hides the pane.
    var onCloseRequested: (() -> Void)?

    override func loadView() {
        let surface = ChromeSurfaceView(fillColor: AppDesignSystem.Chrome.contentBackground)
        surface.frame = NSRect(x: 0, y: 0, width: 260, height: 600)
        view = surface
        view.translatesAutoresizingMaskIntoConstraints = false

        // Prevent layout issues
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        setupUI()
    }

    private func setupUI() {
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Header: "Preview" caption + current file name, matching the terminal header
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(headerView)

        let captionLabel = NSTextField(labelWithString: L10n.text("Preview"))
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        captionLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        captionLabel.textColor = .secondaryLabelColor
        captionLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        headerView.addSubview(captionLabel)

        titleLabel = NSTextField(labelWithString: "")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 11)
        titleLabel.textColor = .tertiaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setAccessibilityIdentifier("PreviewTitle")
        headerView.addSubview(titleLabel)

        let closeIcon = ToolbarIconButton(symbolName: "xmark", accessibilityDescription: L10n.text("Close Preview"))
        closeIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        closeIcon.toolTip = L10n.text("Hide Preview Pane")
        closeIcon.target = self
        closeIcon.action = #selector(closeButtonClicked)
        closeButton = closeIcon
        headerView.addSubview(closeButton)

        let headerDivider = HairlineView()
        headerView.addSubview(headerDivider)

        // Quick Actions (keep layout but hide by default)
        quickActionsView = NSView()
        quickActionsView.translatesAutoresizingMaskIntoConstraints = false
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
        contentScrollView.drawsBackground = false
        containerView.addSubview(contentScrollView)
        
        contentView = FlippedView()
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
            headerView.heightAnchor.constraint(equalToConstant: 30),

            captionLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            captionLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: captionLabel.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -8),

            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 22),
            closeButton.heightAnchor.constraint(equalToConstant: 22),

            headerDivider.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerDivider.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            headerDivider.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),

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
            titleLabel.stringValue = ""
            return
        }
        
        titleLabel.stringValue = fileItem.displayName(showExtensions: settings.showFileExtensions)
        
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
        titleLabel.stringValue = ""
        currentHandler = nil
    }
    
    private func updateLayoutForPosition() {
        // ...
    }
    
    @objc private func closeButtonClicked() {
        onCloseRequested?()
    }
    
    @objc private func rotateButtonClicked() {
        currentHandler?.rotate()
    }
}
