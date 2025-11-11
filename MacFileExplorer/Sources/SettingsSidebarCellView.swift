import Cocoa

class SettingsSidebarCellView: NSTableCellView {
    // Declare a strong reference to the text field
    var strongTextField: NSTextField?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTextField()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextField()
    }

    private func setupTextField() {
        strongTextField = NSTextField(labelWithString: "")
        strongTextField?.translatesAutoresizingMaskIntoConstraints = false
        strongTextField?.lineBreakMode = .byTruncatingTail
        addSubview(strongTextField!)
        self.textField = strongTextField // Assign to the weak property of NSTableCellView

        NSLayoutConstraint.activate([
            strongTextField!.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            strongTextField!.centerYAnchor.constraint(equalTo: centerYAnchor),
            strongTextField!.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
    }
}
