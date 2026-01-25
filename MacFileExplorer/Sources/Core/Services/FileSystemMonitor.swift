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
    private var fileDescriptor: CInt = -1
    private let callback: () -> Void
    private var kqueueDescriptor: CInt = -1
    private var eventTask: Task<Void, Never>?

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

        kqueueDescriptor = kqueue()
        guard kqueueDescriptor >= 0 else {
            debugLog("Failed to create kqueue for monitoring: \(url.path)")
            close(fileDescriptor)
            fileDescriptor = -1
            return
        }

        var event = kevent()
        event.ident = UInt(fileDescriptor)
        event.filter = Int16(EVFILT_VNODE)
        event.flags = UInt16(EV_ADD | EV_CLEAR)
        event.fflags = UInt32(NOTE_WRITE | NOTE_DELETE | NOTE_RENAME | NOTE_LINK)
        event.data = 0
        event.udata = nil

        if kevent(kqueueDescriptor, &event, 1, nil, 0, nil) == -1 {
            debugLog("Failed to register kqueue event for monitoring: \(url.path)")
            close(kqueueDescriptor)
            kqueueDescriptor = -1
            close(fileDescriptor)
            fileDescriptor = -1
            return
        }

        eventTask = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            var event = kevent()
            while !Task.isCancelled {
                var timeout = timespec(tv_sec: 0, tv_nsec: 250_000_000)
                let count = kevent(self.kqueueDescriptor, nil, 0, &event, 1, &timeout)
                if count > 0 {
                    self.callback()
                } else if count == 0 {
                    continue
                } else if errno != EINTR {
                    break
                }
            }
        }
    }

    private func stopMonitoring() {
        eventTask?.cancel()
        eventTask = nil

        if kqueueDescriptor >= 0 {
            close(kqueueDescriptor)
            kqueueDescriptor = -1
        }
        
        // Safety: ensure fd is closed if cancel handler wasn't called
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }
}
