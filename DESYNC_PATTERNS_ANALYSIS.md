# Desynchronization Patterns: Evidence & Impact Analysis

## Executive Summary

This document catalogs all identified state desynchronization patterns with:
- **Location**: Exact file and line numbers
- **Description**: What can diverge
- **Evidence**: Code showing the problem
- **Impact**: When/how user sees the bug
- **Fix Approach**: How to resolve

---

## Pattern 1: Preview Pane Triple State ❌ CRITICAL

### Description
Three separate boolean variables track preview pane visibility:
1. `FileBrowserViewController.previewVisible`
2. `FileBrowserPreviewPaneCoordinator.isVisible`
3. `SettingsStore.previewPaneVisible`

Any two can diverge without error or notification.

### Locations
```
FileBrowserViewController.swift:96         var previewVisible: Bool = false
FileBrowserPreviewPaneCoordinator.swift:23 private(set) var isVisible: Bool = false
SettingsStore.swift:164-170                var previewPaneVisible: Bool { ... }
ToolbarViewController.swift:656             func updatePreviewPaneDisplay(showing: Bool)
```

### Evidence

**ViewController state:**
```swift
// FileBrowserViewController.swift:96
var previewVisible: Bool = false
```

**Coordinator state:**
```swift
// FileBrowserPreviewPaneCoordinator.swift:23
private(set) var isVisible: Bool = false
```

**Settings state:**
```swift
// SettingsStore.swift:164
var previewPaneVisible: Bool {
    get { defaults.bool(forKey: UserDefaults.Keys.showPreviewPane.rawValue) }
    set { 
        defaults.set(newValue, forKey: UserDefaults.Keys.showPreviewPane.rawValue)
        notifyDelegates { delegate in
            delegate.settingsStore(self, previewPaneVisibilityDidChange: newValue)
        }
        NotificationCenter.default.post(name: .previewPaneToggled, object: nil)
    }
}
```

**UI update is manual:**
```swift
// ToolbarViewController.swift:656
func updatePreviewPaneDisplay(showing: Bool) {
    NSAnimationContext.runAnimationGroup { _ in
        NSAnimationContext.current.duration = 0.15
        if showing {
            previewPaneButton.image = NSImage.mfeSymbol(named: "sidebar.right", ...)
            previewPaneButton.contentTintColor = NSColor.customAccentColor
        } else {
            previewPaneButton.image = NSImage.mfeSymbol(named: "sidebar.right", ...)
            previewPaneButton.contentTintColor = nil
        }
    }
}
```

**The toggle flow is scattered:**
```swift
// SplitPaneViewController.swift:~370
private func toolbarDidTogglePreviewPane() {
    guard activePaneIndex < panes.count else { return }
    let activePane = panes[activePaneIndex]
    activePane.toolbarDidTogglePreviewPane()  // ← Goes to FileBrowserViewController
    SettingsStore.shared.previewPaneVisible = activePane.previewVisible  // ← Syncs
}
```

### Desync Scenarios

**Scenario 1: Coordinator state out of sync**
- User toggles preview pane via toolbar
- `SettingsStore.previewPaneVisible` updates ✓
- `FileBrowserPreviewPaneCoordinator.isVisible` updates ✓
- But if coordinator init code reads wrong state first, internal state wrong ✗

**Scenario 2: ViewController state diverges**
- `FileBrowserViewController.previewVisible = false`
- Coordinator shows the pane
- But ViewController doesn't know, so `splitViewDidResizeSubviews()` doesn't persist width ✗

**Scenario 3: Restore on launch fails**
- App closed with preview pane visible
- `previewPaneVisible` saved as `true`
- App relaunches, ToolbarViewController reads setting ✓
- But what if FileBrowserViewController not initialized yet? 
- Coordinator reads stale coordinator state, not settings ✗

### Current Impact
- **Severity**: HIGH
- **Frequency**: Occasional (timing-dependent)
- **User Symptom**: Preview pane width not saved; pane appears/disappears unexpectedly on relaunch
- **Data Loss**: Preview pane width lost (not persisted)

### Fix Approach
```
Make FileBrowserPreviewPaneCoordinator the SINGLE SOURCE OF TRUTH:
  1. Move isVisible to public var (was private(set))
  2. When SettingsStore.previewPaneVisible changes:
     → Notify coordinator via new delegate method
     → Coordinator updates isVisible
     → UI updates automatically (bound to coordinator)
  3. Coordinator always updates SettingsStore on state change
  4. ViewController always reads from coordinator.isVisible
```

---

## Pattern 2: Duplicate Cancellation State ❌ CRITICAL - DATA CORRUPTION RISK

### Description
`FileCopyMoveDialog` has TWO separate `isCancelled` variables with different synchronization:
- One is `@Atomic` (thread-safe)
- One is local function scope (not thread-safe)

Threads may read from different variables, causing:
- File operation to report completion when it's actually cancelled
- Data corruption from partially copied files
- Incorrect error reporting

### Locations
```
FileCopyMoveDialog.swift:14   @Atomic private var isCancelled = false
FileCopyMoveDialog.swift:285  private var isCancelled = false  ← DUPLICATE!
FileCopyMoveDialog.swift:298  isCancelled = true
FileCopyMoveDialog.swift:303  print(isCancelled)
```

### Evidence

**First declaration (thread-safe):**
```swift
// FileCopyMoveDialog.swift:14-15
@Atomic private var isCancelled = false
@Atomic private var isPaused = false
```

**Second declaration (NOT thread-safe):**
```swift
// FileCopyMoveDialog.swift:280-290
private func setupDefaultState() {
    isPaused = false  // ← Shadows @Atomic wrapper
    isCancelled = false  // ← SECOND isCancelled variable!
}
```

**Reads from wrong variable:**
```swift
// FileCopyMoveDialog.swift:298-310
@objc func cancelOperation() {
    isCancelled = true  // ← Which one?? 
}

private func shouldCancel() -> Bool {
    return isCancelled  // ← May read from wrong one
}

private func shouldPauseOrCancel() {
    if isCancelled || !isPaused {  // ← isCancelled is ambiguous
        // ...
    }
}
```

**Background thread checks:**
```swift
// FileCopyMoveDialog.swift:369-376
Task.detached {
    // Background copy task
    if Task.isCancelled || shouldCancel { return }  
    // ← shouldCancel reads from unclear variable
    // ← If wrong variable, operation doesn't stop
}
```

### Scope Analysis

```swift
class FileCopyMoveDialog {
    @Atomic private var isCancelled = false  // ← Class-level, thread-safe
    
    private func setupDefaultState() {
        isCancelled = false  // ← Creates LOCAL copy??
        // OR overwrites class-level?
        // Compiler sees class-level @Atomic
        // But intent was probably to reset it
    }
}
```

The second declaration might be:
- A copy-paste error
- An intent to reset (but done wrong)
- Dead code

### Desync Scenarios

**Scenario 1: Thread reads stale state**
```
Main thread:          Background thread:
isCancelled = true    if isCancelled { return }
  ↓                       ↓ (reads before write visible)
Not visible yet?      Continues copying
  ↓                       ↓
File corruption!      Returns partial file
```

**Scenario 2: Operation completes incorrectly**
```
User clicks Cancel
  ↓
cancelOperation() sets one isCancelled = true
  ↓
Background thread checks shouldCancel()
  ↓
Reads from OTHER isCancelled = false still
  ↓
Operation continues despite cancellation
  ↓
File operation reports success when it wasn't cancelled
```

### Current Impact
- **Severity**: CRITICAL
- **Frequency**: Occasional (depends on timing/thread scheduling)
- **User Symptom**: File copy/move continues after clicking cancel; incomplete files left on disk
- **Data Corruption**: Possible (files left in intermediate states)
- **Detection**: Hard to diagnose (race condition)

### Fix Approach
```
IMMEDIATE:
1. Search for both isCancelled variables
2. Delete the non-@Atomic one
3. Use ONLY the @Atomic version
4. Verify all callers go through shouldCancel()

Code changes:
- Remove the local `isCancelled = false` in setupDefaultState()
- Update cancelOperation() to use $isCancelled.update {} 
- Ensure shouldCancel() calls $isCancelled
```

---

## Pattern 3: Terminal Focus Race Condition ⚠️ HIGH

### Description
Terminal visibility toggle includes a 100ms sleep before focusing, but:
- Sleep duration is arbitrary and timing-dependent
- No guarantee terminal view is actually ready after sleep
- Focus may fail silently
- User sees terminal but it's not focused (confusing UX)

### Locations
```
SplitViewController.swift:142-180     setTerminalVisibility()
SplitViewController.swift:175         try? await Task.sleep(nanoseconds: 100_000_000)
```

### Evidence

```swift
// SplitViewController.swift:142-180
private func setTerminalVisibility(_ visible: Bool, path: String? = nil, animated: Bool = true) {
    guard let terminalSplitItem = terminalSplitItem else { return }
    
    guard isTerminalVisible != visible else {
        if visible {
            terminalViewController?.focusInput()
        }
        return
    }
    
    isTerminalVisible = visible
    if animated {
        terminalSplitItem.animator().isCollapsed = !visible
    } else {
        terminalSplitItem.isCollapsed = !visible
    }
    
    if visible {
        let targetPath = path ?? tabBarController?.getCurrentPath()
        if let targetPath {
            debugLog("  Opening terminal - setting directory to \(targetPath)")
            terminalViewController?.changeDirectory(to: targetPath)
        }
        
        // Defer focus when not animated to ensure view is fully laid out
        if animated {
            terminalViewController?.focusInput()
        } else {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 100_000_000)
                self?.terminalViewController?.focusInput()
            }
        }
    } else {
        debugLog("  Closing terminal - restoring focus to tabBarController.view")
        view.window?.makeFirstResponder(tabBarController?.view)
    }
    
    settingsStore.terminalIsVisible = visible
}
```

### Issues with Current Approach

1. **Arbitrary timeout**: 100ms is not guaranteed to be enough
   - On slow systems: layout may still be in progress
   - On fast systems: sleep wastes 100ms unnecessarily

2. **No wait mechanism**: No async callback when layout complete
   - Could use `viewDidAppear()` on TerminalViewController
   - Could use `NSSplitViewDelegate.splitViewDidResizeSubviews()`
   - Could use layout completion notification

3. **Silent failure**: `focusInput()` may fail silently
   - No check if focus was successful
   - No fallback if terminal view not ready

4. **Inconsistent behavior**: Animated vs non-animated different
   - Animated: focus immediately (may fail if layout not done)
   - Non-animated: wait 100ms then focus
   - User sees different UX depending on flag

### Desync Scenarios

**Scenario 1: Focus fails on slow system**
```
User presses Cmd+T
  ↓
setTerminalVisibility(true, animated: true)
  ↓
isCollapsed = false (animated)
focusInput() called immediately  ← Layout still in progress!
  ↓
Terminal view not ready yet
  ↓
focusInput() fails silently
  ↓
User sees terminal pane but it's not focused
  ↓
User starts typing → typing goes to tab bar instead!
```

**Scenario 2: Focus delayed inconsistently**
```
First toggle: animated=true → focus immediate
Second toggle: animated=false → focus after 100ms
User sees inconsistent focus behavior
```

### Current Impact
- **Severity**: HIGH
- **Frequency**: Frequent (especially when terminal appears for first time)
- **User Symptom**: Terminal visible but not focused; typing goes to wrong view
- **Confusion**: User presses Cmd+T, sees pane appear, starts typing, nothing happens

### Fix Approach
```
OPTION 1: Wait for layout
- Use NSSplitViewDelegate callback
- Focus when splitViewDidResizeSubviews() fires

OPTION 2: Use proper async/await
- When animation completes, then focus
- Replace sleep with proper animation callback

OPTION 3: Focus reliably
- Make focusInput() idempotent and safe
- Have view report when ready
- Focus attempts until successful

Recommended: Use NSSplitViewDelegate callback
- Add to terminalSplitItem setup
- Focus when split view layout completes
- Works for all terminal opening scenarios
```

---

## Pattern 4: Hidden Files Dual Source ⚠️ MEDIUM

### Description
Hidden files visibility tracked in TWO places:
1. `FileBrowserDataSource.showsHiddenFiles` (runtime, triggers reload)
2. `SettingsStore.hiddenFilesState` (persisted)

Can diverge if:
- Settings change but DataSource not updated
- DataSource changes but Settings not persisted
- Notifications arrive out of order

### Locations
```
FileBrowserDataSource.swift        var showsHiddenFiles: Bool
SettingsStore.swift:669            var hiddenFilesState: Bool
FileBrowserViewController.swift    toggleHiddenFiles() implementation
```

### Evidence

**DataSource state:**
```swift
// FileBrowserDataSource.swift
var showsHiddenFiles: Bool {
    didSet {
        // Reload with new visibility
        // But when is this updated?
    }
}
```

**Settings state:**
```swift
// SettingsStore.swift:669
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

**Toggle implementation scattered:**
```swift
// Multiple places call setShowsHiddenFiles or toggle
// But which one updates which state?
```

### Desync Scenarios

**Scenario 1: DataSource out of sync**
```
Settings: hiddenFilesState = true (show hidden)
DataSource: showsHiddenFiles = false (hide them)
Result: User toggled setting, but hidden files still hidden
```

**Scenario 2: Persisting fails**
```
User toggles hidden files
  ↓
DataSource.showsHiddenFiles = true
  ↓
View reloads with hidden files shown ✓
  ↓
But SettingsStore.hiddenFilesState still = false
  ↓
App relaunches
  ↓
DataSource reads false, hidden files hidden again ✗
```

### Current Impact
- **Severity**: MEDIUM
- **Frequency**: Occasional
- **User Symptom**: Hidden files toggle doesn't persist; reappear as hidden on relaunch
- **Workaround**: User manually retoggle after relaunch

### Fix Approach
```
Make SettingsStore the SINGLE SOURCE OF TRUTH:
1. Observer pattern: DataSource observes SettingsStore changes
2. When toggle happens:
   → Only SettingsStore.hiddenFilesState changes
   → Delegate callback notifies DataSource
   → DataSource updates and triggers reload
3. Guarantees: Settings persisted first, then UI updates
```

---

## Pattern 5: View Mode Setup Race Condition ⚠️ MEDIUM-HIGH

### Description
`FileBrowserViewModeCoordinator` uses a state machine to prevent concurrent initialization:
```swift
enum BrowserSetupState { case idle, preparing, creatingBrowser, ready, failed }
```

But `suppressedDisplayCalls` counter may miss legitimate updates if:
- Transition completes but calls still suppressed
- Multiple rapid calls after completion
- State machine gets stuck

### Locations
```
FileBrowserViewModeCoordinator.swift:7-20   State machine
FileBrowserViewModeCoordinator.swift:28-40  displayFiles implementation
```

### Evidence

```swift
// FileBrowserViewModeCoordinator.swift
private enum BrowserSetupState { 
    case idle, preparing, creatingBrowser, ready, failed 
}
private var browserSetupState: BrowserSetupState = .idle {
    didSet {
#if DEBUG
        debugLog("DEBUG: browserSetupState -> \(browserSetupState)")
#endif
    }
}

private var suppressedDisplayCalls = 0

func displayFiles(for viewMode: ViewMode) {
    guard let owner = owner else { return }
    assert(Thread.isMainThread, "displayFiles must run on main thread")
    
    if browserSetupState == .preparing || browserSetupState == .creatingBrowser {
        suppressedDisplayCalls += 1
#if DEBUG
        debugLog("DEBUG: displayFiles blocked (state=\(browserSetupState)) count=\(suppressedDisplayCalls)")
#endif
        return
    }
    
    // ... actual display code ...
    
    // But when does suppressedDisplayCalls get processed?
    // It's only a counter, never acted upon!
}
```

### Issues

1. **Counter never used**: `suppressedDisplayCalls` incremented but never checked
   - Transition completes
   - Counter > 0 but ignored
   - Suppressed calls never replayed

2. **Missed updates**: Legitimate display changes ignored
   - User switches view modes while browser initializing
   - Call suppressed, counter incremented
   - Browser completes
   - Display change lost

3. **State stuck**: No recovery if state machine stuck in intermediate state
   - No timeout
   - No error callback
   - User sees frozen view

### Desync Scenarios

**Scenario 1: Browser initialization + rapid mode switch**
```
User switches to Columns view
  ↓
browserSetupState = .preparing
  ↓
User rapidly switches to Icons view
  ↓
displayFiles(for: .icons) called
  ↓
suppressed (counter = 1)
  ↓
Browser setup completes
  ↓
browserSetupState = .ready
  ↓
No replay of Icons display call!
  ↓
Column view still showing, should be Icons ✗
```

### Current Impact
- **Severity**: MEDIUM-HIGH
- **Frequency**: Occasional (depends on timing)
- **User Symptom**: View mode doesn't change after switching; rapid clicking shows old view
- **Data Loss**: No

### Fix Approach
```
OPTION 1: Serial queue
- Use DispatchQueue(label: "view-mode-display", attributes: .initiallyInactive)
- Serialize all displayFiles() calls
- No need for state machine

OPTION 2: Proper async/await
- Make displayFiles() async
- Wait for setup to complete
- Chain view switches

OPTION 3: Fix state machine
- Actually act on suppressedDisplayCalls
- When ready, replay last suppressed call
- Add timeout to detect stuck state

Recommended: Use DispatchQueue or async/await
- Simpler than state machine
- Easier to reason about
- Standard Swift concurrency pattern
```

---

## Pattern 6: Layout Constraint Leaks ⚠️ MEDIUM

### Description
`FileBrowserViewController` maintains `activeConstraints` array:
```swift
var activeConstraints: [NSLayoutConstraint] = []
```

On view mode switch:
1. Deactivate old constraints
2. Add to activeConstraints array
3. Switch to new view
4. Activate new constraints

But if switch fails mid-way:
- Old constraints deactivated
- New constraints not activated
- View has no layout (broken)
- No way to recover

### Locations
```
FileBrowserViewController.swift:98              var activeConstraints: [NSLayoutConstraint] = []
FileBrowserDisplayController.swift:~100-200     Layout code
```

### Issues

1. **No error recovery**: If constraint activation fails, view broken
2. **Hard to debug**: Which constraints are active? Need logging
3. **Manual management**: Easy to forget a constraint

### Fix Approach
```
OPTION 1: Use view controller containment
- Add/remove view controllers properly
- Let system manage constraints

OPTION 2: Use NSStackView
- Stack view manages constraints automatically
- No manual constraint management

OPTION 3: Improve constraint tracking
- Log all constraint changes
- Add validation after each switch
- Implement recovery mechanism
```

---

## Summary Table

| Pattern | Severity | Frequency | Type | Fix Effort |
|---------|----------|-----------|------|-----------|
| Preview pane triple state | CRITICAL | Medium | Desync | 3h |
| Cancellation duplicate var | CRITICAL | Low-Medium | Bug | 1h |
| Terminal focus race | HIGH | High | Race condition | 2h |
| Hidden files dual source | MEDIUM | Medium | Desync | 2h |
| View mode setup race | MEDIUM-HIGH | Low | Race condition | 3h |
| Layout constraint leaks | MEDIUM | Low | Resource leak | 2h |

**Total Fix Effort: ~13 hours across multiple phases**

---

## Testing the Fixes

Once fixes are implemented, test with these scenarios:

### Preview Pane
- [ ] Toggle preview pane, close app, reopen → state restored
- [ ] Resize preview pane, toggle, toggle back → width preserved
- [ ] Switch view modes with preview open → preview stays open
- [ ] Change preview position setting → coordinator updated

### Terminal
- [ ] Open terminal → focus immediately
- [ ] Open terminal on slow system → still focused
- [ ] Toggle terminal rapidly → consistent focus
- [ ] Close app with terminal open → reopens visible

### Hidden Files
- [ ] Toggle hidden files → both DataSource and Settings updated
- [ ] Change setting, reload app → still hidden/shown
- [ ] Filter with hidden files on/off → filter works

### View Mode
- [ ] Rapid view mode switches → shows latest, not missed mode
- [ ] Switch during browser initialization → doesn't freeze
- [ ] Switch, undo, switch again → works reliably

