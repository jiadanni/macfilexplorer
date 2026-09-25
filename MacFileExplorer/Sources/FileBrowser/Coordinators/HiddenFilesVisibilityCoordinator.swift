import Foundation

/// Delegate protocol for hidden files visibility changes
protocol HiddenFilesVisibilityDelegate: AnyObject {
    func hiddenFilesVisibilityDidChange(isVisible: Bool)
}

/// Single source of truth for hidden files visibility state.
/// This coordinator manages hidden files visibility, persists state to SettingsStore,
/// and notifies delegates of visibility changes.
class HiddenFilesVisibilityCoordinator {
    // MARK: - Properties

    private let settingsStore: SettingsStoreProtocol

    weak var delegate: HiddenFilesVisibilityDelegate?

    /// Whether hidden files are currently visible.
    /// Setting this property triggers a SettingsStore update and observer notification.
    var isVisible: Bool {
        didSet {
            if isVisible != oldValue {
                updateSettingsStore()
                delegate?.hiddenFilesVisibilityDidChange(isVisible: isVisible)
            }
        }
    }

    // MARK: - Initialization

    init(settingsStore: SettingsStoreProtocol = SettingsStore.shared) {
        self.settingsStore = settingsStore
        // Initialize from persistent settings
        self.isVisible = settingsStore.hiddenFilesState
    }

    // MARK: - Public Methods

    /// Toggle hidden files visibility
    func toggleVisibility() {
        isVisible = !isVisible
    }

    /// Set hidden files visibility to a specific state
    func setVisibility(_ visible: Bool) {
        isVisible = visible
    }

    // MARK: - Private Methods

    private func updateSettingsStore() {
        settingsStore.hiddenFilesState = isVisible
    }
}
