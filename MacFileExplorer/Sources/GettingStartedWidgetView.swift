//
//  GettingStartedWidgetView.swift
//  MacFileExplorer
//
//  Getting Started checklist widget for Start Page
//

import Cocoa

class GettingStartedWidgetView: StartWidgetView {

    private var tasksStack: NSStackView!

    private var tasks: [(id: String, title: String, completed: Bool)] = [
        ("pinFolder", "Pin your first folder", false),
        ("grantAccess", "Grant folder access", false),
        ("tryStorage", "Try the Storage Analyzer", false),
        ("customize", "Customize your toolbar", false)
    ]

    init() {
        super.init(title: "Getting Started", icon: StartDesignSystem.Icons.checkmark, dismissible: true)
        loadTaskStates()
        setupContent()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadTaskStates()
        setupContent()
    }

    private func loadTaskStates() {
        for (index, task) in tasks.enumerated() {
            let key = "GettingStarted_\(task.id)"
            let completed = UserDefaults.standard.bool(forKey: key)
            tasks[index].completed = completed
        }
    }

    override func setupContent() {
        tasksStack = NSStackView()
        tasksStack.orientation = .vertical
        tasksStack.spacing = StartDesignSystem.Spacing.sm
        tasksStack.alignment = .leading
        tasksStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tasksStack)

        for (index, task) in tasks.enumerated() {
            let taskView = createTaskView(task: task, index: index)
            tasksStack.addArrangedSubview(taskView)
        }

        // Check if all complete
        if tasks.allSatisfy({ $0.completed }) {
            addCompletionMessage()
        }

        NSLayoutConstraint.activate([
            tasksStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            tasksStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tasksStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tasksStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func createTaskView(task: (id: String, title: String, completed: Bool), index: Int) -> NSView {
        let container = NSView()

        // Checkbox
        let checkbox = NSButton(checkboxWithTitle: task.title, target: self, action: #selector(taskToggled(_:)))
        checkbox.state = task.completed ? .on : .off
        checkbox.tag = index
        checkbox.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(checkbox)

        NSLayoutConstraint.activate([
            checkbox.topAnchor.constraint(equalTo: container.topAnchor),
            checkbox.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            checkbox.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            checkbox.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func addCompletionMessage() {
        let messageLabel = StartDesignSystem.createLabel(
            text: "🎉 Great! You're all set up. Feel free to dismiss this widget.",
            style: .caption
        )
        messageLabel.textColor = StartDesignSystem.Colors.success
        tasksStack.addArrangedSubview(messageLabel)
    }

    @objc private func taskToggled(_ sender: NSButton) {
        let index = sender.tag
        guard index < tasks.count else { return }

        tasks[index].completed = sender.state == .on

        // Save state
        let key = "GettingStarted_\(tasks[index].id)"
        UserDefaults.standard.set(tasks[index].completed, forKey: key)

        // Notify delegate
        delegate?.widgetDidRequestAction(.taskCompleted(tasks[index].id), widget: self)

        // Check if all complete
        if tasks.allSatisfy({ $0.completed }) {
            // Rebuild to show completion message
            tasksStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for (index, task) in tasks.enumerated() {
                let taskView = createTaskView(task: task, index: index)
                tasksStack.addArrangedSubview(taskView)
            }
            addCompletionMessage()
        }
    }

    func markTaskCompleted(id: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].completed = true

        let key = "GettingStarted_\(id)"
        UserDefaults.standard.set(true, forKey: key)

        // Refresh UI
        refresh()
    }

    override func refresh() {
        tasksStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        loadTaskStates()

        for (index, task) in tasks.enumerated() {
            let taskView = createTaskView(task: task, index: index)
            tasksStack.addArrangedSubview(taskView)
        }

        if tasks.allSatisfy({ $0.completed }) {
            addCompletionMessage()
        }
    }
}
