# MacFileExplorer API Naming Consistency Guide

> **Version:** 1.0  
> **Last Updated:** December 23, 2025  
> **Purpose:** Establish and document naming conventions for maintainable, predictable Swift code

## Table of Contents
- [Core Principles](#core-principles)
- [File & Type Naming](#file--type-naming)
- [Property Naming](#property-naming)
- [Method Naming](#method-naming)
- [Coordinator Pattern](#coordinator-pattern)
- [Delegate Protocols](#delegate-protocols)
- [Extensions](#extensions)
- [Safety Patterns](#safety-patterns)

---

## Core Principles

### 1. Clarity Over Brevity
✅ **Good:** `navigationCoordinator`, `previewPaneCoordinator`  
❌ **Bad:** `navCoord`, `ppCoord`

### 2. Consistency Within Domain
Group related functionality with consistent prefixes:
- `FileBrowser*` for file browsing components
- `Storage*` for storage analyzer features
- `Settings*` for settings-related views

### 3. Apple's API Design Guidelines
Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) as the foundation.

---

## File & Type Naming

### View Controllers
**Pattern:** `<Feature><Type>.swift`

```swift
// ✅ Good
FileBrowserViewController.swift
ToolbarViewController.swift
PreviewPaneViewController.swift
StorageAnalyzerWindowController.swift

// ❌ Avoid
FileBrowser.swift         // Missing type suffix
BrowserVC.swift          // Abbreviated type
PreviewController.swift  // Inconsistent with "Pane" domain term
```

### Coordinators
**Pattern:** `<Feature><Responsibility>Coordinator.swift`

```swift
// ✅ Good
FileBrowserNavigationCoordinator.swift
FileBrowserSelectionCoordinator.swift
FileBrowserFilterCoordinator.swift
FileBrowserViewModeCoordinator.swift
FileBrowserPreviewPaneCoordinator.swift
FileBrowserZoomCoordinator.swift

// ❌ Avoid
NavigationCoordinator.swift  // Missing feature prefix
FileBrowserCoordinator.swift // Too generic
```

### Controllers (New Pattern)
**Pattern:** `<Feature><Responsibility>Controller.swift`

```swift
// ✅ Good - Single responsibility controllers
FileBrowserDisplayController.swift
FileBrowserUISetupController.swift

// ❌ Avoid
DisplayManager.swift      // Use "Controller" for consistency
UISetup.swift            // Missing type suffix
```

### Managers
**Pattern:** `<Feature>Manager.swift`

```swift
// ✅ Good
FileOperationsManager.swift
ColorManager.swift
PermissionsManager.swift
NavigationManager.swift

// ❌ Avoid
Operations.swift         // Missing type suffix
FileOps.swift           // Abbreviated
```

### Extensions
**Pattern:** `<Type>+<Feature>.swift`

```swift
// ✅ Good
FileBrowserViewController+Toolbar.swift
FileBrowserViewController+Collection.swift
FileBrowserViewController+Outline.swift
FileBrowserViewController+Columns.swift
FileBrowserViewController+ContextMenu.swift
FileBrowserViewController+FileOperations.swift
FileBrowserViewController+StatusBar.swift
Array+Safe.swift
String+Localization.swift

// ❌ Avoid
FileBrowser-Toolbar.swift           // Use + separator
FileBrowserToolbarExtension.swift   // Redundant "Extension"
```

---

## Property Naming

### Stored Properties
Use descriptive nouns without redundant type information:

```swift
// ✅ Good
var currentDirectory: URL
var rootItem: FileItem?
var selectedItems: [FileItem]
var zoomLevel: Double
var previewVisible: Bool

// ❌ Avoid
var currentDirectoryURL: URL     // Type in name
var rootFileItem: FileItem?      // Redundant type
var selectedItemsArray: [FileItem]
var zoomLevelValue: Double       // Redundant "Value"
var isPreviewVisible: Bool       // Redundant "is" for non-bool-returning method
```

### Boolean Properties
**Pattern:** `is<State>`, `has<State>`, `should<Action>`, `can<Action>`

```swift
// ✅ Good
var isLoading: Bool
var hasChanges: Bool
var shouldAutoSave: Bool
var canUndo: Bool
var previewVisible: Bool  // Acceptable for brevity when context is clear

// ❌ Avoid
var loading: Bool        // Not clear it's a boolean
var changes: Bool        // Ambiguous
var autoSave: Bool       // Missing modal verb
```

### Computed Properties
Return values directly; avoid verbose names:

```swift
// ✅ Good
var currentPath: String {
    return currentDirectory.path
}

var numberOfItems: Int {
    return rootItem?.children?.count ?? 0
}

// ❌ Avoid
func getCurrentPath() -> String {  // Should be computed property
    return currentDirectory.path
}

var currentPathString: String {    // Redundant type suffix
    return currentDirectory.path
}
```

### Lazy Properties
Use `lazy var` for expensive initialization:

```swift
// ✅ Good
lazy var fileOperationsManager: FileOperationsManager = {
    return FileOperationsManager(delegate: self)
}()

lazy var displayController = FileBrowserDisplayController(viewController: self)

// ❌ Avoid
var fileOperationsManager: FileOperationsManager!  // IUO instead of lazy
```

### Coordinators and Controllers
Store as instance properties with descriptive names:

```swift
// ✅ Good
let selectionCoordinator = FileBrowserSelectionCoordinator()
lazy var viewModeCoordinator = FileBrowserViewModeCoordinator(owner: self)
lazy var displayController = FileBrowserDisplayController(viewController: self)

// ❌ Avoid
var coordinator: FileBrowserSelectionCoordinator  // Too generic
var manager: FileBrowserViewModeCoordinator       // Inconsistent type
```

---

## Method Naming

### Action Methods
**Pattern:** `<verb><Object>(parameters)`

```swift
// ✅ Good
func refreshCurrentDirectory()
func updateStatusBarDisplay(selectedCount: Int, totalSize: Int64)
func navigateToURL(_ url: URL)
func applySearchFilter()
func toggleHiddenFilesState()

// ❌ Avoid
func refresh()                    // Too generic
func update()                     // What does it update?
func navigate(_ url: URL)         // Missing "to" preposition
func filterSearch()               // Verb order unclear
func toggleHidden()               // Missing context
```

### Boolean-Returning Methods
**Pattern:** `is<State>`, `has<State>`, `can<Action>`, `should<Action>`

```swift
// ✅ Good
func isValidDestination(_ destination: URL, for urls: [URL]) -> Bool
func isShowingHiddenFiles() -> Bool
func canAddMorePanes() -> Bool
func shouldAutoExpand(item: FileItem) -> Bool

// ❌ Avoid
func validDestination() -> Bool           // Missing "is"
func showingHiddenFiles() -> Bool        // Ambiguous (getter vs action)
func addMorePanes() -> Bool              // Sounds like action, not query
```

### Setup Methods
**Pattern:** `setup<Component>()`

```swift
// ✅ Good
private func setupUI()
private func setupToolbar()
private func setupStatusBar()
private func setupConstraints()
private func setupOutlineViewColumns()

// ❌ Avoid
private func initUI()              // Use "setup" consistently
private func createToolbar()       // Creates confusion with factory methods
private func configureStatusBar()  // Use "setup" for initialization
```

### Delegate Methods
**Pattern:** `<source>Did<Action>` or `<source>Will<Action>`

```swift
// ✅ Good - Delegate Protocol
protocol FileBrowserDelegate: AnyObject {
    func fileBrowserDidBecomeActive(_ browser: FileBrowserViewController)
    func fileBrowser(_ browser: FileBrowserViewController, didSelectFile file: FileItem?)
    func fileBrowser(_ browser: FileBrowserViewController, didUpdateSelection count: Int, totalSize: Int64)
}

// ✅ Good - Implementation
func toolbarDidRequestBack()
func toolbarDidChangeSortColumn(_ column: String, ascending: Bool)
func zoomLevelDidChange(to level: Double)

// ❌ Avoid
func browserActivated()                    // Missing "did" and source
func fileSelected(_ file: FileItem?)       // Missing source context
func onToolbarBack()                       // Use "did" not "on"
```

### Coordinator Methods
**Pattern:** `<verb><Object>` (domain-specific actions)

```swift
// ✅ Good
// FileBrowserNavigationCoordinator
func loadDirectory(_ url: URL)
func goBack()
func goForward()
func navigateToHistoryIndex(_ index: Int)

// FileBrowserSelectionCoordinator
func selectedItems() -> [FileItem]
func handleOutlineSelectionDidChange() -> FileItem?
func clearSelection()

// FileBrowserDisplayController
func displayViewMode(_ viewMode: ViewMode)
func refreshViews()
func currentActiveContentView() -> NSView?

// ❌ Avoid
func directory(_ url: URL)         // Missing verb
func back()                        // Too terse, use "goBack"
func getSelectedItems() -> [FileItem]  // Avoid "get" prefix
func selection() -> [FileItem]     // Ambiguous
```

---

## Coordinator Pattern

### Coordinator Naming
Each coordinator owns a **single responsibility**:

```swift
// ✅ Good - Each has clear, focused responsibility
FileBrowserNavigationCoordinator    // Navigation & history
FileBrowserSelectionCoordinator     // Selection state
FileBrowserFilterCoordinator        // Search & filtering
FileBrowserViewModeCoordinator      // View mode switching
FileBrowserPreviewPaneCoordinator   // Preview pane management
FileBrowserZoomCoordinator          // Zoom levels
FileBrowserDisplayController        // View display & layout
FileBrowserUISetupController        // One-time UI initialization

// ❌ Avoid - Too broad or overlapping
FileBrowserCoordinator              // Too generic
FileBrowserUICoordinator            // Unclear responsibility
FileBrowserManager                  // "Manager" vs "Coordinator" inconsistency
```

### Delegate Protocol Naming
**Pattern:** `<Coordinator>Delegate`

```swift
// ✅ Good
protocol FileBrowserNavigationCoordinatorDelegate: AnyObject {
    func navigationCoordinator(_ coordinator: FileBrowserNavigationCoordinator, 
                              didNavigateTo url: URL)
}

protocol FileBrowserSelectionDelegate: AnyObject {
    var currentViewMode: ViewMode { get }
    var outlineView: NSOutlineView! { get }
    func updateStatusBarDisplay(selectedCount: Int, totalSize: Int64)
}

// ❌ Avoid
protocol NavigationDelegate: AnyObject {  // Missing feature prefix
    func didNavigate(to url: URL)        // Missing coordinator parameter
}
```

### Coordinator Initialization
```swift
// ✅ Good - Explicit ownership
class FileBrowserViewController {
    let selectionCoordinator = FileBrowserSelectionCoordinator()
    lazy var viewModeCoordinator = FileBrowserViewModeCoordinator(owner: self)
    lazy var displayController = FileBrowserDisplayController(viewController: self)
    
    private func commonInit() {
        navigationCoordinator = FileBrowserNavigationCoordinator()
        navigationCoordinator.delegate = self
        selectionCoordinator.delegate = self
    }
}

// ❌ Avoid
class FileBrowserViewController {
    var coordinator: FileBrowserSelectionCoordinator!  // IUO
    var coordinator2: FileBrowserNavigationCoordinator!  // Generic name
}
```

---

## Delegate Protocols

### Protocol Naming
**Pattern:** `<Type>Delegate` or `<Feature>Delegate`

```swift
// ✅ Good
protocol FileBrowserDelegate: AnyObject
protocol ToolbarDelegate: AnyObject
protocol StatusBarDelegate: AnyObject
protocol FileOperationsManagerDelegate: AnyObject

// ❌ Avoid
protocol FileBrowserProtocol: AnyObject  // Redundant "Protocol"
protocol IFileBrowserDelegate            // No Hungarian notation
protocol FileBrowserDelegateProtocol     // Redundant suffixes
```

### Method Naming in Protocols
Use the source as the first parameter:

```swift
// ✅ Good
protocol FileBrowserDelegate: AnyObject {
    func fileBrowserDidBecomeActive(_ browser: FileBrowserViewController)
    func fileBrowser(_ browser: FileBrowserViewController, didSelectFile file: FileItem?)
    func fileBrowser(_ browser: FileBrowserViewController, didUpdateSelection count: Int, totalSize: Int64)
}

protocol ToolbarDelegate: AnyObject {
    func toolbarDidRequestBack()
    func toolbarDidChangeSortColumn(_ column: String, ascending: Bool)
    func toolbarDidToggleHiddenFiles(show: Bool)
}

// ❌ Avoid
protocol FileBrowserDelegate: AnyObject {
    func didBecomeActive()              // Missing source parameter
    func selectFile(_ file: FileItem?)  // Missing "did" and source
    func updateSelection(_ count: Int)  // Sounds like action, not notification
}
```

---

## Extensions

### Extension Organization
Group related functionality in focused extensions:

```swift
// ✅ Good
// FileBrowserViewController+Toolbar.swift
extension FileBrowserViewController {
    func toolbarDidRequestBack() { }
    func toolbarDidChangeSortColumn(_ column: String, ascending: Bool) { }
}

// FileBrowserViewController+Collection.swift
extension FileBrowserViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, 
                       numberOfItemsInSection section: Int) -> Int { }
}

// ❌ Avoid
// FileBrowserViewController+Misc.swift
extension FileBrowserViewController {
    func toolbarDidRequestBack() { }
    func tableView(_ tableView: NSTableView, numberOfRowsInSection: Int) -> Int { }
    func setup() { }  // Unrelated methods in one extension
}
```

### Extension Naming Consistency
```swift
// ✅ Good - Clear feature grouping
FileBrowserViewController+Toolbar.swift
FileBrowserViewController+Collection.swift
FileBrowserViewController+Outline.swift
FileBrowserViewController+Columns.swift
FileBrowserViewController+ContextMenu.swift
FileBrowserViewController+FileOperations.swift
FileBrowserViewController+StatusBar.swift
FileBrowserViewController+SelectionCoordinator.swift
FileBrowserViewController+NavigationCoordinator.swift

// ❌ Avoid
FileBrowserViewController-Toolbar.swift      // Use + not -
FileBrowserToolbarExtension.swift           // Type + Feature pattern
FileBrowserViewControllerToolbar.swift      // Confusing concatenation
```

---

## Safety Patterns

### Safe Array Access
**Pattern:** Use `.safe(at:)` extension

```swift
// ✅ Good
if let item = items.safe(at: index) {
    processItem(item)
}

guard let selectedItem = filteredItems.safe(at: row) else { return }

// ❌ Avoid
let item = items[index]  // Crash risk
if index < items.count {
    let item = items[index]  // Verbose
}
```

### Optional Chaining
Prefer optional chaining over forced unwrapping:

```swift
// ✅ Good
let count = rootItem?.children?.count ?? 0
if let children = fileItem?.children?.safe(at: index) { }

// ❌ Avoid
let count = rootItem!.children!.count  // Crash risk
let children = fileItem?.children![index]
```

### Implicitly Unwrapped Optionals (IUOs)
**Avoid `var!` except for:**
1. **Storyboard/XIB outlets** (temporary until initialized)
2. **View controller lifecycle properties** created in `loadView()`

```swift
// ✅ Acceptable IUO usage
class FileBrowserViewController {
    var toolbarViewController: ToolbarViewController!  // Created in setupUI()
    var outlineView: NSOutlineView!                   // Created in setupUI()
}

// ✅ Better: Use lazy or optionals
class FileBrowserViewController {
    lazy var displayController = FileBrowserDisplayController(viewController: self)
    var collectionView: NSCollectionView?  // Optional, created on demand
}

// ❌ Avoid
var dataSource: FileBrowserDataSource!  // Use lazy initialization
var manager: FileOperationsManager!     // Use lazy initialization
```

### Guard Statements
Use `guard` for early returns:

```swift
// ✅ Good
func processItem(at index: Int) {
    guard let item = items.safe(at: index) else { return }
    guard item.isValid else { return }
    
    // Main logic here
}

// ❌ Avoid (nested ifs)
func processItem(at index: Int) {
    if let item = items.safe(at: index) {
        if item.isValid {
            // Main logic deeply nested
        }
    }
}
```

---

## Summary

### Key Takeaways

1. **Be Descriptive:** `navigationCoordinator` > `navCoord`
2. **Be Consistent:** Use established patterns within your domain
3. **Follow Swift Guidelines:** Apple's API design is the foundation
4. **Single Responsibility:** One coordinator = one clear purpose
5. **Safety First:** Use `.safe(at:)`, optional chaining, and `guard`
6. **Clear Extensions:** `Type+Feature.swift` for organization
7. **Meaningful Delegates:** Include source as first parameter
8. **Avoid IUOs:** Use `lazy var` or optionals instead

### Quick Reference

| Category | Pattern | Example |
|----------|---------|---------|
| View Controller | `<Feature>ViewController` | `FileBrowserViewController` |
| Coordinator | `<Feature><Responsibility>Coordinator` | `FileBrowserNavigationCoordinator` |
| Controller | `<Feature><Responsibility>Controller` | `FileBrowserDisplayController` |
| Manager | `<Feature>Manager` | `FileOperationsManager` |
| Extension | `<Type>+<Feature>.swift` | `FileBrowserViewController+Toolbar.swift` |
| Protocol | `<Type>Delegate` | `FileBrowserDelegate` |
| Boolean Property | `is/has/can/should<State>` | `isLoading`, `canUndo` |
| Action Method | `<verb><Object>` | `refreshCurrentDirectory()` |
| Boolean Method | `is/has/can/should<State>()` | `isValidDestination()` |
| Delegate Method | `<source>Did/Will<Action>` | `toolbarDidRequestBack()` |

---

**Next Steps:**
- Review existing code against these guidelines
- Refactor inconsistencies during feature development
- Use this guide for all new code and code reviews
- Update guide as new patterns emerge
