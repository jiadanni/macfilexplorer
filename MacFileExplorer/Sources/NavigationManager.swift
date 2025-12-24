import Foundation

/// Delegate protocol for navigation state changes.
protocol NavigationManagerDelegate: AnyObject {
    func navigationManager(_ manager: NavigationManager, didUpdateState state: NavigationState)
}

/// Represents the current navigation state.
struct NavigationState {
    let currentURL: URL
    let canGoBack: Bool
    let canGoForward: Bool
    let history: [URL]
    let currentIndex: Int
}

/// Manages navigation history for a file browser.
///
/// `NavigationManager` provides:
/// - Navigation history tracking (back/forward)
/// - State management for navigation buttons
/// - Delegate notifications for UI updates
///
/// **Usage:**
/// ```swift
/// let navManager = NavigationManager()
/// navManager.delegate = self
/// navManager.navigate(to: someURL)
/// navManager.goBack()
/// ```
final class NavigationManager {
    
    weak var delegate: NavigationManagerDelegate?
    
    private var navigationHistory: [URL] = []
    private var currentHistoryIndex: Int = -1
    private let maxHistorySize = AppConfig.Limits.maxHistorySize
    
    // MARK: - Public API
    
    /// Current URL in navigation history.
    var currentURL: URL? {
        guard currentHistoryIndex >= 0, currentHistoryIndex < navigationHistory.count else { return nil }
        return navigationHistory[currentHistoryIndex]
    }
    
    /// Whether back navigation is possible.
    var canGoBack: Bool {
        return currentHistoryIndex > 0
    }
    
    /// Whether forward navigation is possible.
    var canGoForward: Bool {
        return currentHistoryIndex < navigationHistory.count - 1
    }
    
    /// Full navigation history.
    var history: [URL] {
        return navigationHistory
    }
    
    /// Current index in history.
    var currentIndex: Int {
        return currentHistoryIndex
    }
    
    /// Navigate to a new URL, adding it to history.
    ///
    /// - Parameter url: The URL to navigate to.
    /// - Parameter addToHistory: Whether to add this navigation to history (default: true).
    ///
    /// If `addToHistory` is true, this will:
    /// - Remove any forward history beyond the current position
    /// - Append the new URL to history
    /// - Update the current index
    /// - Notify the delegate
    func navigate(to url: URL, addToHistory: Bool = true) {
        if addToHistory {
            // Remove forward history if we're not at the end
            if currentHistoryIndex < navigationHistory.count - 1 {
                navigationHistory.removeSubrange((currentHistoryIndex + 1)...)
            }
            navigationHistory.append(url)
            currentHistoryIndex = navigationHistory.count - 1

            if navigationHistory.count > maxHistorySize {
                let excess = navigationHistory.count - maxHistorySize
                navigationHistory.removeFirst(excess)
                currentHistoryIndex = max(0, currentHistoryIndex - excess)
            }
        }
        
        notifyDelegate(url: url)
    }
    
    /// Go back in navigation history.
    ///
    /// - Returns: The previous URL if available, nil otherwise.
    @discardableResult
    func goBack() -> URL? {
        guard canGoBack else { return nil }
        
        currentHistoryIndex -= 1
        guard currentHistoryIndex >= 0, currentHistoryIndex < navigationHistory.count else {
            currentHistoryIndex += 1 // Revert on error
            return nil
        }
        notifyDelegate(url: navigationHistory[currentHistoryIndex])
        return navigationHistory[currentHistoryIndex]
    }
    
    /// Go forward in navigation history.
    ///
    /// - Returns: The next URL if available, nil otherwise.
    @discardableResult
    func goForward() -> URL? {
        guard canGoForward else { return nil }
        
        currentHistoryIndex += 1
        guard currentHistoryIndex >= 0, currentHistoryIndex < navigationHistory.count else {
            currentHistoryIndex -= 1 // Revert on error
            return nil
        }
        notifyDelegate(url: navigationHistory[currentHistoryIndex])
        return navigationHistory[currentHistoryIndex]
    }
    
    /// Navigate to a specific index in history.
    ///
    /// - Parameter index: The history index to navigate to.
    /// - Returns: The URL at that index if valid, nil otherwise.
    @discardableResult
    func navigateToHistoryIndex(_ index: Int) -> URL? {
        guard index >= 0, index < navigationHistory.count else { return nil }
        
        currentHistoryIndex = index
        notifyDelegate(url: navigationHistory[index])
        return navigationHistory[index]
    }
    
    /// Clear all navigation history.
    func clearHistory() {
        navigationHistory.removeAll()
        currentHistoryIndex = -1
    }
    
    // MARK: - Private Helpers
    
    private func notifyDelegate(url: URL) {
        let state = NavigationState(
            currentURL: url,
            canGoBack: canGoBack,
            canGoForward: canGoForward,
            history: navigationHistory,
            currentIndex: currentHistoryIndex
        )
        delegate?.navigationManager(self, didUpdateState: state)
    }
}
