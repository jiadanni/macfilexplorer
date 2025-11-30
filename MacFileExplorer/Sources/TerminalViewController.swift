import Cocoa
import Darwin

protocol TerminalViewControllerDelegate: AnyObject {
    func terminalViewControllerDidRequestClose(_ controller: TerminalViewController)
}

class TerminalViewController: NSViewController {

    weak var delegate: TerminalViewControllerDelegate?

    private var headerView: NSView!
    private var closeButton: NSButton!
    private var titleLabel: NSTextField!
    private var scrollView: NSScrollView!
    private var textView: NSTextView!
    private var inputField: NSTextField!
    private var currentDirectory: String = ""
    private var commandHistory: [String] = []
    private var historyIndex = 0

    // PTY-based shell session
    private var masterFileDescriptor: Int32 = -1
    private var shellTask: Process?
    private var inputSource: DispatchSourceRead?
    private var outputQueue = DispatchQueue(label: "com.macfileexplorer.terminal.output")
    private var inputBuffer = ""

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 200))
        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        currentDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        startShellSession()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        focusInput()
        inputField.becomeFirstResponder()
    }

    deinit {
        terminateShellSession()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(white: 0.1, alpha: 1.0).cgColor

        // Create header view
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1.0).cgColor
        view.addSubview(headerView)

        // Create title label
        titleLabel = NSTextField(labelWithString: "Terminal")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = NSColor(white: 0.9, alpha: 1.0)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 12)
        headerView.addSubview(titleLabel)

        // Create close button
        closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .texturedRounded
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close Terminal")
        closeButton.target = self
        closeButton.action = #selector(closeButtonClicked(_:))
        closeButton.isBordered = false
        headerView.addSubview(closeButton)

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
        inputField.placeholderString = "$"
        inputField.delegate = self
        inputField.target = self
        inputField.action = #selector(handleEnterKey(_:))
        view.addSubview(inputField)

        // Set up constraints
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 26),

            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 20),
            closeButton.heightAnchor.constraint(equalToConstant: 20),

            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: inputField.topAnchor, constant: -1),

            inputField.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputField.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputField.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            inputField.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    // MARK: - PTY Shell Session Management

    private func startShellSession() {
        // Get the user's shell
        let shellPath = getShellPath()

        // Create PTY
        masterFileDescriptor = posix_openpt(O_RDWR | O_NOCTTY)
        guard masterFileDescriptor >= 0 else {
            appendOutput("Failed to create PTY\n", color: .red)
            return
        }

        guard grantpt(masterFileDescriptor) == 0,
              unlockpt(masterFileDescriptor) == 0 else {
            appendOutput("Failed to configure PTY\n", color: .red)
            close(masterFileDescriptor)
            masterFileDescriptor = -1
            return
        }

        // Get slave PTY path
        guard let slaveName = String(validatingUTF8: ptsname(masterFileDescriptor)) else {
            appendOutput("Failed to get PTY slave name\n", color: .red)
            close(masterFileDescriptor)
            masterFileDescriptor = -1
            return
        }

        // Spawn shell process
        shellTask = Process()
        shellTask?.executableURL = URL(fileURLWithPath: shellPath)
        shellTask?.arguments = ["-l"]  // Login shell

        // Set environment
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["CLICOLOR"] = "1"
        environment["COLORTERM"] = "truecolor"
        environment["PWD"] = currentDirectory
        shellTask?.environment = environment
        shellTask?.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)

        // Open slave PTY for stdin/stdout/stderr
        let slaveFile = open(slaveName, O_RDWR)
        guard slaveFile >= 0 else {
            appendOutput("Failed to open PTY slave\n", color: .red)
            close(masterFileDescriptor)
            masterFileDescriptor = -1
            return
        }

        // Redirect process I/O to slave PTY
        shellTask?.standardInput = FileHandle(fileDescriptor: slaveFile, closeOnDealloc: false)
        shellTask?.standardOutput = FileHandle(fileDescriptor: slaveFile, closeOnDealloc: false)
        shellTask?.standardError = FileHandle(fileDescriptor: slaveFile, closeOnDealloc: false)

        do {
            try shellTask?.run()
            close(slaveFile)  // Close slave in parent process

            // Start reading from master PTY
            startReadingOutput()

            appendOutput("Shell session started (\(shellPath))\n", color: .green)
        } catch {
            appendOutput("Failed to start shell: \(error.localizedDescription)\n", color: .red)
            close(slaveFile)
            close(masterFileDescriptor)
            masterFileDescriptor = -1
        }
    }

    private func startReadingOutput() {
        guard masterFileDescriptor >= 0 else { return }

        // Set terminal window size
        var winsize = winsize()
        winsize.ws_row = 24
        winsize.ws_col = 80
        winsize.ws_xpixel = 0
        winsize.ws_ypixel = 0
        _ = ioctl(masterFileDescriptor, TIOCSWINSZ, &winsize)

        // Make file descriptor non-blocking
        let flags = fcntl(masterFileDescriptor, F_GETFL)
        _ = fcntl(masterFileDescriptor, F_SETFL, flags | O_NONBLOCK)

        // Create dispatch source to read from PTY
        inputSource = DispatchSource.makeReadSource(fileDescriptor: masterFileDescriptor, queue: outputQueue)

        inputSource?.setEventHandler { [weak self] in
            self?.readFromPTY()
        }

        inputSource?.setCancelHandler { [weak self] in
            if let fd = self?.masterFileDescriptor, fd >= 0 {
                close(fd)
            }
        }

        inputSource?.resume()

        // Send initial newline to trigger shell prompt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.writeToPTY("\n")
        }
    }

    private func readFromPTY() {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(masterFileDescriptor, &buffer, buffer.count)

        guard bytesRead > 0 else { return }

        if let output = String(bytes: buffer.prefix(bytesRead), encoding: .utf8) {
            DispatchQueue.main.async { [weak self] in
                self?.processOutput(output)
            }
        }
    }

    private func processOutput(_ output: String) {
        // Parse ANSI escape codes and apply formatting
        let attributed = parseANSI(output)
        textView.textStorage?.append(attributed)
        textView.scrollToEndOfDocument(nil)
    }

    private func parseANSI(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var currentColor: NSColor = NSColor(white: 0.9, alpha: 1.0)
        var currentBold = false

        var i = text.startIndex
        while i < text.endIndex {
            if text[i] == "\u{1B}" {
                // Check if this is an ANSI escape sequence
                let nextIdx = text.index(after: i)
                guard nextIdx < text.endIndex && text[nextIdx] == "[" else {
                    // Not a valid escape sequence, treat as regular character
                    let attrs = NSAttributedString(
                        string: String(text[i]),
                        attributes: [
                            .foregroundColor: currentColor,
                            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: currentBold ? .bold : .regular)
                        ]
                    )
                    result.append(attrs)
                    i = nextIdx
                    continue
                }

                // Found ANSI escape sequence
                var j = text.index(nextIdx, offsetBy: 1)
                var code = ""
                while j < text.endIndex && text[j] != "m" {
                    code.append(text[j])
                    j = text.index(after: j)
                }

                // Parse color code
                if !code.isEmpty {
                    let codes = code.split(separator: ";").compactMap { Int($0) }
                    for c in codes {
                        switch c {
                        case 0:  // Reset
                            currentColor = NSColor(white: 0.9, alpha: 1.0)
                            currentBold = false
                        case 1:  // Bold
                            currentBold = true
                        case 30: currentColor = .black
                        case 31: currentColor = .red
                        case 32: currentColor = .green
                        case 33: currentColor = .yellow
                        case 34: currentColor = .blue
                        case 35: currentColor = .magenta
                        case 36: currentColor = .cyan
                        case 37: currentColor = .white
                        case 90: currentColor = .darkGray
                        case 91: currentColor = NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
                        case 92: currentColor = NSColor(red: 0.4, green: 1.0, blue: 0.4, alpha: 1.0)
                        case 93: currentColor = NSColor(red: 1.0, green: 1.0, blue: 0.4, alpha: 1.0)
                        case 94: currentColor = NSColor(red: 0.4, green: 0.4, blue: 1.0, alpha: 1.0)
                        case 95: currentColor = NSColor(red: 1.0, green: 0.4, blue: 1.0, alpha: 1.0)
                        case 96: currentColor = NSColor(red: 0.4, green: 1.0, blue: 1.0, alpha: 1.0)
                        case 97: currentColor = NSColor(white: 0.95, alpha: 1.0)
                        default: break
                        }
                    }
                }

                // Move past the 'm' character if we found it
                i = j < text.endIndex ? text.index(after: j) : text.endIndex
            } else {
                // Regular character
                var normalText = ""
                while i < text.endIndex && text[i] != "\u{1B}" {
                    normalText.append(text[i])
                    i = text.index(after: i)
                }

                if !normalText.isEmpty {
                    let font = currentBold ?
                        NSFont.monospacedSystemFont(ofSize: 12, weight: .bold) :
                        NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

                    let attrs = NSAttributedString(
                        string: normalText,
                        attributes: [
                            .foregroundColor: currentColor,
                            .font: font
                        ]
                    )
                    result.append(attrs)
                }
            }
        }

        return result
    }

    private func writeToPTY(_ text: String) {
        guard masterFileDescriptor >= 0 else { return }

        if let data = text.data(using: .utf8) {
            data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                _ = write(masterFileDescriptor, bytes.baseAddress, data.count)
            }
        }
    }

    private func terminateShellSession() {
        inputSource?.cancel()
        inputSource = nil

        shellTask?.terminate()
        shellTask = nil

        if masterFileDescriptor >= 0 {
            close(masterFileDescriptor)
            masterFileDescriptor = -1
        }
    }

    private func getShellPath() -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"] {
            return shell
        }

        let userName = NSUserName()
        if let passwdEntry = getpwnam(userName),
           let shellCStr = passwdEntry.pointee.pw_shell {
            return String(cString: shellCStr)
        }

        return "/bin/zsh"
    }

    // MARK: - Public Methods

    func changeDirectory(to path: String) {
        currentDirectory = path
        print("TerminalViewController: changeDirectory to \(path)")
        // Send cd command to shell
        writeToPTY("cd '\(path)'\n")
    }

    func focusInput() {
        print("TerminalViewController: focusInput called")
        view.window?.makeFirstResponder(inputField)
    }

    // MARK: - Private Methods

    private func appendOutput(_ text: String, color: NSColor = NSColor(white: 0.9, alpha: 1.0)) {
        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: color,
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            ]
        )

        textView.textStorage?.append(attributedString)
        textView.scrollToEndOfDocument(nil)
    }

    @objc private func handleEnterKey(_ sender: NSTextField) {
        let command = sender.stringValue
        guard !command.isEmpty else {
            writeToPTY("\n")
            sender.stringValue = ""
            return
        }

        commandHistory.append(command)
        historyIndex = commandHistory.count

        // Send command to PTY
        writeToPTY(command + "\n")
        sender.stringValue = ""
    }

    private func handleTabCompletion() {
        // Send tab character to shell for completion
        writeToPTY("\t")
    }

    @objc private func closeButtonClicked(_ sender: Any) {
        delegate?.terminalViewControllerDidRequestClose(self)
    }
}

// MARK: - NSTextFieldDelegate

extension TerminalViewController: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Handle special keys
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
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
        } else if commandSelector == #selector(NSResponder.insertTab(_:)) {
            // Tab - trigger completion
            handleTabCompletion()
            return true
        }
        return false
    }
}
