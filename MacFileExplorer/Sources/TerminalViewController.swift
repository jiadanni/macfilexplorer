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
    private var currentDirectory: String = ""
    private var commandHistory: [String] = []
    private var historyIndex = 0
    private var promptLocation: Int = 0

    // Shell session via PTY so output is line-buffered like a real terminal
    private var shellTask: Process?
    private var masterFD: Int32 = -1
    private var slaveFD: Int32 = -1
    private var masterSource: DispatchSourceRead?
    private let sentinelEcho = "MFE_SENTINEL_12345"
    private var lastSyncedDirectory: String?
    private var outputQueue = DispatchQueue(label: "com.macfileexplorer.terminal.output")
    private var inputBuffer = ""
    private var suppressOutputUntilSentinel = false

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 200))
        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        currentDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        appendOutput(String(format: L10n.text("Terminal initializing in %@\n"), currentDirectory), color: .darkGray)
        startShellSession()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // Only focus if the window is fully loaded and ready
        if view.window != nil {
            DispatchQueue.main.async { [weak self] in
                self?.focusInput()
            }
        }
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
        titleLabel = NSTextField(labelWithString: L10n.text("Terminal"))
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = NSColor(white: 0.9, alpha: 1.0)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 12)
        titleLabel.setAccessibilityLabel(L10n.text("Terminal"))
        titleLabel.setAccessibilityRole(.staticText)
        headerView.addSubview(titleLabel)

        // Create close button
        closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .texturedRounded
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close Terminal")
        closeButton.target = self
        closeButton.action = #selector(closeButtonClicked(_:))
        closeButton.isBordered = false
        closeButton.setAccessibilityRole(.button)
        closeButton.setAccessibilityLabel(L10n.text("Close Terminal"))
        headerView.addSubview(closeButton)

        // Create scroll view for terminal output
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.verticalScroller?.alphaValue = 0
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 36, right: 0)
        view.addSubview(scrollView)

        // Create text view for terminal output
        textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.backgroundColor = NSColor(white: 0.1, alpha: 1.0)
        textView.textColor = NSColor(white: 0.9, alpha: 1.0)
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width, .height]
        textView.delegate = self
        textView.setAccessibilityLabel(L10n.text("Terminal input and output"))
        textView.setAccessibilityRole(.textArea)
        if let container = textView.textContainer {
            container.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
            container.widthTracksTextView = true
        }
        textView.frame = scrollView.contentView.bounds
        scrollView.documentView = textView

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
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - PTY Shell Session Management

    private func startShellSession() {
        // Get the user's shell (PTY-backed for interactive behavior)
        let shellPath = getShellPath()
        appendOutput("Starting shell (\(shellPath))...\n", color: .gray)

        // Create PTY
        var master: Int32 = -1
        var slave: Int32 = -1
        var win = winsize()
        win.ws_row = 40
        win.ws_col = 120
        win.ws_xpixel = 0
        win.ws_ypixel = 0

        if openpty(&master, &slave, nil, nil, &win) != 0 {
            appendOutput("Failed to create PTY\n", color: .red)
            return
        }
        masterFD = master
        slaveFD = slave

        let task = Process()
        task.executableURL = URL(fileURLWithPath: shellPath)
        task.arguments = ["-l"]

        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["CLICOLOR"] = "1"
        environment["COLORTERM"] = "truecolor"
        environment["PWD"] = currentDirectory
        // Disable zsh's partial line indicator (the % symbol)
        environment["PROMPT_EOL_MARK"] = ""
        task.environment = environment
        task.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)

        let slaveHandle = FileHandle(fileDescriptor: slave, closeOnDealloc: false)
        task.standardInput = slaveHandle
        task.standardOutput = slaveHandle
        task.standardError = slaveHandle

        task.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                self?.appendOutput("\nShell exited (\(proc.terminationStatus))\n", color: .gray)
            }
        }

        do {
            try task.run()
            shellTask = task
            startReadingPTY()
            appendOutput("Shell session started (\(shellPath))\n", color: .green)
            lastSyncedDirectory = currentDirectory
            // Disable shell-side echo so input isn't duplicated; hide command output via sentinel.
            suppressOutputUntilSentinel = true
            writeToShell("stty -echo; printf \"\(sentinelEcho)\\n\"\n")
            // Trigger prompt display without altering user prompt or shell rc behavior
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.writeToShell("\n")
            }
        } catch {
            appendOutput("Failed to start shell: \(error.localizedDescription)\n", color: .red)
            shellTask = nil
            if masterFD >= 0 {
                close(masterFD)
                masterFD = -1
            }
            if slaveFD >= 0 {
                close(slaveFD)
                slaveFD = -1
            }
        }
    }

    private func startReadingPTY() {
        guard masterFD >= 0 else { return }

        // Make non-blocking
        let flags = fcntl(masterFD, F_GETFL)
        _ = fcntl(masterFD, F_SETFL, flags | O_NONBLOCK)

        let source = DispatchSource.makeReadSource(fileDescriptor: masterFD, queue: outputQueue)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let bytes = read(self.masterFD, &buffer, buffer.count)
                if bytes > 0 {
                    if let output = String(bytes: buffer.prefix(bytes), encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.processOutput(output)
                        }
                    }
                } else {
                    break
                }
            }
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.masterFD, fd >= 0 {
                close(fd)
                self?.masterFD = -1
            }
        }
        masterSource = source
        source.resume()
    }

    private func processOutput(_ output: String) {
        // Drop any programmatic cd echoes until the sentinel is seen so the UI stays clean
        var text = output
        if suppressOutputUntilSentinel {
            if let sentinelRange = text.range(of: sentinelEcho) {
                suppressOutputUntilSentinel = false
                text = String(text[sentinelRange.upperBound...])
            } else {
                return
            }
        }

        // Normalize CRLF/CR so carriage returns don't leave ghost prompts in the text view.
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let cleaned = stripControlSequences(normalized)
        let filtered = cleaned
            .components(separatedBy: "\n")
            .filter { !$0.contains(sentinelEcho) }
            .joined(separator: "\n")
            .replacingOccurrences(of: "\\n", with: "\n") // Avoid literal \n noise from stty or prompts

        let attributed = parseANSI(filtered)
        if attributed.length > 0 {
            textView.textStorage?.append(attributed)
            textView.scrollToEndOfDocument(nil)
            updateScrollVisibility()
            // Update prompt location to the end of the text
            promptLocation = textView.string.count
            // Ensure cursor is positioned at the end for user input
            textView.setSelectedRange(NSRange(location: promptLocation, length: 0))
        } else if suppressOutputUntilSentinel == false {
            // Even if no text was added, update cursor position (e.g., after sentinel-only output)
            promptLocation = textView.string.count
            textView.setSelectedRange(NSRange(location: promptLocation, length: 0))
        }
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

    // Remove OSC (Operating System Command) sequences like ESC ] ... BEL / ESC \ that can appear in prompts
    private func stripControlSequences(_ text: String) -> String {
        var output = ""
        var i = text.startIndex
        while i < text.endIndex {
            let char = text[i]
            if char == "\u{1B}" { // ESC
                let next = text.index(after: i)
                if next < text.endIndex && text[next] == "]" {
                    // Skip until BEL or ST (ESC \)
                    var j = text.index(after: next)
                    while j < text.endIndex && text[j] != "\u{07}" {
                        if text[j] == "\u{1B}" {
                            let maybe = text.index(after: j)
                            if maybe < text.endIndex && text[maybe] == "\\" {
                                j = text.index(after: maybe)
                                break
                            }
                        }
                        j = text.index(after: j)
                    }
                    if j < text.endIndex && text[j] == "\u{07}" {
                        i = text.index(after: j)
                    } else {
                        i = j
                    }
                    continue
                }
            }
            output.append(char)
            i = text.index(after: i)
        }
        return output
    }

    private func writeToShell(_ text: String) {
        guard masterFD >= 0 else { return }
        if let data = text.data(using: .utf8) {
            data.withUnsafeBytes { ptr in
                _ = write(masterFD, ptr.baseAddress, data.count)
            }
        }
    }

    private func terminateShellSession() {
        masterSource?.cancel()
        masterSource = nil

        shellTask?.terminate()
        shellTask = nil

        if slaveFD >= 0 {
            close(slaveFD)
            slaveFD = -1
        }

        if masterFD >= 0 {
            close(masterFD)
            masterFD = -1
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
        if path == lastSyncedDirectory { return }
        lastSyncedDirectory = path
        currentDirectory = path
        debugLog("TerminalViewController: changeDirectory to \(path)")
        // Send cd command without echoing to the terminal and drop any echoed text until sentinel arrives
        suppressOutputUntilSentinel = true
        // Escape single quotes in the path for the shell.
        let escapedPath = path.replacingOccurrences(of: "'", with: "'\"'\"'")
        let command = "cd '\(escapedPath)' 2>/dev/null; printf \"\(sentinelEcho)\\n\"\n"
        writeToShell(command)
    }

    func focusInput() {
        debugLog("TerminalViewController: focusInput called")
        guard let window = view.window, window.isVisible else {
            debugLog("  Window not ready for focus, deferring")
            return
        }
        window.makeFirstResponder(textView)
        textView.moveToEndOfDocument(nil)
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
        updateScrollVisibility()
    }

    @objc private func closeButtonClicked(_ sender: Any) {
        delegate?.terminalViewControllerDidRequestClose(self)
    }

    private func updateScrollVisibility() {
        let isEmpty = textView.string.isEmpty
        scrollView.verticalScroller?.alphaValue = isEmpty ? 0 : 1
    }
}

// MARK: - NSTextViewDelegate for inline input

extension TerminalViewController: NSTextViewDelegate {
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        // Prevent editing before the prompt; only allow insert/replace within the current input line.
        let promptStart = promptLocation
        let currentLength = textView.string.utf16.count
        if affectedCharRange.location < promptStart {
            textView.setSelectedRange(NSRange(location: currentLength, length: 0))
            return false
        }
        // Disallow inserting newlines directly; Return is handled in doCommandBy.
        if replacementString == "\n" || replacementString == "\r" {
            return false
        }
        return true
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            let fullText = textView.string as NSString
            let input = fullText.substring(from: promptLocation)
            commandHistory.append(input)
            historyIndex = commandHistory.count
            writeToShell(input + "\n")
            return true
        } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
            if historyIndex > 0 {
                historyIndex -= 1
                replaceCurrentInput(with: commandHistory[historyIndex])
            }
            return true
        } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
            if historyIndex < commandHistory.count - 1 {
                historyIndex += 1
                replaceCurrentInput(with: commandHistory[historyIndex])
            } else {
                historyIndex = commandHistory.count
                replaceCurrentInput(with: "")
            }
            return true
        } else if commandSelector == #selector(NSResponder.insertTab(_:)) {
            writeToShell("\t")
            return true
        }
        return false
    }

    private func replaceCurrentInput(with text: String) {
        let nsString = textView.string as NSString
        let range = NSRange(location: promptLocation, length: nsString.length - promptLocation)
        textView.replaceCharacters(in: range, with: text)
        textView.setSelectedRange(NSRange(location: promptLocation + text.count, length: 0))
    }
}
