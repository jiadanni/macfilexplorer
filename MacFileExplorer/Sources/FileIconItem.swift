import Cocoa

class FileIconItem: NSCollectionViewItem {

    var fileItem: FileItem? {
        didSet {
            updateView()
        }
    }

    private var myImageView: NSImageView?
    private var myTextField: NSTextField?
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func loadView() {
        // Create and configure the view
        let containerView = NSView()
        containerView.wantsLayer = true
        self.view = containerView
        
        // Set up the UI immediately in loadView to ensure it's ready
        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    private func setupUI() {
        // Prevent double setup
        guard myImageView == nil else { return }
        
        myImageView = NSImageView()
        myImageView?.translatesAutoresizingMaskIntoConstraints = false
        myImageView?.imageScaling = .scaleProportionallyDown
        view.addSubview(myImageView!)
        self.imageView = myImageView // Assign to the NSCollectionViewItem's imageView property

        myTextField = NSTextField(labelWithString: "")
        myTextField?.translatesAutoresizingMaskIntoConstraints = false
        myTextField?.usesSingleLineMode = true
        myTextField?.maximumNumberOfLines = 1
        myTextField?.lineBreakMode = .byTruncatingTail
        myTextField?.alignment = .center
        view.addSubview(myTextField!)
        self.textField = myTextField // Assign to the NSCollectionViewItem's textField property

        NSLayoutConstraint.activate([
            myImageView!.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            myImageView!.topAnchor.constraint(equalTo: view.topAnchor, constant: 5),
            myImageView!.widthAnchor.constraint(equalToConstant: 64),
            myImageView!.heightAnchor.constraint(equalToConstant: 64),

            myTextField!.topAnchor.constraint(equalTo: myImageView!.bottomAnchor, constant: 5),
            myTextField!.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
            myTextField!.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2),
            myTextField!.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -5)
        ])
    }

    private func updateView() {
        guard let fileItem = fileItem else { return }
        myImageView?.image = fileItem.icon
        myTextField?.stringValue = fileItem.name

        // Apply custom folder color if set
        if fileItem.isDirectory, let customColor = ColorManager.shared.getColor(for: fileItem.url) {
            myImageView?.contentTintColor = customColor
        } else {
            myImageView?.contentTintColor = nil // Reset tint color
        }
    }
}
