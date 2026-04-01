//
//  StorageSettingsViewController.swift
//  MacFileExplorer
//
//  Created on 17/11/2025.
//

import Cocoa

class StorageSettingsViewController: NSViewController {
    
    private var stackView: NSStackView!
    
    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.controlBackgroundColor
        self.view = scrollView
        
        let contentView = SettingsContentView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 16
        contentView.addSubview(stackView)
        
        scrollView.documentView = contentView
        
        NSLayoutConstraint.activate([
            // Properly constrain document view to scroll view's content view
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        
        setupUI()
    }
    
    private func setupUI() {
        // Title
        let titleLabel = NSTextField(labelWithString: "Storage Analyzer")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 2)
        stackView.addArrangedSubview(titleLabel)
        
        // Description
        let descriptionLabel = NSTextField(labelWithString: "Analyze your disk usage to find large files and folders consuming space.")
        descriptionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 0
        descriptionLabel.preferredMaxLayoutWidth = 450
        stackView.addArrangedSubview(descriptionLabel)
        
        addSpacer(height: 8)
        
        // Adaptive scanning info
        let adaptiveTitle = NSTextField(labelWithString: "Adaptive Scanning")
        adaptiveTitle.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 1)
        stackView.addArrangedSubview(adaptiveTitle)
        
        let adaptiveInfo = NSTextField(labelWithString: """
        The storage analyzer adapts to your permission level:
        
        • Standard Access: Scans your home directory and personal files
        • Full Disk Access: Enables complete system scan including caches and system data
        
        The analyzer will automatically detect and use the appropriate scan mode.
        """)
        adaptiveInfo.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        adaptiveInfo.textColor = .secondaryLabelColor
        adaptiveInfo.lineBreakMode = .byWordWrapping
        adaptiveInfo.maximumNumberOfLines = 0
        adaptiveInfo.preferredMaxLayoutWidth = 450
        stackView.addArrangedSubview(adaptiveInfo)
        
        addSpacer(height: 8)
        
        // Launch button
        let launchButton = NSButton(title: "Open Storage Analyzer", target: self, action: #selector(launchAnalyzerClicked))
        launchButton.bezelStyle = .rounded
        launchButton.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(launchButton)
        
        addSpacer(height: 16)
        
        // FDA info section
        let fdaTitle = NSTextField(labelWithString: "Enabling Full Disk Access")
        fdaTitle.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 1)
        stackView.addArrangedSubview(fdaTitle)
        
        let fdaInfo = NSTextField(labelWithString: """
        For a complete system scan including all system files and caches:
        
        1. Open System Settings
        2. Go to Privacy & Security → Full Disk Access
        3. Click the + button and add MacFileExplorer
        4. Restart MacFileExplorer
        
        After enabling FDA, the analyzer will automatically scan your entire system.
        """)
        fdaInfo.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        fdaInfo.textColor = .secondaryLabelColor
        fdaInfo.lineBreakMode = .byWordWrapping
        fdaInfo.maximumNumberOfLines = 0
        fdaInfo.preferredMaxLayoutWidth = 450
        stackView.addArrangedSubview(fdaInfo)
        
        let fdaButton = NSButton(title: "Open System Settings", target: self, action: #selector(openSystemSettingsClicked))
        fdaButton.bezelStyle = .rounded
        fdaButton.controlSize = .small
        stackView.addArrangedSubview(fdaButton)
    }
    
    private func addSpacer(height: CGFloat) {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
        stackView.addArrangedSubview(spacer)
    }
    
    @objc private func launchAnalyzerClicked() {
        let analyzerWindow = StorageAnalyzerWindowController()
        analyzerWindow.showWindow(nil)
    }
    
    @objc private func openSystemSettingsClicked() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        } else {
            debugLog("StorageSettingsViewController: Failed to create URL for System Settings")
        }
    }
}
