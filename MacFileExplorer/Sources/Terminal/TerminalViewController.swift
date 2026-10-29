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
    private var subtitleLabel: NSTextField!
    private var scrollView: NSScrollView!
    private var textView: NSTextView!
    private var currentDirectory: String = "" {
        didSet { updateHeaderSubtitle() }
    }
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
    /// Per-session secret carried by every OSC 133 marker the shell integration emits.
    /// Output from `cat`, a build log or a remote host cannot know it, so it cannot forge
    /// prompt/idle markers. `nil` accepts the legacy un-nonced form (used by tests and by
    /// shells running an old integration script).
    var markerNonce: String? = UUID().uuidString.replacingOccurrences(of: "-", with: "")
    private var sentinelEcho: String { "MFE_SENTINEL_" + (markerNonce ?? "12345") }
    /// Tail of an escape sequence cut off by a PTY read boundary, completed by the next read.
    private var pendingEscape = ""
    /// Text typed while a password-style prompt is active; never displayed or recorded.
    private var secretInput = ""
    private static let maxScrollbackUTF16 = 400_000
    private static let maxCommandHistory = 1000
    private(set) var lastSyncedDirectory: String?
    /// Everything currently shown in the terminal view (for tests).
    var textViewStringForTesting: String { textView?.string ?? "" }
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
        // The terminal keeps a fixed dark theme; resolve semantic colors (scrollers,
        // header buttons) against the dark appearance regardless of system setting.
        view.appearance = NSAppearance(named: .darkAqua)

        // Header: "Terminal  zsh — ~/path" with a close button and a hairline below
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = AppDesignSystem.Terminal.headerBackground.cgColor
        view.addSubview(headerView)

        titleLabel = NSTextField(labelWithString: L10n.text("Terminal"))
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = AppDesignSystem.Terminal.headerTitleColor
        titleLabel.font = AppDesignSystem.Terminal.headerTitleFont
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.setAccessibilityLabel(L10n.text("Terminal"))
        titleLabel.setAccessibilityRole(.staticText)
        headerView.addSubview(titleLabel)

        subtitleLabel = NSTextField(labelWithString: "")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.textColor = AppDesignSystem.Terminal.headerSubtitleColor
        subtitleLabel.font = AppDesignSystem.Terminal.headerSubtitleFont
        subtitleLabel.lineBreakMode = .byTruncatingHead
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        headerView.addSubview(subtitleLabel)

        let closeIcon = ToolbarIconButton(symbolName: "xmark", accessibilityDescription: L10n.text("Close Terminal"))
        closeIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        closeIcon.toolTip = L10n.text("Hide Terminal")
        closeIcon.target = self
        closeIcon.action = #selector(closeButtonClicked(_:))
        closeButton = closeIcon
        headerView.addSubview(closeButton)

        let headerDivider = HairlineView(color: AppDesignSystem.Terminal.headerDivider)
        headerView.addSubview(headerDivider)

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
        let terminalTextView = TerminalTextView()
        terminalTextView.onControlByte = { [weak self] byte in self?.sendControlByte(byte) }
        textView = terminalTextView
        textView.isEditable = true
        textView.isSelectable = true
        textView.backgroundColor = AppDesignSystem.Terminal.background
        textView.textColor = AppDesignSystem.Terminal.foreground
        textView.font = AppDesignSystem.Typography.monospace()
        textView.textContainerInset = NSSize(width: 12, height: 12)
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
            headerView.heightAnchor.constraint(equalToConstant: 30),

            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            subtitleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -8),

            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 22),
            closeButton.heightAnchor.constraint(equalToConstant: 22),

            headerDivider.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerDivider.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            headerDivider.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),

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
        if let nonce = markerNonce {
            // Un-exported by the integration script right after zsh starts, so child
            // processes do not inherit it.
            environment["MFE_NONCE"] = nonce
        }
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
            // The child now holds its own copy of the slave end. Close ours so the
            // master sees EOF when the shell exits; otherwise the read loop never ends.
            close(slaveFD)
            slaveFD = -1
            startReadingPTY()
            appendOutput("Shell session started (\(shellPath))\n", color: AppDesignSystem.Colors.success)
            lastSyncedDirectory = currentDirectory
            // PTY echo is already disabled via termios, just send sentinel
            beginSuppressingOutput()
            // Leading space keeps it out of history (HIST_IGNORE_SPACE in the integration script).
            writeToShell(" printf \"\(sentinelEcho)\\n\"\n")

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
                // read(2) instead of availableData: once the shell exits the master
                // returns EIO, which availableData surfaces as an uncatchable exception.
                var buffer = [UInt8](repeating: 0, count: 4096)
                let count = read(handle.fileDescriptor, &buffer, buffer.count)
                if count > 0 {
                    continuation.yield(Data(buffer[0..<count]))
                } else if count == 0 || (errno != EAGAIN && errno != EINTR) {
                    continuation.finish()
                    handle.readabilityHandler = nil
                }
            }
        }

        outputTask?.cancel()
        // Hold self weakly for the lifetime of the loop so the controller can deinit
        // (and tear the session down) while the shell is still running.
        outputTask = Task.detached { [weak self] in
            var pending = [UInt8]()
            for await data in stream {
                if Task.isCancelled { break }
                pending.append(contentsOf: data)
                let output = TerminalViewController.takeDecodableUTF8(from: &pending)
                guard !output.isEmpty else { continue }
                guard let self else { break }
                await self.processOutput(output)
            }
        }
    }

    /// Decodes the bytes in `buffer` up to the last complete UTF-8 sequence and leaves
    /// any trailing partial sequence in `buffer` for the next read, so a character split
    /// across PTY reads isn't lost. Invalid bytes decode as U+FFFD rather than dropping output.
    nonisolated static func takeDecodableUTF8(from buffer: inout [UInt8]) -> String {
        guard !buffer.isEmpty else { return "" }
        var leadIndex = buffer.count - 1
        var continuationBytes = 0
        while leadIndex >= 0, continuationBytes < 3, buffer[leadIndex] & 0xC0 == 0x80 {
            leadIndex -= 1
            continuationBytes += 1
        }
        var cut = buffer.count
        if leadIndex >= 0 {
            let lead = buffer[leadIndex]
            let sequenceLength = lead >= 0xF0 ? 4 : lead >= 0xE0 ? 3 : lead >= 0xC0 ? 2 : 1
            if sequenceLength > continuationBytes + 1 {
                cut = leadIndex
            }
        }
        let output = String(decoding: buffer[0..<cut], as: UTF8.self)
        buffer.removeFirst(cut)
        return output
    }

    func processOutput(_ output: String) {
        // A PTY read can end in the middle of an escape sequence; hold the tail back and
        // finish it with the next read instead of printing or mis-parsing the fragments.
        let split = Self.splitIncompleteEscape(pendingEscape + output)
        pendingEscape = split.pending
        var text = split.complete
        if text.isEmpty { return }

        // Drop any programmatic echoes until the sentinel is seen so the UI stays clean
        
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
            trimScrollbackIfNeeded()
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

                // Parse color code if the final character is 'm' (an empty list means reset)
                if finalChar == "m" {
                    let codes = code.isEmpty
                        ? [0]
                        : code.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
                    var index = 0
                    while index < codes.count {
                        let c = codes[index]
                        switch c {
                        case 0:  // Reset
                            currentColor = AppDesignSystem.Terminal.foreground
                            currentBold = false
                        case 1:  // Bold
                            currentBold = true
                        case 22: currentBold = false
                        case 30: currentColor = AppDesignSystem.Terminal.ANSI.black
                        case 31: currentColor = AppDesignSystem.Terminal.ANSI.red
                        case 32: currentColor = AppDesignSystem.Terminal.ANSI.green
                        case 33: currentColor = AppDesignSystem.Terminal.ANSI.yellow
                        case 34: currentColor = AppDesignSystem.Terminal.ANSI.blue
                        case 35: currentColor = AppDesignSystem.Terminal.ANSI.magenta
                        case 36: currentColor = AppDesignSystem.Terminal.ANSI.cyan
                        case 37: currentColor = AppDesignSystem.Terminal.ANSI.white
                        case 39: currentColor = AppDesignSystem.Terminal.foreground
                        case 90: currentColor = AppDesignSystem.Terminal.ANSI.brightBlack
                        case 91: currentColor = AppDesignSystem.Terminal.ANSI.brightRed
                        case 92: currentColor = AppDesignSystem.Terminal.ANSI.brightGreen
                        case 93: currentColor = AppDesignSystem.Terminal.ANSI.brightYellow
                        case 94: currentColor = AppDesignSystem.Terminal.ANSI.brightBlue
                        case 95: currentColor = AppDesignSystem.Terminal.ANSI.brightMagenta
                        case 96: currentColor = AppDesignSystem.Terminal.ANSI.brightCyan
                        case 97: currentColor = AppDesignSystem.Terminal.ANSI.brightWhite
                        case 38, 48:
                            // Extended colour: 38;5;<n> / 38;2;<r>;<g>;<b> (48 = background, which
                            // this view does not draw). Consume the parameters so they are not
                            // misread as standalone SGR codes (e.g. the 31 in 38;5;31).
                            if index + 1 < codes.count, codes[index + 1] == 5 {
                                if c == 38, index + 2 < codes.count {
                                    currentColor = Self.xterm256Color(codes[index + 2])
                                }
                                index += 2
                            } else if index + 1 < codes.count, codes[index + 1] == 2 {
                                if c == 38, index + 4 < codes.count {
                                    currentColor = NSColor(
                                        srgbRed: CGFloat(min(max(codes[index + 2], 0), 255)) / 255,
                                        green: CGFloat(min(max(codes[index + 3], 0), 255)) / 255,
                                        blue: CGFloat(min(max(codes[index + 4], 0), 255)) / 255,
                                        alpha: 1)
                                }
                                index += 4
                            }
                        default: break
                        }
                        index += 1
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
                    if terminated, let marker = parseOSC133(body) {
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
    /// terminator) into a `SemanticMarker` if it is an authentic OSC 133 sequence.
    /// With a session nonce set, the nonce must be the final field; markers without
    /// it are ignored as untrusted output.
    private func parseOSC133(_ body: String) -> SemanticMarker? {
        var parts = body.split(separator: ";", omittingEmptySubsequences: false)
        guard parts.first == "133", parts.count >= 2 else { return nil }
        if let nonce = markerNonce {
            guard parts.count >= 3, parts.last == Substring(nonce) else { return nil }
            parts.removeLast()
        }
        switch parts[1] {
        case "A": return .promptStart
        case "B": return .promptEnd
        case "C": return .commandStart
        case "D":
            // 133;D or 133;D;<exit-code> (nonce already removed)
            let code = parts.count >= 3 ? Int(parts[2]) : nil
            return .commandEnd(code)
        default:
            return nil
        }
    }

    /// Splits `text` into the part that ends on a complete escape-sequence boundary and a
    /// trailing fragment of an unfinished CSI/OSC sequence (to be completed by the next read).
    nonisolated static func splitIncompleteEscape(_ text: String) -> (complete: String, pending: String) {
        var i = text.startIndex
        var incompleteStart: String.Index?
        while i < text.endIndex {
            guard text[i] == "\u{1B}" else { i = text.index(after: i); continue }
            let next = text.index(after: i)
            if next == text.endIndex { incompleteStart = i; break }

            if text[next] == "[" {
                var j = text.index(after: next)
                var finished = false
                while j < text.endIndex {
                    let value = text[j].unicodeScalars.first?.value ?? 0
                    if value >= 0x40 && value <= 0x7E { finished = true; break }
                    j = text.index(after: j)
                }
                if !finished { incompleteStart = i; break }
                i = text.index(after: j)
            } else if text[next] == "]" {
                var j = text.index(after: next)
                var finished = false
                while j < text.endIndex {
                    if text[j] == "\u{07}" { j = text.index(after: j); finished = true; break }
                    if text[j] == "\u{1B}" {
                        let after = text.index(after: j)
                        if after == text.endIndex { break } // possibly the start of ST (ESC \)
                        if text[after] == "\\" { j = text.index(after: after); finished = true; break }
                    }
                    j = text.index(after: j)
                }
                if !finished { incompleteStart = i; break }
                i = j
            } else {
                i = next
            }
        }
        guard let start = incompleteStart else { return (text, "") }
        let pending = String(text[start...])
        // Never hold back more than a sane sequence length (runaway/unterminated input).
        if pending.utf16.count > 4096 { return (text, "") }
        return (String(text[..<start]), pending)
    }

    private static func xterm256Color(_ n: Int) -> NSColor {
        let ansi = AppDesignSystem.Terminal.ANSI.self
        let base: [NSColor] = [ansi.black, ansi.red, ansi.green, ansi.yellow, ansi.blue, ansi.magenta, ansi.cyan, ansi.white,
                               ansi.brightBlack, ansi.brightRed, ansi.brightGreen, ansi.brightYellow,
                               ansi.brightBlue, ansi.brightMagenta, ansi.brightCyan, ansi.brightWhite]
        switch n {
        case 0..<16:
            return base[n]
        case 16..<232:
            let v = n - 16
            func component(_ c: Int) -> CGFloat { c == 0 ? 0 : CGFloat(55 + 40 * c) / 255 }
            return NSColor(srgbRed: component(v / 36), green: component((v / 6) % 6), blue: component(v % 6), alpha: 1)
        case 232..<256:
            let gray = CGFloat(8 + 10 * (n - 232)) / 255
            return NSColor(srgbRed: gray, green: gray, blue: gray, alpha: 1)
        default:
            return AppDesignSystem.Terminal.foreground
        }
    }

    private func trimScrollbackIfNeeded() {
        guard let storage = textView.textStorage, storage.length > Self.maxScrollbackUTF16 else { return }
        // Drop an extra quarter so trimming is not repeated on every chunk.
        let excess = storage.length - Self.maxScrollbackUTF16 + Self.maxScrollbackUTF16 / 4
        storage.deleteCharacters(in: NSRange(location: 0, length: excess))
        promptLocation = max(0, promptLocation - excess)
    }

    private func writeToShell(_ text: String) {
        guard masterFD >= 0, let data = text.data(using: .utf8) else { return }
        let fd = masterFD
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            var retries = 0
            // The master is non-blocking: handle partial writes and a full PTY buffer
            // instead of silently dropping the rest of the input.
            while offset < raw.count {
                let written = write(fd, base.advanced(by: offset), raw.count - offset)
                if written > 0 {
                    offset += written
                    retries = 0
                } else if written < 0, errno == EINTR || errno == EAGAIN, retries < 200 {
                    retries += 1
                    usleep(1000)
                } else {
                    debugLog("[Terminal] write to PTY failed: \(String(cString: strerror(errno)))")
                    break
                }
            }
        }
    }

    /// True while a program (not the shell prompt) is waiting on a password-style prompt.
    private var isSecretInputActive: Bool {
        guard !isAtPrompt, let textView else { return false }
        let text = textView.string as NSString
        let end = min(promptLocation, text.length)
        guard end > 0 else { return false }
        let head = text.substring(to: end)
        return Self.looksLikeSecretPrompt(head.components(separatedBy: "\n").last ?? head)
    }

    /// Heuristic for lines such as `[sudo] password for me:` or `Enter passphrase:`.
    nonisolated static func looksLikeSecretPrompt(_ line: String) -> Bool {
        let lower = line.lowercased().trimmingCharacters(in: .whitespaces)
        guard lower.hasSuffix(":") else { return false }
        return ["password", "passphrase", "passcode"].contains { lower.contains($0) }
    }

    /// Sends a raw control byte (Ctrl-C = 0x03, Ctrl-D = 0x04, Ctrl-Z = 0x1A) to the shell.
    func sendControlByte(_ byte: UInt8) {
        guard masterFD >= 0 else { return }
        secretInput = ""
        let nsText = textView.string as NSString
        let pendingInput = promptLocation <= nsText.length ? nsText.substring(from: promptLocation) : ""
        if byte == 0x04, isAtPrompt, !pendingInput.isEmpty { return } // Ctrl-D only ends an empty line
        if byte == 0x03, isAtPrompt, !pendingInput.isEmpty { replaceCurrentInput(with: "") }
        var value = byte
        _ = write(masterFD, &value, 1)
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

        if let task = shellTask, task.isRunning {
            // Closing a terminal hangs up the shell (interactive shells ignore SIGTERM);
            // zsh forwards SIGHUP to its jobs.
            kill(task.processIdentifier, SIGHUP)
            task.terminate()
        }
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

    /// "zsh — ~/Desktop" next to the header title.
    private func updateHeaderSubtitle() {
        guard let subtitleLabel else { return }
        let shellName = URL(fileURLWithPath: getShellPath()).lastPathComponent
        let directory = (currentDirectory as NSString).abbreviatingWithTildeInPath
        subtitleLabel.stringValue = directory.isEmpty ? shellName : "\(shellName) — \(directory)"
    }

    private func getShellPath() -> String {
        // Only launch a shell the system lists in /etc/shells; $SHELL is just an
        // environment variable and may be stale or attacker-influenced.
        let allowed = Self.registeredShells()
        func usable(_ path: String) -> Bool {
            allowed.contains(path) && FileManager.default.isExecutableFile(atPath: path)
        }

        if let shell = ProcessInfo.processInfo.environment["SHELL"], usable(shell) {
            return shell
        }

        let userName = NSUserName()
        if let passwdEntry = getpwnam(userName),
           let shellCStr = passwdEntry.pointee.pw_shell {
            let shell = String(cString: shellCStr)
            if usable(shell) { return shell }
        }

        return "/bin/zsh"
    }

    private static func registeredShells() -> Set<String> {
        guard let contents = try? String(contentsOfFile: "/etc/shells", encoding: .utf8) else { return [] }
        return Set(contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("/") })
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

        installShellIntegration(in: terminalConfigDir)
        return terminalConfigDir.path
    }

    /// Source line appended to a `.zshrc` that predates the managed integration script.
    private static let integrationSourceLine = #"[[ -r "${ZDOTDIR:-$HOME}/mfe-integration.zsh" ]] && source "${ZDOTDIR:-$HOME}/mfe-integration.zsh""#

    /// OSC 133 shell integration. Rewritten on every launch (so it always matches this app
    /// version) and kept separate from the user-editable `.zshrc`.
    static let shellIntegrationScript = #"""
# MacFileExplorer shell integration for the built-in terminal.
# Managed by the app and rewritten on every launch - put your own settings in .zshrc.
[[ -n "$MFE_NONCE" ]] || return 0
typeset +x MFE_NONCE        # keep the marker secret from child processes
setopt HIST_IGNORE_SPACE    # commands injected by the app start with a space
autoload -Uz add-zsh-hook

function mfe_precmd() {
    local exit_code=$?
    if [[ -n "$MFE_CMD_ACTIVE" ]]; then
        printf '\033]133;D;%s;%s\007' "$exit_code" "$MFE_NONCE"
        unset MFE_CMD_ACTIVE
    fi
    printf '\033]133;A;%s\007' "$MFE_NONCE"
    # End every prompt with a zero-width 133;B marker: where typed input begins.
    if [[ "$PROMPT" != *'133;B;'* ]]; then
        PROMPT="${PROMPT}%{"$'\033]133;B;'"${MFE_NONCE}"$'\007'"%}"
    fi
}
function mfe_preexec() {
    printf '\033]133;C;%s\007' "$MFE_NONCE"
    MFE_CMD_ACTIVE=1
}
add-zsh-hook precmd mfe_precmd
add-zsh-hook preexec mfe_preexec

"""#

    private func installShellIntegration(in directory: URL) {
        let scriptURL = directory.appendingPathComponent("mfe-integration.zsh")
        do {
            try Self.shellIntegrationScript.write(to: scriptURL, atomically: true, encoding: .utf8)
        } catch {
            debugLog("TerminalViewController: Failed to write shell integration: \(error)")
        }

        let zshrcURL = directory.appendingPathComponent(".zshrc")
        let existing = (try? String(contentsOf: zshrcURL, encoding: .utf8)) ?? ""
        if !existing.contains("mfe-integration.zsh") {
            let addition = "\n# Added by MacFileExplorer: shell integration for the built-in terminal\n\(Self.integrationSourceLine)\n"
            do {
                try (existing + addition).write(to: zshrcURL, atomically: true, encoding: .utf8)
            } catch {
                debugLog("TerminalViewController: Failed to update .zshrc: \(error)")
            }
        }
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

        // Quoting protects against the shell, but the PTY line discipline acts on
        // control bytes (^C, ^U, ^D...) before the shell ever sees the quotes.
        guard !Self.containsControlCharacters(path) else {
            appendOutput("Skipped directory sync: path contains control characters\n", color: AppDesignSystem.Terminal.dimForeground)
            return
        }

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

    static func containsControlCharacters(_ path: String) -> Bool {
        path.unicodeScalars.contains { $0.value < 0x20 || $0.value == 0x7F }
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
        // Leading space keeps it out of the user's real shell history (HIST_IGNORE_SPACE).
        let command = " cd -- \(escapedPath) 2>/dev/null; printf \"\(sentinelEcho)\\n\"\n"
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
        // A password-style prompt is active: collect keystrokes privately instead of
        // displaying them (the PTY's own echo is off), and never record them.
        if isSecretInputActive {
            if let replacement = replacementString, !replacement.isEmpty {
                secretInput += replacement.filter { !$0.isNewline }
            } else if !secretInput.isEmpty {
                secretInput.removeLast()
            }
            return false
        }

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
        // Pasted multi-line text would run line by line on a single Return; flatten it so
        // what is shown is exactly what will be executed, as one line.
        if let replacement = replacementString,
           replacement.unicodeScalars.count > 1,
           replacement.unicodeScalars.contains(where: { $0 == "\n" || $0 == "\r" }) {
            let flattened = replacement
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
            textView.insertText(flattened, replacementRange: affectedCharRange)
            return false
        }
        return true
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if isSecretInputActive || !secretInput.isEmpty {
                let secret = secretInput
                secretInput = ""
                isAtPrompt = false
                writeToShell(secret + "\n")
                return true
            }
            let fullText = textView.string as NSString
            let input = fullText.substring(from: promptLocation)
            // Input typed while a command is running belongs to that program (answers,
            // passwords, REPL lines), not to the shell: keep it out of recallable history.
            if !isCommandRunning {
                commandHistory.append(input)
                if commandHistory.count > Self.maxCommandHistory {
                    commandHistory.removeFirst(commandHistory.count - Self.maxCommandHistory)
                }
            }
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

// MARK: - Terminal text view

/// Forwards Ctrl-C / Ctrl-D / Ctrl-Z to the shell instead of treating them as text-view commands.
final class TerminalTextView: NSTextView {
    var onControlByte: ((UInt8) -> Void)?

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .control, let key = event.charactersIgnoringModifiers?.lowercased() {
            switch key {
            case "c": onControlByte?(0x03); return
            case "d": onControlByte?(0x04); return
            case "z": onControlByte?(0x1A); return
            default: break
            }
        }
        super.keyDown(with: event)
    }
}
