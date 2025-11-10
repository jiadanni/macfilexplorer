import Cocoa

class FileIconItem: NSCollectionViewItem {

    var fileItem: FileItem? {
        didSet {
            updateView()
        }
    }

    override func loadView() {
        self.view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        imageView = NSImageView()
        imageView?.translatesAutoresizingMaskIntoConstraints = false
        imageView?.imageScaling = .scaleProportionallyDown
        view.addSubview(imageView!)

        textField = NSTextField(labelWithString: "")
        textField?.translatesAutoresizingMaskIntoConstraints = false
        textField?.usesSingleLineMode = true
        textField?.maximumNumberOfLines = 1
        textField?.lineBreakMode = .byTruncatingTail
        textField?.alignment = .center
        view.addSubview(textField!)

        NSLayoutConstraint.activate([
            imageView!.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView!.topAnchor.constraint(equalTo: view.topAnchor, constant: 5),
            imageView!.widthAnchor.constraint(equalToConstant: 64),
            imageView!.heightAnchor.constraint(equalToConstant: 64),

            textField!.topAnchor.constraint(equalTo: imageView!.bottomAnchor, constant: 5),
            textField!.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
            textField!.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2),
            textField!.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -5)
        ])
    }

    private func updateView() {
        guard let fileItem = fileItem else { return }
        imageView?.image = fileItem.icon
        textField?.stringValue = fileItem.name

        // Apply custom folder color if set
        if fileItem.isDirectory, let customColor = ColorManager.shared.getColor(for: fileItem.url) {
            imageView?.contentTintColor = customColor
        } else {
            imageView?.contentTintColor = nil // Reset tint color
        }
    }
}
