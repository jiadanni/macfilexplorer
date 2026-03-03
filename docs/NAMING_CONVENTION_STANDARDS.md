# Naming Convention Standardization

## Overview
This document documents the standardization of naming conventions across the MacFileExplorer codebase, specifically focusing on protocol naming for communication patterns.

## Standard: Use "Delegate" Pattern

The project has standardized on the **Delegate** naming pattern for all protocol-based communication, following Swift and Apple's conventions.

### Rationale
- **Apple Standard**: UIViewController, UITableViewDelegate, URLSessionDelegate all use "Delegate" suffix
- **Swift Convention**: Standard library and frameworks use "Delegate" for observer/listener patterns
- **Clarity**: "Delegate" clearly indicates responsibility delegation rather than passive observation
- **Consistency**: Enables IDE autocomplete and developers' intuition

## Changes Made

### Protocol Naming Updates

| Before | After | File |
|--------|-------|------|
| `HiddenFilesVisibilityObserver` | `HiddenFilesVisibilityDelegate` | HiddenFilesVisibilityCoordinator.swift |
| `TerminalVisibilityObserver` | `TerminalVisibilityDelegate` | TerminalVisibilityCoordinator.swift |

### Property Updates

| Before | After | File |
|--------|-------|------|
| `weak var observer: HiddenFilesVisibilityObserver?` | `weak var delegate: HiddenFilesVisibilityDelegate?` | HiddenFilesVisibilityCoordinator.swift |
| `weak var observer: TerminalVisibilityObserver?` | `weak var delegate: TerminalVisibilityDelegate?` | TerminalVisibilityCoordinator.swift |

## Naming Guidelines

### For New Protocols

All new communication/observer protocols should follow this pattern:

```swift
// ✅ CORRECT
protocol FileOperationsDelegate: AnyObject {
    func fileOperationsDidComplete(_ manager: FileOperationsManager)
}

protocol NavigationDelegate: AnyObject {
    func navigationDidChange(to path: URL)
}

protocol SettingsStoreDelegate: AnyObject {
    func settingsStore(_ store: SettingsStore, accentColorDidChange: NSColor)
}

// ❌ AVOID
protocol FileOperationsObserver: AnyObject { }
protocol NavigationListener: AnyObject { }
protocol SettingsStoreWatcher: AnyObject { }
```

### Property Naming

When assigning delegates to properties, use consistent naming:

```swift
// ✅ CORRECT
class MyCoordinator {
    weak var delegate: MyDelegate?
    
    func notifyDelegate() {
        delegate?.something(didHappen: true)
    }
}

// ❌ AVOID
class MyCoordinator {
    weak var observer: MyObserver?
    weak var listener: MyListener?
    weak var handler: MyHandler?
}
```

### Method Naming in Delegate Protocols

Use past tense or "did" verbs for event notification:

```swift
// ✅ CORRECT - Past tense indicates event has occurred
protocol ViewControllerDelegate: AnyObject {
    func viewControllerDidLoad(_ viewController: UIViewController)
    func viewController(_ viewController: UIViewController, didSelectItemAt indexPath: IndexPath)
    func viewControllerDidBecomeActive(_ viewController: UIViewController)
}

// ❌ AVOID - Present tense suggests ongoing action
protocol ViewControllerDelegate: AnyObject {
    func viewControllerIsLoading(_ viewController: UIViewController)
    func viewControllerSelectItemAt(_ viewController: UIViewController, _ indexPath: IndexPath)
}
```

## Delegate Protocol Template

When creating new delegate protocols, use this template:

```swift
/// Delegate protocol for [Feature] changes/events
protocol [Feature]Delegate: AnyObject {
    /// Called when [specific event] occurs
    ///
    /// - Parameters:
    ///   - [owner]: The [Feature] instance that triggered the event
    ///   - [parameter]: Description of parameter
    func [owner]Did[Event](_ [owner]: [OwnerType], [parameter]: [ParameterType])
    
    /// Called when [another event] occurs
    func [owner]Did[AnotherEvent](_ [owner]: [OwnerType])
}

// Example:
protocol FileOperationsDelegate: AnyObject {
    /// Called when file operations complete
    func fileOperationsDidComplete(_ manager: FileOperationsManager)
    
    /// Called when an error occurs during operations
    func fileOperations(_ manager: FileOperationsManager, didFailWithError error: Error)
}
```

## Verification Checklist

When reviewing code or PRs:

- [ ] All communication protocols use "Delegate" suffix
- [ ] No "Observer", "Listener", "Watcher", or "Handler" protocols (unless specifically for handlers like click handlers)
- [ ] Delegate properties use `delegate` variable name
- [ ] Delegate methods use past tense ("did...") or descriptive verbs
- [ ] Weak reference to delegate (`weak var delegate:`)
- [ ] Proper AnyObject conformance for memory management

## Protocol Categories

### 1. Coordinator Delegates (Event Notification)
Used by coordinators to notify view controllers of state changes:

```swift
protocol HiddenFilesVisibilityDelegate: AnyObject {
    func hiddenFilesVisibilityDidChange(isVisible: Bool)
}
```

### 2. View Controller Delegates (Data/Action Requests)
Used by child view controllers to request actions from parents:

```swift
protocol FileOperationsManagerDelegate: AnyObject {
    func fileOperationsManager(_ manager: FileOperationsManager, 
                             didRequestPresentSheet viewController: NSViewController)
}
```

### 3. Data Source Delegates (Data Provision)
Used to provide data to views:

```swift
// Note: Swift typically uses DataSource suffix, but treat similarly
protocol FileBrowserDataSource: AnyObject {
    func numberOfItems(in view: NSView) -> Int
}
```

## Reference

- [Swift API Guidelines](https://swift.org/documentation/api-design-guidelines/#naming)
- [UIKit Delegate Patterns](https://developer.apple.com/documentation/uikit)
- [AppKit Delegate Patterns](https://developer.apple.com/documentation/appkit)
