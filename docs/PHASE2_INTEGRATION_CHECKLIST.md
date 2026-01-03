# FileBrowserViewController Integration Checklist - Phase 2

## Overview
This document tracks the integration of Phase 1 coordinators into FileBrowserViewController.

## Integration Tasks

### 1. Context Menu Coordinator Integration
- [ ] Add `contextMenuProvider: FileBrowserContextMenuProvider` property
- [ ] Initialize in `viewDidLoad()` 
- [ ] Implement `FileBrowserContextMenuDelegate` protocol
- [ ] Replace `createContextMenu()` with `contextMenuProvider.createContextMenu()`
- [ ] Replace `createHeaderColumnsMenu()` with `contextMenuProvider.createColumnVisibilityMenu()`
- [ ] Replace `toggleColumnVisibility()` with `contextMenuProvider.handleToggleColumn()`
- [ ] Remove extracted methods (~150 lines)

**Methods to remove:**
- `createContextMenu()` (lines 1350-1414) - 65 lines
- `createHeaderColumnsMenu()` (lines 1443-1461) - 19 lines
- `toggleColumnVisibility()` (lines 1465-1475) - 11 lines
- `resetColumnVisibility()` (lines 1477-1491) - 15 lines
- `applyColumnVisibility()` (lines 1493-1505) - 13 lines
- `menuNeedsUpdate()` (lines 1507-1580) - 74 lines
- **Total: 197 lines**

---

### 2. Preview Pane Coordinator Integration
- [ ] Add `previewPaneCoordinator: FileBrowserPreviewPaneCoordinator` property
- [ ] Initialize in `viewDidLoad()`
- [ ] Implement `FileBrowserPreviewPaneDelegate` protocol
- [ ] Replace `showPreviewPane()` with `previewPaneCoordinator.showPreviewPane()`
- [ ] Replace `hidePreviewPane()` with `previewPaneCoordinator.hidePreviewPane()`
- [ ] Replace `updatePreviewPane()` with `previewPaneCoordinator.updatePreviewPane()`
- [ ] Wire split view delegate to coordinator
- [ ] Remove extracted methods (~50 lines)

**Methods to remove:**
- `updatePreviewPane()` (lines 697-705) - 9 lines
- `showPreviewPane()` (lines 706-710) - 5 lines
- `hidePreviewPane()` (lines 711-715) - 5 lines
- **Total: 19 lines**

---

### 3. View Mode Coordinator Integration  
- [ ] Add `viewModeCoordinator: FileBrowserViewModeCoordinator` property
- [ ] Initialize in `viewDidLoad()`
- [ ] Implement `FileBrowserViewModeDelegate` protocol
- [ ] Replace view mode switching logic in `displayFiles()`
- [ ] Remove view mode constraint management code
- [ ] Remove extracted methods (~80 lines)

**Methods to remove/refactor:**
- View mode switching in `displayFiles()` (lines 716-830) - ~115 lines
- `updateZoomControlVisibility()` - part refactoring

---

### 4. Zoom Coordinator Integration
- [ ] Add `zoomCoordinator: FileBrowserZoomCoordinator` property
- [ ] Initialize in `viewDidLoad()`
- [ ] Implement `FileBrowserZoomDelegate` protocol
- [ ] Replace `setZoomLevel()` method
- [ ] Replace `zoomLevelDidChange()` method
- [ ] Remove extracted methods (~70 lines)

**Methods to remove:**
- `setZoomLevel()` (lines 1192-1196) - 5 lines
- `updateZoomControlVisibility()` (lines 1202-1232) - 31 lines
- `zoomLevelDidChange()` (lines 1235-1246) - 12 lines
- Zoom level property usage - scatter through file

---

### 5. Filter Coordinator Integration
- [ ] Add `filterCoordinator: FileBrowserFilterCoordinator` property
- [ ] Initialize in `viewDidLoad()`
- [ ] Implement `FileBrowserFilterDelegate` protocol
- [ ] Replace filter/search logic
- [ ] Update `dataSource.filterCriteria` to use coordinator
- [ ] Remove extracted methods (~100 lines)

**Methods to refactor:**
- Filter-related properties and methods throughout file
- Estimated extraction: 100-150 lines

---

### 6. Status Bar Manager Integration
- [ ] Add `statusBarManager: FileBrowserStatusBarManager` property
- [ ] Initialize in `viewDidLoad()`
- [ ] Implement `FileBrowserStatusBarDelegate` protocol
- [ ] Replace `updateStatusBar()` calls with coordinator method
- [ ] Remove extracted status bar logic (~40 lines)

---

## Expected Results

### Line Count Reduction
- **Current:** 2,111 lines
- **After Phase 2:** ~1,600-1,700 lines
- **Reduction:** 400-500 lines (~20-24%)

### Quality Improvements
- ✅ Context menu logic isolated and testable
- ✅ Preview pane lifecycle managed separately
- ✅ View mode switching decoupled
- ✅ Zoom controls isolated
- ✅ Filter/search logic separated
- ✅ Status bar management separated
- ✅ Main VC focused on coordination and view lifecycle

---

## Integration Order

1. **Status Bar Manager** (easiest) - ~40 lines
2. **Zoom Coordinator** - ~70 lines  
3. **Preview Pane Coordinator** - ~50 lines
4. **View Mode Coordinator** - ~80 lines
5. **Context Menu Coordinator** - ~197 lines
6. **Filter Coordinator** - ~100 lines (last due to complexity)

---

## Testing Strategy

### Per Coordinator
- [ ] Verify initialization succeeds
- [ ] Verify delegate callbacks work
- [ ] Verify state persistence works
- [ ] Build with zero warnings
- [ ] Run existing tests pass

### Integration
- [ ] All view modes switch correctly
- [ ] Context menus display properly
- [ ] Preview pane shows/hides
- [ ] Zoom controls function
- [ ] Filters apply correctly
- [ ] Status bar updates

### Regression
- [ ] Keyboard shortcuts still work
- [ ] Drag and drop still works
- [ ] Selection behavior unchanged
- [ ] Performance metrics comparable

---

## Commit Strategy

### Commit 1: Status Bar + Zoom
- Status bar manager integration
- Zoom coordinator integration
- Reduced VC by ~110 lines

### Commit 2: Preview Pane
- Preview pane coordinator integration
- Reduced VC by ~50 lines

### Commit 3: View Mode
- View mode coordinator integration
- Reduced VC by ~80 lines

### Commit 4: Context Menu
- Context menu provider integration
- Reduced VC by ~197 lines

### Commit 5: Filter
- Filter coordinator integration
- Reduced VC by ~100 lines
- Might require additional method extraction

---

## Notes

### Tricky Integrations
1. **View Mode Switching:** Currently spread across `displayFiles()` - need to extract constraint logic
2. **Zoom Level:** Used in multiple places - need property wrapper or observer pattern
3. **Context Menu:** Requires `NSMenuDelegate` - coordinator already implements it
4. **Filter Criteria:** Used by datasource - need observer or delegation pattern

### Potential Complications
- Some methods might have multiple responsibilities
- Constraint management might need additional refactoring
- May discover circular dependencies that need resolution
- Thread safety considerations for shared properties

---

## Success Criteria

✅ All coordinators properly integrated
✅ Main ViewController <1,700 lines
✅ Build succeeds with 0 warnings
✅ All tests pass
✅ No regression in functionality
✅ Clear separation of concerns
✅ Each coordinator is independently testable
