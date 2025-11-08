# Mac File Explorer

A native macOS file explorer application built with Swift that combines the familiar Finder interface with powerful features like split-view tabs, an integrated terminal panel, and Windows Explorer-style list view with multiple columns.

## Features

### 📊 Windows Explorer-Style List View
- Multi-column list view with sortable headers
- Columns: Name, Date Modified, Type, Size, Date Created
- Click column headers to sort (ascending/descending)
- Visual sort indicators on column headers
- Resizable and reorderable columns
- Alternating row colors for better readability
- Right-aligned size column like Windows Explorer
- File type descriptions (e.g., "PDF Document", "JPEG Image")

### 📑 Split View with Tabs
- Multiple tabs for browsing different directories simultaneously
- Easy tab management with keyboard shortcuts
- Tab switching and navigation
- Each tab maintains its own browsing history

### 💻 Integrated Terminal Panel
- Built-in terminal that automatically tracks the current directory
- Toggle visibility with keyboard shortcut (Ctrl + `)
- Full command execution support
- Command history navigation (up/down arrows)
- Built-in commands: `ls`, `cd`, `pwd`, `clear`, `help`
- Execute any system command from within the app

### 🎨 Bulk Folder Color Customization
- Select multiple folders and change their colors at once
- Custom color picker integration
- Colors are preserved across app restarts
- Visual distinction for organized folder hierarchies

### 📁 File System Features
- Real-time directory monitoring and updates
- Navigate through folder hierarchies
- Double-click to open files and folders
- System file icons for all file types
- Hidden files are filtered out by default

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Building the Project

### Using Xcode

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd macfilexplorer
   ```

2. Open the project in Xcode:
   ```bash
   open MacFileExplorer.xcodeproj
   ```

3. Select the "MacFileExplorer" scheme and your target device (My Mac)

4. Build and run the project:
   - Press `Cmd + R` to build and run
   - Or use Product > Run from the menu

### Using Command Line

Build the project from the terminal:

```bash
xcodebuild -project MacFileExplorer.xcodeproj \
           -scheme MacFileExplorer \
           -configuration Release \
           -derivedDataPath ./build
```

The built application will be located at:
```
./build/Build/Products/Release/MacFileExplorer.app
```

## Usage

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd + T` | New Tab |
| `Cmd + W` | Close Tab |
| `Ctrl + `` | Toggle Terminal Panel |
| `Shift + Cmd + C` | Change Folder Colors |
| `Cmd + Q` | Quit Application |

### Navigation

- **Double-click** a folder to navigate into it
- **Double-click** a file to open it with the default application
- Use the **terminal** to navigate with `cd` commands
- The terminal automatically updates when you navigate in the file browser

### Changing Folder Colors

1. Select one or more folders in the file browser
2. Press `Shift + Cmd + C` or use View > Change Folder Colors...
3. Choose a color from the system color picker
4. The selected folders will display in the chosen color

## Project Structure

```
MacFileExplorer/
├── MacFileExplorer.xcodeproj/     # Xcode project file
│   └── project.pbxproj
├── MacFileExplorer/
│   ├── Sources/                   # Swift source files
│   │   ├── AppDelegate.swift                # App lifecycle management
│   │   ├── MainWindowController.swift       # Main window controller
│   │   ├── SplitViewController.swift        # Split view management
│   │   ├── TabBarController.swift           # Tab management
│   │   ├── FileBrowserViewController.swift  # File browsing UI
│   │   ├── TerminalViewController.swift     # Terminal integration
│   │   ├── FileItem.swift                   # File/folder model
│   │   ├── ColorManager.swift               # Folder color persistence
│   │   └── FileSystemMonitor.swift          # Real-time file monitoring
│   ├── Resources/                 # App resources
│   │   ├── Assets.xcassets/       # Asset catalog
│   │   └── MainMenu.xib           # Main menu definition
│   └── Supporting Files/          # Configuration files
│       ├── Info.plist             # App metadata
│       └── MacFileExplorer.entitlements  # Security entitlements
└── README.md                      # This file
```

## Architecture

### Component Overview

- **AppDelegate**: Manages application lifecycle and creates the main window
- **MainWindowController**: Controls the main application window
- **SplitViewController**: Manages the split between file browser and terminal
- **TabBarController**: Handles multiple browsing tabs
- **FileBrowserViewController**: Displays files and folders in a list view
- **TerminalViewController**: Provides terminal functionality
- **FileItem**: Model representing a file or folder
- **ColorManager**: Persists and retrieves custom folder colors
- **FileSystemMonitor**: Monitors directory changes in real-time

### Key Technologies

- **AppKit**: Native macOS UI framework
- **NSOutlineView**: Hierarchical file display
- **NSSplitView**: Split view layout management
- **NSTabView**: Tab management
- **Process**: Terminal command execution
- **DispatchSource**: File system monitoring
- **UserDefaults**: Color preferences persistence

## Customization

### Modifying the Terminal

Edit `TerminalViewController.swift` to:
- Add custom commands
- Change terminal appearance
- Modify command execution behavior

### Changing the UI Theme

Edit the color constants in:
- `FileBrowserViewController.swift` for the file browser
- `TerminalViewController.swift` for the terminal panel

### Adding New Features

The modular architecture makes it easy to extend:
- Add new view controllers to `SplitViewController`
- Extend `FileItem` for additional file metadata
- Implement new commands in `TerminalViewController`

## Security Considerations

The app requires certain entitlements to function:
- **File Access**: Read/write access to user-selected files
- **Apple Events**: For automation support
- **JIT**: Required for terminal process execution

The app is **not sandboxed** to allow full file system access and terminal functionality.

## Troubleshooting

### Build Errors

If you encounter build errors:
1. Clean the build folder: Product > Clean Build Folder (Shift + Cmd + K)
2. Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData`
3. Ensure you're using Xcode 15.0 or later
4. Verify your macOS deployment target is set to 13.0

### Terminal Not Working

If terminal commands fail:
1. Check that the app has necessary permissions
2. Verify that `/bin/bash` exists on your system
3. Check Console.app for error messages

### Folder Colors Not Persisting

If folder colors reset:
1. Check app has permission to write to UserDefaults
2. Verify the app isn't being terminated unexpectedly
3. Look for UserDefaults errors in Console.app

## Contributing

Contributions are welcome! Areas for improvement:
- Icon view mode (in addition to list view)
- Column view mode (like Finder)
- Search functionality
- File operations (copy, move, delete)
- Favorites/bookmarks sidebar
- Preview panel
- More terminal features (colors, custom shell selection)

## License

This project is open source and available under the MIT License.

## Acknowledgments

- Inspired by macOS Finder and KDE Dolphin
- Built with native Apple technologies
- Designed for macOS 13.0+
