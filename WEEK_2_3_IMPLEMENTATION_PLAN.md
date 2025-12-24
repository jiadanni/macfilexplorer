# Week 2-3 Implementation Plan: Single Source of Truth Coordinators

**Objective**: Implement SSOT (Single Source of Truth) coordinators for preview pane, terminal, view mode, and selection state.

**Estimated Effort**: 8-10 hours over 2 weeks  
**Risk Level**: MEDIUM (requires careful refactoring)

---

## Pre-Implementation Checklist

Before starting Week 2-3 work:

- [ ] Read WEEK_1_STATE_AUDIT.md (state machines)
- [ ] Read DESYNC_PATTERNS_ANALYSIS.md (all 6 patterns)
- [ ] Read this document completely
- [ ] Create feature branch: `git checkout -b week2-3-ssot-refactor`
- [ ] Run existing tests to establish baseline
- [ ] Build project to verify current state

---

## Implementation Phase 1: Critical Bug Fixes (1-2 hours)

These are prerequisites for other work.

### Fix 1.1: FileCopyMoveDialog Duplicate Variable

**File**: `MacFileExplorer/Sources/FileCopyMoveDialog.swift`

**Problem**:
- Two `isCancelled` variables with different synchronization
- One at line 14 (@Atomic), one at line 285 (not thread-safe)
- Threads may read from wrong one

**Steps**:
1. Open FileCopyMoveDialog.swift
2. Find line 285: `private var isCancelled = false`
3. Delete this line (it shadows the @Atomic version)
4. Find all uses of `isCancelled` in the function scope after line 285
5. Replace with `$isCancelled.update { ... }` pattern
6. Verify no local variable shadows the class property

**Code Change**:
```swift
// BEFORE
private func setupDefaultState() {
    isPaused = false
    isCancelled = false  // ← DELETE THIS LINE
}

// AFTER
private func setupDefaultState() {
    $isPaused.update { _ in false }
    $isCancelled.update { _ in false }
}
```

**Verification**:
```bash
# Search for isCancelled variables in file
grep -n "var isCancelled" MacFileExplorer/Sources/FileCopyMoveDialog.swift
# Should only show ONE match at line 14
```

**Testing**:
- [ ] Copy/move operations complete normally
- [ ] Cancel button works
- [ ] No files left in partial states
- [ ] Build succeeds with no warnings

---

### Fix 1.2: StorageAnalyzerEngine Thread Safety

**File**: `MacFileExplorer/Sources/StorageAnalyzerEngine.swift`

**Problem**:
- `isCancelled` and `isPaused` accessed from background threads without synchronization
- Can read stale values
- Operations may not stop when they should

**Steps**:
1. Open StorageAnalyzerEngine.swift
2. Find line ~40: `private var isCancelled = false` and `private var isPaused = false`
3. Add @Atomic wrapper (same as FileCopyMoveDialog)
4. Update all reads/writes to use @Atomic pattern

**Code Changes**:
```swift
// BEFORE
private var isCancelled = false
private var isPaused = false

// AFTER
@Atomic private var isCancelled = false
@Atomic private var isPaused = false
```

**Verification**:
```bash
# Build and verify no errors
xcodebuild build -project MacFileExplorer.xcodeproj -scheme MacFileExplorer
```

**Testing**:
- [ ] Storage analysis completes normally
- [ ] Cancel during analysis works
- [ ] No files scanned after cancel
- [ ] Pause/resume works correctly

---

### Fix 1.3: Terminal Focus Race Condition

**File**: `MacFileExplorer/Sources/SplitViewController.swift`

**Problem**:
- Arbitrary 100ms sleep before focusing (not guaranteed)
- No check that terminal is actually ready
- Focus may fail silently

**Steps**:
1. Open SplitViewController.swift
2. Find `setTerminalVisibility()` method (around line 142)
3. Locate the Task.sleep block (line 175)
4. Replace with proper async completion callback

**Code Changes**:
```swift
// BEFORE
if animated {
    terminalViewController?.focusInput()
} else {
    Task { @MainActor [weak self] in
        try? await Task.sleep(nanoseconds: 100_000_000)
        self?.terminalViewController?.focusInput()
    }
}

// AFTER
if animated {
    terminalViewController?.focusInput()
} else {
    // Wait for split view layout to complete
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        self?.terminalViewController?.focusInput()
    }
}
```

**Better Solution (use delegate)**:
```swift
// Make SplitViewController implement NSSplitViewDelegate
func splitViewDidResizeSubviews(_ notification: Notification) {
    guard isTerminalVisible, !hasSetInitialFocus else { return }
    hasSetInitialFocus = true
    terminalViewController?.focusInput()
}
```

**Testing**:
- [ ] Open terminal with animation enabled
- [ ] Open terminal with animation disabled
- [ ] Terminal is focused immediately (type works)
- [ ] Works on slow system (simulate with slower machine if available)

---

## Implementation Phase 2: Preview Pane SSOT (2-3 hours)

Make FileBrowserPreviewPaneCoordinator the sole authority for preview state.

### Architecture

**Current State**:
```
FileBrowserViewController.previewVisible ✗
FileBrowserPreviewPaneCoordinator.isVisible ✗
SettingsStore.previewPaneVisible ✗
           ↓↓↓ Can diverge ↓↓↓
```

**Desired State**:
```
FileBrowserPreviewPaneCoordinator
  ├─ isVisible: Bool (SINGLE SOURCE)
  ├─ position: String
  ├─ width: CGFloat
  └─ updateSettingsStore() (on every change)
         ↓
SettingsStore (read-only for UI)
ViewController (reads from coordinator)
```

### Implementation Steps

#### Step 2.1: Extend PreviewPaneCoordinator Protocol

**File**: `MacFileExplorer/Sources/FileBrowserPreviewPaneCoordinator.swift`

**Add to coordinator**:
```swift
protocol FileBrowserPreviewPaneDelegate: AnyObject {
    func previewPaneVisibilityDidChange(_ isVisible: Bool)
    func previewPanePositionDidChange(_ position: String)
    func previewPaneWidthDidChange(_ width: CGFloat)
}

class FileBrowserPreviewPaneCoordinator {
    weak var delegate: FileBrowserPreviewPaneDelegate?
    
    var position: String {
        didSet { updateSettingsStore() }
    }
    
    var width: CGFloat {
        didSet { updateSettingsStore() }
    }
    
    private func updateSettingsStore() {
        settings.previewPanePosition = position
        settings.previewPaneWidth = width
        settings.previewPaneVisible = isVisible
    }
}
```

#### Step 2.2: Update FileBrowserViewController

**File**: `MacFileExplorer/Sources/FileBrowserViewController.swift`

**Changes**:
```swift
// REMOVE this:
var previewVisible: Bool = false

// ADD this (read-only computed):
var previewVisible: Bool {
    return previewPaneCoordinator.isVisible
}

// UPDATE in setupUI():
previewPaneCoordinator.delegate = self

// Implement delegate:
extension FileBrowserViewController: FileBrowserPreviewPaneDelegate {
    func previewPaneVisibilityDidChange(_ isVisible: Bool) {
        // Update UI only
        updatePreviewPaneUI()
    }
}
```

#### Step 2.3: Update ToolbarViewController

**File**: `MacFileExplorer/Sources/ToolbarViewController.swift`

**Changes**:
```swift
// When preview pane button clicked, delegate to coordinator:
@objc func previewPaneButtonClicked(_ sender: NSButton) {
    // Instead of:
    // fileBrowserViewController?.togglePreviewPane()
    
    // Call:
    fileBrowserViewController?.previewPaneCoordinator.togglePreviewPane()
}

// Observe coordinator changes:
// In init or setupUI():
NotificationCenter.default.addObserver(
    self,
    selector: #selector(previewPaneVisibilityDidChange),
    name: NSNotification.Name("PreviewPaneVisibilityDidChange"),
    object: nil
)
```

#### Step 2.4: Handle Restoration on Launch

**File**: `MacFileExplorer/Sources/SplitViewController.swift` or `MainWindowController.swift`

**Add restoration logic**:
```swift
// In viewDidLoad or initialization:
let wasVisible = SettingsStore.shared.previewPaneVisible
let position = SettingsStore.shared.previewPanePosition
let width = SettingsStore.shared.previewPaneWidth

fileBrowserViewController.previewPaneCoordinator.setVisible(
    wasVisible, 
    position: position, 
    width: width
)
```

### Testing Preview Pane Changes

- [ ] Toggle preview pane → isVisible updates
- [ ] Resize preview pane → width persists
- [ ] Change position setting → coordinator reflects change
- [ ] Close with preview open → reopens on next launch
- [ ] Close with preview closed → stays closed
- [ ] Switch view modes with preview open → preview stays open
- [ ] Toolbar button reflects coordinator state
- [ ] No duplicate state changes (watch for loops)

---

## Implementation Phase 3: Terminal Visibility SSOT (1-2 hours)

Make SplitViewController the sole authority for terminal state.

### Architecture

**Desired State**:
```
TerminalVisibilityCoordinator (or use SplitViewController as authority)
  ├─ isVisible: Bool (SINGLE SOURCE)
  ├─ focusOnShow: Bool
  └─ currentDirectory: URL?
         ↓
SettingsStore (synced automatically)
Other VCs (observe changes)
```

### Implementation Steps

#### Step 3.1: Refactor SplitViewController

**File**: `MacFileExplorer/Sources/SplitViewController.swift`

**Changes**:
```swift
class SplitViewController: NSSplitViewController {
    private var _isTerminalVisible = false {
        didSet {
            if oldValue != _isTerminalVisible {
                settingsStore.terminalIsVisible = _isTerminalVisible
                notifyTerminalVisibilityChanged()
            }
        }
    }
    
    var isTerminalVisible: Bool {
        get { _isTerminalVisible }
        set { _isTerminalVisible = newValue }
    }
    
    private func notifyTerminalVisibilityChanged() {
        NotificationCenter.default.post(
            name: NSNotification.Name("TerminalVisibilityDidChange"),
            object: self,
            userInfo: ["isVisible": _isTerminalVisible]
        )
    }
}
```

#### Step 3.2: Update Focus Handling

**Replace the sleep-based focus with**:
```swift
private func showTerminal(at path: String? = nil) {
    isTerminalVisible = true
    
    // Update directory
    if let path = path {
        terminalViewController?.changeDirectory(to: path)
    } else if let currentPath = tabBarController?.getCurrentPath() {
        terminalViewController?.changeDirectory(to: currentPath)
    }
    
    // Focus with completion callback
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
        self?.terminalViewController?.focusInput()
    }
}
```

### Testing Terminal Changes

- [ ] Open terminal → isVisible = true
- [ ] Close terminal → isVisible = false
- [ ] Terminal focused immediately (typing works)
- [ ] Close app with terminal open → reopens visible
- [ ] Close app with terminal closed → stays closed
- [ ] Switching tabs changes terminal directory
- [ ] Rapid toggle doesn't break anything

---

## Implementation Phase 4: View Mode Improvements (2-3 hours)

Improve view mode coordinator to prevent race conditions.

### Current Problem

The `suppressedDisplayCalls` counter is incremented but never replayed. When browser setup completes, missed display calls are not re-executed.

### Solution: Serial Dispatch Queue

Replace the state machine with a serial queue:

**File**: `MacFileExplorer/Sources/FileBrowserViewModeCoordinator.swift`

```swift
class FileBrowserViewModeCoordinator {
    private let displayQueue = DispatchQueue(
        label: "com.macfilexplorer.viewmode.display",
        qos: .userInteractive
    )
    
    func displayFiles(for viewMode: ViewMode) {
        guard let owner = owner else { return }
        
        // Serialize all display calls
        displayQueue.async { [weak self] in
            self?.performDisplay(for: viewMode)
        }
    }
    
    private func performDisplay(for viewMode: ViewMode) {
        // Actual display logic (can no longer race)
        // ...
    }
}
```

### Implementation Steps

#### Step 4.1: Replace State Machine

1. Remove `BrowserSetupState` enum
2. Remove `suppressedDisplayCalls` counter
3. Add serial dispatch queue
4. Move actual display code to `performDisplay()`
5. All calls go through queue (serialized)

#### Step 4.2: Handle Concurrent Calls

Since queue is serial, later calls automatically override earlier ones:

```swift
// User rapidly switches view modes:
displayFiles(for: .icons)     // Queued, will execute
displayFiles(for: .columns)   // Queued, will wait
displayFiles(for: .list)      // Queued, will wait

// Executes in order:
// 1. Icons display
// 2. Columns display  
// 3. List display
// No calls missed! ✓
```

### Testing View Mode Changes

- [ ] Switch view modes → correct view displayed
- [ ] Rapid view mode switches → shows final mode, not intermediate
- [ ] Switch during initialization → doesn't freeze
- [ ] Switch before ViewController ready → waits then displays
- [ ] Toolbar reflects current view mode
- [ ] Zoom controls enabled/disabled appropriately
- [ ] Selection preserved across switches

---

## Implementation Phase 5: Selection & Hidden Files (2-3 hours)

### Hidden Files: Route Through Settings

**File**: `MacFileExplorer/Sources/SettingsStore.swift`

Make `hiddenFilesState` the source of truth:

```swift
var hiddenFilesState: Bool {
    get { defaults.bool(forKey: UserDefaults.Keys.hiddenFilesState.rawValue) }
    set {
        defaults.set(newValue, forKey: UserDefaults.Keys.hiddenFilesState.rawValue)
        // Notify all observers
        notifyDelegates { delegate in
            delegate.settingsStore(self, hiddenFilesStateDidChange: newValue)
        }
    }
}
```

**File**: `MacFileExplorer/Sources/FileBrowserDataSource.swift`

Observe SettingsStore:

```swift
class FileBrowserDataSource {
    private let settings: SettingsStoreProtocol
    
    init(settings: SettingsStoreProtocol = SettingsStore.shared) {
        self.settings = settings
        settings.addDelegate(self)
    }
    
    // SettingsStoreDelegate
    func settingsStore(_ settingsStore: SettingsStoreProtocol, 
                      hiddenFilesStateDidChange isVisible: Bool) {
        showsHiddenFiles = isVisible
        // Reload automatically via didSet
    }
}
```

### Selection State

Keep in NSView objects for now, but create clear delegation:

**File**: `MacFileExplorer/Sources/FileBrowserSelectionCoordinator.swift`

```swift
class FileBrowserSelectionCoordinator {
    // Query current selection (source is NSView objects)
    func selectedItems() -> [FileItem] { ... }
    
    // Mutate selection (coordinated across views)
    func setSelection(_ items: [FileItem]) { ... }
    
    // Clear selection
    func clearSelection() { ... }
}
```

No change to storage; just clearer API.

---

## Validation Checklist

After completing all implementations, verify:

### Code Quality
- [ ] No compiler warnings
- [ ] All files build successfully
- [ ] All existing tests pass
- [ ] No new crashes in debug builds

### State Synchronization
- [ ] Preview pane: setting change → coordinator updates
- [ ] Terminal: visibility change → setting syncs
- [ ] View mode: rapid switches don't miss updates
- [ ] Selection: operations preserve selection
- [ ] Hidden files: toggle persists correctly

### UI Responsiveness
- [ ] Preview pane toggle instant
- [ ] Terminal open/close smooth
- [ ] View mode switches responsive
- [ ] No freezing on rapid changes

### Persistence
- [ ] Close with preview open → reopens open
- [ ] Close with terminal visible → reopens visible
- [ ] Close with different view mode → reopens same mode
- [ ] All widths/positions preserved

### Thread Safety
- [ ] File operations don't corrupt
- [ ] Cancel buttons work correctly
- [ ] No race conditions
- [ ] Analyzer pause/resume works

---

## Common Pitfalls to Avoid

### 1. Delegate/Notification Loops
❌ **WRONG**:
```swift
// Coordinator updates setting
settings.previewPaneVisible = true

// Setting notifies coordinator
func settingsStore(...) { coordinator.isVisible = true }

// Coordinator updates setting again → LOOP!
```

✅ **CORRECT**:
```swift
// Only coordinator updates setting
// Only coordinators listen to own setting changes
// Settings never call back to original coordinator
```

### 2. Missing Main Thread Guards
❌ **WRONG**: Updating UI from background thread
✅ **CORRECT**: Use `@MainActor` or `DispatchQueue.main.async`

### 3. Incomplete State Transitions
❌ **WRONG**:
```swift
// Start transition but don't finish
coordinator.beginTransition()
// Crash or exception here
// Never reaches coordinator.endTransition()
```

✅ **CORRECT**:
```swift
do {
    try coordinator.performTransition()
} catch {
    coordinator.rollback()
}
```

### 4. Forgetting to Update All Callers
❌ **WRONG**: Change coordinator API but miss one caller → crash
✅ **CORRECT**: Use compiler to find all callers:
```bash
grep -r "previewPaneVisible" MacFileExplorer/Sources --include="*.swift"
# Update all locations
```

### 5. Not Testing Edge Cases
- Fast/slow systems (timing)
- Weak reference deallocated
- State changes before view ready
- Multiple rapid changes

---

## Implementation Timeline

| Task | Effort | Status | Week |
|------|--------|--------|------|
| Fix FileCopyMoveDialog | 1h | Not Started | W2-Mon |
| Fix StorageAnalyzer | 1h | Not Started | W2-Mon |
| Fix Terminal Focus | 1h | Not Started | W2-Tue |
| Preview Pane SSOT | 3h | Not Started | W2-Wed/Thu |
| Terminal SSOT | 2h | Not Started | W2-Fri |
| View Mode Queue | 3h | Not Started | W3-Mon/Tue |
| Hidden Files → Settings | 1h | Not Started | W3-Wed |
| Selection Refactoring | 1h | Not Started | W3-Thu |
| Testing/Validation | 2h | Not Started | W3-Fri |
| **Total** | **15h** | | |

---

## Success Metrics

✅ **Week 2-3 Complete When**:
1. All critical bugs fixed (no data corruption)
2. All 4 coordinators are clear SSOT
3. All state changes observable
4. No compiler warnings
5. All tests pass
6. No regressions from existing functionality
7. Documentation updated with new patterns

✅ **Week 4 Ready When**:
1. State synchronization rock-solid
2. No more desync bugs
3. Foundation ready for error handling
4. Architecture clear for future changes

---

## Questions & Debugging

### If compilation fails:
1. Check for unresolved references to removed properties
2. Verify delegate methods match protocol
3. Look for property shadowing (duplicate variable names)
4. Use `⌘B` to see full compiler errors

### If tests fail:
1. Check for timing issues (use Task.sleep in tests)
2. Verify delegate callbacks fired
3. Check weak reference deallocated
4. Look for missing @MainActor guards

### If state diverges:
1. Add logging to all mutation points:
   ```swift
   debugLog("State change: \(variable) = \(newValue) from \(caller)")
   ```
2. Trace all callers
3. Verify atomicity of changes
4. Check for missing syncs

---

**Ready for Week 2-3 Implementation ✓**

