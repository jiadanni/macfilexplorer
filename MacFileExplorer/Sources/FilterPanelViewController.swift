import Cocoa

class FilterPanelViewController: NSViewController {
    
    private var currentFilter: FilterCriteria
    private var onApply: ((FilterCriteria) -> Void)?
    
    // UI Elements
    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    
    // File Type controls
    private var fileTypeCheckboxes: [String: NSButton] = [:]
    
    // Size controls
    private var sizeMinField: NSTextField!
    private var sizeMaxField: NSTextField!
    private var sizeUnitPopup: NSPopUpButton!
    
    // Date controls
    private var dateMinPicker: NSDatePicker!
    private var dateMaxPicker: NSDatePicker!
    private var dateMinCheckbox: NSButton!
    private var dateMaxCheckbox: NSButton!

    private var fileTypeOptions: [(title: String, extensions: [String])] {
        [
            (L10n.text("All Files"), ["*"]),
            (L10n.text("Documents"), ["pdf", "doc", "docx", "txt", "rtf", "pages"]),
            (L10n.text("Images"), ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic"]),
            (L10n.text("Videos"), ["mp4", "mov", "avi", "mkv", "m4v"]),
            (L10n.text("Audio"), ["mp3", "m4a", "aac", "wav", "flac"]),
            (L10n.text("Archives"), ["zip", "rar", "7z", "tar", "gz", "dmg"])
        ]
    }
    
    init(currentFilter: FilterCriteria, onApply: @escaping (FilterCriteria) -> Void) {
        self.currentFilter = currentFilter
        self.onApply = onApply
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.currentFilter = FilterCriteria()
        self.onApply = nil
        super.init(coder: coder)
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 500))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        setupUI()
    }
    
    private func setupUI() {
        // Create scroll view
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        view.addSubview(scrollView)
        
        // Create stack view
        stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 16
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        scrollView.documentView = contentView
        
        // Title
        let titleLabel = NSTextField(labelWithString: L10n.text("Filter Files"))
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.setAccessibilityLabel(L10n.text("Filter Files"))
        stackView.addArrangedSubview(titleLabel)
        
        // File Type Section
        addFileTypeSection()
        
        // Size Section
        addSizeSection()
        
        // Date Section
        addDateSection()
        
        // Button Row
        addButtonRow()
        
        // Constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }
    
    private func addFileTypeSection() {
        let sectionLabel = NSTextField(labelWithString: L10n.text("File Type:"))
        sectionLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(sectionLabel)
        
        for (name, types) in fileTypeOptions {
            let checkbox = AccentCheckbox(title: name, target: self, action: #selector(fileTypeChanged(_:)))
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            
            // Check if this category is active
            let isSelected = types.contains { currentFilter.fileTypes.contains($0) }
            checkbox.state = isSelected ? NSControl.StateValue.on : NSControl.StateValue.off
            
            fileTypeCheckboxes[name] = checkbox
            stackView.addArrangedSubview(checkbox)
        }
    }
    
    private func addSizeSection() {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
        stackView.addArrangedSubview(spacer)
        
        let sectionLabel = NSTextField(labelWithString: L10n.text("Size:"))
        sectionLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(sectionLabel)
        
        // Min size
        let minContainer = NSView()
        minContainer.translatesAutoresizingMaskIntoConstraints = false
        let minLabel = NSTextField(labelWithString: L10n.text("Minimum:"))
        minLabel.translatesAutoresizingMaskIntoConstraints = false
        sizeMinField = NSTextField()
        sizeMinField.translatesAutoresizingMaskIntoConstraints = false
        sizeMinField.placeholderString = L10n.text("No minimum")
        sizeMinField.setAccessibilityLabel(L10n.text("Minimum size value"))
        if let min = currentFilter.sizeMin {
            sizeMinField.stringValue = "\(min / 1024)" // Display in KB
        }
        minContainer.addSubview(minLabel)
        minContainer.addSubview(sizeMinField)
        
        NSLayoutConstraint.activate([
            minLabel.leadingAnchor.constraint(equalTo: minContainer.leadingAnchor),
            minLabel.centerYAnchor.constraint(equalTo: minContainer.centerYAnchor),
            minLabel.widthAnchor.constraint(equalToConstant: 80),
            
            sizeMinField.leadingAnchor.constraint(equalTo: minLabel.trailingAnchor, constant: 8),
            sizeMinField.centerYAnchor.constraint(equalTo: minContainer.centerYAnchor),
            sizeMinField.trailingAnchor.constraint(equalTo: minContainer.trailingAnchor),
            sizeMinField.widthAnchor.constraint(equalToConstant: 120),
            minContainer.heightAnchor.constraint(equalToConstant: 24)
        ])
        stackView.addArrangedSubview(minContainer)
        
        // Max size
        let maxContainer = NSView()
        maxContainer.translatesAutoresizingMaskIntoConstraints = false
        let maxLabel = NSTextField(labelWithString: L10n.text("Maximum:"))
        maxLabel.translatesAutoresizingMaskIntoConstraints = false
        sizeMaxField = NSTextField()
        sizeMaxField.translatesAutoresizingMaskIntoConstraints = false
        sizeMaxField.placeholderString = L10n.text("No maximum")
        sizeMaxField.setAccessibilityLabel(L10n.text("Maximum size value"))
        if let max = currentFilter.sizeMax {
            sizeMaxField.stringValue = "\(max / 1024)" // Display in KB
        }
        maxContainer.addSubview(maxLabel)
        maxContainer.addSubview(sizeMaxField)
        
        NSLayoutConstraint.activate([
            maxLabel.leadingAnchor.constraint(equalTo: maxContainer.leadingAnchor),
            maxLabel.centerYAnchor.constraint(equalTo: maxContainer.centerYAnchor),
            maxLabel.widthAnchor.constraint(equalToConstant: 80),
            
            sizeMaxField.leadingAnchor.constraint(equalTo: maxLabel.trailingAnchor, constant: 8),
            sizeMaxField.centerYAnchor.constraint(equalTo: maxContainer.centerYAnchor),
            sizeMaxField.trailingAnchor.constraint(equalTo: maxContainer.trailingAnchor),
            sizeMaxField.widthAnchor.constraint(equalToConstant: 120),
            maxContainer.heightAnchor.constraint(equalToConstant: 24)
        ])
        stackView.addArrangedSubview(maxContainer)
        
        // Size unit popup
        sizeUnitPopup = AccentPopUpButton()
        sizeUnitPopup.translatesAutoresizingMaskIntoConstraints = false
        sizeUnitPopup.addItems(withTitles: [L10n.text("KB"), L10n.text("MB"), L10n.text("GB")])
        sizeUnitPopup.selectItem(at: 1) // Default to MB
        sizeUnitPopup.setAccessibilityLabel(L10n.text("Size unit"))
        stackView.addArrangedSubview(sizeUnitPopup)
    }
    
    private func addDateSection() {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
        stackView.addArrangedSubview(spacer)
        
        let sectionLabel = NSTextField(labelWithString: L10n.text("Modified Date:"))
        sectionLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stackView.addArrangedSubview(sectionLabel)
        
        // Min date
        dateMinCheckbox = AccentCheckbox(title: L10n.text("After:"), target: self, action: #selector(dateCheckboxChanged(_:)))
        dateMinCheckbox.state = currentFilter.dateMin != nil ? .on : .off
        stackView.addArrangedSubview(dateMinCheckbox)
        
        dateMinPicker = NSDatePicker()
        dateMinPicker.translatesAutoresizingMaskIntoConstraints = false
        dateMinPicker.datePickerStyle = .textFieldAndStepper
        dateMinPicker.datePickerElements = .yearMonthDay
        dateMinPicker.dateValue = currentFilter.dateMin ?? Date()
        dateMinPicker.isEnabled = currentFilter.dateMin != nil
        dateMinPicker.setAccessibilityLabel(L10n.text("Earliest modified date"))
        stackView.addArrangedSubview(dateMinPicker)
        
        // Max date
        dateMaxCheckbox = AccentCheckbox(title: L10n.text("Before:"), target: self, action: #selector(dateCheckboxChanged(_:)))
        dateMaxCheckbox.state = currentFilter.dateMax != nil ? .on : .off
        stackView.addArrangedSubview(dateMaxCheckbox)
        
        dateMaxPicker = NSDatePicker()
        dateMaxPicker.translatesAutoresizingMaskIntoConstraints = false
        dateMaxPicker.datePickerStyle = .textFieldAndStepper
        dateMaxPicker.datePickerElements = .yearMonthDay
        dateMaxPicker.dateValue = currentFilter.dateMax ?? Date()
        dateMaxPicker.isEnabled = currentFilter.dateMax != nil
        dateMaxPicker.setAccessibilityLabel(L10n.text("Latest modified date"))
        stackView.addArrangedSubview(dateMaxPicker)
    }
    
    private func addButtonRow() {
        let buttonContainer = NSView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let clearButton = NSButton(title: L10n.text("Clear All"), target: self, action: #selector(clearFilters(_:)))
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.setAccessibilityLabel(L10n.text("Clear All Filters"))
        
        let cancelButton = NSButton(title: L10n.text("Cancel"), target: self, action: #selector(cancel(_:)))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.keyEquivalent = "\u{1b}" // Escape key
        cancelButton.setAccessibilityLabel(L10n.text("Cancel filtering"))
        
        let applyButton = NSButton(title: L10n.text("Apply"), target: self, action: #selector(applyFilters(_:)))
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        applyButton.keyEquivalent = "\r" // Return key
        applyButton.bezelStyle = .rounded
        applyButton.setAccessibilityLabel(L10n.text("Apply filters"))
        
        buttonContainer.addSubview(clearButton)
        buttonContainer.addSubview(cancelButton)
        buttonContainer.addSubview(applyButton)
        
        NSLayoutConstraint.activate([
            clearButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            clearButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            
            applyButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            applyButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            
            cancelButton.trailingAnchor.constraint(equalTo: applyButton.leadingAnchor, constant: -8),
            cancelButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            
            buttonContainer.heightAnchor.constraint(equalToConstant: 32),
            buttonContainer.widthAnchor.constraint(equalTo: stackView.widthAnchor)
        ])
        
        stackView.addArrangedSubview(buttonContainer)
    }
    
    @objc private func fileTypeChanged(_ sender: NSButton) {
        // This will be updated in applyFilters
    }
    
    @objc private func dateCheckboxChanged(_ sender: NSButton) {
        if sender == dateMinCheckbox {
            dateMinPicker.isEnabled = sender.state == .on
        } else if sender == dateMaxCheckbox {
            dateMaxPicker.isEnabled = sender.state == .on
        }
    }
    
    @objc private func clearFilters(_ sender: Any) {
        // Clear all checkboxes
        for checkbox in fileTypeCheckboxes.values {
            checkbox.state = .off
        }
        
        // Clear size fields
        sizeMinField.stringValue = ""
        sizeMaxField.stringValue = ""
        
        // Clear date checkboxes and pickers
        dateMinCheckbox.state = .off
        dateMaxCheckbox.state = .off
        dateMinPicker.isEnabled = false
        dateMaxPicker.isEnabled = false
    }
    
    @objc private func cancel(_ sender: Any) {
        dismiss(self)
    }
    
    @objc private func applyFilters(_ sender: Any) {
        var newFilter = FilterCriteria()
        
        // Collect file types
        let fileTypeMap = Dictionary(uniqueKeysWithValues: fileTypeOptions.map { ($0.title, $0.extensions) })
        for (name, checkbox) in fileTypeCheckboxes {
            if checkbox.state == .on, let types = fileTypeMap[name] {
                newFilter.fileTypes.formUnion(types)
            }
        }
        
        // Collect size filters
        let multiplier: Int64
        switch sizeUnitPopup.indexOfSelectedItem {
        case 0: multiplier = 1024 // KB
        case 1: multiplier = 1024 * 1024 // MB
        case 2: multiplier = 1024 * 1024 * 1024 // GB
        default: multiplier = 1024
        }
        
        if !sizeMinField.stringValue.isEmpty, let min = Int64(sizeMinField.stringValue) {
            newFilter.sizeMin = min * multiplier
        }
        if !sizeMaxField.stringValue.isEmpty, let max = Int64(sizeMaxField.stringValue) {
            newFilter.sizeMax = max * multiplier
        }
        
        // Collect date filters
        if dateMinCheckbox.state == .on {
            newFilter.dateMin = dateMinPicker.dateValue
        }
        if dateMaxCheckbox.state == .on {
            newFilter.dateMax = dateMaxPicker.dateValue
        }
        
        onApply?(newFilter)
        dismiss(self)
    }
}
