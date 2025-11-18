//
//  AccentColorControls.swift
//  MacFileExplorer
//
//  Custom controls that use the app's custom accent color
//
//
//  AccentColorControls.swift
//  MacFileExplorer
//
//  Custom controls that use the app's custom accent color
//

import Cocoa

/// Legacy custom checkbox replaced by system checkbox for consistency
class AccentCheckbox: NSButton {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupSystemCheckbox()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSystemCheckbox()
    }

    convenience init(title: String, target: AnyObject?, action: Selector?) {
        self.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
    }

    private func setupSystemCheckbox() {
        // Use the system checkbox appearance without extra background/pill
        setButtonType(.switch)
        // Ensure we use the native checkbox style
        isBordered = false
        bezelStyle = .regularSquare
        focusRingType = .none
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = false
    }
}

/// A popup button with custom-drawn arrow using accent color
/// Use system popup button appearance; no custom arrow drawing
class AccentPopUpButton: NSPopUpButton {
    override init(frame frameRect: NSRect, pullsDown flag: Bool) {
        super.init(frame: frameRect, pullsDown: flag)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        translatesAutoresizingMaskIntoConstraints = false
    }

    convenience init() {
        self.init(frame: .zero, pullsDown: false)
    }

    convenience override init(frame frameRect: NSRect) {
        self.init(frame: frameRect, pullsDown: false)
    }
}

/// Extension to NSButton for convenience creation of accent-colored checkboxes
extension NSButton {
    static func accentCheckbox(title: String, target: AnyObject?, action: Selector?) -> NSButton {
        let checkbox = AccentCheckbox(title: title, target: target, action: action)
        return checkbox
    }
}

/// Extension to NSPopUpButton for convenience creation
extension NSPopUpButton {
    static func accentPopUpButton(frame: NSRect = .zero, pullsDown: Bool = false) -> AccentPopUpButton {
        let popup = AccentPopUpButton(frame: frame, pullsDown: pullsDown)
        return popup
    }
}
