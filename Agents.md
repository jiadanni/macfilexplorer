# 🤖 AI Agent Guide: MacFileExplorer

This project is a native macOS file explorer built with **Swift** and **AppKit**. This guide helps AI assistants understand the codebase architecture and development workflows to provide high-quality contributions.

## 🏗️ Architecture & Core Principles

- **Modular Organization**: The project is organized into functional modules within `Sources/`:
    - `App/`: Core application lifecycle (`AppDelegate`) and the main window.
    - `Core/`: Business logic, models (`FileItem`), and shared services (`FileSystemMonitor`, `ColorManager`, `FileOperationsManager`).
    - `FileBrowser/`: The main browsing interface, using the **Coordinator pattern** to separate navigation, selection, and display logic.
    - `Settings/`: Modular preferences UI (Appearance, Terminal, Context Menu, etc.).
    - `StorageAnalyzer/`: Disk usage visualization feature.
    - `Terminal/`: Integrated terminal functionality and settings.
    - `Preview/`: File preview panel logic.
    - `Sidebar/`: Sidebar navigation and favorites.
- **Pure Code UI**: While the project uses some XIBs for the main menu, prefer programmatic UI construction for new components to maintain modularity and consistency.
- **Coordinator Pattern**: Complex UI logic in the file browser is delegated to specialized coordinators (e.g., `FileBrowserSelectionCoordinator`, `FileBrowserNavigationCoordinator`).
- **Service Integration**: Core functionalities like file system monitoring and color management are abstracted into reusable services.
- **Persistence**: Application settings and custom folder colors are persisted using `UserDefaults` via the `SettingsStore`.

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
- **Asset Management**: Place new icons or images in `Assets.xcassets`.
- **Documentation**: Maintain the `README.md` and this `Agents.md` when introducing significant architecture changes or new capabilities.

## 🗂️ Key Files & Entry Points

- `Sources/App/AppConfig.swift`: Global constants and app-wide configuration.
- `Sources/Core/Models/FileItem.swift`: Fundamental model for files and directories.
- `Sources/App/MainWindowController.swift`: Manages the primary window and high-level layout.
- `README.md`: Comprehensive user guide and feature overview.
