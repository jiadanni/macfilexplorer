import Foundation

class FileSystemMonitor {
    private var fileDescriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?
    private let callback: () -> Void

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
            print("Failed to open directory for monitoring: \(url.path)")
            return
        }

        // Create dispatch source
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .link],
            queue: DispatchQueue.global(qos: .background)
        )

        source?.setEventHandler { [weak self] in
            self?.callback()
        }

        source?.setCancelHandler { [weak self] in
            guard let fd = self?.fileDescriptor else { return }
            close(fd)
        }

        source?.resume()
    }

    private func stopMonitoring() {
        source?.cancel()
        source = nil
    }
}
