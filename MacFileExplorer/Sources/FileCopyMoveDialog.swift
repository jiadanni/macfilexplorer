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

        guard let window = window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn {
                let shouldCancel = self?.$isCancelled.update { cancelled in
                    if cancelled { return false }
                    cancelled = true
                    return true
                } ?? false
                
                if shouldCancel {
                    self?.operation?.cancel()
                    self?.closeWindow()
                }
            }
        }
    }

    private func closeWindow() {
        if let window = window, let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
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
            self.closeWindow()
        }
    }

    func fileOperationDidFail(error: String) {
        Task { @MainActor [weak self] in
            guard let self = self, let window = self.window else { return }

            let alert = NSAlert()
            alert.messageText = L10n.text("Operation Failed")
            alert.informativeText = error
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            
            alert.beginSheetModal(for: window) { [weak self] _ in
                self?.closeWindow()
            }
        }
    }

    func fileOperationDidUpdateQueue(files: [String]) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            // Using joined for efficient string creation now that the count is limited
            let queueText = files.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")
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
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var isPaused = false

    func pause() {
        isPaused = true
    }

    func resume() {
        isPaused = false
        resumeAll()
    }

    func cancel() {
        isPaused = false
        resumeAll()
    }

    private func resumeAll() {
        let currentWaiters = waiters
        waiters.removeAll()
        for waiter in currentWaiters {
            waiter.resume()
        }
    }

    func wait() async {
        if !isPaused { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}

class FileOperation {

    let type: FileCopyMoveDialog.OperationType
    let sourceFiles: [URL]
    private let destination: URL
    private weak var delegate: FileOperationDelegate?

    private let control = FileOperationControl()
    private var operationTask: Task<Void, Never>?

    @Atomic private var isPaused = false
    @Atomic private var isCancelled = false
    private var lastUpdateTimestamp: CFAbsoluteTime = 0
    private let updateInterval: TimeInterval = 0.1 // 100ms throttle

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
        isPaused = true
        Task { await control.pause() }
    }

    func resume() {
        isPaused = false
        Task { await control.resume() }
    }

    func cancel() {
        isCancelled = true
        operationTask?.cancel()
        Task { await control.cancel() }
    }

    private func performOperation() async {
        let fileManager = FileManager.default

        // Calculate total size
        var totalSize: Int64 = 0
        var filesToProcess: [URL] = []
        var sourceSizes: [URL: Int64] = [:]

        for sourceURL in sourceFiles {
            var sourceSize: Int64 = 0

            if let enumerator = fileManager.enumerator(at: sourceURL, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) {
                var yieldCounter = 0
                while let fileURL = enumerator.nextObject() as? URL {
                    if Task.isCancelled || isCancelled { return }

                    filesToProcess.append(fileURL)

                    // Get file size
                    if isPaused {
                        await control.wait()
                    }
                    if Task.isCancelled || isCancelled { return }
                    
                    yieldCounter += 1
                    if yieldCounter >= 100 {
                        await Task.yield()
                        yieldCounter = 0
                    }

                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                        if let isDirectory = resourceValues.isDirectory, !isDirectory {
                            let fileSize = Int64(resourceValues.fileSize ?? 0)
                            totalSize += fileSize
                            sourceSize += fileSize
                        }
                    } catch {
                        debugLog("Error getting file size: \(error)")
                    }
                }
            } else {
                do {
                    let resourceValues = try sourceURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                    if resourceValues.isDirectory != true {
                        let fileSize = Int64(resourceValues.fileSize ?? 0)
                        totalSize += fileSize
                        sourceSize += fileSize
                        filesToProcess.append(sourceURL)
                    }
                } catch {
                    debugLog("Error getting file size: \(error)")
                }
            }
            sourceSizes[sourceURL] = sourceSize
        }

        delegate?.fileOperationDidStart(totalBytes: totalSize, fileCount: filesToProcess.count)
        
        // Limit the queue display to first 500 items to avoid freezing UI
        let displayLimit = 500
        var queueFiles = filesToProcess.prefix(displayLimit).map { $0.lastPathComponent }
        if filesToProcess.count > displayLimit {
            queueFiles.append("... and \(filesToProcess.count - displayLimit) more items")
        }
        delegate?.fileOperationDidUpdateQueue(files: queueFiles)

        // Process files
        var bytesProcessed: Int64 = 0

        for sourceURL in sourceFiles {
            if Task.isCancelled || isCancelled { return }

            if isPaused {
                await control.wait()
            }
            if Task.isCancelled || isCancelled { return }

            let fileName = sourceURL.lastPathComponent
            let destinationURL = destination.appendingPathComponent(fileName)

            // Check for conflict and handle auto-rename if needed
            var finalDestination = destinationURL
            if fileManager.fileExists(atPath: destinationURL.path) {
                if SettingsStore.shared.autoRenameOnConflict {
                    finalDestination = generateUniqueURL(for: destinationURL)
                } else {
                    delegate?.fileOperationDidFail(error: "File '\(fileName)' already exists at destination")
                    return
                }
            }

            do {
                if type == .move && isOnSameVolume(sourceURL, destination) {
                    // Fast atomic move on same volume
                    try fileManager.moveItem(at: sourceURL, to: finalDestination)
                    bytesProcessed += sourceSizes[sourceURL] ?? 0
                    sendProgress(currentFile: fileName, bytesProcessed: bytesProcessed, totalBytes: totalSize)
                } else {
                    // Copy (or cross-volume move) - handle recursively for progress
                    try await processRecursively(at: sourceURL, to: finalDestination, totalSize: totalSize, bytesProcessed: &bytesProcessed)
                    
                    if type == .move {
                        // If it was a cross-volume move, we copied it. Now delete source.
                        try fileManager.removeItem(at: sourceURL)
                    }
                }
            } catch {
                delegate?.fileOperationDidFail(error: "Failed to \(type == .copy ? "copy" : "move") '\(fileName)': \(error.localizedDescription)")
                return
            }
        }

        // Final progress update to ensure 100%
        delegate?.fileOperationDidProgress(currentFile: "", bytesProcessed: bytesProcessed, totalBytes: totalSize)
        delegate?.fileOperationDidComplete()
    }

    private func sendProgress(currentFile: String, bytesProcessed: Int64, totalBytes: Int64) {
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastUpdateTimestamp >= updateInterval || bytesProcessed == totalBytes {
            lastUpdateTimestamp = now
            delegate?.fileOperationDidProgress(currentFile: currentFile, bytesProcessed: bytesProcessed, totalBytes: totalBytes)
        }
    }

    private func isOnSameVolume(_ url1: URL, _ url2: URL) -> Bool {
        do {
            let v1 = try url1.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
            let v2 = try url2.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
            return v1?.isEqual(v2) ?? false
        } catch {
            return false
        }
    }

    private func processRecursively(at source: URL, to destination: URL, totalSize: Int64, bytesProcessed: inout Int64) async throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory) else { return }

        if isDirectory.boolValue {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            let contents = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
            for item in contents {
                if Task.isCancelled || isCancelled { return }
                if isPaused {
                    await control.wait()
                }

                let itemName = item.lastPathComponent
                let itemDestination = destination.appendingPathComponent(itemName)
                try await processRecursively(at: item, to: itemDestination, totalSize: totalSize, bytesProcessed: &bytesProcessed)
            }
            
            // Copy directory attributes after contents are processed
            let attributes = try fileManager.attributesOfItem(atPath: source.path)
            try fileManager.setAttributes(attributes, ofItemAtPath: destination.path)
        } else {
            try await chunkedCopy(from: source, to: destination, totalSize: totalSize, bytesProcessed: &bytesProcessed)
        }
    }

    private func chunkedCopy(from source: URL, to destination: URL, totalSize: Int64, bytesProcessed: inout Int64) async throws {
        let fileManager = FileManager.default
        let fileName = source.lastPathComponent
        
        guard let inputStream = InputStream(url: source) else {
            throw NSError(domain: "FileOperation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open source file for reading"])
        }
        guard let outputStream = OutputStream(url: destination, append: false) else {
            throw NSError(domain: "FileOperation", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to open destination file for writing"])
        }

        inputStream.open()
        outputStream.open()
        defer {
            inputStream.close()
            outputStream.close()
        }

        let bufferSize = 1024 * 1024 // 1MB buffer
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while inputStream.hasBytesAvailable {
            if Task.isCancelled || isCancelled { 
                try? fileManager.removeItem(at: destination) // Cleanup partial file
                return 
            }
            if isPaused {
                await control.wait()
            }

            let bytesRead = inputStream.read(buffer, maxLength: bufferSize)
            if bytesRead < 0 {
                throw inputStream.streamError ?? NSError(domain: "FileOperation", code: 3, userInfo: [NSLocalizedDescriptionKey: "Read error"])
            } else if bytesRead == 0 {
                break
            }

            var bytesWrittenTotal = 0
            while bytesWrittenTotal < bytesRead {
                let bytesWritten = outputStream.write(buffer.advanced(by: bytesWrittenTotal), maxLength: bytesRead - bytesWrittenTotal)
                if bytesWritten < 0 {
                    throw outputStream.streamError ?? NSError(domain: "FileOperation", code: 4, userInfo: [NSLocalizedDescriptionKey: "Write error"])
                }
                bytesWrittenTotal += bytesWritten
            }

            bytesProcessed += Int64(bytesRead)
            sendProgress(currentFile: fileName, bytesProcessed: bytesProcessed, totalBytes: totalSize)
            
            if bytesRead % (10 * bufferSize) == 0 {
                await Task.yield()
            }
        }
        
        // Copy file attributes
        let attributes = try fileManager.attributesOfItem(atPath: source.path)
        try fileManager.setAttributes(attributes, ofItemAtPath: destination.path)
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
