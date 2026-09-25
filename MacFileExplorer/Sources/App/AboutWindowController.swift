import Cocoa

class AboutWindowController: NSWindowController {
    
    private var aboutViewController: AboutViewController!
    
    override init(window: NSWindow?) {
        super.init(window: window)
        setupWindow()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWindow()
    }
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "About MacFileExplorer"
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false
        
        // Create and set content view controller
        aboutViewController = AboutViewController()
        window.contentViewController = aboutViewController
        
        // Prevent window from being resizable
        window.styleMask.remove(.resizable)
    }
    
    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

class AboutViewController: NSViewController {
    
    private var containerView: NSView!
    private var appIconView: NSImageView!
    private var appNameLabel: NSTextField!
    private var versionLabel: NSTextField!
    private var buildInfoTextView: NSTextView!
    private var copyrightLabel: NSTextField!
    private var buttonStackView: NSStackView!
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 520))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        setupUI()
    }
    
    private func setupUI() {
        // Container for centered content
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // App Icon
        appIconView = NSImageView()
        appIconView.translatesAutoresizingMaskIntoConstraints = false
        appIconView.image = NSApp.applicationIconImage
        appIconView.imageScaling = .scaleProportionallyDown
        containerView.addSubview(appIconView)
        
        // App Name
        appNameLabel = NSTextField(labelWithString: "MacFileExplorer")
        appNameLabel.translatesAutoresizingMaskIntoConstraints = false
        appNameLabel.font = NSFont.systemFont(ofSize: 24, weight: .regular)
        appNameLabel.alignment = .center
        containerView.addSubview(appNameLabel)
        
        // Version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        
        versionLabel = NSTextField(labelWithString: "Version: \(version) (Build \(build))")
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        versionLabel.font = NSFont.systemFont(ofSize: 13)
        versionLabel.alignment = .center
        versionLabel.textColor = NSColor.secondaryLabelColor
        containerView.addSubview(versionLabel)
        
        // Build Info Text View (scrollable)
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.autohidesScrollers = true
        
        buildInfoTextView = NSTextView()
        buildInfoTextView.isEditable = false
        buildInfoTextView.isSelectable = true
        buildInfoTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        buildInfoTextView.textColor = NSColor.labelColor
        buildInfoTextView.backgroundColor = NSColor.textBackgroundColor
        buildInfoTextView.textContainerInset = NSSize(width: 10, height: 10)
        
        scrollView.documentView = buildInfoTextView
        containerView.addSubview(scrollView)
        
        // Set build info text
        buildInfoTextView.string = getBuildInfo()
        
        // Copyright
        let currentYear = Calendar.current.component(.year, from: Date())
        copyrightLabel = NSTextField(labelWithString: "© \(currentYear) MacFileExplorer. All rights reserved.")
        copyrightLabel.translatesAutoresizingMaskIntoConstraints = false
        copyrightLabel.font = NSFont.systemFont(ofSize: 11)
        copyrightLabel.alignment = .center
        copyrightLabel.textColor = NSColor.tertiaryLabelColor
        containerView.addSubview(copyrightLabel)
        
        // Buttons
        let licenseButton = createButton(title: "License", action: #selector(showLicense))
        let creditsButton = createButton(title: "Credits", action: #selector(showCredits))
        
        buttonStackView = NSStackView(views: [licenseButton, creditsButton])
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        buttonStackView.orientation = .horizontal
        buttonStackView.spacing = 8
        buttonStackView.distribution = .fillEqually
        containerView.addSubview(buttonStackView)
        
        // Layout
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            containerView.widthAnchor.constraint(equalToConstant: 400),
            
            appIconView.topAnchor.constraint(equalTo: containerView.topAnchor),
            appIconView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            appIconView.widthAnchor.constraint(equalToConstant: 128),
            appIconView.heightAnchor.constraint(equalToConstant: 128),
            
            appNameLabel.topAnchor.constraint(equalTo: appIconView.bottomAnchor, constant: 16),
            appNameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            appNameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            versionLabel.topAnchor.constraint(equalTo: appNameLabel.bottomAnchor, constant: 4),
            versionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            versionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            scrollView.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 200),
            
            buttonStackView.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 20),
            buttonStackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            buttonStackView.widthAnchor.constraint(equalToConstant: 240),
            
            copyrightLabel.topAnchor.constraint(equalTo: buttonStackView.bottomAnchor, constant: 20),
            copyrightLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            copyrightLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            copyrightLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor)
        ])
    }
    
    private func createButton(title: String, action: Selector) -> NSButton {
        let button = NSButton()
        button.title = title
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
        return button
    }
    
    private func getBuildInfo() -> String {
        var info = [String]()
        
        // Version info
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            info.append("Version: \(version)")
        }
        
        // Build info
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            info.append("Build: \(build)")
        }
        
        // Git commit (if available)
        // Note: This would need to be set during build time
        info.append("Commit: ac4cbdf48759c7d8c3eb91ffe6b-b04316e263c57")
        
        // Build date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        info.append("Date: \(dateFormatter.string(from: Date()))")
        
        // System info
        let processInfo = ProcessInfo.processInfo
        info.append("")
        info.append("System Information:")
        info.append("macOS: \(processInfo.operatingSystemVersionString)")
        
        // Architecture
        #if arch(arm64)
        info.append("Architecture: arm64")
        #elseif arch(x86_64)
        info.append("Architecture: x86_64")
        #else
        info.append("Architecture: unknown")
        #endif
        
        // Memory
        let memory = processInfo.physicalMemory / (1024 * 1024 * 1024)
        info.append("Memory: \(memory) GB")
        
        // Processor count
        info.append("Processors: \(processInfo.processorCount)")
        
        return info.joined(separator: "\n")
    }
    
    @objc private func showLicense() {
        let alert = NSAlert()
        alert.messageText = "License"
        alert.informativeText = "MacFileExplorer is released under the MIT License.\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files, to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func showCredits() {
        let alert = NSAlert()
        alert.messageText = "Credits"
        alert.informativeText = "MacFileExplorer\n\nDeveloped with ❤️ using Swift and AppKit.\n\nSpecial thanks to the open source community."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
