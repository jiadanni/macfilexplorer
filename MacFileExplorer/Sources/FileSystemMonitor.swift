import Foundation

/// Monitors a directory for file system changes using low-level `DispatchSource` APIs.
///
/// `FileSystemMonitor` detects changes such as:
/// - File/directory creation
/// - File/directory deletion
/// - File modifications
/// - File renames
/// - Link changes
///
/// **Usage:**
/// ```swift
/// let monitor = FileSystemMonitor(url: directoryURL) {
///     print("Directory contents changed!")
///     // Reload directory contents
/// }
/// // Monitor automatically stops when deallocated
/// ```
///
/// **Performance:** Monitoring happens on a background queue. The callback
/// is invoked on a background thread, so UI updates must be dispatched to main queue.
///
/// **Lifecycle:** Monitoring automatically starts on init and stops on deinit.
/// Keep a strong reference to the monitor to keep monitoring active.
///
/// **Thread Safety:** The callback may be invoked from any thread.
final class FileSystemMonitor {
    private var fileDescriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?
    private let callback: () -> Void
    private let queue = DispatchQueue(label: "com.macfileexplorer.filesystemmonitor", qos: .background)

    /// Initializes a file system monitor for the specified directory.
    ///
    /// - Parameters:
    ///   - url: The directory URL to monitor.
    ///   - callback: Closure called when directory changes are detected.
    ///
    /// **Important:** The callback is invoked on a background queue.
    /// Dispatch to main queue for UI updates:
    /// ```swift
    /// let monitor = FileSystemMonitor(url: url) {
    ///     DispatchQueue.main.async {
    ///         // Update UI
    ///     }
    /// }
    /// ```
    init(url: URL, callback: @escaping () -> Void) {
        self.callback = callback
        startMonitoring(url: url)
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring(url: URL) {
        // Open the directory
        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            debugLog("Failed to open directory for monitoring: \(url.path)")
            return
        }

        // Create dispatch source
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .link],
            queue: queue
        )

        source?.setEventHandler { [weak self] in
            self?.callback()
        }

        source?.setCancelHandler { [weak self] in
            guard let self = self, self.fileDescriptor >= 0 else { return }
            let fd = self.fileDescriptor
            // Ensure file descriptor is marked invalid before closing
            self.fileDescriptor = -1
            close(fd)
        }

        source?.resume()
    }

    private func stopMonitoring() {
        // Cancel the source, which triggers the cancel handler to close the fd
        source?.cancel()
        source = nil
        
        // Safety: ensure fd is closed if cancel handler wasn't called
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }
}
