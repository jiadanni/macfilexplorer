# ADR-001: Adoption of Coordinator Pattern and Single Source of Truth (SSOT)

## Status
Accepted

## Date
2026-01-02

## Context
The `MacFileExplorer` application was suffering from "Massive View Controller" syndrome, particularly in `FileBrowserViewController` and `SidebarViewController`. Navigation logic, state management, and UI configuration were tightly coupled, leading to:

1.  **State Inconsistency**: Multiple sources of truth for settings and navigation state (e.g., scattered `NotificationCenter` observers).
2.  **Poor Testability**: Difficult to isolate components for unit and UI testing due to hard dependencies.
3.  **Maintenance Friction**: Adding features required modifying large, monolithic files, increasing the risk of regression.

## Decision
We decided to adopt the **Coordinator Pattern** for navigation and responsibility isolation, and enforce **Single Source of Truth (SSOT)** for application state, specifically via a `SettingsStoreProtocol`.

### 1. Coordinator Pattern
We extracted distinct responsibilities from `FileBrowserViewController` into dedicated coordinators:

*   **`FileBrowserNavigationCoordinator`**: Manages directory navigation, history (back/forward), and path validation.
*   **`FileBrowserPreviewPaneCoordinator`**: Manages the lifecycle and visibility of the preview pane.
*   **`FileBrowserViewModeCoordinator`**: Handles switching between List, Icon, and Column views.
*   **`FileBrowserSelectionCoordinator`**: Manages file selection state.
*   **`HiddenFilesVisibilityCoordinator`**: Manages the visibility of hidden files.
*   **`FileBrowserFilterCoordinator`**: Handles search and filtering logic.
*   **`FileBrowserOutlineCoordinator`**: Manages `NSOutlineView` data source and delegate logic (List view).
*   **`FileBrowserCollectionCoordinator`**: Manages `NSCollectionView` logic (Icon and Windows List views).
*   **`FileBrowserColumnCoordinator`**: Manages `NSBrowser` logic (Column view).
*   **`FileBrowserInteractionCoordinator`**: Handles click tracking, double-clicks, and delayed renaming.
*   **`FileBrowserQuickLookCoordinator`**: Manages QuickLook preview panel integration.
*   **`FileBrowserStatusBarCoordinator`**: Manages status bar updates and zoom controls.
*   **`FileBrowserDragDropCoordinator`**: Handles root-level drag-and-drop operations.

### 2. Dependency Injection & SSOT
*   **`SettingsStoreProtocol`**: Defined a protocol for the settings store to allow dependency injection.
*   **`SettingsStoreDelegate`**: Replaced loose `NotificationCenter` observers with a type-safe delegate pattern for settings updates (e.g., accent color, show hidden files).
*   **Injection**: View Controllers (`FavoritesViewController`, `LocationsViewController`, `FolderOutlineViewController`, `FileBrowserViewController`) now accept a `SettingsStoreProtocol` in their initializers.

## Consequences

### Positive
*   **Separation of Concerns**: Each coordinator has a single, well-defined responsibility.
*   **Improved Testability**: Coordinators and the `SettingsStore` can be easily mocked.
*   **Type Safety**: Delegate pattern reduces reliance on string-typed Notifications.
*   **Modularity**: Child view controllers (e.g., in Sidebar) are now self-contained and reusable.

### Negative
*   **Boilerplate**: Requires creating more files and passing dependencies (Coordinator initialization).
*   **Indirection**: Logic is distributed, which may require jumping between files to follow the complete flow (though this is mitigated by clear naming).

## References
- `FileBrowserViewController.swift`
- `SettingsStore.swift`
- `SidebarViewController.swift`
