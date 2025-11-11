# MacFileExplorer Unit Tests

This directory contains unit tests for the MacFileExplorer application.

## Test Files

### FileItemTests.swift
Tests for the `FileItem` model class:
- Initialization of file and directory items
- Name and path extraction
- Directory detection
- Children loading for directories
- Icon retrieval
- File size and modification date
- Hidden file detection
- File type determination

### ColorManagerTests.swift
Tests for the `ColorManager` singleton:
- Shared instance pattern
- Setting and retrieving colors for URLs
- Removing colors
- Handling multiple colors
- Color persistence

### ModelTests.swift
Tests for model enums:
- ViewMode enum (all cases, raw values, initialization)
- SplitOrientation enum

### ToolbarViewControllerTests.swift
Tests for the `ToolbarViewController`:
- View controller initialization
- View size constraints
- Path updates
- View mode display updates
- Hidden files display updates
- Sort display updates

## Running Tests

### Option 1: Using Xcode
1. Open `MacFileExplorer.xcodeproj` in Xcode
2. Go to File → New → Target
3. Select "Unit Testing Bundle"
4. Name it "MacFileExplorerTests"
5. Add the test files from the `MacFileExplorerTests` directory
6. Run tests with ⌘U or Product → Test

### Option 2: Command Line (xcodebuild)
```bash
# Add test target to project first, then run:
xcodebuild test \
  -project MacFileExplorer.xcodeproj \
  -scheme MacFileExplorer \
  -destination 'platform=macOS'
```

### Option 3: Using the test script
```bash
./run-tests.sh
```

## Test Coverage

The current test suite covers:
- ✅ FileItem model (initialization, properties, children)
- ✅ ColorManager (singleton pattern, CRUD operations)
- ✅ ViewMode and SplitOrientation enums
- ✅ ToolbarViewController (basic functionality)

### Areas for Additional Testing
- FileBrowserViewController (view mode switching, file operations)
- SplitPaneViewController (split management, pane coordination)
- TabBarController (tab management)
- FileSystemMonitor (file system change detection)
- TerminalViewController (command execution, shell integration)

## Adding New Tests

1. Create a new test file in `MacFileExplorerTests/`
2. Import XCTest and `@testable import MacFileExplorer`
3. Create a class that inherits from `XCTestCase`
4. Add test methods (prefix with `test`)
5. Use XCTest assertions (XCTAssertEqual, XCTAssertTrue, etc.)

Example:
```swift
import XCTest
@testable import MacFileExplorer

class MyNewTests: XCTestCase {
    
    func testSomething() {
        // Arrange
        let value = 42
        
        // Act
        let result = value * 2
        
        // Assert
        XCTAssertEqual(result, 84)
    }
}
```

## Best Practices

- Use `setUpWithError()` and `tearDownWithError()` for setup/cleanup
- Create temporary files/directories for file system tests
- Always clean up test resources
- Test both success and failure cases
- Use descriptive test names
- One assertion concept per test method
- Avoid dependencies between tests
