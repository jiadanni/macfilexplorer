import Darwin
import Foundation

/// Monitors a directory for file system changes using `kqueue`/`EVFILT_VNODE`.
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
/// **Performance:** Monitoring happens off the main actor. The callback
/// is invoked on a background thread, so UI updates must hop to the main actor.
///
/// **Lifecycle:** Monitoring automatically starts on init and stops on deinit.
/// Keep a strong reference to the monitor to keep monitoring active.
///
/// **Thread Safety:** The callback may be invoked from any thread.
final class FileSystemMonitor {
    /// Shared serial queue for all monitors' event handlers.
    private static let eventQueue = DispatchQueue(label: "com.macfileexplorer.filesystemmonitor", qos: .utility)

    // A dispatch source rather than a kevent loop in a Task: a blocking kevent
    // call would pin a cooperative-pool thread for the monitor's lifetime, and
    // the loop's strong capture of self prevented deinit from ever running.
    private let source: DispatchSourceFileSystemObject?

    /// Initializes a file system monitor for the specified directory.
    ///
    /// - Parameters:
    ///   - url: The directory URL to monitor.
    ///   - callback: Closure called when directory changes are detected.
    ///
    /// **Important:** The callback is invoked on a background thread.
    /// Hop to the main actor for UI updates:
    /// ```swift
    /// let monitor = FileSystemMonitor(url: url) {
    ///     Task { @MainActor in
    ///         // Update UI
    ///     }
    /// }
    /// ```
    init(url: URL, callback: @escaping () -> Void) {
        let fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            debugLog("Failed to open directory for monitoring: \(url.path)")
            source = nil
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .link],
            queue: Self.eventQueue
        )
        source.setEventHandler(handler: callback)
        source.setCancelHandler {
            close(fileDescriptor)
        }
        source.resume()
        self.source = source
    }

    deinit {
        // The cancel handler closes the file descriptor.
        source?.cancel()
    }
}
