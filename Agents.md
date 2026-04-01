# 🤖 AI Agent Guide: MacFileExplorer

This project is a native macOS file explorer built with **Swift** and **AppKit**. This guide helps AI assistants understand the codebase architecture and development workflows to provide high-quality contributions.

## 🏗️ Architecture & Core Principles

- **Workspace Layout**: App source files live under `MacFileExplorer/Sources/`. Tests live under `MacFileExplorerTests/`. The repository root also contains scripts and the Xcode project.
- **Modular Organization**: The app is organized into functional modules within `MacFileExplorer/Sources/`:
    - `App/`: Core application lifecycle (`AppDelegate`) and the main window.
    - `Core/`: Business logic, models (`FileItem`), shared services, and persistence abstractions.
    - `FileBrowser/`: The main browsing interface, using the **Coordinator pattern** to separate navigation, selection, filtering, preview, and display logic.
    - `Settings/`: Modular preferences UI and shared settings components.
    - `StorageAnalyzer/`: Disk usage visualization and related settings/view controllers.
    - `Terminal/`: Integrated terminal functionality and terminal state handling.
    - `Preview/`: File preview handlers and preview panel logic.
    - `Sidebar/`, `Toolbar/`, `Start/`, `Utilities/`: Supporting app surfaces and shared helpers.
- **Pure Code UI**: While the project uses some XIBs for the main menu, prefer programmatic UI construction for new components to maintain modularity and consistency.
- **Coordinator Pattern**: Complex UI logic in the file browser is delegated to specialized coordinators (e.g., `FileBrowserSelectionCoordinator`, `FileBrowserNavigationCoordinator`).
- **Protocol-Driven Services**: Prefer testable protocols such as `SettingsStoreProtocol`, `PermissionsManaging`, and `ColorManaging` over hard-wiring concrete singletons in reusable logic.
- **Single Source of Truth**: Persisted UI state such as hidden files, preview pane state, and terminal visibility should live in dedicated coordinators or stores. Avoid duplicating that state across multiple controllers.
- **Persistence**: Application settings and custom folder colors are persisted using `UserDefaults` via `SettingsStore` and staged through `PendingSettings` where appropriate.

## 🛠️ Development Workflow

- **Requirements**: macOS 13.0+, Xcode 15.0+, Swift 5.9+.
- **Pre-flight Scripts**: The repository includes several helper scripts for project maintenance:
    - `./build-and-test.sh`: Quick build and launch in Debug mode.
    - `./run-tests.sh`: Executes the test suite.
    - `./install-release.sh`: Builds and optionally installs a release version.
    - Various `.rb` scripts for managing Xcode project membership (e.g., `add_file_to_project.rb`).

## 📝 Coding Standards for Agents

- **Naming**: Use descriptive camelCase names. Coordinators should end in `Coordinator`, services in `Service` or `Manager`.
- **UI Framework**: Use **AppKit** (NSView, NSViewController, etc.). Avoid SwiftUI unless a specific component requires it.
- **Concurrency**: Favor Swift's `async/await` for new asynchronous operations.
- **Dependency Injection**: For models, coordinators, handlers, and reusable controllers, prefer initializer or property injection with protocol types and default to shared singletons only at the boundary.
- **State Ownership**: If a feature already has a coordinator or store acting as SSOT, extend that owner rather than introducing parallel booleans or duplicated persistence logic in views/controllers.
- **Observers & Lifecycles**: When adding `NotificationCenter` or similar observers, remove them in `deinit` and use weak captures where closure-based observers are involved.
- **Security-Sensitive Areas**: Treat terminal commands, file operations, path handling, sandbox permissions, security-scoped bookmarks, and previews of untrusted files as security-sensitive. Avoid shell interpolation, validate paths explicitly, and cap expensive reads for previews.
- **Performance**: Reuse shared formatters and avoid repeated expensive object creation on hot UI paths such as file listing, previews, and storage analysis.
- **Asset Management**: Place new icons or images in `Assets.xcassets`.
- **Settings Scroll Views**: For scrollable settings panes, use a flipped document view (`SettingsContentView`) inside `NSScrollView`. Do not “scroll to top” with `(0, 0)` on a non-flipped document view because that lands at the bottom in AppKit.
- **Testing**: Run `./run-tests.sh` for coverage. It copies `MacFileExplorer/Sources/` and `MacFileExplorerTests/` into a temporary Swift package, so new source/test files must be compatible with that layout.
- **Documentation**: Maintain the `README.md` and this `Agents.md` when introducing significant architecture changes or new capabilities.

## 🗂️ Key Files & Entry Points

- `MacFileExplorer/Sources/App/AppConfig.swift`: Global constants and app-wide configuration.
- `MacFileExplorer/Sources/Core/Models/FileItem.swift`: Fundamental model for files and directories.
- `MacFileExplorer/Sources/Core/Storage/SettingsStoreProtocol.swift`: Primary settings abstraction for injection and testing.
- `MacFileExplorer/Sources/App/MainWindowController.swift`: Manages the primary window and high-level layout.
- `MacFileExplorer/Sources/FileBrowser/Coordinators/`: Main file browser state and behavior coordinators.
- `MacFileExplorer/Sources/TerminalViewController.swift`: PTY-backed terminal implementation and a security-sensitive code path.
- `README.md`: Comprehensive user guide and feature overview.
