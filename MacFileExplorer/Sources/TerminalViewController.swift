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
    private(set) var promptLocation: Int = 0

    // Shell session via PTY so output is line-buffered like a real terminal
    private var shellTask: Process?
    private var masterFD: Int32 = -1
    private var slaveFD: Int32 = -1
    private var masterHandle: FileHandle?
    private var outputTask: Task<Void, Never>?
    private var outputContinuation: AsyncStream<Data>.Continuation?
    private let sentinelEcho = "MFE_SENTINEL_12345"
    private(set) var lastSyncedDirectory: String?
    private var inputBuffer = ""
    private(set) var suppressOutputUntilSentinel = false

    // OSC 133 semantic-prompt state (populated from shell-integration markers).
    /// Exit code reported by the most recently finished command, if any.
    private(set) var lastExitCode: Int?
    /// True between a `commandStart` (133;C) marker and the next `commandEnd` (133;D).
    private(set) var isCommandRunning = false
    /// True once a `promptEnd` (133;B) marker has pinned `promptLocation` precisely,
    /// so `processOutput` should stop overwriting it with the end-of-text heuristic.
    private var promptLocationIsPinned = false
    /// True while the shell is idle at a prompt (between `133;B` and the next
    /// `133;C`). Directory syncs are only safe to inject when this is true —
    /// otherwise the `cd` string would be delivered as keystrokes to whatever
    /// foreground program owns the PTY (vim, ssh, a sudo password prompt).
    private(set) var isAtPrompt = false
    /// A directory sync requested while a command was running; flushed on the
    /// next `133;B`. Only the most recent target matters.
    private(set) var pendingDirectorySync: String?
    /// Fallback that clears `suppressOutputUntilSentinel` if the expected
    /// sentinel / prompt marker never arrives (e.g. a shell without our .zshrc,
    /// or a wedged foreground program), so the panel never goes permanently dark.
    private var suppressionTimeoutTask: Task<Void, Never>?
    private let suppressionTimeout: Duration = .seconds(2)

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 200))
        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        currentDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        appendOutput(String(format: L10n.text("Terminal initializing in %@\n"), currentDirectory), color: AppDesignSystem.Terminal.dimForeground)
        startShellSession()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // Only focus if the window is fully loaded and ready
        if view.window != nil {
            Task { @MainActor [weak self] in
                self?.focusInput()
            }
        }
    }

    deinit {
        terminateShellSession()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = AppDesignSystem.Terminal.background.cgColor

        // Create header view
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = AppDesignSystem.Terminal.headerBackground.cgColor
        view.addSubview(headerView)

        // Create title label
        titleLabel = NSTextField(labelWithString: L10n.text("Terminal"))
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = AppDesignSystem.Terminal.foreground
        titleLabel.font = AppDesignSystem.Terminal.headerTitleFont
        titleLabel.setAccessibilityLabel(L10n.text("Terminal"))
        titleLabel.setAccessibilityRole(.staticText)
        headerView.addSubview(titleLabel)

        // Create close button
        closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .texturedRounded
        closeButton.image = NSImage.mfeSymbol(named: "xmark", accessibilityDescription: "Close Terminal")
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
        textView.backgroundColor = AppDesignSystem.Terminal.background
        textView.textColor = AppDesignSystem.Terminal.foreground
        textView.font = AppDesignSystem.Typography.monospace()
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
            container.lineBreakMode = .byCharWrapping
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
        // Guard against double-initialization - prevent file descriptor leaks
        guard masterFD == -1 else {
            debugLog("[Terminal] Shell session already running, skipping start")
            return
        }
        
        // Get the user's shell (PTY-backed for interactive behavior)
        let shellPath = getShellPath()
        appendOutput("Starting shell (\(shellPath))...\n", color: AppDesignSystem.Terminal.dimForeground)

        // Create PTY
        var master: Int32 = -1
        var slave: Int32 = -1
        var win = winsize()
        win.ws_row = 40
        win.ws_col = 120
        win.ws_xpixel = 0
        win.ws_ypixel = 0

        if openpty(&master, &slave, nil, nil, &win) != 0 {
            appendOutput("Failed to create PTY\n", color: AppDesignSystem.Colors.error)
            return
        }
        masterFD = master
        slaveFD = slave

        // Disable echo at PTY level before starting shell to prevent setup commands from being visible
        var termios = Darwin.termios()
        if tcgetattr(master, &termios) == 0 {
            termios.c_lflag &= ~UInt(ECHO)
            tcsetattr(master, TCSANOW, &termios)
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: shellPath)
        task.arguments = ["-i"]  // Interactive shell (not login) since we use custom RC via ZDOTDIR

        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["CLICOLOR"] = "1"
        environment["COLORTERM"] = "truecolor"
        environment["PWD"] = currentDirectory
        // Disable zsh's partial line indicator (the % symbol)
        environment["PROMPT_EOL_MARK"] = ""
        // Use app-specific terminal config directory instead of user's ~/.zshrc
        if let terminalConfigDir = getOrCreateTerminalConfigDir() {
            environment["ZDOTDIR"] = terminalConfigDir
        }
        task.environment = environment
        task.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)

        let slaveHandle = FileHandle(fileDescriptor: slave, closeOnDealloc: false)
        task.standardInput = slaveHandle
        task.standardOutput = slaveHandle
        task.standardError = slaveHandle

        task.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                self?.appendOutput("\nShell exited (\(proc.terminationStatus))\n", color: AppDesignSystem.Terminal.dimForeground)
            }
        }

        do {
            try task.run()
            shellTask = task
            startReadingPTY()
            appendOutput("Shell session started (\(shellPath))\n", color: AppDesignSystem.Colors.success)
            lastSyncedDirectory = currentDirectory
            // PTY echo is already disabled via termios, just send sentinel
            beginSuppressingOutput()
            writeToShell("printf \"\(sentinelEcho)\\n\"\n")

        } catch {
            appendOutput("Failed to start shell: \(error.localizedDescription)\n", color: AppDesignSystem.Colors.error)
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

        let handle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: false)
        masterHandle = handle

        let stream = AsyncStream<Data> { [weak self] continuation in
            Task { @MainActor [weak self] in
                self?.outputContinuation = continuation
            }
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.outputContinuation = nil
                }
            }
            handle.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    continuation.finish()
                    handle.readabilityHandler = nil
                } else {
                    continuation.yield(data)
                }
            }
        }

        outputTask?.cancel()
        outputTask = Task.detached { [weak self] in
            guard let self else { return }
            for await data in stream {
                if Task.isCancelled { break }
                if let output = String(data: data, encoding: .utf8) {
                    await MainActor.run {
                        self.processOutput(output)
                    }
                }
            }
        }
    }

    func processOutput(_ output: String) {
        // Drop any programmatic echoes until the sentinel is seen so the UI stays clean
        var text = output
        
        if suppressOutputUntilSentinel {
            if let sentinelRange = text.range(of: sentinelEcho) {
                endSuppressingOutput()

                // Seeing our own sentinel echoed back is proof the shell consumed
                // a full line, i.e. it is sitting at a prompt. This is the only
                // idle signal available for shells without our OSC 133 .zshrc.
                isAtPrompt = true
                flushPendingDirectorySync()

                // Discard everything in the current buffer up to and including the current line
                // This ensures the echo of the command itself is completely hidden.
                let afterSentinel = text[sentinelRange.upperBound...]
                if let nextNewline = afterSentinel.firstIndex(of: "\n") {
                    text = String(afterSentinel[afterSentinel.index(after: nextNewline)...])
                } else if let nextCR = afterSentinel.firstIndex(of: "\r") {
                    text = String(afterSentinel[afterSentinel.index(after: nextCR)...])
                } else {
                    text = ""
                }
                
                // If nothing meaningful remains, we've successfully swallowed the internal command.
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // The injected `cd` triggers a fresh prompt whose 133;B marker
                    // will re-pin promptLocation; until then fall back to the heuristic.
                    promptLocationIsPinned = false
                    // promptLocation is consumed as an NSRange offset, so it must be a
                    // UTF-16 length — String.count diverges on emoji/multi-scalar output.
                    promptLocation = (textView.string as NSString).length
                    textView.setSelectedRange(NSRange(location: promptLocation, length: 0))
                    return
                }
            } else {
                // Sentinel not found yet in this chunk, discard all to keep UI clean.
                return
            }
        }

        // Normalize carriage returns: 
        // 1. CRLF -> LF
        // 2. standalone CR -> LF (avoids staircase "jumping" in log-style view)
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
                            .replacingOccurrences(of: "\r", with: "\n")
        
        var markers: [SemanticMarker] = []
        let cleaned = stripControlSequences(normalized, markers: &markers)
        let filtered = cleaned
            .components(separatedBy: "\n")
            .filter { !$0.contains(sentinelEcho) }
            .joined(separator: "\n")

        let attributed = parseANSI(filtered)
        if attributed.length > 0 {
            textView.textStorage?.append(attributed)
            textView.scrollToEndOfDocument(nil)
            updateScrollVisibility()
        }

        applySemanticMarkers(markers)

        // Fall back to the end-of-text heuristic only while no 133;B marker has
        // pinned the prompt location for the current prompt.
        if !promptLocationIsPinned {
            promptLocation = (textView.string as NSString).length
        }
        textView.setSelectedRange(NSRange(location: promptLocation, length: 0))
    }

    /// React to OSC 133 markers extracted from a chunk of shell output. Markers
    /// arrive interleaved with text, but by the time this runs the text for this
    /// chunk has already been appended, so "current end of text" is the right
    /// anchor for `promptEnd`.
    private func applySemanticMarkers(_ markers: [SemanticMarker]) {
        for marker in markers {
            switch marker {
            case .promptStart:
                // A new prompt is being drawn; the previous pin is stale.
                promptLocationIsPinned = false
            case .promptEnd:
                // The prompt string has finished printing — everything the user
                // types starts exactly here, and the shell is now idle.
                promptLocation = (textView.string as NSString).length
                promptLocationIsPinned = true
                isCommandRunning = false
                isAtPrompt = true
                flushPendingDirectorySync()
            case .commandStart:
                isCommandRunning = true
                isAtPrompt = false
            case .commandEnd(let code):
                isCommandRunning = false
                lastExitCode = code
            }
        }
    }

    /// If a directory sync was deferred while a command was running, issue it now
    /// that the shell is back at a prompt.
    private func flushPendingDirectorySync() {
        guard let path = pendingDirectorySync else { return }
        pendingDirectorySync = nil
        guard path != lastSyncedDirectory else { return }
        debugLog("TerminalViewController: flushing deferred directory sync to \(path)")
        performDirectorySync(to: path)
    }

    private func parseANSI(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var currentColor: NSColor = AppDesignSystem.Terminal.foreground
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
                            .font: AppDesignSystem.Typography.monospace(weight: currentBold ? .bold : .regular)
                        ]
                    )
                    result.append(attrs)
                    i = nextIdx
                    continue
                }

                // Found ANSI escape sequence
                var j = text.index(nextIdx, offsetBy: 1)
                var code = ""
                var finalChar: Character = "\0"

                while j < text.endIndex {
                    let char = text[j]
                    let scalar = char.unicodeScalars.first?.value ?? 0

                    // The final byte of a CSI sequence is in the range 0x40 to 0x7E (@ through ~)
                    if scalar >= 0x40 && scalar <= 0x7E {
                        finalChar = char
                        break
                    }

                    code.append(char)
                    j = text.index(after: j)
                }

                // Parse color code if the final character is 'm'
                if finalChar == "m" && !code.isEmpty {
                    let codes = code.split(separator: ";").compactMap { Int($0) }
                    for c in codes {
                        switch c {
                        case 0:  // Reset
                            currentColor = AppDesignSystem.Terminal.foreground
                            currentBold = false
                        case 1:  // Bold
                            currentBold = true
                        case 30: currentColor = AppDesignSystem.Terminal.ANSI.black
                        case 31: currentColor = AppDesignSystem.Terminal.ANSI.red
                        case 32: currentColor = AppDesignSystem.Terminal.ANSI.green
                        case 33: currentColor = AppDesignSystem.Terminal.ANSI.yellow
                        case 34: currentColor = AppDesignSystem.Terminal.ANSI.blue
                        case 35: currentColor = AppDesignSystem.Terminal.ANSI.magenta
                        case 36: currentColor = AppDesignSystem.Terminal.ANSI.cyan
                        case 37: currentColor = AppDesignSystem.Terminal.ANSI.white
                        case 90: currentColor = AppDesignSystem.Terminal.ANSI.brightBlack
                        case 91: currentColor = AppDesignSystem.Terminal.ANSI.brightRed
                        case 92: currentColor = AppDesignSystem.Terminal.ANSI.brightGreen
                        case 93: currentColor = AppDesignSystem.Terminal.ANSI.brightYellow
                        case 94: currentColor = AppDesignSystem.Terminal.ANSI.brightBlue
                        case 95: currentColor = AppDesignSystem.Terminal.ANSI.brightMagenta
                        case 96: currentColor = AppDesignSystem.Terminal.ANSI.brightCyan
                        case 97: currentColor = AppDesignSystem.Terminal.ANSI.brightWhite
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
                    let font = AppDesignSystem.Typography.monospace(weight: currentBold ? .bold : .regular)

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

    // MARK: - OSC 133 semantic prompt markers

    /// A parsed OSC 133 shell-integration marker (see default-terminal.zshrc).
    enum SemanticMarker: Equatable {
        case promptStart          // 133;A  — fresh line, a new prompt is about to be drawn
        case promptEnd            // 133;B  — end of the prompt string; user input begins here
        case commandStart         // 133;C  — the entered command has begun executing
        case commandEnd(Int?)     // 133;D  — command finished; associated value is the exit code
    }

    /// Strip OSC (Operating System Command) sequences that can appear in prompts,
    /// extracting any OSC 133 semantic markers in the order they occur. Non-133
    /// OSC sequences are removed silently, matching the previous behaviour.
    func stripControlSequences(_ text: String, markers: inout [SemanticMarker]) -> String {
        var output = ""
        var i = text.startIndex
        while i < text.endIndex {
            let char = text[i]
            if char == "\u{1B}" { // ESC
                let next = text.index(after: i)
                if next < text.endIndex && text[next] == "]" {
                    // Collect the OSC body up to BEL or ST (ESC \).
                    var body = ""
                    var j = text.index(after: next)
                    var terminated = false
                    while j < text.endIndex {
                        if text[j] == "\u{07}" { // BEL
                            j = text.index(after: j)
                            terminated = true
                            break
                        }
                        if text[j] == "\u{1B}" {
                            let maybe = text.index(after: j)
                            if maybe < text.endIndex && text[maybe] == "\\" { // ST
                                j = text.index(after: maybe)
                                terminated = true
                                break
                            }
                        }
                        body.append(text[j])
                        j = text.index(after: j)
                    }
                    if terminated, let marker = Self.parseOSC133(body) {
                        markers.append(marker)
                    }
                    i = j
                    continue
                }
            }
            output.append(char)
            i = text.index(after: i)
        }
        return output
    }

    /// Parse the body of an OSC sequence (everything between `ESC ]` and the
    /// terminator) into a `SemanticMarker` if it is an OSC 133 sequence.
    private static func parseOSC133(_ body: String) -> SemanticMarker? {
        let parts = body.split(separator: ";", omittingEmptySubsequences: false)
        guard parts.first == "133", parts.count >= 2 else { return nil }
        switch parts[1] {
        case "A": return .promptStart
        case "B": return .promptEnd
        case "C": return .commandStart
        case "D":
            // 133;D or 133;D;<exit-code>
            let code = parts.count >= 3 ? Int(parts[2]) : nil
            return .commandEnd(code)
        default:
            return nil
        }
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
        suppressionTimeoutTask?.cancel()
        suppressionTimeoutTask = nil
        outputTask?.cancel()
        outputTask = nil
        outputContinuation?.finish()
        outputContinuation = nil
        masterHandle?.readabilityHandler = nil
        masterHandle = nil

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

    /// Returns the path to the app's custom terminal config directory.
    /// Creates the directory and copies the default .zshrc if needed.
    private func getOrCreateTerminalConfigDir() -> String? {
        let fileManager = FileManager.default

        // Get Application Support directory
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            debugLog("TerminalViewController: Could not find Application Support directory")
            return nil
        }

        let terminalConfigDir = appSupport
            .appendingPathComponent("MacFileExplorer", isDirectory: true)
            .appendingPathComponent("terminal", isDirectory: true)

        // Create directory if needed
        if !fileManager.fileExists(atPath: terminalConfigDir.path) {
            do {
                try fileManager.createDirectory(at: terminalConfigDir, withIntermediateDirectories: true)
                debugLog("TerminalViewController: Created terminal config directory at \(terminalConfigDir.path)")
            } catch {
                debugLog("TerminalViewController: Failed to create terminal config directory: \(error)")
                return nil
            }
        }

        // Copy default .zshrc from bundle if it doesn't exist
        let zshrcPath = terminalConfigDir.appendingPathComponent(".zshrc")
        if !fileManager.fileExists(atPath: zshrcPath.path) {
            if let bundleRC = Bundle.main.path(forResource: "default-terminal", ofType: "zshrc") {
                do {
                    try fileManager.copyItem(atPath: bundleRC, toPath: zshrcPath.path)
                    debugLog("TerminalViewController: Copied default terminal config to \(zshrcPath.path)")
                } catch {
                    debugLog("TerminalViewController: Failed to copy default terminal config: \(error)")
                }
            } else {
                debugLog("TerminalViewController: default-terminal.zshrc not found in bundle")
            }
        }

        return terminalConfigDir.path
    }

    /// Returns the path to the terminal config file for external editing.
    static func terminalConfigFilePath() -> URL? {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport
            .appendingPathComponent("MacFileExplorer", isDirectory: true)
            .appendingPathComponent("terminal", isDirectory: true)
            .appendingPathComponent(".zshrc")
    }

    // MARK: - Public Methods

    /// Escape a string for safe use in shell commands.
    /// Escapes all shell metacharacters to prevent command injection.
    private static func escapeShellArgument(_ arg: String) -> String {
        // If the string is empty, return empty quotes
        if arg.isEmpty { return "''" }
        
        // Check if string contains any special characters
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~/:@")
        if arg.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) {
            return arg
        }
        
        // Escape by wrapping in single quotes and replacing single quotes with '\"'\"'
        // This is the safest approach: close quote, add escaped quote, open quote
        return "'" + arg.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    func changeDirectory(to path: String) {
        if path == lastSyncedDirectory { return }
        currentDirectory = path
        debugLog("TerminalViewController: changeDirectory to \(path)")

        // Only inject the `cd` when the shell is idle at a prompt. If a command
        // is running, the string would go to that program as keystrokes; instead
        // remember the target and flush it once the shell returns to a prompt.
        guard isAtPrompt else {
            debugLog("  shell busy, deferring directory sync to \(path)")
            pendingDirectorySync = path
            return
        }

        performDirectorySync(to: path)
    }

    /// Actually write the `cd` command to the shell. Caller must ensure the shell
    /// is at a prompt.
    private func performDirectorySync(to path: String) {
        lastSyncedDirectory = path
        pendingDirectorySync = nil
        // Send cd command without echoing to the terminal and drop any echoed text until sentinel arrives
        beginSuppressingOutput()
        // Properly escape path for shell execution
        let escapedPath = Self.escapeShellArgument(path)
        // "--" stops option parsing so a hyphen-leading path can't be read as a flag
        let command = "cd -- \(escapedPath) 2>/dev/null; printf \"\(sentinelEcho)\\n\"\n"
        writeToShell(command)
    }

    /// Start dropping shell output until the startup/sync sentinel is seen, and
    /// arm a timeout so a missing sentinel can never leave the panel dark forever.
    private func beginSuppressingOutput() {
        suppressOutputUntilSentinel = true
        suppressionTimeoutTask?.cancel()
        let timeout = suppressionTimeout
        suppressionTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.suppressOutputUntilSentinel else { return }
                debugLog("TerminalViewController: suppression timeout fired; re-enabling output")
                self.suppressOutputUntilSentinel = false
                self.promptLocationIsPinned = false
                self.promptLocation = (self.textView.string as NSString).length
                self.textView.setSelectedRange(NSRange(location: self.promptLocation, length: 0))
            }
        }
    }

    /// Stop suppressing output and cancel the timeout.
    private func endSuppressingOutput() {
        suppressOutputUntilSentinel = false
        suppressionTimeoutTask?.cancel()
        suppressionTimeoutTask = nil
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

    private func appendOutput(_ text: String, color: NSColor = AppDesignSystem.Terminal.foreground) {
        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: color,
                .font: AppDesignSystem.Typography.monospace()
            ]
        )

        textView.textStorage?.append(attributedString)
        textView.scrollToEndOfDocument(nil)
        updateScrollVisibility()
    }

    @objc func closeButtonClicked(_ sender: Any) {
        delegate?.terminalViewControllerDidRequestClose(self)
    }

    private func updateScrollVisibility() {
        let isEmpty = textView.string.isEmpty
        scrollView.verticalScroller?.alphaValue = isEmpty ? 0 : 1
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updatePTYSize()
    }

    private func updatePTYSize() {
        guard masterFD >= 0 else { return }
        
        // Calculate rows and columns based on view size and font
        let font = AppDesignSystem.Typography.monospace()
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let charSize = ("A" as NSString).size(withAttributes: attributes)
        
        let horizontalInset: CGFloat = 10
        let verticalInset: CGFloat = 10
        let lineFragmentPadding: CGFloat = 5 // Default for NSTextContainer
        
        // availableWidth should subtract both insets and lineFragmentPadding on both sides
        let availableWidth = textView.bounds.width - (horizontalInset * 2) - (lineFragmentPadding * 2)
        let availableHeight = scrollView.contentView.bounds.height - (verticalInset * 2)
        
        let cols = Int32(max(10, floor(availableWidth / charSize.width)))
        let rows = Int32(max(1, floor(availableHeight / charSize.height)))
        
        var win = winsize()
        win.ws_row = UInt16(rows)
        win.ws_col = UInt16(cols)
        win.ws_xpixel = 0
        win.ws_ypixel = 0
        
        // Use TIOCSWINSZ to update the PTY window size
        // Note: TIOCSWINSZ is usually defined in sys/ioctl.h
        if ioctl(masterFD, TIOCSWINSZ, &win) == -1 {
            debugLog("TerminalViewController: Failed to update PTY size via ioctl: \(String(cString: strerror(errno)))")
        } else {
            debugLog("TerminalViewController: Updated PTY size to \(cols)x\(rows)")
        }
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
            // The shell is about to run a command; treat it as busy immediately
            // so a directory sync in the gap before the 133;C marker is deferred
            // rather than injected into the running program.
            isAtPrompt = false
            writeToShell(input + "\n")
            return true
        } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
            if !commandHistory.isEmpty && historyIndex > 0 {
                historyIndex -= 1
                replaceCurrentInput(with: commandHistory[historyIndex])
            } else if !commandHistory.isEmpty && historyIndex == 0 {
                // Already at first command, stay there
                replaceCurrentInput(with: commandHistory[0])
            }
            return true
        } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
            if historyIndex < commandHistory.count - 1 {
                historyIndex += 1
                replaceCurrentInput(with: commandHistory[historyIndex])
            } else if historyIndex < commandHistory.count {
                historyIndex = commandHistory.count
                replaceCurrentInput(with: "")
            }
            // If already past history (historyIndex >= commandHistory.count), stay there
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
        textView.setSelectedRange(NSRange(location: promptLocation + (text as NSString).length, length: 0))
    }
}
