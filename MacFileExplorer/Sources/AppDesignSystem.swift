//
//  AppDesignSystem.swift
//  MacFileExplorer
//
//  Shared design system constants used across the app's chrome
//  (sidebar, toolbar, status bar, terminal, Start Page).
//

import Cocoa

/// App-wide design system. Members under `StartPage` are scoped to the
/// Start Page widget grid; everything else is shared chrome styling.
struct AppDesignSystem {

    // MARK: - Colors

    struct Colors {
        /// Primary accent color for interactive elements
        static var accent: NSColor {
            return NSColor.customAccentColor
        }

        /// Widget/panel background color
        static let widgetBackground = NSColor.controlBackgroundColor

        /// Widget/panel border color
        static let widgetBorder = NSColor.separatorColor

        /// Success/granted permission color
        static let success = NSColor.systemGreen

        /// Warning/partial permission color
        static let warning = NSColor.systemOrange

        /// Error/denied permission color
        static let error = NSColor.systemRed

        /// Inactive/placeholder color
        static let inactive = NSColor.secondaryLabelColor

        /// Subtle hover overlay (e.g. Start Page card hover)
        static var hoverOverlay: NSColor {
            return NSColor.customAccentColor.withAlphaComponent(0.05)
        }

        /// Stronger hover/pressed overlay (e.g. toolbar icon buttons)
        static var hoverOverlayStrong: NSColor {
            return NSColor.customAccentColor.withAlphaComponent(0.2)
        }

        /// Selection highlight fill (e.g. sidebar row selection)
        static var selectionOverlay: NSColor {
            return NSColor.customAccentColor.withAlphaComponent(0.3)
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

        /// Sidebar section header ("FAVORITES", "LOCATIONS", ...)
        static let sidebarHeader = NSFont.systemFont(ofSize: 11, weight: .semibold)

        /// Sidebar row label (Favorites, Locations, Folder Explorer rows)
        static let sidebarRow = NSFont.systemFont(ofSize: 13, weight: .regular)

        /// Monospaced text (terminal output/input)
        static func monospace(weight: NSFont.Weight = .regular) -> NSFont {
            return NSFont.monospacedSystemFont(ofSize: 12, weight: weight)
        }
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

        /// Small control corner radius (address bar, banners, chips)
        static let controlCornerRadius: CGFloat = 6

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

    // MARK: - Terminal

    /// Colors for the Terminal panel, which intentionally keeps a fixed
    /// dark theme regardless of the system's light/dark appearance.
    struct Terminal {
        static let background = NSColor(white: 0.1, alpha: 1.0)
        static let headerBackground = NSColor(white: 0.15, alpha: 1.0)
        static let foreground = NSColor(white: 0.9, alpha: 1.0)
        static let brightForeground = NSColor(white: 0.95, alpha: 1.0)
        static let dimForeground = NSColor.darkGray
        static let headerTitleFont = NSFont.boldSystemFont(ofSize: 12)

        /// ANSI 16-color palette (SGR codes 30-37, 90-97)
        enum ANSI {
            static let black = NSColor.black
            static let red = NSColor.red
            static let green = NSColor.green
            static let yellow = NSColor.yellow
            static let blue = NSColor.blue
            static let magenta = NSColor.magenta
            static let cyan = NSColor.cyan
            static let white = NSColor.white
            static let brightBlack = NSColor.darkGray
            static let brightRed = NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
            static let brightGreen = NSColor(red: 0.4, green: 1.0, blue: 0.4, alpha: 1.0)
            static let brightYellow = NSColor(red: 1.0, green: 1.0, blue: 0.4, alpha: 1.0)
            static let brightBlue = NSColor(red: 0.4, green: 0.4, blue: 1.0, alpha: 1.0)
            static let brightMagenta = NSColor(red: 1.0, green: 0.4, blue: 1.0, alpha: 1.0)
            static let brightCyan = NSColor(red: 0.4, green: 1.0, blue: 1.0, alpha: 1.0)
            static let brightWhite = NSColor(white: 0.95, alpha: 1.0)
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
        if let sysImage = NSImage.mfeSymbol(named: granted ? Icons.checkmark : Icons.lock, accessibilityDescription: nil) {
            let useGrayscale = SettingsStore.shared.useGrayscaleIcons
            icon.image = useGrayscale ? sysImage.grayscale() : sysImage
        }
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
