import Foundation

/// Observer protocol for terminal visibility changes
protocol TerminalVisibilityObserver: AnyObject {
    func terminalVisibilityDidChange(isVisible: Bool)
}

/// Single source of truth for terminal visibility state.
/// This coordinator manages terminal visibility, persists state to SettingsStore,
/// and notifies observers of visibility changes.
class TerminalVisibilityCoordinator {
    // MARK: - Properties

    private let settingsStore: SettingsStoreProtocol

    weak var observer: TerminalVisibilityObserver?

    /// Whether the terminal is currently visible.
    /// Setting this property triggers a SettingsStore update and observer notification.
    var isVisible: Bool {
        didSet {
            if isVisible != oldValue {
                updateSettingsStore()
                observer?.terminalVisibilityDidChange(isVisible: isVisible)
            }
        }
    }

    // MARK: - Initialization

    init(settingsStore: SettingsStoreProtocol = SettingsStore.shared) {
        self.settingsStore = settingsStore
        // Initialize from persistent settings
        self.isVisible = settingsStore.terminalIsVisible
    }

    // MARK: - Public Methods

    /// Toggle terminal visibility
    func toggleTerminal() {
        isVisible = !isVisible
    }

    /// Set terminal visibility to a specific state
    func setVisibility(_ visible: Bool) {
        isVisible = visible
    }

    // MARK: - Private Methods

    private func updateSettingsStore() {
        settingsStore.terminalIsVisible = isVisible
    }
}
