# Dependency Injection Strategy for MacFileExplorer

## Recommended DI Style: **Constructor Injection with Protocol Abstraction**

### Why This Approach?

1. **Explicit dependencies** - Clear what each component needs
2. **Testability** - Easy to mock/stub in tests
3. **Type safety** - Compiler enforces contracts
4. **Swift-native** - No external DI framework needed
5. **Incremental adoption** - Can migrate gradually

---

## Singleton Classification & Migration Priority

### Category 1: MUST REPLACE (High Priority) 🔴

These are used in business logic and prevent testing:

#### `SettingsStore.shared`
- **Usage:** 40+ files
- **Problem:** Every component couples to global state
- **Solution:** Already has `SettingsStoreProtocol` ✅
- **Migration:**
  ```swift
  // Before
  class FileBrowserViewController {
      func loadSettings() {
          let showHidden = SettingsStore.shared.hiddenFilesState
      }
  }
  
  // After
  class FileBrowserViewController {
      private let settings: SettingsStoreProtocol
      
      init(settings: SettingsStoreProtocol = SettingsStore.shared) {
          self.settings = settings
      }
      
      func loadSettings() {
          let showHidden = settings.hiddenFilesState
      }
  }
  ```
- **Status:** Partially implemented (FileBrowserViewController already uses this pattern!)
- **Remaining:** ~35 files still use `.shared` directly

#### `ColorManager.shared`
- **Usage:** ~15 files
- **Problem:** Hard-codes color logic into views; itself depends on SettingsStore.shared
- **Solution:** Create `ColorManaging` protocol
- **Migration:**
  ```swift
  protocol ColorManaging {
      func setColor(_ color: NSColor, forFolderName name: String)
      func getColor(forFolderName name: String) -> NSColor?
      func getGlobalFolderColor() -> NSColor?
      func setGlobalFolderColor(_ color: NSColor?)
      func clearAllColors()
      func getFoldersWithCustomColors() -> [String]
  }
  
  final class ColorManager: ColorManaging {
      private let settings: SettingsStoreProtocol
      
      init(settings: SettingsStoreProtocol = SettingsStore.shared) {
          self.settings = settings
      }
      
      // Remove static shared, make it injectable
  }
  ```
- **Priority:** HIGH - Should be done after SettingsStore migration

#### `PendingSettings.shared`
- **Usage:** Settings window controllers
- **Problem:** Global mutable state for uncommitted changes
- **Better Design:** Pass as parameter to settings view controllers
- **Migration:**
  ```swift
  // Before
  class SettingsViewController {
      func applyChanges() {
          PendingSettings.shared.applyChanges()
      }
  }
  
  // After
  class SettingsViewController {
      private var pendingSettings: PendingSettings
      
      init(pendingSettings: PendingSettings = PendingSettings()) {
          self.pendingSettings = pendingSettings
      }
      
      func applyChanges() {
          pendingSettings.applyChanges()
      }
  }
  ```
- **Priority:** MEDIUM

---

### Category 2: CONSIDER REPLACING (Medium Priority) 🟡

These have state but are primarily coordinators:

#### `PermissionsManager.shared`
- **Usage:** ~15 files
- **Problem:** Manages security-scoped bookmarks with mutable state
- **Consideration:** This is more of an "app-level service" than business logic
- **Recommendation:** **Keep as singleton but add protocol**
  ```swift
  protocol PermissionsManaging: AnyObject {
      func addGrantedDirectory(_ url: URL)
      func hasAccess(to url: URL) -> Bool
      func startAccessingAllSecurityScoped()
      // ... etc
  }
  
  final class PermissionsManager: PermissionsManaging {
      static let shared = PermissionsManager()  // Keep singleton
      // But also allow injection for testing
  }
  ```
- **Rationale:** 
  - Single source of truth needed for security-scoped resources
  - Process-wide state (URL bookmarks must persist)
  - Rarely needs mocking (can use real filesystem in tests)
- **Priority:** LOW - Protocol extraction only

#### `ContextualPermissionManager.shared`
- **Usage:** ~5 files
- **Problem:** Shows permission dialogs
- **Consideration:** UI coordinator, not data layer
- **Recommendation:** **Keep as singleton**
- **Rationale:**
  - Stateless (no mutable state to manage)
  - Only shows dialogs
  - Not worth the injection overhead
- **Priority:** SKIP

---

### Category 3: KEEP AS SINGLETON ✅

These are truly application-level services:

#### `FileSystemMonitor` (if exists)
- **Rationale:** Single observer pattern for filesystem events
- **Keep as singleton:** One monitor per application is correct

#### `OperationMetricsManager.shared` (if exists)
- **Rationale:** Application-wide telemetry
- **Keep as singleton:** Central metrics collection point

#### `NSWorkspace.shared`, `FileManager.default`
- **System singletons:** Don't replace these

---

## Implementation Plan

### Phase 1: Protocol Extraction (Week 1)

Create protocols for services that need DI:

```swift
// MacFileExplorer/Sources/Core/Protocols/Services.swift

protocol SettingsManaging: AnyObject {
    // Already exists as SettingsStoreProtocol ✅
}

protocol ColorManaging: AnyObject {
    func setColor(_ color: NSColor, forFolderName name: String)
    func getColor(forFolderName name: String) -> NSColor?
    func getGlobalFolderColor() -> NSColor?
    func setGlobalFolderColor(_ color: NSColor?)
    func clearAllColors()
}

protocol PermissionsManaging: AnyObject {
    func addGrantedDirectory(_ url: URL)
    func hasAccess(to url: URL) -> Bool
    func checkFullDiskAccess() -> Bool
    // ... essential methods only
}
```

### Phase 2: Services Refactoring (Week 2)

Break ColorManager's SettingsStore dependency:

```swift
final class ColorManager: ColorManaging {
    private let settings: SettingsStoreProtocol
    
    // Remove static shared
    init(settings: SettingsStoreProtocol) {
        self.settings = settings
    }
    
    func setColor(_ color: NSColor, forFolderName name: String) {
        var stored = settings.folderColors
        stored[name] = color.toHex()
        settings.folderColors = stored
    }
    
    // ... implement protocol
}
```

### Phase 3: AppDelegate Service Container (Week 2)

Create lightweight service container in AppDelegate:

```swift
// AppDelegate.swift

class AppDelegate: NSObject, NSApplicationDelegate {
    
    // Service instances
    private let settings: SettingsStoreProtocol = SettingsStore.shared
    private lazy var colorManager: ColorManaging = ColorManager(settings: settings)
    private lazy var permissionsManager: PermissionsManaging = PermissionsManager.shared
    
    // Service factory
    func makeFileBrowserViewController() -> FileBrowserViewController {
        return FileBrowserViewController(
            settings: settings,
            colorManager: colorManager,
            permissionsManager: permissionsManager
        )
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // ... existing code ...
        
        let mainVC = makeFileBrowserViewController()
        // ... setup window with mainVC
    }
}
```

### Phase 4: View Controller Migration (Weeks 3-4)

Migrate view controllers one by one:

**Priority Order:**
1. ✅ `FileBrowserViewController` (already uses SettingsStoreProtocol!)
2. `ToolbarViewController`
3. `SidebarViewController`
4. `PreviewPaneViewController`
5. Settings view controllers (10+ files)
6. Storage analyzer views

**Pattern:**
```swift
class ToolbarViewController: NSViewController {
    private let settings: SettingsStoreProtocol
    private let colorManager: ColorManaging
    
    init(settings: SettingsStoreProtocol, colorManager: ColorManaging) {
        self.settings = settings
        self.colorManager = colorManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        // For XIB/Storyboard loading
        self.settings = SettingsStore.shared
        self.colorManager = ColorManager(settings: self.settings)
        super.init(coder: coder)
    }
}
```

### Phase 5: Model Layer Cleanup (Week 5)

Remove singleton dependencies from models:

```swift
// Before - FileItem.swift
var displayName: String {
    return displayName(showExtensions: SettingsStore.shared.showFileExtensions)
}

// After - Remove the convenience property, force explicit parameter
// (Already has displayName(showExtensions:) method ✅)
```

---

## Testing Strategy

### Mock Implementations

```swift
// MacFileExplorerTests/Mocks/MockSettingsStore.swift

class MockSettingsStore: SettingsStoreProtocol {
    var hiddenFilesState: Bool = false
    var showFileExtensions: Bool = true
    var defaultViewMode: ViewMode = .list
    // ... implement all properties with defaults
    
    // Track calls for assertions
    var setHiddenFilesCallCount = 0
}

// MacFileExplorerTests/Mocks/MockColorManager.swift

class MockColorManager: ColorManaging {
    var colors: [String: NSColor] = [:]
    var globalColor: NSColor?
    
    func setColor(_ color: NSColor, forFolderName name: String) {
        colors[name] = color
    }
    
    func getColor(forFolderName name: String) -> NSColor? {
        return colors[name]
    }
    
    // ... etc
}
```

### Test Example

```swift
// MacFileExplorerTests/FileBrowserViewControllerTests.swift

class FileBrowserViewControllerTests: XCTestCase {
    var sut: FileBrowserViewController!
    var mockSettings: MockSettingsStore!
    var mockColorManager: MockColorManager!
    
    override func setUp() {
        super.setUp()
        mockSettings = MockSettingsStore()
        mockColorManager = MockColorManager()
        
        sut = FileBrowserViewController(
            settings: mockSettings,
            colorManager: mockColorManager
        )
    }
    
    func testHiddenFilesToggle() {
        // Given
        mockSettings.hiddenFilesState = false
        
        // When
        sut.toggleHiddenFiles()
        
        // Then
        XCTAssertTrue(mockSettings.hiddenFilesState)
    }
}
```

---

## Migration Checklist

### Week 1: Foundation
- [ ] Create `ColorManaging` protocol
- [ ] Add `PermissionsManaging` protocol (optional)
- [ ] Document protocol contracts

### Week 2: Core Services
- [ ] Refactor `ColorManager` to accept settings via init
- [ ] Create AppDelegate service container
- [ ] Update `MainWindowController` to use factories

### Week 3: View Controllers (Batch 1)
- [ ] Migrate `ToolbarViewController`
- [ ] Migrate `SidebarViewController`  
- [ ] Migrate `StatusBarViewController`
- [ ] Write tests for each

### Week 4: View Controllers (Batch 2)
- [ ] Migrate `PreviewPaneViewController`
- [ ] Migrate `TabBarController`
- [ ] Migrate `SplitViewController`
- [ ] Write tests for each

### Week 5: Settings & Models
- [ ] Migrate all settings view controllers (10 files)
- [ ] Clean up `FileItem` singleton usage
- [ ] Remove `PendingSettings.shared` pattern

### Week 6: Testing & Cleanup
- [ ] Achieve 40% test coverage
- [ ] Remove all `.shared` usage from business logic
- [ ] Update documentation

---

## Anti-Patterns to Avoid

### ❌ Don't Use Service Locator
```swift
// BAD - Service locator hides dependencies
class ServiceLocator {
    static let shared = ServiceLocator()
    let settings = SettingsStore.shared
    let colorManager = ColorManager.shared
}

class MyVC {
    func foo() {
        let settings = ServiceLocator.shared.settings  // Hidden dependency!
    }
}
```

### ❌ Don't Overuse Property Injection
```swift
// BAD - Mutable dependencies
class MyVC {
    var settings: SettingsStoreProtocol?  // Can be nil! Can change!
}
```

### ✅ DO Use Constructor Injection
```swift
// GOOD - Immutable, explicit, guaranteed
class MyVC {
    private let settings: SettingsStoreProtocol
    
    init(settings: SettingsStoreProtocol) {
        self.settings = settings
    }
}
```

---

## Summary

**Replace these:**
- ✅ `SettingsStore.shared` → Constructor injection (already 20% done)
- 🔴 `ColorManager.shared` → Constructor injection with protocol
- 🟡 `PendingSettings.shared` → Constructor parameter

**Protocol-ize but keep singleton:**
- 🟡 `PermissionsManager.shared` → Add protocol, optional DI for tests

**Keep as-is:**
- ✅ `ContextualPermissionManager.shared` (stateless UI helper)
- ✅ `FileSystemMonitor.shared` (if exists)
- ✅ System singletons (`NSWorkspace`, `FileManager`)

**Estimated effort:** 4-6 weeks for complete migration

**ROI:** High - Testability increases dramatically, enables true unit testing
