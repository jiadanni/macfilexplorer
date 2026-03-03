# State Synchronization Best Practices

**Document:** Architectural guidelines for state management  
**Date:** January 5, 2026

## Problem Statement

The codebase currently maintains state in three layers without clear ownership, causing:
- Race conditions during rapid state changes
- Inconsistency between UI and persisted state
- Unclear code flow (7-layer call chains for simple toggles)
- Difficult debugging (state scattered across files)

## Solution: Single Source of Truth (SSOT) Pattern

Each major state should have **exactly one owner** responsible for:
1. **Holding the current value**
2. **Validating changes**
3. **Persisting to UserDefaults**
4. **Notifying observers**
5. **Orchestrating UI updates**

---

## Pattern: Coordinator as SSOT

### State Categories

| State | Owner | Persistence | Thread | Observers |
|-------|-------|-------------|--------|-----------|
| Preview Pane (visible, position, width) | `FileBrowserPreviewPaneCoordinator` | `SettingsStore` | Main | Delegate protocol |
| Terminal Visibility | `TerminalVisibilityCoordinator` | `SettingsStore` | Main | Delegate protocol |
| Hidden Files Visibility | `HiddenFilesVisibilityCoordinator` | `SettingsStore` | Main | Delegate protocol |
| View Mode (list/icons/columns) | `FileBrowserViewModeCoordinator` | `SettingsStore` | Main | Delegate protocol |
| File Selection | `FileBrowserSelectionCoordinator` | (Runtime only) | Main | Delegate protocol |

### Implementation Template

```swift
/// [FEATURE] state coordinator - SINGLE SOURCE OF TRUTH
class [Feature]Coordinator {
    // MARK: - Configuration
    weak var delegate: [Feature]Delegate?
    private let settings: SettingsStoreProtocol
    
    // MARK: - State (Private - SSOT)
    private(set) var state: Bool = false {
        didSet {
            guard oldValue != state else { return }
            
            // 1. Persist immediately
            settings.[property] = state
            
            // 2. Notify observers
            delegate?.did[Feature]Change(state)
            
            // 3. Update UI as needed
            updateUI()
        }
    }
    
    // MARK: - Initialization
    init(settings: SettingsStoreProtocol = SettingsStore.shared) {
        self.settings = settings
        
        // Initialize from persisted state
        self.state = settings.[property]
    }
    
    // MARK: - Public API
    /// Single entry point for state changes
    func setState(_ newValue: Bool) {
        guard newValue != state else { return }
        state = newValue  // Triggers didSet
    }
    
    // MARK: - Private Helpers
    private func updateUI() {
        // Update views based on new state
    }
}

// MARK: - Delegate Protocol
protocol [Feature]Delegate: AnyObject {
    func did[Feature]Change(_ newValue: Bool)
}
```

---

## Common Mistakes to Avoid

### ❌ MISTAKE 1: Duplicate State in Multiple Files

```swift
// DON'T DO THIS:
class FileBrowserViewController {
    var previewVisible: Bool  // Duplicate! 🔴
}

class FileBrowserPreviewPaneCoordinator {
    var isVisible: Bool  // Duplicate! 🔴
}

class SettingsStore {
    var previewPaneVisible: Bool  // Triple duplicate! 🔴
}
```

### ✅ CORRECT: Single Owner

```swift
// DO THIS:
class FileBrowserPreviewPaneCoordinator {
    // SSOT
    private(set) var isVisible: Bool {
        didSet {
            settings.previewPaneVisible = isVisible  // Persist
            delegate?.previewPaneVisibilityDidChange(isVisible)  // Notify
        }
    }
}

class FileBrowserViewController {
    // Read-only computed property from coordinator
    var previewVisible: Bool {
        return previewPaneCoordinator.isVisible
    }
}
```

---

### ❌ MISTAKE 2: Fire-and-Forget Notifications

```swift
// DON'T DO THIS:
NotificationCenter.default.post(name: .previewPaneToggled, object: nil)
// No one knows if observers handled it
// No way to wait for completion
// Easy to forget to post or listen
```

### ✅ CORRECT: Delegate Callbacks

```swift
// DO THIS:
delegate?.previewPaneVisibilityDidChange(isVisible)
// Explicit, type-safe
// Can be acknowledged
// Required by protocol
```

---

### ❌ MISTAKE 3: Long Call Chains

```swift
// DON'T DO THIS:
// 7 layers of function calls to toggle a boolean
mainWindow.togglePreviewPane()
  → splitVC.togglePreviewPane()
  → tabBarCtrl.setViewMode()
  → splitPane.togglePreviewPane()
  → fileBrowserVC.togglePreviewPane()
  → previewCoordinator.togglePreviewPane()
  → ???
```

### ✅ CORRECT: Direct Coordinator Call

```swift
// DO THIS - Direct SSOT update:
previewPaneCoordinator.setPreviewPaneVisible(!previewPaneCoordinator.isVisible)

// Or from UI:
@IBAction func togglePreviewPane(_ sender: Any) {
    previewPaneCoordinator.setPreviewPaneVisible(
        !previewPaneCoordinator.isVisible
    )
}
```

---

## Applying SSOT to Preview Pane

### Current State (BROKEN)

```
User clicks button
    ↓
7-layer call chain updates:
  - FileBrowserViewController.previewVisible
  - FileBrowserPreviewPaneCoordinator.isVisible
  - SettingsStore.previewPaneVisible
    ↓
Notification posted
    ↓
Listeners update button/UI
    ↓
RESULT: Possible race conditions, unclear ordering
```

### Fixed State (SSOT)

```
User clicks button
    ↓
previewPaneCoordinator.setPreviewPaneVisible(value)
    ↓
Coordinator didSet {
  1. Update SettingsStore
  2. Notify delegate
  3. Update UI
}
    ↓
FileBrowserViewController observes via delegate
    ↓
RESULT: Single flow, no ambiguity, no races
```

---

## Checklist for Adding New State

- [ ] Choose a coordinator (new or existing)
- [ ] Define state property with `didSet`
- [ ] Add SSOT comment above state
- [ ] Implement persistence in `didSet`
- [ ] Implement delegate protocol notification in `didSet`
- [ ] Create public `setState()` method (only entry point)
- [ ] Document initialization from persisted state
- [ ] Remove duplicate state from other files
- [ ] Use computed properties for read-only access
- [ ] Write integration tests for state consistency

---

## Review Checklist

When reviewing code with state changes:

- [ ] Is there only ONE owner of this state?
- [ ] Is persistence handled in the owner?
- [ ] Are observers notified via delegate (not notifications)?
- [ ] Can I trace the code flow clearly?
- [ ] No force-unwrapped properties?
- [ ] No race conditions on rapid changes?
- [ ] Is state initialized from UserDefaults?
- [ ] Are tests included?

---

## Files Demonstrating Best Practices

- ✅ `FileBrowserPreviewPaneCoordinator.swift` - Good SSOT pattern
- ✅ `HiddenFilesVisibilityCoordinator.swift` - Good ownership
- ✅ `TerminalVisibilityCoordinator.swift` - Good structure
- ⚠️ `SettingsStore.swift` - Persistence layer (not UI state owner)
- ❌ `FileBrowserViewController.swift` - Needs decomposition

---

## Future Work

See CRITICAL_ISSUES_ACTION_PLAN.md for:
1. **Phase 1: Preview Pane SSOT** (3 days)
2. **Phase 2: Terminal Visibility** (2 days)
3. **Phase 3: Hidden Files** (1 day)
