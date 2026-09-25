import Foundation

/// Delegate protocol for terminal visibility changes
protocol TerminalVisibilityDelegate: AnyObject {
    func terminalVisibilityDidChange(isVisible: Bool)
}

/// Single source of truth for terminal visibility state.
/// This coordinator manages terminal visibility, persists state to SettingsStore,
/// and notifies delegates of visibility changes.
class TerminalVisibilityCoordinator {
    // MARK: - Properties

    private let settingsStore: SettingsStoreProtocol

    weak var delegate: TerminalVisibilityDelegate?

    /// Whether the terminal is currently visible.
    var isVisible: Bool {
        didSet {
            if isVisible != oldValue {
                updateSettingsStore()
                postNotification()
                delegate?.terminalVisibilityDidChange(isVisible: isVisible)
            }
        }
    }

    /// The current directory the terminal should be at.
    var currentDirectory: URL? {
        didSet {
            if currentDirectory != oldValue {
                postNotification()
            }
        }
    }

    // MARK: - Initialization

    init(settingsStore: SettingsStoreProtocol = SettingsStore.shared) {
        self.settingsStore = settingsStore
        // Initialize from persistent settings
        self.isVisible = settingsStore.terminalIsVisible
        self.currentDirectory = nil
    }

    // MARK: - Public Methods

    /// Toggle terminal visibility
    func toggleTerminal() {
        isVisible = !isVisible
    }

    /// Set terminal visibility and optionally a path
    func setVisibility(_ visible: Bool, at path: URL? = nil) {
        if let path = path {
            currentDirectory = path
        }
        isVisible = visible
    }

    // MARK: - Private Methods

    private func updateSettingsStore() {
        settingsStore.terminalIsVisible = isVisible
    }

    private func postNotification() {
        NotificationCenter.default.post(
            name: NSNotification.Name("TerminalStateDidChange"),
            object: self,
            userInfo: [
                "isVisible": isVisible,
                "currentDirectory": currentDirectory as Any
            ]
        )
    }
}
