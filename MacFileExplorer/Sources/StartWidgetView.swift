//
//  StartWidgetView.swift
//  MacFileExplorer
//
//  Base class for Start Page widgets
//

import Cocoa

protocol StartWidgetDelegate: AnyObject {
    func widgetDidRequestAction(_ action: StartWidgetAction, widget: StartWidgetView)
    func widgetDidRequestNavigation(to url: URL)
    func widgetDidRequestDismiss(_ widget: StartWidgetView)
}

enum StartWidgetAction {
    case openFolder(URL)
    case requestPermission(folder: URL?)
    case openStorageAnalyzer
    case openSettings
    case addFavorite
    case openTerminal
    case ejectAll
    case newFolder
    case taskCompleted(String)
}

class StartWidgetView: NSView {
    // MARK: - Properties

    weak var delegate: StartWidgetDelegate?

    var widgetTitle: String {
        didSet {
            titleLabel?.stringValue = widgetTitle
        }
    }

    var widgetIcon: String? {
        didSet {
            updateIcon()
        }
    }

    var canDismiss: Bool {
        didSet {
            dismissButton?.isHidden = !canDismiss
        }
    }

    // UI Components
    private var containerView: NSView!
    private var headerView: NSView!
    private var titleLabel: NSTextField!
    private var iconView: NSImageView!
    private var dismissButton: NSButton!
    var contentView: NSView!

    // MARK: - Initialization

    init(title: String, icon: String? = nil, dismissible: Bool = false) {
        self.widgetTitle = title
        self.widgetIcon = icon
        self.canDismiss = dismissible

        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        self.widgetTitle = ""
        self.widgetIcon = nil
        self.canDismiss = false
        super.init(coder: coder)
        setupUI()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupUI() {
        wantsLayer = true

        // Container with styling
        containerView = StartDesignSystem.createWidgetContainer()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        // Header
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(headerView)

        // Icon
        if let iconName = widgetIcon {
            iconView = NSImageView()
            iconView.image = NSImage.mfeSymbol(named: iconName, accessibilityDescription: nil)
            iconView.contentTintColor = StartDesignSystem.Colors.accent
            iconView.translatesAutoresizingMaskIntoConstraints = false
            headerView.addSubview(iconView)
        }

        // Title
        titleLabel = StartDesignSystem.createLabel(text: widgetTitle, style: .title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        // Dismiss button
        if canDismiss {
            dismissButton = NSButton()
            dismissButton.image = NSImage.mfeSymbol(named: "xmark.circle.fill", accessibilityDescription: "Dismiss")
            dismissButton.bezelStyle = .inline
            dismissButton.isBordered = false
            dismissButton.target = self
            dismissButton.action = #selector(dismissTapped)
            dismissButton.translatesAutoresizingMaskIntoConstraints = false
            headerView.addSubview(dismissButton)
        }

        // Content view (for subclasses to add content)
        contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contentView)

        setupConstraints()
        setupHoverEffect()
        observeAccentColorChanges()
    }

    private func setupConstraints() {
        var constraints: [NSLayoutConstraint] = [
            // Container fills parent
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Header
            headerView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: StartDesignSystem.Spacing.widgetPadding),
            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: StartDesignSystem.Spacing.widgetPadding),
            headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -StartDesignSystem.Spacing.widgetPadding),
            headerView.heightAnchor.constraint(equalToConstant: 28),

            // Content view
            contentView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: StartDesignSystem.Spacing.md),
            contentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: StartDesignSystem.Spacing.widgetPadding),
            contentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -StartDesignSystem.Spacing.widgetPadding),
            contentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -StartDesignSystem.Spacing.widgetPadding)
        ]

        // Icon constraints
        if let icon = iconView {
            constraints.append(contentsOf: [
                icon.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
                icon.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 20),
                icon.heightAnchor.constraint(equalToConstant: 20),
                titleLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: StartDesignSystem.Spacing.sm)
            ])
        } else {
            constraints.append(titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor))
        }

        // Title constraints
        constraints.append(titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor))

        // Dismiss button constraints
        if let dismiss = dismissButton {
            constraints.append(contentsOf: [
                dismiss.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
                dismiss.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
                dismiss.widthAnchor.constraint(equalToConstant: 20),
                dismiss.heightAnchor.constraint(equalToConstant: 20),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: dismiss.leadingAnchor, constant: -StartDesignSystem.Spacing.sm)
            ])
        } else {
            constraints.append(titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor))
        }

        NSLayoutConstraint.activate(constraints)
    }

    private func setupHoverEffect() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    private func observeAccentColorChanges() {
        NotificationCenter.default.addObserver(
            forName: .accentColorDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAccentColors()
        }
    }

    private func updateAccentColors() {
        // Update icon tint color
        iconView?.contentTintColor = StartDesignSystem.Colors.accent
    }

    // MARK: - Hover Effects

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = StartDesignSystem.Animation.fastDuration
            containerView.layer?.borderColor = StartDesignSystem.Colors.accent.cgColor
        })
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = StartDesignSystem.Animation.fastDuration
            containerView.layer?.borderColor = StartDesignSystem.Colors.widgetBorder.cgColor
        })
    }

    // MARK: - Actions

    @objc private func dismissTapped() {
        delegate?.widgetDidRequestDismiss(self)
        animateOut()
    }

    // MARK: - Animations

    func animateIn() {
        alphaValue = 0

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = StartDesignSystem.Animation.duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        })
    }

    func animateOut(completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = StartDesignSystem.Animation.fastDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }, completionHandler: {
            self.removeFromSuperview()
            completion?()
        })
    }

    // MARK: - Helpers

    private func updateIcon() {
        guard let iconName = widgetIcon else {
            iconView?.removeFromSuperview()
            iconView = nil
            return
        }

        if iconView == nil {
            iconView = NSImageView()
            iconView.contentTintColor = StartDesignSystem.Colors.accent
            iconView.translatesAutoresizingMaskIntoConstraints = false
            headerView.addSubview(iconView)
        }

        iconView.image = NSImage.mfeSymbol(named: iconName, accessibilityDescription: nil)
    }

    /// Override this in subclasses to add custom content
    func setupContent() {
        // Override in subclasses
    }

    /// Called when widget should refresh its content
    func refresh() {
        // Override in subclasses
    }
}
