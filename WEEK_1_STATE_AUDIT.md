# Week 1: State Synchronization Audit

## Overview
Comprehensive audit of all state variables across MacFileExplorer, identifying desynchronization patterns and creating state machine designs for core features.

---

## 1. State Variables Inventory

### 1.1 Preview Pane State

**Sources of Truth:**
- `FileBrowserViewController.previewVisible: Bool` (runtime state)
- `FileBrowserPreviewPaneCoordinator.isVisible: Bool` (coordinator state)
- `SettingsStore.previewPaneVisible: Bool` (persisted state)
- `SettingsStore.previewPanePosition: String` ("right" | "bottom")
- `SettingsStore.previewPaneWidth: CGFloat` (persisted width)

**State Holders:**
```swift
// FileBrowserViewController.swift (line 96)
var previewVisible: Bool = false

// FileBrowserPreviewPaneCoordinator.swift (line 23)
private(set) var isVisible: Bool = false

// SettingsStore.swift (line 164)
var previewPaneVisible: Bool {
    get { defaults.bool(forKey: UserDefaults.Keys.showPreviewPane.rawValue) }
    set { /* ... posts notification */ }
}
```

**Synchronization Points:**
1. ToolbarViewController reads `settings.previewPaneVisible` at startup
2. FileBrowserViewController manually updates `settings.previewPaneWidth` in `splitViewDidResizeSubviews()`
3. FileBrowserPreviewPaneCoordinator manages visibility via `setPreviewPaneVisible()`
4. Notifications: `.previewPaneToggled` (legacy)

**Desync Patterns Identified:**
- ❌ Three separate boolean flags: `previewVisible`, `isVisible`, `previewPaneVisible`
- ❌ No guaranteed sync between coordinator state and SettingsStore
- ❌ Size updates only persisted on resize, not on initial setup
- ❌ Position changes in SettingsStore don't propagate to coordinator
- ❌ UI state (toolbar button) must be manually updated via `updatePreviewPaneDisplay()`

---

### 1.2 Terminal Visibility State

**Sources of Truth:**
- `SplitViewController.isTerminalVisible: Bool` (runtime state)
- `SettingsStore.terminalIsVisible: Bool` (persisted state)

**State Holders:**
```swift
// SplitViewController.swift (line 15)
var isTerminalVisible = false

// SettingsStore.swift (line 563)
var terminalIsVisible: Bool {
    get { defaults.bool(forKey: AdditionalKeys.terminalIsVisible) }
    set { defaults.set(newValue, forKey: AdditionalKeys.terminalIsVisible) }
}
```

**Synchronization Points:**
1. SplitViewController restores state in `viewDidAppear()` from `settingsStore.terminalIsVisible`
2. `setTerminalVisibility()` updates both runtime state and persisted state
3. Terminal focus managed separately via `TerminalViewController.focusInput()`

**Desync Patterns Identified:**
- ❌ Manual synchronization between runtime and persisted state
- ❌ No notification when terminal visibility changes
- ❌ Focus restoration delayed by 100ms Task.sleep() (timing-dependent)
- ❌ No validation that terminal exists before attempting focus
- ⚠️  Only SplitViewController holds the authoritative state

---

### 1.3 View Mode State

**Sources of Truth:**
- `FileBrowserViewController.currentViewMode` (computed via displayController)
- `SettingsStore.defaultViewMode: ViewMode` (persisted, but only default)
- `FileBrowserDisplayController` manages actual display state

**State Holders:**
```swift
// FileBrowserViewModeCoordinator.swift (line 7)
private enum BrowserSetupState { case idle, preparing, creatingBrowser, ready, failed }
private var browserSetupState: BrowserSetupState = .idle

// SettingsStore.swift (line 197)
var defaultViewMode: ViewMode {
    get { /* reads UserDefaults */ }
    set { /* writes to UserDefaults */ }
}
```

**Synchronization Points:**
1. FileBrowserViewController reads defaultViewMode on startup
2. FileBrowserViewModeCoordinator uses setup state machine to prevent race conditions
3. ViewMode changes trigger displayFiles() which updates multiple views simultaneously
4. Toolbar updates via ToolbarViewController.updateViewModeDisplay()

**Desync Patterns Identified:**
- ⚠️  Setup state machine is private to coordinator (hard to reason about externally)
- ❌ No per-pane view mode storage (all panes share defaultViewMode)
- ❌ browserSetupState can race with displayFiles() calls
- ❌ suppressedDisplayCalls counter may miss legitimate updates
- ⚠️  No validation that display succeeded before updating toolbar

---

### 1.4 Selection State

**Sources of Truth:**
- `FileBrowserOutlineView` selection (NSOutlineView)
- `NSCollectionView` selection (collection view)
- `NSBrowser` selection (browser/columns view)
- `FileBrowserSelectionCoordinator` aggregates selection across view modes

**State Holders:**
```swift
// FileBrowserViewController.swift
var outlineView: NSOutlineView!
var collectionView: NSCollectionView?
var browserView: NSBrowser?

// FileBrowserSelectionCoordinator.swift (line 10)
private let selectionManager = FileBrowserSelectionManager()
```

**Synchronization Points:**
1. Each view notifies on selection change
2. FileBrowserSelectionCoordinator responds to all three
3. Status bar updated via `updateStatusBar()`
4. Preview pane updated via `updatePreviewPane(with:)`

**Desync Patterns Identified:**
- ❌ Selection lives in NSView objects, no single source of truth
- ❌ Selection manager may be out of sync if view selection changes unexpectedly
- ❌ Multi-view selection requires manual synchronization during view switches
- ❌ Click tracking state separate from selection state (can diverge)
- ⚠️  No transaction-like semantics for multi-step selection updates

---

### 1.5 Hidden Files State

**Sources of Truth:**
- `FileBrowserDataSource.showsHiddenFiles: Bool`
- `SettingsStore.hiddenFilesState: Bool` (persisted)

**State Holders:**
```swift
// FileBrowserDataSource.swift
var showsHiddenFiles: Bool { didSet { /* reload */ } }

// SettingsStore.swift (line 669)
var hiddenFilesState: Bool {
    get { defaults.bool(forKey: UserDefaults.Keys.hiddenFilesState.rawValue) }
    set { 
        defaults.set(newValue, forKey: UserDefaults.Keys.hiddenFilesState.rawValue)
        notifyDelegates { delegate in
            delegate.settingsStore(self, hiddenFilesStateDidChange: isVisible)
        }
    }
}
```

**Synchronization Points:**
1. AppDelegate observes `hiddenFilesStateDidChange` delegate callback
2. FileBrowserViewController reads initial state from DataSource
3. ToolbarViewController reflects state in button appearance
4. Toggle via menu or toolbar button updates both sources

**Desync Patterns Identified:**
- ⚠️  State split between DataSource and SettingsStore
- ❌ No guarantee that reload completes before state is considered updated
- ❌ Filter state may not account for hidden files changes

---

### 1.6 Cancellation/Operation State

**Sources of Truth:**
- `CancellationToken` (Thread-safe wrapper around boolean flag)
- `FileCopyMoveDialog.@Atomic isCancelled` (threaded)
- `FileCopyMoveDialog.isCancelled` (non-threaded duplicate!)
- `StorageAnalyzerEngine.isCancelled` (non-threaded)

**State Holders:**
```swift
// FileBrowserViewController.swift (line 68)
final class CancellationToken {
    private let lock = DispatchSemaphore(value: 1)
    private var _isCancelled = false
    var isCancelled: Bool { lock.wait(); defer { lock.signal() }; return _isCancelled }
    func cancel() { lock.wait(); _isCancelled = true; lock.signal() }
}

// FileCopyMoveDialog.swift (line 14-15)
@Atomic private var isCancelled = false
private var isCancelled = false  // ⚠️ DUPLICATE!
```

**Synchronization Points:**
1. CancellationToken used for QL preview operations
2. @Atomic wrapper for file operations
3. Manual semaphore management in some places

**Desync Patterns Identified:**
- ❌ **CRITICAL**: FileCopyMoveDialog has TWO isCancelled variables (line 14 vs 285)
- ❌ Inconsistent synchronization: CancellationToken vs @Atomic vs nothing
- ❌ StorageAnalyzerEngine.isCancelled not thread-safe despite concurrent access
- ❌ No way to check if operation completed vs just cancelled

---

### 1.7 Layout/Constraint State

**Sources of Truth:**
- `FileBrowserViewController.activeConstraints: [NSLayoutConstraint]` (current layout)
- `FileBrowserDisplayController.collectionView` view hierarchy
- Frame values on NSView subviews

**State Holders:**
```swift
// FileBrowserViewController.swift (line 98)
var activeConstraints: [NSLayoutConstraint] = []
```

**Synchronization Points:**
1. View mode switches deactivate old, activate new constraints
2. Window resize triggers constraint updates
3. Split pane changes require constraint recalculation

**Desync Patterns Identified:**
- ❌ Constraints managed manually with lists (easy to leak/forget)
- ❌ No validation that constraint activation succeeds
- ⚠️  Hard to debug which constraints are active (need logging)

---

## 2. Desynchronization Patterns

### Pattern 1: Multiple Boolean Flags (Preview Pane)
```
Problem:  previewVisible, isVisible, previewPaneVisible all track same state
Impact:   Any two can diverge without warning
Severity: HIGH
```

### Pattern 2: No Notification on Coordinator Change
```
Problem:  FileBrowserPreviewPaneCoordinator.isVisible is private(set)
Impact:   SettingsStore changes don't reach coordinator; UI can miss updates
Severity: HIGH
```

### Pattern 3: Manual Sync Between Runtime and Persisted State
```
Problem:  Every view mode change manually updates SettingsStore
Impact:   Easy to forget to persist; state lost on crash
Severity: MEDIUM
```

### Pattern 4: Duplicate State Variables (FileCopyMoveDialog)
```
Problem:  Two isCancelled vars with different synchronization
Impact:   Operation may read stale value; data corruption possible
Severity: CRITICAL
```

### Pattern 5: View State Lives in NSView Objects
```
Problem:  Selection, visibility, expansion all in view, no coordinator
Impact:   Impossible to serialize/restore; hard to reason about
Severity: MEDIUM
```

### Pattern 6: Setup Race Conditions (ViewMode)
```
Problem:  browserSetupState machine can race with displayFiles() calls
Impact:   Browser creation interrupted mid-setup; crashes possible
Severity: MEDIUM-HIGH
```

---

## 3. Proposed State Machine Designs

### 3.1 Preview Pane State Machine

```
States:
  ├─ Hidden
  │  ├─ on togglePreviewPane() → Showing
  │  └─ on show() → Showing
  │
  ├─ Showing
  │  ├─ on togglePreviewPane() → Hidden
  │  ├─ on hide() → Hidden
  │  ├─ on setPosition(x) → Showing (position updated)
  │  └─ on updateContent(file) → Showing (content updated)
  │
  └─ Loading (transient)
     ├─ on contentLoaded() → Showing
     └─ on loadFailed(error) → Showing (show error)

Invariants:
  - isVisible == coordinator.isVisible == (settings.previewPaneVisible || runtime override)
  - If Showing: previewPaneViewController != nil
  - If Hidden: previewSplitView == nil (cleanup)
  - Position always valid: "right" | "bottom"
  - Width always >= 100

Mutations:
  - Only PreviewPaneCoordinator can change state
  - All mutations must trigger: delegate callback + notification
  - Mutations must update SettingsStore within transaction
```

### 3.2 Terminal Visibility State Machine

```
States:
  ├─ Hidden
  │  ├─ on toggleTerminal() → Showing
  │  ├─ on show(path) → Showing (chdir to path)
  │  └─ [terminal pane remains allocated but collapsed]
  │
  ├─ Showing
  │  ├─ on toggleTerminal() → Hidden
  │  ├─ on hide() → Hidden
  │  └─ on setDirectory(path) → Showing (chdir)
  │
  └─ Initializing (transient)
     ├─ on ready() → Showing
     └─ on setupFailed() → Hidden

Invariants:
  - isTerminalVisible == (terminalSplitItem?.isCollapsed == false)
  - If Showing: terminalViewController != nil && focused
  - If Hidden: focus returned to tab bar
  - Directory always valid URL | current tab directory

Mutations:
  - Only SplitViewController can change state
  - Must update both runtime + SettingsStore.terminalIsVisible atomically
  - Focus changes must occur on main thread
  - Setting.terminalIsVisible updates must be persisted immediately
```

### 3.3 View Mode State Machine

```
States:
  ├─ List
  │  ├─ on displayFiles(for: .icons) → Icons (view creation)
  │  ├─ on displayFiles(for: .columns) → Columns
  │  └─ on displayFiles(for: .list) → List (no-op)
  │
  ├─ Icons
  │  ├─ layout: free-form (FreeFormCollectionViewLayout)
  │  └─ can transition to any other mode
  │
  ├─ Columns
  │  ├─ layout: column hierarchy (NSBrowser)
  │  └─ can transition to any other mode
  │
  ├─ WindowsList
  │  ├─ special case of Icons
  │  └─ can transition to any other mode
  │
  └─ Transitioning (transient)
     ├─ browserSetupState guards concurrency
     ├─ View hierarchy reconfigured
     └─ on ready() → target state

Invariants:
  - Exactly one view active: outlineView OR collectionView OR browserView
  - activeConstraints only contain active view's constraints
  - All other views removed from hierarchy
  - Toolbar reflects current mode
  - Zoom controls enabled only if appropriate for mode

Mutations:
  - Only FileBrowserViewModeCoordinator can change state
  - Must: (1) deactivate old, (2) remove old view, (3) create new, (4) layout, (5) activate
  - Must update SettingsStore.defaultViewMode
  - Concurrent displayFiles() calls rejected during Transitioning
  - All updates on main thread
```

### 3.4 Selection State Machine

```
States:
  ├─ Empty (no selection)
  │  └─ any click → SingleItem | MultipleItems
  │
  ├─ SingleItem
  │  ├─ on click(same) → SingleItem (possible rename ready)
  │  ├─ on click(different) → SingleItem (different item)
  │  ├─ on click(empty) → Empty
  │  ├─ on cmd+click(item) → MultipleItems
  │  └─ on clearSelection() → Empty
  │
  ├─ MultipleItems
  │  ├─ on click(item) → SingleItem
  │  ├─ on cmd+click(item) → MultipleItems (add/remove)
  │  ├─ on click(empty) → Empty
  │  └─ on clearSelection() → Empty
  │
  └─ RenameReady (transient)
     ├─ second click on SingleItem within renameClickDelay
     └─ on timeout() → SingleItem (rename cancelled)

Invariants:
  - Status bar shows: selected count + total size
  - Preview pane shows: selected item (SingleItem) or nil
  - Toolbar enabled based on selection
  - Click tracking: tracks (row, timestamp) for rename detection
  - All views in sync: selection same across list/icon/column views

Mutations:
  - FileBrowserSelectionCoordinator mediates all changes
  - Single view change → sync to other views
  - Selection change → update status bar + preview
  - Rename click recorded with NSLock protection
```

---

## 4. Critical Issues to Address (Priority Order)

### CRITICAL - Fix Now
1. **FileCopyMoveDialog Duplicate Variable** (line 14 + 285)
   - Two separate `isCancelled` variables
   - One is @Atomic, one is not
   - Thread safety guarantees unclear
   - Fix: Consolidate to single @Atomic variable

2. **Terminal Focus Race Condition** (SplitViewController line 175)
   - 100ms sleep before focus is not deterministic
   - Focus may fail if terminal not ready
   - Fix: Use proper completion callback or wait for view ready notification

### HIGH - Week 2
3. **Preview Pane Triple State**
   - Three separate boolean flags can diverge
   - No single source of truth
   - Fix: PreviewPaneCoordinator becomes sole authority; others derive state

4. **View Mode Setup Race**
   - browserSetupState can race with displayFiles() calls
   - suppressedDisplayCalls counter unreliable
   - Fix: Use serial dispatch queue or async/await for serialization

### MEDIUM - Week 3
5. **Selection State in NSView**
   - Selection lives in view objects, no coordinator
   - Hard to query/serialize state
   - Fix: Extract selection to FileBrowserSelectionCoordinator

6. **Hidden Files Inconsistency**
   - State split between DataSource and SettingsStore
   - No notification when toggle happens
   - Fix: Centralize in SettingsStore, DataSource observes changes

---

## 5. Testing Strategy

### Unit Tests Needed
- [ ] PreviewPaneCoordinator state transitions
- [ ] Terminal visibility sync with settings
- [ ] View mode transitions (especially race conditions)
- [ ] Selection state consistency across view modes
- [ ] Cancellation token thread safety
- [ ] Hidden files toggle persistence

### Integration Tests Needed
- [ ] Preview pane toggle + show/hide sequence
- [ ] Terminal visibility restoration on launch
- [ ] View mode switch with selection preservation
- [ ] Multiple rapid state changes don't corrupt state
- [ ] State persists and restores correctly

### Manual QA Checklist
- [ ] Close with preview pane open, reopen → restored
- [ ] Close with terminal visible, reopen → restored  
- [ ] Switch view modes → current selection preserved
- [ ] Change hidden files state → both toolbar and data reflect change
- [ ] Rapid toggling of features doesn't crash
- [ ] File operations don't report false completions

---

## 6. Recommended Reading Order
1. [FileBrowserPreviewPaneCoordinator.swift](MacFileExplorer/Sources/FileBrowserPreviewPaneCoordinator.swift) - Current preview implementation
2. [SplitViewController.swift](MacFileExplorer/Sources/SplitViewController.swift) (lines 1-200) - Terminal state
3. [FileBrowserViewModeCoordinator.swift](MacFileExplorer/Sources/FileBrowserViewModeCoordinator.swift) - View mode state machine
4. [FileBrowserSelectionCoordinator.swift](MacFileExplorer/Sources/FileBrowserSelectionCoordinator.swift) - Selection handling
5. [FileCopyMoveDialog.swift](MacFileExplorer/Sources/FileCopyMoveDialog.swift) (lines 10-20, 284-310) - Problematic cancellation state

---

## 7. Summary

### Current State
- **Fragmented**: State lives in multiple places (ViewControllers, Coordinators, SettingsStore, NSView objects)
- **Unsafe**: Thread-safety inconsistent; duplicate variables; race conditions in setup
- **Hard to Test**: No clear way to query state; manual synchronization everywhere
- **Error-Prone**: Easy to forget to update all places when state changes

### Desired State
- **Unified**: Single source of truth for each concern (PreviewPaneCoordinator, SplitViewController, etc.)
- **Safe**: All mutations atomic; clear thread boundaries
- **Observable**: Notifications/delegates when state changes
- **Persistent**: SettingsStore integration transparent to clients
- **Testable**: State machines can be unit tested; clear invariants

### Effort Estimate
- Week 1: Audit + design (THIS WEEK) - 2-3 hours
- Week 2-3: Implement SSOT coordinators - 8-10 hours
  - Preview pane: 3 hours
  - Terminal: 2 hours  
  - View mode: 3 hours
  - Selection: 2-3 hours
- Week 4: Error handling - 5-6 hours

**Total: ~18-22 hours across 4 weeks**

