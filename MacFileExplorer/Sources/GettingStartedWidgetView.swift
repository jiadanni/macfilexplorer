//
//  GettingStartedWidgetView.swift
//  MacFileExplorer
//
//  Getting Started checklist widget for Start Page
//

import Cocoa

class GettingStartedWidgetView: StartWidgetView {

    private var tasksStack: NSStackView!
    private var messageLabel: NSTextField!

    private var suggestions: [(id: String, title: String)] = [
        ("pinFolder", "Pin your favorite folders for quick access"),
        ("grantAccess", "Grant folder access to open protected folders"),
        ("tryStorage", "Try the Storage Analyzer to find what's taking up space"),
        ("customize", "Customize your toolbar and sidebar to your liking")
    ]

    init() {
        super.init(title: "Getting Started", icon: StartDesignSystem.Icons.start, dismissible: true)
        setupContent()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupContent()
    }

    override func setupContent() {
        // Welcome message
        messageLabel = StartDesignSystem.createLabel(
            text: "Your files, your way. Get started by exploring these powerful features.",
            style: .body
        )
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(messageLabel)
        
        // Suggestions stack
        tasksStack = NSStackView()
        tasksStack.orientation = .vertical
        tasksStack.spacing = StartDesignSystem.Spacing.sm
        tasksStack.alignment = .leading
        tasksStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tasksStack)

        for suggestion in suggestions {
            let suggestionView = createSuggestionView(suggestion: suggestion)
            tasksStack.addArrangedSubview(suggestionView)
        }

        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            tasksStack.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: StartDesignSystem.Spacing.lg),
            tasksStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tasksStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tasksStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func createSuggestionView(suggestion: (id: String, title: String)) -> NSView {
        let container = NSView()

        // Bullet point
        let bullet = StartDesignSystem.createLabel(text: "•", style: .body)
        bullet.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bullet)
        
        // Suggestion text
        let label = StartDesignSystem.createLabel(text: suggestion.title, style: .body)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            bullet.topAnchor.constraint(equalTo: container.topAnchor),
            bullet.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bullet.widthAnchor.constraint(equalToConstant: 12),
            
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.leadingAnchor.constraint(equalTo: bullet.trailingAnchor, constant: StartDesignSystem.Spacing.sm),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    func markTaskCompleted(id: String) {
        // No-op now that we removed checkboxes
    }

    override func refresh() {
        // No refresh needed for static suggestions
    }
}
