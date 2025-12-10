# Communication & State Architecture

## Communication rules
- Use delegates for 1:1 parent→child (or owner→owned view controller) communication.
- Use `NotificationCenter` only for cross-tree/global events (theme change, permission revocation, app-wide setting changes). Add new notifications to `NotificationNames.swift` with a short comment explaining scope.
- Avoid direct controller references except for ownership (presented/pushed controllers or injected services).

## Current delegate surface (sampling)
- SplitViewControllerDelegate, SplitPaneViewControllerDelegate, TabBarControllerDelegate, FileBrowserDelegate, SidebarDelegate, TerminalViewControllerDelegate, ToolbarDelegate, StartViewControllerDelegate, StorageListViewDelegate, ViewOptionsDelegate.
- Action item: consolidate where multiple delegates overlap, and prefer a single delegate per VC.

## Refactor plan (incremental)
1) Normalize the File Browser stack: keep `FileBrowserViewController` as coordinator; push listing/filtering into `FileBrowserDataSource`, selection into `FileBrowserSelectionManager`, drag/drop into `FileBrowserDragDropHandler`, and context menus into `FileBrowserContextMenuProvider`.
2) Sidebar/Toolbar: split data/build vs. UI handling; keep one delegate to the parent.
3) Settings: break into category VCs with one coordinator and a single delegate up; drop notifications for parent→child traffic.
4) Notifications: audit `NotificationNames.swift`, keep only global events; migrate local interactions to delegates.

## State management
- Wrap UserDefaults access behind a `SettingsStore` (typed accessors, single source of truth).
- Consider an `AppState` owner (in AppDelegate/root coordinator) for shared runtime state to reduce singleton sprawl.
