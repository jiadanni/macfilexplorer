import Cocoa

class TerminalViewController: NSViewController {

    private var scrollView: NSScrollView!
    private var textView: NSTextView!
    private var inputField: NSTextField!
    private var currentDirectory: String = ""
    private var commandHistory: [String] = []
    private var historyIndex = 0

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 200))
        setupUI()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(white: 0.1, alpha: 1.0).cgColor

        // Create scroll view for terminal output
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        view.addSubview(scrollView)

        // Create text view for terminal output
        textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = NSColor(white: 0.1, alpha: 1.0)
        textView.textColor = NSColor(white: 0.9, alpha: 1.0)
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        scrollView.documentView = textView

        // Create input field for commands
        inputField = NSTextField()
        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.backgroundColor = NSColor(white: 0.15, alpha: 1.0)
        inputField.textColor = NSColor(white: 0.9, alpha: 1.0)
        inputField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        inputField.isBordered = false
        inputField.focusRingType = .none
        inputField.placeholderString = "Enter command..."
        inputField.delegate = self
        view.addSubview(inputField)

        // Set up constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: inputField.topAnchor, constant: -1),

            inputField.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputField.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputField.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            inputField.heightAnchor.constraint(equalToConstant: 30)
        ])

        // Display welcome message
        appendOutput("Terminal Ready\nType 'help' for available commands\n\n")
    }

    // MARK: - Public Methods

    func changeDirectory(to path: String) {
        currentDirectory = path
        appendOutput("📁 Changed directory to: \(path)\n")
        updatePrompt()
    }

    // MARK: - Private Methods

    private func updatePrompt() {
        let prompt = "\(currentDirectory) $ "
        inputField.placeholderString = prompt
    }

    private func appendOutput(_ text: String) {
        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: NSColor(white: 0.9, alpha: 1.0),
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            ]
        )

        textView.textStorage?.append(attributedString)
        textView.scrollToEndOfDocument(nil)
    }

    private func executeCommand(_ command: String) {
        guard !command.isEmpty else { return }

        commandHistory.append(command)
        historyIndex = commandHistory.count

        appendOutput("\(currentDirectory) $ \(command)\n")

        // Handle built-in commands
        let components = command.split(separator: " ").map(String.init)
        guard let cmd = components.first else { return }

        switch cmd {
        case "help":
            showHelp()
        case "clear":
            textView.string = ""
        case "pwd":
            appendOutput("\(currentDirectory)\n")
        case "ls":
            listDirectory()
        case "cd":
            if components.count > 1 {
                changeToDirectory(components[1])
            } else {
                appendOutput("Usage: cd <directory>\n")
            }
        default:
            // Execute external command
            executeExternalCommand(command)
        }
    }

    private func showHelp() {
        let helpText = """
        Available commands:
        - ls                List files in current directory
        - cd <dir>         Change directory
        - pwd              Print working directory
        - clear            Clear terminal
        - help             Show this help message

        You can also run any system command.

        """
        appendOutput(helpText)
    }

    private func listDirectory() {
        let fileManager = FileManager.default
        do {
            let items = try fileManager.contentsOfDirectory(atPath: currentDirectory)
            let sortedItems = items.sorted()

            for item in sortedItems {
                let itemPath = (currentDirectory as NSString).appendingPathComponent(item)
                var isDir: ObjCBool = false
                fileManager.fileExists(atPath: itemPath, isDirectory: &isDir)

                if isDir.boolValue {
                    appendOutput("📁 \(item)\n")
                } else {
                    appendOutput("📄 \(item)\n")
                }
            }
        } catch {
            appendOutput("Error: \(error.localizedDescription)\n")
        }
    }

    private func changeToDirectory(_ path: String) {
        var newPath: String

        if path.hasPrefix("/") {
            // Absolute path
            newPath = path
        } else if path == ".." {
            // Parent directory
            newPath = (currentDirectory as NSString).deletingLastPathComponent
        } else if path == "~" {
            // Home directory
            newPath = FileManager.default.homeDirectoryForCurrentUser.path
        } else {
            // Relative path
            newPath = (currentDirectory as NSString).appendingPathComponent(path)
        }

        // Check if directory exists
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: newPath, isDirectory: &isDir), isDir.boolValue {
            currentDirectory = newPath
            updatePrompt()
            appendOutput("Changed to: \(newPath)\n")
        } else {
            appendOutput("Error: Directory not found: \(newPath)\n")
        }
    }

    private func executeExternalCommand(_ command: String) {
        let task = Process()
        task.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                appendOutput(output)
            }

            if task.terminationStatus != 0 {
                appendOutput("Command exited with status: \(task.terminationStatus)\n")
            }
        } catch {
            appendOutput("Error executing command: \(error.localizedDescription)\n")
        }
    }
}

// MARK: - NSTextFieldDelegate

extension TerminalViewController: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // Enter key pressed
            let command = inputField.stringValue
            executeCommand(command)
            inputField.stringValue = ""
            return true
        } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
            // Up arrow - previous command
            if historyIndex > 0 {
                historyIndex -= 1
                inputField.stringValue = commandHistory[historyIndex]
            }
            return true
        } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
            // Down arrow - next command
            if historyIndex < commandHistory.count - 1 {
                historyIndex += 1
                inputField.stringValue = commandHistory[historyIndex]
            } else if historyIndex == commandHistory.count - 1 {
                historyIndex = commandHistory.count
                inputField.stringValue = ""
            }
            return true
        }
        return false
    }
}
