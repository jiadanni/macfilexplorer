import Cocoa

class PreviewViewController: NSViewController {

    var fileItem: FileItem? {
        didSet {
            updatePreview()
        }
    }

    private var imageLoadTask: Task<Void, Never>?

    private let nameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.boldSystemFont(ofSize: 16)
        return label
    }()

    private let pathLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }()

    private let typeLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 12)
        return label
    }()

    private let sizeLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 12)
        return label
    }()
    
    private let imageView: NSImageView = {
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.isHidden = true // Hidden by default, shown for images
        return imageView
    }()

    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updatePreview()
    }

    private func setupUI() {
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        stackView.addArrangedSubview(nameLabel)
        stackView.addArrangedSubview(pathLabel)
        stackView.addArrangedSubview(typeLabel)
        stackView.addArrangedSubview(sizeLabel)
        stackView.addArrangedSubview(imageView)
        
        // Add a flexible space to push content to the top
        stackView.addArrangedSubview(NSView())

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            imageView.widthAnchor.constraint(lessThanOrEqualTo: stackView.widthAnchor, multiplier: 0.8),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: stackView.heightAnchor, multiplier: 0.5)
        ])
    }

    private func updatePreview() {
        guard isViewLoaded else { return }

        imageLoadTask?.cancel()
        imageLoadTask = nil

        if let item = fileItem {
            nameLabel.stringValue = item.name
            pathLabel.stringValue = item.url.path
            typeLabel.stringValue = "Type: \(item.kind)"
            sizeLabel.stringValue = "Size: \(item.sizeString)"
            
            // Handle image preview
            if item.isImage {
                imageView.isHidden = false
                let targetURL = item.url
                imageLoadTask = Task.detached(priority: .userInitiated) { [weak self] in
                    let image = NSImage(contentsOf: targetURL)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self?.imageView.image = image
                    }
                }
            } else {
                imageView.isHidden = true
                imageView.image = nil
            }

            // TODO: Add more sophisticated preview logic for other file types (text, PDF, etc.)
        } else {
            nameLabel.stringValue = "No file selected"
            pathLabel.stringValue = ""
            typeLabel.stringValue = ""
            sizeLabel.stringValue = ""
            imageView.isHidden = true
            imageView.image = nil
        }
    }
}
