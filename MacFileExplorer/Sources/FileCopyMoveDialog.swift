import Cocoa
import Foundation

class FileCopyMoveDialog: NSWindowController {

    private var progressIndicator: NSProgressIndicator!
    private var speedLabel: NSTextField!
    private var fileQueueTextView: NSTextView!
    private var pauseButton: NSButton!
    private var cancelButton: NSButton!
    private var statusLabel: NSTextField!
    private var titleLabel: NSTextField!

    @Atomic private var isPaused = false
    @Atomic private var isCancelled = false
    private var operation: FileOperation?

    private var startTime: Date?
    private var totalBytesProcessed: Int64 = 0
    private var totalBytesToProcess: Int64 = 0
    var onCompletion: (() -> Void)?

    enum OperationType {
        case copy
        case move
    }

    init(operationType: OperationType, sourceFiles: [URL], destination: URL) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = operationType == .copy ? L10n.text("Copying Files") : L10n.text("Moving Files")
        window.center()

        super.init(window: window)

        setupUI()

        // Start the operation
        operation = FileOperation(
            type: operationType,
            sourceFiles: sourceFiles,
            destination: destination,
            delegate: self
        )
        startOperation()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func setupUI() {
        guard let window = window, let contentView = window.contentView else { return }

        // Main stack view
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        contentView.addSubview(stackView)

        // Title label
        titleLabel = NSTextField(labelWithString: L10n.text("Preparing files..."))
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        stackView.addArrangedSubview(titleLabel)

        // Status label
        statusLabel = NSTextField(labelWithString: L10n.text("Calculating size..."))
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(statusLabel)

        // Progress indicator
        progressIndicator = NSProgressIndicator()
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 100
        progressIndicator.doubleValue = 0
        progressIndicator.setAccessibilityLabel(L10n.text("Operation progress"))
        stackView.addArrangedSubview(progressIndicator)

        // Speed label
        speedLabel = NSTextField(labelWithString: "Speed: --")
        speedLabel.font = NSFont.systemFont(ofSize: 11)
        speedLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(speedLabel)

        // File queue section
        let queueLabel = NSTextField(labelWithString: L10n.text("File Queue:"))
        queueLabel.font = NSFont.boldSystemFont(ofSize: 12)
        stackView.addArrangedSubview(queueLabel)

        // Scroll view for file queue
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.autohidesScrollers = true
        stackView.addArrangedSubview(scrollView)

        fileQueueTextView = NSTextView()
        fileQueueTextView.isEditable = false
        fileQueueTextView.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        fileQueueTextView.setAccessibilityLabel(L10n.text("Queued files"))
        scrollView.documentView = fileQueueTextView

        // Buttons
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 10
        stackView.addArrangedSubview(buttonStack)

        pauseButton = NSButton(title: L10n.text("Pause"), target: self, action: #selector(pauseButtonClicked(_:)))
        pauseButton.bezelStyle = .rounded
        pauseButton.setAccessibilityLabel(L10n.text("Pause"))
        buttonStack.addArrangedSubview(pauseButton)

        cancelButton = NSButton(title: L10n.text("Cancel"), target: self, action: #selector(cancelButtonClicked(_:)))
        cancelButton.bezelStyle = .rounded
        cancelButton.setAccessibilityLabel(L10n.text("Cancel"))
        buttonStack.addArrangedSubview(cancelButton)

        // Constraints
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),

            progressIndicator.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            scrollView.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 150)
        ])
    }

    private func startOperation() {
        startTime = Date()
        operation?.start()
    }

    @objc private func pauseButtonClicked(_ sender: NSButton) {
        let paused = $isPaused.update { value in
            value.toggle()
            return value
        }

        if paused {
            pauseButton.title = L10n.text("Resume")
            pauseButton.setAccessibilityLabel(L10n.text("Resume"))
            operation?.pause()
        } else {
            pauseButton.title = L10n.text("Pause")
            pauseButton.setAccessibilityLabel(L10n.text("Pause"))
            operation?.resume()
        }
    }

    @objc private func cancelButtonClicked(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = L10n.text("Cancel Operation")
        alert.informativeText = L10n.text("Are you sure you want to cancel this operation?")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.text("Cancel Operation Button"))
        alert.addButton(withTitle: L10n.text("Continue"))

        if alert.runModal() == .alertFirstButtonReturn {
            let shouldCancel = $isCancelled.update { cancelled in
                if cancelled { return false }
                cancelled = true
                return true
            }
            guard shouldCancel else { return }
            operation?.cancel()
            close()
        }
    }

    private func updateSpeed() {
        guard let startTime = startTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed > 0 && totalBytesProcessed > 0 {
            let bytesPerSecond = Double(totalBytesProcessed) / elapsed
            let speedString = ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file)
            speedLabel.stringValue = "Speed: \(speedString)/s"
        }
    }
}

// MARK: - FileOperationDelegate

extension FileCopyMoveDialog: FileOperationDelegate {
    func fileOperationDidStart(totalBytes: Int64, fileCount: Int) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.totalBytesToProcess = totalBytes
            self.statusLabel.stringValue = "\(fileCount) file(s) to process"
        }
    }

    func fileOperationDidProgress(currentFile: String, bytesProcessed: Int64, totalBytes: Int64) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            self.totalBytesProcessed = bytesProcessed
            self.titleLabel.stringValue = "Processing: \(currentFile)"

            if totalBytes > 0 {
                let percentage = Double(bytesProcessed) / Double(totalBytes) * 100
                self.progressIndicator.doubleValue = percentage
            }

            self.updateSpeed()
        }
    }

    func fileOperationDidComplete() {
        Task { @MainActor [weak self] in
            guard let self else { return }

            self.titleLabel.stringValue = L10n.text("Complete!")
            self.statusLabel.stringValue = L10n.text("All files processed successfully")
            self.progressIndicator.doubleValue = 100
            self.pauseButton.isEnabled = false

            self.onCompletion?()

            if let start = self.startTime {
                OperationMetricsManager.append(type: self.operation?.type == .copy ? "advanced-copy" : "advanced-move", bytes: self.totalBytesProcessed, files: self.operation?.sourceFiles.count ?? 0, start: start, end: Date())
            }

            // Auto-close after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.close()
        }
    }

    func fileOperationDidFail(error: String) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            let alert = NSAlert()
            alert.messageText = L10n.text("Operation Failed")
            alert.informativeText = error
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()

            self.close()
        }
    }

    func fileOperationDidUpdateQueue(files: [String]) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            var queueText = ""
            for (index, file) in files.enumerated() {
                queueText += "\(index + 1). \(file)\n"
            }
            self.fileQueueTextView.string = queueText
        }
    }
}

// MARK: - FileOperation

protocol FileOperationDelegate: AnyObject {
    func fileOperationDidStart(totalBytes: Int64, fileCount: Int)
    func fileOperationDidProgress(currentFile: String, bytesProcessed: Int64, totalBytes: Int64)
    func fileOperationDidComplete()
    func fileOperationDidFail(error: String)
    func fileOperationDidUpdateQueue(files: [String])
}

private actor FileOperationControl {
    private var isPaused = false
    private var isCancelled = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func pause() {
        isPaused = true
    }

    func resume() {
        isPaused = false
        resumeAll()
    }

    func cancel() {
        isCancelled = true
        resumeAll()
    }

    func shouldCancel() -> Bool {
        isCancelled
    }

    func waitIfPaused() async {
        if isCancelled || !isPaused {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func resumeAll() {
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}

class FileOperation {

    let type: FileCopyMoveDialog.OperationType
    let sourceFiles: [URL]
    private let destination: URL
    private weak var delegate: FileOperationDelegate?

    private let control = FileOperationControl()
    private var operationTask: Task<Void, Never>?

    init(type: FileCopyMoveDialog.OperationType, sourceFiles: [URL], destination: URL, delegate: FileOperationDelegate?) {
        self.type = type
        self.sourceFiles = sourceFiles
        self.destination = destination
        self.delegate = delegate
    }

    func start() {
        operationTask = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.performOperation()
        }
    }

    func pause() {
        Task { await control.pause() }
    }

    func resume() {
        Task { await control.resume() }
    }

    func cancel() {
        operationTask?.cancel()
        Task { await control.cancel() }
    }

    private func performOperation() async {
        let fileManager = FileManager.default

        // Calculate total size
        var totalSize: Int64 = 0
        var filesToProcess: [URL] = []

        for sourceURL in sourceFiles {
            if let enumerator = fileManager.enumerator(at: sourceURL, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) {
                for case let fileURL as URL in enumerator {
                    if Task.isCancelled || await control.shouldCancel() { return }

                    filesToProcess.append(fileURL)

                    // Get file size
                    await control.waitIfPaused()
                    if Task.isCancelled || await control.shouldCancel() { return }
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                        if let isDirectory = resourceValues.isDirectory, !isDirectory {
                            totalSize += Int64(resourceValues.fileSize ?? 0)
                        }
                    } catch {
                        debugLog("Error getting file size: \(error)")
                    }
                }
            }
        }

        delegate?.fileOperationDidStart(totalBytes: totalSize, fileCount: filesToProcess.count)
        delegate?.fileOperationDidUpdateQueue(files: filesToProcess.map { $0.lastPathComponent })

        // Process files
        var bytesProcessed: Int64 = 0

        for sourceURL in sourceFiles {
            if Task.isCancelled || await control.shouldCancel() { return }

            await control.waitIfPaused()
            if Task.isCancelled || await control.shouldCancel() { return }

            let fileName = sourceURL.lastPathComponent
            let destinationURL = destination.appendingPathComponent(fileName)

            // Check for conflict and handle auto-rename if needed
            var finalDestination = destinationURL
            if fileManager.fileExists(atPath: destinationURL.path) {
                if SettingsStore.shared.autoRenameOnConflict {
                    finalDestination = generateUniqueURL(for: destinationURL)
                } else {
                    // Show conflict dialog (simplified for now)
                    delegate?.fileOperationDidFail(error: "File '\(fileName)' already exists at destination")
                    return
                }
            }

            do {
                if type == .copy {
                    try fileManager.copyItem(at: sourceURL, to: finalDestination)
                } else {
                    try fileManager.moveItem(at: sourceURL, to: finalDestination)
                }

                // Update progress
                if let attributes = try? fileManager.attributesOfItem(atPath: sourceURL.path),
                   let fileSize = attributes[.size] as? Int64 {
                    bytesProcessed += fileSize
                }

                delegate?.fileOperationDidProgress(
                    currentFile: fileName,
                    bytesProcessed: bytesProcessed,
                    totalBytes: totalSize
                )
            } catch {
                delegate?.fileOperationDidFail(error: "Failed to \(type == .copy ? "copy" : "move") '\(fileName)': \(error.localizedDescription)")
                return
            }
        }

        delegate?.fileOperationDidComplete()
    }

    private func generateUniqueURL(for url: URL) -> URL {
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        var counter = 1
        var newURL = url

        while fileManager.fileExists(atPath: newURL.path) {
            let newFilename = ext.isEmpty ? "\(filename) (\(counter))" : "\(filename) (\(counter)).\(ext)"
            newURL = directory.appendingPathComponent(newFilename)
            counter += 1
        }

        return newURL
    }

}
