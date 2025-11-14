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

    override func viewDidLoad() {
        super.viewDidLoad()
        currentDirectory = FileManager.default.homeDirectoryForCurrentUser.path
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // Display prompt after view is fully laid out
        if textView.string.isEmpty || !textView.string.contains("$") {
            displayPrompt()
        }
        focusInput()
        inputField.becomeFirstResponder()
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
        inputField.placeholderString = ""
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
        appendOutput("Terminal Ready - Using shell: \(getShellPath())\n")
        appendOutput("Type 'help' for available commands\n\n")
    }
    
    private func getShellPath() -> String {
        // First try SHELL environment variable
        if let shell = ProcessInfo.processInfo.environment["SHELL"] {
            return shell
        }
        
        // Fallback to user's default shell from /etc/passwd or use zsh
        let userName = NSUserName()
        if let passwdEntry = getpwnam(userName),
           let shellCStr = passwdEntry.pointee.pw_shell {
            return String(cString: shellCStr)
        }
        
        // Final fallback to zsh (macOS default since Catalina)
        return "/bin/zsh"
    }

    // MARK: - Public Methods

    func changeDirectory(to path: String) {
        currentDirectory = path
        appendOutput("📁 Changed directory to: \(path)\n")
        displayPrompt()
    }

    func focusInput() {
        view.window?.makeFirstResponder(inputField)
    }

    // MARK: - Private Methods

    private func getPromptString() -> String {
        let dirName = (currentDirectory as NSString).lastPathComponent
        return "\(dirName) $ "
    }
    
    private func displayPrompt() {
        let promptString = getPromptString()
        let attributedPrompt = NSAttributedString(
            string: promptString,
            attributes: [
                .foregroundColor: NSColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0),
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
            ]
        )
        textView.textStorage?.append(attributedPrompt)
        textView.scrollToEndOfDocument(nil)
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
        guard !command.isEmpty else {
            displayPrompt()
            return
        }

        commandHistory.append(command)
        historyIndex = commandHistory.count

        // Echo the command
        appendOutput("\(command)\n")

        // Handle built-in commands
        let components = command.split(separator: " ").map(String.init)
        guard let cmd = components.first else { 
            displayPrompt()
            return
        }

        switch cmd {
        case "help":
            showHelp()
            displayPrompt()
        case "clear", "cls":
            textView.string = ""
            displayPrompt()
        case "pwd":
            appendOutput("\(currentDirectory)\n")
            displayPrompt()
        case "ls", "dir":
            listDirectory()
            displayPrompt()
        case "cd":
            if components.count > 1 {
                changeToDirectory(components[1])
            } else {
                // cd without arguments goes to home
                changeToDirectory("~")
            }
            displayPrompt()
        case "cat":
            if components.count > 1 {
                showFileContents(components[1])
            } else {
                appendErrorOutput("Usage: cat <file>\n")
            }
            displayPrompt()
        case "exit", "quit":
            appendOutput("Terminal cannot be closed from here. Use the View menu to toggle terminal visibility.\n")
            displayPrompt()
        default:
            // Execute external command
            executeExternalCommand(command)
            displayPrompt()
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
            // Don't call displayPrompt here - it's called after this function returns
        } else {
            appendErrorOutput("Error: Directory not found: \(newPath)\n")
        }
    }

    private func executeExternalCommand(_ command: String) {
        let task = Process()
        task.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)

        // Use the system's default shell
        let shellPath = getShellPath()
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
        print("control(_:textView:doCommandBy:) called with selector: \(commandSelector)")
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // Enter key pressed
            print("Enter key pressed")
            let command = inputField.stringValue
            executeCommand(command)
            inputField.stringValue = ""
            return true
        } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
            // Up arrow - previous command
            print("Up arrow pressed")
            if historyIndex > 0 {
                historyIndex -= 1
                inputField.stringValue = commandHistory[historyIndex]
            }
            return true
        } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
            // Down arrow - next command
            print("Down arrow pressed")
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
