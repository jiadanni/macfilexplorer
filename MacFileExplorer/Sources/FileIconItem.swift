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
        // Pass to next responder to ensure selection works in NSCollectionView
        self.nextResponder?.mouseDown(with: event)
    }
}

class FileIconItem: NSCollectionViewItem, SelectableItemViewDelegate {

    var fileItem: FileItem? {
        didSet {
            updateView()
        }
    }

    var isListMode: Bool = false { // Set to true for Windows List view
        didSet {
            guard isListMode != oldValue else { return }
            if myImageView == nil {
                setupUI()
            }
            updateLayoutConstraints()
        }
    }
    var zoomLevel: Double = 1.0 {
        didSet {
            // Ensure UI is set up before updating constraints
            if myImageView == nil {
                setupUI()
            }
            updateLayoutConstraints()
            updateFontSize()
        }
    }
    var showCheckbox: Bool = false {
        didSet {
            if showCheckbox != oldValue {
                // Ensure UI is set up before updating constraints
                if myImageView == nil {
                    setupUI()
                }
                updateLayoutConstraints()
            }
        }
    }

    private var myImageView: NSImageView?
    private var myTextField: NSTextField?
    private var myCheckbox: NSButton?
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
        containerView.layer?.masksToBounds = true // Clip subviews to bounds
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
        
        // Observe accent color changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accentColorDidChange),
            name: .accentColorDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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
        myTextField?.cell?.wraps = false // Ensure no wrapping
        myTextField?.cell?.truncatesLastVisibleLine = true
        myTextField?.preferredMaxLayoutWidth = 100 // Constrain text width
        view.addSubview(myTextField!)
        self.textField = myTextField // Assign to the NSCollectionViewItem's textField property

        // Create checkbox (will be shown/hidden based on showCheckbox property)
        myCheckbox = AccentCheckbox(title: "", target: self, action: #selector(checkboxToggled(_:)))
        myCheckbox?.translatesAutoresizingMaskIntoConstraints = false
        myCheckbox?.isHidden = !showCheckbox
        view.addSubview(myCheckbox!)

        // Accessibility
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.button)

        updateLayoutConstraints()
        updateFontSize()
    }

    @objc private func checkboxToggled(_ sender: NSButton) {
        // Toggle selection when checkbox is clicked
        isSelected = (sender.state == .on)
    }

    private func updateFontSize() {
        guard let myTextField = myTextField else { return }
        // Scale font size with zoom but maintain minimum readable size
        let baseFontSize: CGFloat = 11
        let scaledFontSize = max(8, baseFontSize * zoomLevel) // Minimum 8pt
        myTextField.font = NSFont.systemFont(ofSize: scaledFontSize)

        // Update max width to scale with zoom level (base 100pt * zoom)
        // This ensures text doesn't overflow at higher zoom levels
        myTextField.preferredMaxLayoutWidth = 100 * zoomLevel
    }
    
    private func updateLayoutConstraints() {
        // Remove existing constraints
        NSLayoutConstraint.deactivate(currentConstraints)
        currentConstraints.removeAll()

        guard let myImageView = myImageView, let myTextField = myTextField, let myCheckbox = myCheckbox else { return }

        // Update checkbox visibility
        myCheckbox.isHidden = !showCheckbox

        if isListMode {
            // Horizontal layout for Windows List view: [checkbox?] [icon] [label]
            myTextField.alignment = .left
            let iconSize = max(12, CGFloat(16 * zoomLevel)) // Scale icon but keep minimum size
            let spacing = max(2, CGFloat(4 * zoomLevel)) // Scale spacing with zoom

            if showCheckbox {
                currentConstraints = [
                    myCheckbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
                    myCheckbox.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    myCheckbox.widthAnchor.constraint(equalToConstant: 18),

                    myImageView.leadingAnchor.constraint(equalTo: myCheckbox.trailingAnchor, constant: 2),
                    myImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    myImageView.widthAnchor.constraint(equalToConstant: iconSize),
                    myImageView.heightAnchor.constraint(equalToConstant: iconSize),

                    myTextField.leadingAnchor.constraint(equalTo: myImageView.trailingAnchor, constant: spacing),
                    myTextField.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    myTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2)
                ]
            } else {
                currentConstraints = [
                    myImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
                    myImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    myImageView.widthAnchor.constraint(equalToConstant: iconSize),
                    myImageView.heightAnchor.constraint(equalToConstant: iconSize),

                    myTextField.leadingAnchor.constraint(equalTo: myImageView.trailingAnchor, constant: spacing),
                    myTextField.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    myTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2)
                ]
            }
        } else {
            // Vertical layout for Icons view: checkbox in top-left corner, icon above label
            myTextField.alignment = .center
            // Scale icon size with zoom level - base size should be 85pt for better visibility
            let iconSize = max(32, CGFloat(85 * zoomLevel)) // At 100% = 85pt, at 200% = 170pt
            let topPadding = max(2, CGFloat(5 * zoomLevel))
            let labelSpacing = max(2, CGFloat(4 * zoomLevel))

            // Ensure label remains visible by adjusting its minimum height
            let minLabelHeight: CGFloat = 14 // Minimum height for label visibility

            if showCheckbox {
                currentConstraints = [
                    myCheckbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
                    myCheckbox.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
                    myCheckbox.widthAnchor.constraint(equalToConstant: 18),

                    myImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    myImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: topPadding),
                    myImageView.widthAnchor.constraint(equalToConstant: iconSize),
                    myImageView.heightAnchor.constraint(equalToConstant: iconSize),

                    myTextField.topAnchor.constraint(equalTo: myImageView.bottomAnchor, constant: labelSpacing),
                    myTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
                    myTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2),
                    myTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: minLabelHeight),
                    myTextField.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -2)
                ]
            } else {
                currentConstraints = [
                    myImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    myImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: topPadding),
                    myImageView.widthAnchor.constraint(equalToConstant: iconSize),
                    myImageView.heightAnchor.constraint(equalToConstant: iconSize),

                    myTextField.topAnchor.constraint(equalTo: myImageView.bottomAnchor, constant: labelSpacing),
                    myTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
                    myTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2),
                    myTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: minLabelHeight),
                    myTextField.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -2)
                ]
            }
        }

        NSLayoutConstraint.activate(currentConstraints)
    }

    private func updateView() {
        guard let fileItem = fileItem else { return }

        // Ensure UI is set up before updating (in case this is called before viewDidLoad)
        if myImageView == nil {
            setupUI()
        }

        myImageView?.image = fileItem.icon(useGrayscale: SettingsStore.shared.useGrayscaleIcons)
        myTextField?.stringValue = fileItem.displayName(showExtensions: SettingsStore.shared.showFileExtensions)

        // Apply custom folder color if set
        if fileItem.isDirectory,
           let customColor = ColorManager.shared.getColor(forFolderName: fileItem.url.lastPathComponent) {
            myImageView?.contentTintColor = customColor
        } else {
            myImageView?.contentTintColor = nil // Reset tint color
        }

        view.setAccessibilityLabel(fileItem.displayName(showExtensions: SettingsStore.shared.showFileExtensions))

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
            // Sync checkbox state with selection
            myCheckbox?.state = isSelected ? .on : .off
        }
    }

    private func updateSelectionAppearance() {
        // Update visual appearance based on selection state
        if isSelected {
            view.layer?.backgroundColor = NSColor.customAccentColor.withAlphaComponent(0.3).cgColor
        } else {
            view.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    // MARK: - SelectableItemViewDelegate
    
    func itemViewDidReceiveMouseDown() {
        // Provide immediate visual feedback on mouse down
        // Temporarily show selection appearance until the actual selection state is set
        view.layer?.backgroundColor = NSColor.customAccentColor.withAlphaComponent(0.2).cgColor
    }

    @objc private func accentColorDidChange() {
        // Update selection color when accent color changes
        if isSelected {
            updateSelectionAppearance()
        }
    }
}
