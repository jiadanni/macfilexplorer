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

### Quick Start - Test Installation

**⚡ Easiest way (using provided script):**
```bash
# Clone the repository
git clone <repository-url>
cd macfilexplorer

# Run the automated build and test script
./build-and-test.sh
```

The script will:
- ✅ Verify Xcode installation
- 🔨 Build the app in Debug mode
- 🚀 Launch the app automatically
- 📋 Show a test checklist

**📝 Manual quick start:**

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd macfilexplorer
   ```

2. **Verify Xcode installation:**
   ```bash
   xcodebuild -version
   # Should show Xcode 15.0 or later
   ```

3. **Build and run immediately:**
   ```bash
   # Open in Xcode and run with one command
   open MacFileExplorer.xcodeproj
   # Then press Cmd+R in Xcode to build and run
   ```

   **OR** build from command line:
   ```bash
   xcodebuild -project MacFileExplorer.xcodeproj \
              -scheme MacFileExplorer \
              -configuration Debug \
              build
   ```

4. **Run the test build:**
   ```bash
   # The app is built in DerivedData, run it directly:
   open ~/Library/Developer/Xcode/DerivedData/MacFileExplorer-*/Build/Products/Debug/MacFileExplorer.app
   ```

### Full Build Instructions

#### Option 1: Using Xcode (Recommended for Development)

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd macfilexplorer
   ```

2. **Open the project in Xcode:**
   ```bash
   open MacFileExplorer.xcodeproj
   ```

3. **Configure build settings (if needed):**
   - Select "MacFileExplorer" project in the navigator
   - Select "MacFileExplorer" target
   - Under "Signing & Capabilities", select your development team (or leave as "Sign to Run Locally")

4. **Select build scheme:**
   - Click the scheme selector in the toolbar
   - Choose "MacFileExplorer > My Mac"

5. **Build and run:**
   - Press `Cmd + R` to build and run
   - Or use Product > Run from the menu
   - The app will launch automatically when the build completes

6. **For testing, you can also:**
   - Press `Cmd + B` to build without running
   - Press `Cmd + U` to run unit tests (if any)
   - Press `Shift + Cmd + K` to clean build folder

#### Option 2: Using Command Line

**For Debug Build (Development):**
```bash
# Build for testing/development
xcodebuild -project MacFileExplorer.xcodeproj \
           -scheme MacFileExplorer \
           -configuration Debug \
           clean build

# Find and run the app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/MacFileExplorer-*/Build/Products/Debug -name "MacFileExplorer.app" | head -n 1)
open "$APP_PATH"
```

**For Release Build (Production):**
```bash
# Build optimized release version
xcodebuild -project MacFileExplorer.xcodeproj \
           -scheme MacFileExplorer \
           -configuration Release \
           -derivedDataPath ./build \
           clean build

# The built application will be at:
# ./build/Build/Products/Release/MacFileExplorer.app
```

**Install to Applications folder:**
```bash
# Copy the release build to Applications
cp -r ./build/Build/Products/Release/MacFileExplorer.app /Applications/

# Launch from Applications
open /Applications/MacFileExplorer.app
```

#### Option 3: Quick Test Build Script

Create a test script for rapid building and testing:

```bash
#!/bin/bash
# save as build-and-test.sh

echo "Building MacFileExplorer..."
xcodebuild -project MacFileExplorer.xcodeproj \
           -scheme MacFileExplorer \
           -configuration Debug \
           -quiet \
           build

if [ $? -eq 0 ]; then
    echo "Build successful! Launching app..."
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/MacFileExplorer-*/Build/Products/Debug -name "MacFileExplorer.app" -print -quit)
    open "$APP_PATH"
else
    echo "Build failed!"
    exit 1
fi
```

Make it executable and run:
```bash
chmod +x build-and-test.sh
./build-and-test.sh
```

### Build Verification

After building, verify the app works correctly:

1. **Check app launches:**
   - The app window should appear
   - You should see your home directory files

2. **Test Windows Explorer list view:**
   - Verify 5 columns are visible: Name, Date Modified, Type, Size, Date Created
   - Click column headers - they should sort
   - Check for alternating row colors

3. **Test terminal panel:**
   - Press `Ctrl + `` - terminal panel should appear at bottom
   - Type `pwd` - should show current directory
   - Terminal should update when you navigate folders

4. **Test tabs:**
   - Press `Cmd + T` - new tab should open
   - Navigate to different directories in each tab

5. **Test folder colors:**
   - Select a folder
   - Press `Shift + Cmd + C`
   - Choose a color - folder icon should change color

### Installing for Daily Use

**⚡ Easiest way (using provided script):**
```bash
# Run the automated release build and install script
./install-release.sh
```

The script will:
- ✅ Build optimized Release version
- 📦 Show app size
- 📥 Optionally install to /Applications
- 🚀 Optionally launch the app

**📝 Manual installation:**

```bash
# Build release version
xcodebuild -project MacFileExplorer.xcodeproj \
           -scheme MacFileExplorer \
           -configuration Release \
           -derivedDataPath ./build \
           clean build

# Install to Applications
sudo cp -r ./build/Build/Products/Release/MacFileExplorer.app /Applications/

# Make it accessible
sudo xattr -cr /Applications/MacFileExplorer.app

# Launch
open /Applications/MacFileExplorer.app
```

**Add to Dock for quick access:**
- Right-click the app in the Dock while it's running
- Select Options > Keep in Dock

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
