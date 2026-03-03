# SettingsStore Refactoring: Grouped Settings Pattern

## Overview
The `SettingsStore` class has been enhanced with organized property groups to improve code clarity and maintainability. Properties are now grouped into logical domains through nested `struct` extensions.

## Benefits

1. **Improved Organization**: Related settings are grouped logically
2. **Reduced Cognitive Load**: Easier to find related settings
3. **Better Encapsulation**: Groups can be validated/updated together
4. **Consistent API**: All groups follow the same pattern
5. **Future Extensibility**: Easy to add validation or computed properties to groups

## Available Setting Groups

### AppearanceSettings
Controls app visual appearance (colors, themes, zoom level)
```swift
let appearance = store.appearance
appearance.accentColor = NSColor.blue
appearance.zoomLevel = 1.2
let folderColor = appearance.globalFolderColor
```

### ViewSettings
File browser display and view options
```swift
let view = store.view
view.defaultViewMode = .list
view.hiddenFilesState = true
view.showFolderSizes = false
```

### FileOperationsSettings
Behavior for copy, move, delete operations
```swift
let operations = store.fileOperations
operations.autoRenameOnConflict = true
operations.confirmFileOperations = true
```

### UIVisibilitySettings
Controls which UI elements are visible
```swift
let ui = store.uiVisibility
ui.showStatusBar = true
ui.showHiddenFilesButton = true
ui.showStorageAnalyzerButton = true
```

### ContextMenuSettings
Customizes context menu items
```swift
let contextMenu = store.contextMenu
contextMenu.hideCopy = false
contextMenu.hideOpenWith = true
```

### SidebarSettings
Sidebar appearance and behavior
```swift
let sidebar = store.sidebar
sidebar.showFavorites = true
sidebar.expandSidebarToCurrentDirectory = false
sidebar.sidebarFavorites.append("/Users/Documents")
```

### GoMenuSettings
Controls menu items in the Go menu
```swift
let goMenu = store.goMenu
goMenu.showGoHome = true
goMenu.showGoDownloads = true
```

### StartPageSettings
Start page/onboarding related settings
```swift
let startPage = store.startPage
startPage.hasCompletedOnboarding = true
startPage.favoriteWidgetFolders = ["/Users/Documents"]
```

### WindowLayoutSettings
Window, pane, and layout settings
```swift
let layout = store.windowLayout
layout.terminalIsVisible = true
layout.previewPaneWidth = 350
layout.maximumPanes = 4
```

### TerminalSettings
Terminal-related preferences
```swift
let terminal = store.terminal
terminal.openTerminalByDefault = false
```

### OtherSettings
Miscellaneous settings that don't fit other groups
```swift
let other = store.other
other.enableEasySelect = true
other.filterCriteriaData = data
```

## Implementation Details

Each group is a `struct` that wraps the `SettingsStoreProtocol`:

```swift
struct AppearanceSettings {
    private let store: SettingsStoreProtocol
    
    var accentColor: NSColor? {
        get { store.accentColor }
        set { store.accentColor = newValue }
    }
    
    // ... more properties
}
```

Groups are lazy-loaded properties on the SettingsStore:

```swift
var appearance: AppearanceSettings {
    return AppearanceSettings(store: self)
}

var view: ViewSettings {
    return ViewSettings(store: self)
}
// ... etc
```

## Migration Guide

### Before (Flat API)
```swift
let store = SettingsStore.shared
store.accentColor = NSColor.blue
store.globalFolderColor = colorData
store.zoomLevel = 1.2
store.defaultViewMode = .list
store.showFolderSizes = false
```

### After (Grouped API)
```swift
let store = SettingsStore.shared
store.appearance.accentColor = NSColor.blue
store.appearance.globalFolderColor = colorData
store.appearance.zoomLevel = 1.2
store.view.defaultViewMode = .list
store.view.showFolderSizes = false
```

## Future Improvements

### Validation
Groups can add validation to prevent invalid state:

```swift
struct WindowLayoutSettings {
    var maximumPanes: Int {
        get { store.maximumPanes }
        set { 
            let validated = min(max(newValue, 1), 8)
            store.maximumPanes = validated 
        }
    }
}
```

### Nested Validation
Prevent conflicting settings:

```swift
extension WindowLayoutSettings {
    mutating func enableSplitView() {
        store.showSplitButtons = true
        if maximumPanes < 2 {
            maximumPanes = 2
        }
    }
}
```

### Settings Profiles
Groups make it easier to save/load entire profile sections:

```swift
func saveWindowLayout() -> [String: Any] {
    let layout = store.windowLayout
    return [
        "sidebarWidth": layout.sidebarFixedWidth,
        "terminalVisible": layout.terminalIsVisible,
        "previewWidth": layout.previewPaneWidth
    ]
}
```

## Backward Compatibility

Both APIs are supported:

```swift
// Old API still works
let old = SettingsStore.shared.accentColor

// New API also works
let new = SettingsStore.shared.appearance.accentColor
```

## Benefits Summary

| Aspect | Before | After |
|--------|--------|-------|
| Property count per group | 50+ mixed | 7-15 related |
| Discoverability | Hard to find related settings | Clear with autocomplete |
| Validation | Per-property | Group-level possible |
| Documentation | Long, flat list | Organized by domain |
| Testing | Mock entire store | Mock specific groups |
