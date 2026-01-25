import Cocoa

/// Manages banner notifications (info, error messages) with auto-dismiss.
/// Extracted from FileBrowserViewController to reduce complexity.
final class BannerNotificationManager {
    private weak var view: NSView?
    private weak var statusBarAnchor: NSView?
    
    private var bannerContainer: NSView?
    private var bannerDismissTask: Task<Void, Never>?
    
    enum BannerStyle {
        case info
        case error
    }
    
    /// Initializes banner manager with parent view and status bar anchor.
    /// - Parameters:
    ///   - view: The parent view where banner will be added
    ///   - statusBarAnchor: The view whose top will anchor the banner (typically status bar)
    init(view: NSView, statusBarAnchor: NSView) {
        self.view = view
        self.statusBarAnchor = statusBarAnchor
    }
    
    /// Shows an informational banner that auto-dismisses after 3 seconds.
    func showInfo(_ message: String) {
        showBanner(message: message, style: .info)
    }
    
    /// Shows an error banner that auto-dismisses after 3 seconds.
    func showError(_ message: String) {
        showBanner(message: message, style: .error)
    }
    
    /// Shows a banner with specified style and auto-dismiss.
    private func showBanner(message: String, style: BannerStyle) {
        bannerDismissTask?.cancel()

        if bannerContainer == nil {
            guard let view = view, let statusBarAnchor = statusBarAnchor else { return }
            
            let container = NSView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.wantsLayer = true
            view.addSubview(container)
            
            NSLayoutConstraint.activate([
                container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
                container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -12),
                container.bottomAnchor.constraint(equalTo: statusBarAnchor.topAnchor, constant: -6),
                container.heightAnchor.constraint(greaterThanOrEqualToConstant: 24)
            ])
            bannerContainer = container
        }

        guard let bannerContainer = bannerContainer else { return }
        bannerContainer.subviews.forEach { $0.removeFromSuperview() }
        bannerContainer.isHidden = false

        let label = NSTextField(labelWithString: message)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = (style == .info) ? .labelColor : .systemRed
        bannerContainer.addSubview(label)

        bannerContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9).cgColor
        bannerContainer.layer?.cornerRadius = 6

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: bannerContainer.topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: bannerContainer.bottomAnchor, constant: -5)
        ])

        bannerDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self?.bannerContainer?.isHidden = true
        }
    }
    
    /// Cancels any pending dismiss task (useful on deinit).
    func cleanup() {
        bannerDismissTask?.cancel()
        bannerDismissTask = nil
    }
    
    deinit {
        cleanup()
    }
}
