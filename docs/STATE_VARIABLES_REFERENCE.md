# State Variables Reference: Complete Inventory

## Quick Index by Component

### FileBrowserViewController.swift
| Variable | Type | Scope | Purpose | Persistence |
|----------|------|-------|---------|-------------|
| `previewVisible` | Bool | Computed | READ-ONLY: Delegates to Coordinator | No (runtime) |
| `containerView` | NSView! | instance | Top-level content container | No |
| `scrollView` | NSScrollView! | instance | List view scroll container | No |
| `outlineView` | NSOutlineView! | instance | List/hierarchy view | No |
| `collectionView` | NSCollectionView? | instance | Icon view | No |
| `browserView` | NSBrowser? | instance | Column/browser view | No |
| `freeFormLayout` | FreeFormCollectionViewLayout? | instance | Icon view layout | No |
| `zoomControlsAllowedByPane` | Bool | instance | Zoom feature availability | No |
| `activeConstraints` | [NSLayoutConstraint] | instance | Current layout constraints | No |
| `currentDirectory` | URL | Computed | READ-ONLY: Delegates to DataSource | No |
| `showsHiddenFiles` | Bool | Computed | READ-WRT: Delegates to Coordinator | No |
| `viewModeCoordinator` | Coordinator | instance | **SSOT** for View Mode | Yes (via Settings) |
| `hiddenFilesCoordinator` | Coordinator | instance | **SSOT** for Hidden Files | Yes (via Settings) |

### SplitViewController.swift
| Variable | Type | Scope | Purpose | Persistence |
|----------|------|-------|---------|-------------|
| `isTerminalVisible` | Bool | Computed | READ-ONLY: Delegates to Coordinator | No (runtime) |
| `hasInitializedTabs` | Bool | instance | First-time setup guard | No |
| `isAdjustingSplitPosition` | Bool | instance | Resize recursion guard | No |
| `terminalCoordinator` | Coordinator | instance | **SSOT** for Terminal Visibility | Yes (via Settings) |

### FileBrowserPreviewPaneCoordinator.swift
| Variable | Type | Scope | Purpose | Persistence |
|----------|------|-------|---------|-------------|
| `isVisible` | Bool | instance | Coordinator preview state | No (but syncs to settings) |
| `previewPaneViewController` | PreviewPaneViewController? | instance | Active preview controller | No |

### TerminalVisibilityCoordinator.swift
| Variable | Type | Scope | Purpose | Persistence |
|----------|------|-------|---------|-------------|
| `isVisible` | Bool | instance | **SSOT** for Terminal State | Yes (via Settings) |
| `delegate` | TerminalVisibilityDelegate? | instance | Notification channel | No |

### FileBrowserNavigationCoordinator.swift
| Variable | Type | Scope | Purpose | Persistence |
|----------|------|-------|---------|-------------|
| `navigationManager` | NavigationManager | instance | **SSOT** for History/Back/Fwd | No |
| `delegate.currentDirectory` | URL | Delegated | Reads from VC (Circular!) | No |

### FileBrowserFilterCoordinator.swift
| Variable | Type | Scope | Purpose | Persistence |
|----------|------|-------|---------|-------------|
| `currentFilterCriteria` | FilterCriteria | instance | **SSOT** for Filter State | Yes (via Settings) |
| `searchHistory` | [String] | instance | **SSOT** for Search History | Yes (via Settings) |

### FileBrowserSelectionCoordinator.swift
| Variable | Type | Purpose | Authority |
|----------|------|---------|-----------|
| `selectionManager` | FileBrowserSelectionManager | Selection state aggregator | NSView objects |
| `currentSingleSelection()` | FileItem? | Computed from active view | NSOutlineView/NSCollectionView/NSBrowser |
| `selectedItems()` | [FileItem] | All selected items | NSOutlineView/NSCollectionView/NSBrowser |

### FileCopyMoveDialog.swift
| Variable | Type | Scope | Synchronization | Line | Issue |
|----------|------|-------|-----------------|------|-------|
| `@Atomic isCancelled` | Bool | instance | @Atomic wrapper | 14 | ✓ Thread-safe |
| `isCancelled` (dup!) | Bool | local function scope | None | 285 | ❌ NOT thread-safe; shadows @Atomic |
| `@Atomic isPaused` | Bool | instance | @Atomic wrapper | 14 | ✓ Thread-safe |

### StorageAnalyzerEngine.swift
| Variable | Type | Synchronization | Issue |
|----------|------|-----------------|-------|
| `isCancelled` | Bool | None | ❌ Not thread-safe despite background threads |
| `isPaused` | Bool | None | ❌ Not thread-safe |

### NavigationManager.swift
| Variable | Type | Purpose | State |
|----------|------|---------|-------|
| `canGoBack` | Bool (computed) | Back button enabled | Derived from history |
| `canGoForward` | Bool (computed) | Forward button enabled | Derived from history |

### ToolbarViewController.swift
| Variable | Type | Purpose | Syncing |
|----------|------|---------|--------|
| `currentURL` | URL? | Current location display | Updated via `updatePath()` |
| `canGoBack` | Bool | Back button state | Updated via `updatePath()` |
| `canGoForward` | Bool | Forward button state | Updated via `updatePath()` |
| `navigationHistory` | [URL] | Breadcrumb data | Updated via `updatePath()` |

### SidebarViewController.swift
| Variable | Type | Purpose | State |
|----------|------|---------|-------|
| `isHovering` | Bool | Hover effect tracking | Local UI state |

### TabBarController.swift
| Variable | Type | Purpose | Persistence |
|----------|------|---------|-------------|
| `tabs` | [NSViewController] | Open tabs/panes | Conditional via `restoreTabsOnReopen` |
| `currentTabIndex` | Int | Active tab selection | Updated on click |

### MainWindowController.swift
| Variable | Type | Purpose | Persistence |
|----------|------|---------|-------------|
| `splitViewController` | SplitViewController? | Root layout controller | N/A |

---

## State Update Flow Diagrams

### Preview Pane Current Flow (FRAGMENTED ❌)

```
User clicks toolbar button
         ↓
ToolbarViewController.previewPaneButton clicked
         ↓
MainWindowController.togglePreviewPane() 
         ↓
SplitViewController.togglePreviewPane() / showTerminal()
         ↓
TabBarController.setViewMode()
         ↓
SplitPaneViewController.togglePreviewPane()
         ↓
FileBrowserViewController.togglePreviewPane()
         ↓
FileBrowserPreviewPaneCoordinator.togglePreviewPane()
         ├─ isVisible = !isVisible (COORDINATOR)
         ├─ settings.previewPaneVisible = value (SETTINGS)
         └─ UIViewController changes (PRESENTER)
         ↓
SettingsStore notifies delegates & posts notification
         ↓
AppDelegate observes notification
ToolbarViewController observes delegate callback
         ↓
updatePreviewPaneDisplay() (MANUAL UI UPDATE)

Problems:
- 3 separate boolean values must be synchronized
- UI layer handles persistence logic
- No single "source of truth" (all 3 are authoritative)
- Order of operations matters for consistency
- Notifications are fire-and-forget; state lag possible
```

### Terminal Visibility Current Flow (BETTER BUT MANUAL ⚠️)

```
User presses Cmd+T or clicks button
         ↓
MainWindowController receives command
         ↓
SplitViewController.toggleTerminal()
         ↓
setTerminalVisibility(visible: Bool)
         ├─ isTerminalVisible = visible (RUNTIME)
         ├─ terminalSplitItem.isCollapsed = !visible (VIEW)
         ├─ settings.terminalIsVisible = visible (PERSISTED)
         ├─ focus terminal or tab bar
         └─ 100ms delay before focus (TIMING HACK)
         ↓
[State is updated, but...]

Problems:
- Focus update is timing-dependent (not guaranteed)
- No notification when toggle completes
- 3 separate state updates (not atomic)
- Sleep-based focus timing unreliable on slow systems
```

### Hidden Files Current Flow (MULTI-SOURCE ❌)

```
User clicks toolbar button / menu
         ↓
FileBrowserViewController.toggleHiddenFiles()
         ↓
DataSource.showsHiddenFiles = !showsHiddenFiles
         ├─ didSet reload trigger
         └─ triggers outline/collection view reload
         ↓
         PLUS somewhere...
         ↓
SettingsStore.hiddenFilesState = value
         ├─ notifyDelegates
         └─ post notification
         ↓
AppDelegate observes and updates menu checkmark
ToolbarViewController updates button state

Problems:
- Two separate state sources (DataSource + SettingsStore)
- Toggle may update only one initially
- Reload timing may not match settings persistence
- Menu checkmark updates via notification (async)
- Can get out of sync if one is missed
```

---

## Thread Safety Analysis

### Current Thread Safety Status

| Component | State Variable | Safe? | Mechanism | Issues |
|-----------|---|---|---|---|
| FileBrowserViewController | previewVisible | ✓ | Main thread only | N/A |
| FileBrowserViewController | activeConstraints | ✓ | Main thread only | Need verification |
| SplitViewController | isTerminalVisible | ✓ | Main thread only | N/A |
| FileBrowserPreviewPaneCoordinator | isVisible | ✓ | Main thread only | N/A |
| CancellationToken | _isCancelled | ✓ | DispatchSemaphore | Correct |
| FileCopyMoveDialog | @Atomic isCancelled | ✓ | @Atomic wrapper | Correct |
| FileCopyMoveDialog | local isCancelled | ❌ | None | **DUPLICATE** |
| StorageAnalyzerEngine | isCancelled | ❌ | None | Accessed from threads |
| StorageAnalyzerEngine | isPaused | ❌ | None | Accessed from threads |
| SettingsStore properties | All | ✓ | UserDefaults locks | NSUserDefaults is thread-safe |
| NSView selection | outlineView selection | ⚠️ | Main thread assumed | No explicit guard |
| NSView selection | collectionView selection | ⚠️ | Main thread assumed | No explicit guard |
| NSView selection | browserView selection | ⚠️ | Main thread assumed | No explicit guard |

---

## Notification/Callback Registry

### Currently Posted Notifications
- `.previewPaneToggled` (legacy, for backward compatibility)
- `.settingsDidChange` (generic settings change)

### SettingsStore Delegate Callbacks
```swift
protocol SettingsStoreDelegate: AnyObject {
    func settingsStore(_ settingsStore: SettingsStoreProtocol, 
                      previewPaneVisibilityDidChange isVisible: Bool)
    func settingsStore(_ settingsStore: SettingsStoreProtocol, 
                      hiddenFilesStateDidChange isVisible: Bool)
}
```

### Issues with Current System
- ❌ No callback when `previewPanePosition` changes
- ❌ No callback when `previewPaneWidth` changes  
- ❌ No callback when `terminalIsVisible` changes
- ❌ No callback when view mode changes
- ⚠️  Callbacks are fire-and-forget (no acknowledgment)
- ⚠️  Order of callbacks not guaranteed
- ⚠️  Delegate may be deallocated before callback fires

---

## State Persistence Strategy (Current)

### on Launch (AppDelegate.applicationDidFinishLaunching)
1. MainWindowController created
2. SplitViewController created
3. SettingsStore properties read
4. TabBarController initialized with tabs (if `restoreTabsOnReopen`)
5. Terminal restored if `terminalIsVisible`
6. Preview pane restored if `previewPaneVisible`

### During Runtime
- ToolbarViewController reads/writes settings directly
- FileBrowserViewController reads settings on initialization only
- Most other components don't persist (runtime-only state)

### on Quit (AppDelegate.applicationShouldTerminateAfterLastWindowClosed)
- SplitViewController persists terminal visibility
- FileBrowserViewController persists preview pane width
- TabBarController persists open tabs (if enabled)
- All other state lost

### Issues
- ❌ Inconsistent persistence strategy across components
- ❌ View layout state not persisted (constraints, positions)
- ❌ Selection state lost on close
- ⚠️  Some mutations only persist on window close (race condition window)

---

## Recommended Next Steps

1. **Immediate** (Critical bugs):
   - Fix FileCopyMoveDialog duplicate isCancelled
   - Fix StorageAnalyzerEngine thread safety
   - Fix terminal focus race condition

2. **This Week** (Design):
   - Complete state machine designs for all 4 major components
   - Identify all mutation points for each state
   - Design notification/callback strategy

3. **Next Phase** (Implementation):
   - Implement PreviewPaneCoordinator as SSOT
   - Implement TerminalVisibilityCoordinator as SSOT
   - Implement ViewModeCoordinator improvements
   - Implement SelectionCoordinator refactoring

