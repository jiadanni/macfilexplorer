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

    func focusInput() {
        view.window?.makeFirstResponder(inputField)
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

    private func appendErrorOutput(_ text: String) {
        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0),
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
        case "clear", "cls":
            textView.string = ""
        case "pwd":
            appendOutput("\(currentDirectory)\n")
        case "ls", "dir":
            listDirectory()
        case "cd":
            if components.count > 1 {
                changeToDirectory(components[1])
            } else {
                // cd without arguments goes to home
                changeToDirectory("~")
            }
        case "cat":
            if components.count > 1 {
                showFileContents(components[1])
            } else {
                appendErrorOutput("Usage: cat <file>\n")
            }
        case "exit", "quit":
            appendOutput("Terminal cannot be closed from here. Use the View menu to toggle terminal visibility.\n")
        default:
            // Execute external command
            executeExternalCommand(command)
        }
    }

    private func showHelp() {
        let helpText = """
        Available Built-in Commands:
        - ls, dir           List files in current directory
        - cd [dir]          Change directory (no args = home)
        - pwd               Print working directory
        - cat <file>        Display file contents
        - clear, cls        Clear terminal screen
        - help              Show this help message

        You can also run any system command (git, grep, find, etc.)

        """
        appendOutput(helpText)
    }

    private func showFileContents(_ filename: String) {
        var filePath: String

        if filename.hasPrefix("/") {
            // Absolute path
            filePath = filename
        } else if filename.hasPrefix("~") {
            // Expand tilde
            let path = (filename as NSString).expandingTildeInPath
            filePath = path
        } else {
            // Relative path
            filePath = (currentDirectory as NSString).appendingPathComponent(filename)
        }

        do {
            let contents = try String(contentsOfFile: filePath, encoding: .utf8)
            appendOutput(contents)
            if !contents.hasSuffix("\n") {
                appendOutput("\n")
            }
        } catch {
            appendErrorOutput("Error reading file: \(error.localizedDescription)\n")
        }
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
            appendErrorOutput("Error: \(error.localizedDescription)\n")
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
            appendErrorOutput("Error: Directory not found: \(newPath)\n")
        }
    }

    private func executeExternalCommand(_ command: String) {
        let task = Process()
        task.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)

        // Use the user's default shell from environment, fallback to zsh (default on modern macOS)
        let shellPath = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        task.executableURL = URL(fileURLWithPath: shellPath)
        task.arguments = ["-c", command]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()

            // Read output asynchronously to prevent deadlocks
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            task.waitUntilExit()

            // Display standard output
            if let output = String(data: outputData, encoding: .utf8), !output.isEmpty {
                appendOutput(output)
            }

            // Display error output in red
            if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty {
                appendErrorOutput(errorOutput)
            }

            if task.terminationStatus != 0 {
                appendErrorOutput("Command exited with status: \(task.terminationStatus)\n")
            }
        } catch {
            appendErrorOutput("Error executing command: \(error.localizedDescription)\n")
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
