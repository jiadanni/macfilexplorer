import Cocoa

// Custom view that provides immediate visual feedback on mouse down
protocol SelectableItemViewDelegate: AnyObject {
    func itemViewDidReceiveMouseDown()
}

class SelectableItemView: NSView {
    weak var itemDelegate: SelectableItemViewDelegate?
    
    override func mouseDown(with event: NSEvent) {
        // Notify delegate immediately on mouse down for instant visual feedback
        itemDelegate?.itemViewDidReceiveMouseDown()
        // Pass the event to super to maintain normal selection behavior
        super.mouseDown(with: event)
    }
}

class FileIconItem: NSCollectionViewItem, SelectableItemViewDelegate {

    var fileItem: FileItem? {
        didSet {
            updateView()
        }
    }
    
    var isListMode: Bool = false // Set to true for Windows List view

    private var myImageView: NSImageView?
    private var myTextField: NSTextField?
    private var hasSetupUI = false
    private var currentConstraints: [NSLayoutConstraint] = []
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        // Don't call commonInit here - let loadView handle it
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        // Don't call commonInit here - let loadView handle it
    }

    override func loadView() {
        // Always create a fresh view
        // Size will be determined by the collection view's layout
        let containerView = SelectableItemView(frame: NSRect(x: 0, y: 0, width: 100, height: 120))
        containerView.wantsLayer = true
        containerView.itemDelegate = self
        self.view = containerView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Set up UI once when view is loaded
        if !hasSetupUI {
            setupUI()
            hasSetupUI = true
        }
    }

    private func setupUI() {
        // Prevent double setup
        guard myImageView == nil else {
            // If already set up but mode changed, update constraints
            updateLayoutConstraints()
            return
        }
        
        myImageView = NSImageView()
        myImageView?.translatesAutoresizingMaskIntoConstraints = false
        myImageView?.imageScaling = .scaleProportionallyDown
        myImageView?.isEditable = false
        view.addSubview(myImageView!)
        self.imageView = myImageView // Assign to the NSCollectionViewItem's imageView property

        myTextField = NSTextField(labelWithString: "")
        myTextField?.translatesAutoresizingMaskIntoConstraints = false
        myTextField?.usesSingleLineMode = true
        myTextField?.maximumNumberOfLines = 1
        myTextField?.lineBreakMode = .byTruncatingTail
        myTextField?.font = NSFont.systemFont(ofSize: 11)
        myTextField?.isBordered = false
        myTextField?.isEditable = false
        myTextField?.isSelectable = false
        myTextField?.drawsBackground = false
        view.addSubview(myTextField!)
        self.textField = myTextField // Assign to the NSCollectionViewItem's textField property
        
        updateLayoutConstraints()
    }
    
    private func updateLayoutConstraints() {
        // Remove existing constraints
        NSLayoutConstraint.deactivate(currentConstraints)
        currentConstraints.removeAll()
        
        guard let myImageView = myImageView, let myTextField = myTextField else { return }
        
        if isListMode {
            // Horizontal layout for Windows List view: [icon] [label]
            myTextField.alignment = .left
            currentConstraints = [
                myImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
                myImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                myImageView.widthAnchor.constraint(equalToConstant: 16),
                myImageView.heightAnchor.constraint(equalToConstant: 16),
                
                myTextField.leadingAnchor.constraint(equalTo: myImageView.trailingAnchor, constant: 4),
                myTextField.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                myTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2)
            ]
        } else {
            // Vertical layout for Icons view: icon above label
            myTextField.alignment = .center
            currentConstraints = [
                myImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                myImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 5),
                myImageView.widthAnchor.constraint(equalToConstant: 64),
                myImageView.heightAnchor.constraint(equalToConstant: 64),

                myTextField.topAnchor.constraint(equalTo: myImageView.bottomAnchor, constant: 5),
                myTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
                myTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2),
                myTextField.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -5)
            ]
        }
        
        NSLayoutConstraint.activate(currentConstraints)
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

        // Apply dimmed appearance for cut files
        if isFileCut(fileItem.url) {
            myImageView?.alphaValue = 0.5
            myTextField?.alphaValue = 0.5
        } else {
            myImageView?.alphaValue = 1.0
            myTextField?.alphaValue = 1.0
        }
    }

    // Helper method to check if a file is in the cut state
    private func isFileCut(_ url: URL) -> Bool {
        let pasteboard = NSPasteboard.general
        guard pasteboard.string(forType: NSPasteboard.PasteboardType("com.macfileexplorer.cutOperation")) == "cut",
              let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else {
            return false
        }
        return urls.contains(url)
    }
    
    override var isSelected: Bool {
        didSet {
            updateSelectionAppearance()
        }
    }
    
    private func updateSelectionAppearance() {
        // Update visual appearance based on selection state
        if isSelected {
            view.layer?.backgroundColor = NSColor.selectedContentBackgroundColor.cgColor
        } else {
            view.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    // MARK: - SelectableItemViewDelegate
    
    func itemViewDidReceiveMouseDown() {
        // Provide immediate visual feedback on mouse down
        // Temporarily show selection appearance until the actual selection state is set
        view.layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.5).cgColor
    }
}
