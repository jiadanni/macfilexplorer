//
//  StartDesignSystem.swift
//  MacFileExplorer
//
//  Design system constants for the Start Page
//

import Cocoa

/// Design system for Start Page widgets and components
struct StartDesignSystem {

    // MARK: - Colors

    struct Colors {
        /// Primary accent color for interactive elements
        static var accent: NSColor {
            return NSColor.customAccentColor
        }

        /// Widget background color
        static let widgetBackground = NSColor.controlBackgroundColor

        /// Widget border color
        static let widgetBorder = NSColor.separatorColor

        /// Success/granted permission color
        static let success = NSColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)

        /// Warning/partial permission color
        static let warning = NSColor(red: 1.0, green: 0.7, blue: 0.0, alpha: 1.0)

        /// Error/denied permission color
        static let error = NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)

        /// Inactive/placeholder color
        static let inactive = NSColor.secondaryLabelColor

        /// Card hover overlay
        static var hoverOverlay: NSColor {
            return NSColor.customAccentColor.withAlphaComponent(0.05)
        }
    }

    // MARK: - Typography

    struct Typography {
        /// Large title for page header
        static let largeTitle = NSFont.systemFont(ofSize: 28, weight: .bold)

        /// Widget title
        static let widgetTitle = NSFont.systemFont(ofSize: 16, weight: .semibold)

        /// Widget subtitle
        static let widgetSubtitle = NSFont.systemFont(ofSize: 13, weight: .regular)

        /// Body text
        static let body = NSFont.systemFont(ofSize: 13, weight: .regular)

        /// Small caption text
        static let caption = NSFont.systemFont(ofSize: 11, weight: .regular)

        /// Button text
        static let button = NSFont.systemFont(ofSize: 13, weight: .medium)
    }

    // MARK: - Spacing

    struct Spacing {
        /// Extra small spacing (4pt)
        static let xs: CGFloat = 4

        /// Small spacing (8pt)
        static let sm: CGFloat = 8

        /// Medium spacing (12pt)
        static let md: CGFloat = 12

        /// Large spacing (16pt)
        static let lg: CGFloat = 16

        /// Extra large spacing (24pt)
        static let xl: CGFloat = 24

        /// Extra extra large spacing (32pt)
        static let xxl: CGFloat = 32

        /// Widget padding (internal content padding)
        static let widgetPadding: CGFloat = 16

        /// Grid spacing between widgets
        static let gridSpacing: CGFloat = 16
    }

    // MARK: - Layout

    struct Layout {
        /// Widget corner radius
        static let cornerRadius: CGFloat = 12

        /// Widget border width
        static let borderWidth: CGFloat = 1

        /// Maximum content width for Start Page
        static let maxContentWidth: CGFloat = 1200

        /// Minimum widget height
        static let minWidgetHeight: CGFloat = 100

        /// Maximum widget height (before scrolling)
        static let maxWidgetHeight: CGFloat = 400

        /// Widget shadow
        static var shadow: NSShadow {
            let shadow = NSShadow()
            shadow.shadowOffset = NSSize(width: 0, height: -2)
            shadow.shadowBlurRadius = 8
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.1)
            return shadow
        }
    }

    // MARK: - Animation

    struct Animation {
        /// Default animation duration
        static let duration: TimeInterval = 0.25

        /// Fast animation duration
        static let fastDuration: TimeInterval = 0.15

        /// Slow animation duration
        static let slowDuration: TimeInterval = 0.4

        /// Spring animation response
        static let springResponse: CGFloat = 0.3

        /// Spring animation damping
        static let springDamping: CGFloat = 0.75
    }

    // MARK: - Icons

    struct Icons {
        /// System icon names used throughout Start Page
        static let start = "star.fill"
        static let folder = "folder.fill"
        static let addFolder = "folder.badge.plus"
        static let document = "doc.fill"
        static let download = "arrow.down.circle.fill"
        static let desktop = "desktopcomputer"
        static let pictures = "photo.fill"
        static let music = "music.note"
        static let applications = "app.fill"
        static let storage = "chart.pie.fill"
        static let checkmark = "checkmark.circle.fill"
        static let warning = "exclamationmark.triangle.fill"
        static let lock = "lock.fill"
        static let unlock = "lock.open.fill"
        static let settings = "gearshape.fill"
        static let terminal = "terminal.fill"
        static let eject = "eject.fill"
        static let newFolder = "folder.badge.plus"
        static let search = "magnifyingglass"
        static let info = "info.circle.fill"
    }

    // MARK: - Widget Sizes

    enum WidgetSize {
        case small   // 1 column
        case medium  // 2 columns
        case large   // Full width

        var columns: Int {
            switch self {
            case .small: return 1
            case .medium: return 2
            case .large: return 3
            }
        }
    }

    // MARK: - Helper Methods

    /// Creates a styled widget container view
    static func createWidgetContainer() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = Colors.widgetBackground.cgColor
        container.layer?.cornerRadius = Layout.cornerRadius
        container.layer?.borderWidth = Layout.borderWidth
        container.layer?.borderColor = Colors.widgetBorder.cgColor
        container.shadow = Layout.shadow
        return container
    }

    /// Creates a styled button
    static func createButton(title: String, style: ButtonStyle = .primary) -> NSButton {
        let button = NSButton()
        button.title = title
        button.bezelStyle = .rounded
        button.font = Typography.button

        switch style {
        case .primary:
            button.keyEquivalent = "\r"
        case .secondary:
            button.bezelStyle = .texturedRounded
        case .text:
            button.bezelStyle = .inline
            button.isBordered = false
        }

        return button
    }

    enum ButtonStyle {
        case primary
        case secondary
        case text
    }

    /// Creates a styled label
    static func createLabel(text: String, style: LabelStyle = .body) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0

        switch style {
        case .largeTitle:
            label.font = Typography.largeTitle
        case .title:
            label.font = Typography.widgetTitle
        case .subtitle:
            label.font = Typography.widgetSubtitle
            label.textColor = .secondaryLabelColor
        case .body:
            label.font = Typography.body
        case .caption:
            label.font = Typography.caption
            label.textColor = .tertiaryLabelColor
        }

        return label
    }

    enum LabelStyle {
        case largeTitle
        case title
        case subtitle
        case body
        case caption
    }

    /// Creates a permission status indicator
    static func createStatusIndicator(granted: Bool) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 4

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: granted ? Icons.checkmark : Icons.lock, accessibilityDescription: nil)
        icon.contentTintColor = .white
        icon.translatesAutoresizingMaskIntoConstraints = false

        container.layer?.backgroundColor = (granted ? Colors.success : Colors.inactive).cgColor
        container.addSubview(icon)

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 12),
            icon.heightAnchor.constraint(equalToConstant: 12),
            container.widthAnchor.constraint(equalToConstant: 24),
            container.heightAnchor.constraint(equalToConstant: 24)
        ])

        return container
    }
}
