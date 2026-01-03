# MacFileExplorer - Development Notes

## Window Resizing Fix for Start Tab

### Issue
The Start screen tab prevented horizontal window resizing due to inflexible constraints in the `FavoritesWidgetView`.

### Root Cause
The favorites widget used a horizontal stack view with `.fillEqually` distribution and fixed width constraints (100pt) on the folder cards. This created an inflexible layout that prevented the window from resizing horizontally.

### Solution
**File: `MacFileExplorer/Sources/FavoritesWidgetView.swift`**

1. **Changed stack distribution** (line 46):
   - FROM: `containerStack.distribution = .fillEqually`
   - TO: `containerStack.distribution = .fill`

2. **Removed fixed width constraints** on cards:
   - REMOVED: `card.widthAnchor.constraint(equalToConstant: 100)`
   - Cards now only have height constraint: `card.heightAnchor.constraint(equalToConstant: 100)`

3. **Set content hugging priority**:
   - Added: `card.setContentHuggingPriority(.defaultLow, for: .horizontal)`
   - This allows cards to resize flexibly with the window

### Additional Changes
**File: `MacFileExplorer/Sources/StartViewController.swift`**

1. **Added width constraint** to scroll view content (line 101):
   - `contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)`
   - Prevents horizontal scrolling while allowing window resize

2. **Set low content hugging priorities** (lines 56-57, 65-66):
   - On main view and scroll view for horizontal direction
   - Ensures views don't resist resizing

### Important Notes
- **DO NOT** use fixed width constraints on widgets or cards in the Start tab
- **DO NOT** use `.fillEqually` distribution on horizontal stacks containing widgets
- The `.fill` distribution with low hugging priority allows proper resizing
- Cards in FavoritesWidgetView should only constrain height, not width

### Additional Fix: StorageOverviewWidget
**File: `MacFileExplorer/Sources/StorageOverviewWidgetView.swift`**

The StorageOverviewWidget also prevented horizontal resizing due to label compression resistance:

1. **Set low compression resistance** on status labels:
   - Added: `statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)`
   - Applied to both placeholder view (line 58) and granted view (line 92)
   - Allows labels to shrink and wrap text when window resizes

### Testing
- Window should resize both horizontally and vertically on Start tab
- Full screen/maximize should work without crashes
- Cards should expand/contract naturally with window size
- All widgets (GettingStarted, Favorites, QuickActions, StorageOverview) allow resizing
