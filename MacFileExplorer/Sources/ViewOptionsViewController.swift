import Cocoa

protocol ViewOptionsDelegate: AnyObject {
    func viewOptionsDidChange(_ options: ViewOptions)
}

class ViewOptionsViewController: NSViewController {

    weak var delegate: ViewOptionsDelegate?
    private var viewOptions: ViewOptions

    // View mode checkboxes
    private var alwaysOpenInIconViewCheckbox: NSButton!
    private var browseInIconViewCheckbox: NSButton!

    // Group and sort controls
    private var groupByPopup: NSPopUpButton!
    private var sortByPopup: NSPopUpButton!
    private var sortAscendingButton: NSButton!

    // Icon view controls
    private var iconSizeSlider: NSSlider!
    private var iconSizeLabel: NSTextField!
    private var gridSpacingSlider: NSSlider!
    private var textSizeField: NSTextField!
    private var labelPositionBottom: NSButton!
    private var labelPositionRight: NSButton!

    // Display options
    private var showItemInfoCheckbox: NSButton!
    private var showIconPreviewCheckbox: NSButton!

    // Background options
    private var backgroundDefaultRadio: NSButton!
    private var backgroundColorRadio: NSButton!
    private var backgroundPictureRadio: NSButton!

    init() {
        self.viewOptions = UserDefaults.standard.loadViewOptions()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.viewOptions = UserDefaults.standard.loadViewOptions()
        super.init(coder: coder)
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 432, height: 700))
        setupUI()
    }

    private func setupUI() {
        view.wantsLayer = true

        var yOffset: CGFloat = view.bounds.height - 30

        // Title
        let titleLabel = NSTextField(labelWithString: "View Options")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        titleLabel.frame = NSRect(x: 20, y: yOffset, width: 200, height: 20)
        view.addSubview(titleLabel)
        yOffset -= 40

        // Always open in icon view
        alwaysOpenInIconViewCheckbox = AccentCheckbox(title: "Always open in icon view", target: self, action: #selector(optionChanged(_:)))
        alwaysOpenInIconViewCheckbox.frame = NSRect(x: 20, y: yOffset, width: 300, height: 20)
        alwaysOpenInIconViewCheckbox.state = viewOptions.alwaysOpenInIconView ? .on : .off
        view.addSubview(alwaysOpenInIconViewCheckbox)
        yOffset -= 30

        // Browse in icon view (indented)
        browseInIconViewCheckbox = AccentCheckbox(title: "Browse in icon view", target: self, action: #selector(optionChanged(_:)))
        browseInIconViewCheckbox.frame = NSRect(x: 40, y: yOffset, width: 280, height: 20)
        browseInIconViewCheckbox.state = viewOptions.browseInIconView ? .on : .off
        view.addSubview(browseInIconViewCheckbox)
        yOffset -= 40

        // Group By
        let groupByLabel = NSTextField(labelWithString: "Group By:")
        groupByLabel.frame = NSRect(x: 20, y: yOffset, width: 100, height: 20)
        view.addSubview(groupByLabel)

        groupByPopup = AccentPopUpButton(frame: NSRect(x: 120, y: yOffset - 3, width: 290, height: 26), pullsDown: false)
        groupByPopup.target = self
        groupByPopup.action = #selector(optionChanged(_:))
        for option in GroupByOption.allCases {
            groupByPopup.addItem(withTitle: option.rawValue)
        }
        groupByPopup.selectItem(withTitle: viewOptions.groupBy.rawValue)
        view.addSubview(groupByPopup)
        yOffset -= 35

        // Sort By
        let sortByLabel = NSTextField(labelWithString: "Sort By:")
        sortByLabel.frame = NSRect(x: 20, y: yOffset, width: 100, height: 20)
        view.addSubview(sortByLabel)

        sortByPopup = AccentPopUpButton(frame: NSRect(x: 120, y: yOffset - 3, width: 240, height: 26), pullsDown: false)
        sortByPopup.target = self
        sortByPopup.action = #selector(optionChanged(_:))
        for option in SortByOption.allCases {
            sortByPopup.addItem(withTitle: option.rawValue)
        }
        sortByPopup.selectItem(withTitle: viewOptions.sortBy.rawValue)
        view.addSubview(sortByPopup)

        // Sort ascending/descending button
        sortAscendingButton = NSButton(frame: NSRect(x: 370, y: yOffset - 3, width: 40, height: 26))
        sortAscendingButton.bezelStyle = .rounded
        sortAscendingButton.image = NSImage(systemSymbolName: viewOptions.sortAscending ? "arrow.up" : "arrow.down", accessibilityDescription: nil)
        sortAscendingButton.target = self
        sortAscendingButton.action = #selector(toggleSortDirection(_:))
        view.addSubview(sortAscendingButton)
        yOffset -= 40

        // Icon size
        let iconSizeHeaderLabel = NSTextField(labelWithString: "Icon size:")
        iconSizeHeaderLabel.frame = NSRect(x: 20, y: yOffset, width: 100, height: 20)
        view.addSubview(iconSizeHeaderLabel)

        iconSizeLabel = NSTextField(labelWithString: "\(Int(viewOptions.iconSize))×\(Int(viewOptions.iconSize))")
        iconSizeLabel.frame = NSRect(x: 120, y: yOffset, width: 100, height: 20)
        iconSizeLabel.alignment = .center
        view.addSubview(iconSizeLabel)
        yOffset -= 30

        // Use actual Finder folder icon (small size)
        let folderIcon = NSImageView(frame: NSRect(x: 25, y: yOffset - 20, width: 20, height: 20))
        folderIcon.image = NSWorkspace.shared.icon(for: .folder)
        folderIcon.imageScaling = .scaleProportionallyDown
        folderIcon.toolTip = "Small icon size"
        view.addSubview(folderIcon)

        iconSizeSlider = NSSlider(frame: NSRect(x: 65, y: yOffset, width: 280, height: 20))
        iconSizeSlider.minValue = 16
        iconSizeSlider.maxValue = 512
        iconSizeSlider.doubleValue = viewOptions.iconSize
        iconSizeSlider.target = self
        iconSizeSlider.action = #selector(iconSizeChanged(_:))
        view.addSubview(iconSizeSlider)

        // Use actual Finder document icon (large size)
        let fileIcon = NSImageView(frame: NSRect(x: 365, y: yOffset - 30, width: 40, height: 40))
        fileIcon.image = NSWorkspace.shared.icon(forFileType: "public.data")
        fileIcon.imageScaling = .scaleProportionallyDown
        fileIcon.toolTip = "Large icon size"
        view.addSubview(fileIcon)
        yOffset -= 50

        // Grid spacing
        let gridSpacingLabel = NSTextField(labelWithString: "Grid spacing:")
        gridSpacingLabel.frame = NSRect(x: 20, y: yOffset, width: 120, height: 20)
        view.addSubview(gridSpacingLabel)
        yOffset -= 30

        let gridIconSmall = NSImageView(frame: NSRect(x: 25, y: yOffset - 20, width: 30, height: 30))
        gridIconSmall.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)
        gridIconSmall.toolTip = "Tight grid spacing"
        view.addSubview(gridIconSmall)

        gridSpacingSlider = NSSlider(frame: NSRect(x: 65, y: yOffset, width: 280, height: 20))
        gridSpacingSlider.minValue = 0
        gridSpacingSlider.maxValue = 100
        gridSpacingSlider.doubleValue = viewOptions.gridSpacing
        gridSpacingSlider.target = self
        gridSpacingSlider.action = #selector(optionChanged(_:))
        view.addSubview(gridSpacingSlider)

        let gridIconLarge = NSImageView(frame: NSRect(x: 360, y: yOffset - 20, width: 30, height: 30))
        gridIconLarge.image = NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: nil)
        gridIconLarge.toolTip = "Wide grid spacing"
        view.addSubview(gridIconLarge)
        yOffset -= 50

        // Text size
        let textSizeLabel = NSTextField(labelWithString: "Text size:")
        textSizeLabel.frame = NSRect(x: 20, y: yOffset, width: 100, height: 20)
        view.addSubview(textSizeLabel)

        textSizeField = NSTextField(frame: NSRect(x: 140, y: yOffset - 3, width: 100, height: 26))
        textSizeField.integerValue = viewOptions.textSize
        textSizeField.formatter = {
            let formatter = NumberFormatter()
            formatter.minimum = 10
            formatter.maximum = 16
            return formatter
        }()
        textSizeField.target = self
        textSizeField.action = #selector(optionChanged(_:))
        view.addSubview(textSizeField)
        yOffset -= 35

        // Label position
        let labelPositionLabel = NSTextField(labelWithString: "Label position:")
        labelPositionLabel.frame = NSRect(x: 20, y: yOffset, width: 120, height: 20)
        view.addSubview(labelPositionLabel)
        yOffset -= 25

        labelPositionBottom = NSButton(radioButtonWithTitle: "Bottom", target: self, action: #selector(optionChanged(_:)))
        labelPositionBottom.frame = NSRect(x: 30, y: yOffset, width: 100, height: 20)
        labelPositionBottom.state = viewOptions.labelPosition == .bottom ? .on : .off
        view.addSubview(labelPositionBottom)

        labelPositionRight = NSButton(radioButtonWithTitle: "Right", target: self, action: #selector(optionChanged(_:)))
        labelPositionRight.frame = NSRect(x: 150, y: yOffset, width: 100, height: 20)
        labelPositionRight.state = viewOptions.labelPosition == .right ? .on : .off
        view.addSubview(labelPositionRight)
        yOffset -= 40

        // Show item info
        showItemInfoCheckbox = AccentCheckbox(title: "Show item info", target: self, action: #selector(optionChanged(_:)))
        showItemInfoCheckbox.frame = NSRect(x: 20, y: yOffset, width: 300, height: 20)
        showItemInfoCheckbox.state = viewOptions.showItemInfo ? .on : .off
        view.addSubview(showItemInfoCheckbox)
        yOffset -= 25

        // Show icon preview
        showIconPreviewCheckbox = AccentCheckbox(title: "Show icon preview", target: self, action: #selector(optionChanged(_:)))
        showIconPreviewCheckbox.frame = NSRect(x: 20, y: yOffset, width: 300, height: 20)
        showIconPreviewCheckbox.state = viewOptions.showIconPreview ? .on : .off
        view.addSubview(showIconPreviewCheckbox)
        yOffset -= 40

        // Background
        let backgroundLabel = NSTextField(labelWithString: "Background:")
        backgroundLabel.frame = NSRect(x: 20, y: yOffset, width: 120, height: 20)
        view.addSubview(backgroundLabel)
        yOffset -= 25

        backgroundDefaultRadio = NSButton(radioButtonWithTitle: "Default", target: self, action: #selector(optionChanged(_:)))
        backgroundDefaultRadio.frame = NSRect(x: 30, y: yOffset, width: 100, height: 20)
        backgroundDefaultRadio.state = viewOptions.backgroundType == .defaultBackground ? .on : .off
        view.addSubview(backgroundDefaultRadio)
        yOffset -= 25

        backgroundColorRadio = NSButton(radioButtonWithTitle: "Color", target: self, action: #selector(optionChanged(_:)))
        backgroundColorRadio.frame = NSRect(x: 30, y: yOffset, width: 100, height: 20)
        backgroundColorRadio.state = viewOptions.backgroundType == .color ? .on : .off
        view.addSubview(backgroundColorRadio)
        yOffset -= 25

        backgroundPictureRadio = NSButton(radioButtonWithTitle: "Picture", target: self, action: #selector(optionChanged(_:)))
        backgroundPictureRadio.frame = NSRect(x: 30, y: yOffset, width: 100, height: 20)
        backgroundPictureRadio.state = viewOptions.backgroundType == .picture ? .on : .off
        view.addSubview(backgroundPictureRadio)
    }

    @objc private func iconSizeChanged(_ sender: NSSlider) {
        let size = Int(sender.doubleValue)
        iconSizeLabel.stringValue = "\(size)×\(size)"
        optionChanged(sender)
    }

    @objc private func toggleSortDirection(_ sender: NSButton) {
        viewOptions.sortAscending.toggle()
        sender.image = NSImage(systemSymbolName: viewOptions.sortAscending ? "arrow.up" : "arrow.down", accessibilityDescription: nil)
        saveAndNotify()
    }

    @objc private func optionChanged(_ sender: Any) {
        // Update model from UI
        viewOptions.alwaysOpenInIconView = alwaysOpenInIconViewCheckbox.state == .on
        viewOptions.browseInIconView = browseInIconViewCheckbox.state == .on

        if let groupByTitle = groupByPopup.selectedItem?.title,
           let groupBy = GroupByOption(rawValue: groupByTitle) {
            viewOptions.groupBy = groupBy
        }

        if let sortByTitle = sortByPopup.selectedItem?.title,
           let sortBy = SortByOption(rawValue: sortByTitle) {
            viewOptions.sortBy = sortBy
        }

        viewOptions.iconSize = iconSizeSlider.doubleValue
        viewOptions.gridSpacing = gridSpacingSlider.doubleValue
        viewOptions.textSize = textSizeField.integerValue
        viewOptions.labelPosition = labelPositionBottom.state == .on ? .bottom : .right
        viewOptions.showItemInfo = showItemInfoCheckbox.state == .on
        viewOptions.showIconPreview = showIconPreviewCheckbox.state == .on

        if backgroundDefaultRadio.state == .on {
            viewOptions.backgroundType = .defaultBackground
        } else if backgroundColorRadio.state == .on {
            viewOptions.backgroundType = .color
        } else {
            viewOptions.backgroundType = .picture
        }

        saveAndNotify()
    }

    private func saveAndNotify() {
        UserDefaults.standard.saveViewOptions(viewOptions)
        delegate?.viewOptionsDidChange(viewOptions)
    }
}
