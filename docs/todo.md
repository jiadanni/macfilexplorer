Features
[]Copy/move files between split panes with drag & drop
[ ] Inconsistency in previews between folder and file
[] Folder color and accent color not working. Apply button should be un-grayed out once a new color has been selected. 
[x] Create help docs linked to it in menu for existing link  , open in new tab. 
Connect to Server creates the server in Finder and launches Finder. 
[] Zoom does not increase icon size only the label
[] Support for search in subdirectories
[] Auto expand to folder
[] Columns View Mode - incomplete
[] Advanced Copy/Move Dialog: A dialog with a progress graph, transfer speed, pause button, and a detailed file queue.
[] app icon
[] Permissions. 
[-] Display Folder size in the list view, if possible. 
[x] Google Drive folders are not displayed correctly. - Fixed: Added support for ~/Google Drive path detection


[x] Zoom slider should not be displayed for Application views that are not applicable

[x] Filter by file type, size, date modified 
[x] X button on top does not appear to be part of the tab
[x] toolbar and URL styling does not feel cohesive. Wanted to look seamless like Finder but acknowledge finder does not have the URL at the top

[x] hide preview pane button doesn't work, neither does the X. 

[x]No warning when destination has less free space
[x]No comparison of total file sizes between panes
[x]No "Available space: X / Required space: Y" indicator


[x] List view, columns should be configurable with right-click. Hide date created and tags by default hello. 
[x] Storage Analyzer


[x]Divide the sidebar into three equal parts. Each section should occupy identical space.
[x] export/import not implemented
[x] Status bar should be linked to the pane, one displayed for every pane. 
[x]No visual indication of active pane during drag operations
[x]Progress indicators for copy/move/delete operations
[x]Confirmation dialogs with file counts and sizes
[x]Advanced FileCopyMoveDialog exists but unused
[x]Move To has progress but no confirmation
[x] Paste has no confirmation or progress

[x] Add more keyboard shortcuts (arrow keys for navigation, Enter to open, etc.)
[x]Show shortcuts in context menus (you have the setting but not implemented)
[x]Remember sort preferences per folder
[x]Natural sorting for numbers in filenames
[x] Item preview On right side 
[x] Drag and Drop favourites
[x] auto expand project explorer - Implemented: expandToCurrentDirectory() in sidebar
[x] add setting export/import - Implemented in Advanced Settings
[x] Terminal close button - Implemented: Close (X) button in terminal header
[x] delayed click and f2 to rename
[x] Indicate percentage on Zoom Slider.
[x] Context menu configuration. Ability to hide options - Implemented in Settings
[x] Easy Select/Checkboxes - Implemented with UserDefaults toggle
[x] Toolbar customization - Implemented: Settings to show/hide toolbar buttons
[x] View Options dialog - Implemented: Finder-style View Options with grouping, sorting, icon size, etc.
[x] Eject icon hover effect - Implemented: Circular background appears on hover
[x] Improved folder color picker - Implemented: Preset color palette with instant feedback (replaces confusing color well)

[x] Color should not be folder-specific but an option within settings - Implemented: Global folder color in General settings


Bugs
[x] Google Drive folders are not displayed correctly. - Fixed: Auto-redirect to "My Drive"
[x] Length issues with file types. Issues with wrapping and formatting. - Fixed: Changed to byTruncatingTail
[x] Labels disappear below a certain zoom level - Fixed: Added zoom scaling with minimum font size
[x] add eject icon to disk - Fixed: Added eject button for removable drives in sidebar
[x] open with context menu is shown for folder - Fixed: Hidden for folders and multiple selections
[x] get info opens finder - Working as intended (shows custom dialog)
[x] Add shift click - Already working (NSOutlineView/NSCollectionView built-in)
[x] Auto expand - project explorer - Implemented: expandToCurrentDirectory() in sidebar
[x] folder colour not applying - Fixed: Global folder color reload implemented
[x] implement escape key
[x] copy to... menu - Implemented with folder picker
[x] move to... menu - Implemented with folder picker
[x] Cmd+X There is not a clear distinction made to indicate that it has been cut. - Implemented: Dimmed appearance (50% alpha)
[x] status bar with file info or free space if no file selected - Implemented
[x] SplitPane close - Implemented: Close button (X) in toolbar for split panes
[x] Allow resizing of sidebar sections - Already working (NSSplitView built-in)
[x]  Toolbar, tool tips. 
[x]Add toolbar items for common actions (preview pane toggle, view modes, etc.)
[x]Allow users to customize which buttons appear in the toolbar
[x]Quick Look Integration
[x]Dynamic Menu Item Titles
[x] Change "Show Preview Pane" to "Hide Preview Pane" when it's visible
[x] Same for "Show Hidden Files" → "Hide Hidden Files"
[x] No scroll in settings. Some text is cut off and not wrapped.
[x] Show more information in preview similar to Get Info. 
[x]Add a search bar to filter/find files in current 

****Unsure****
Read and display macOS file tags (color labels)
File Tags Support
Allow adding/removing tags from context menu
[]Track recently visited folders
[]Add to sidebar or Go menu
[]Favorites/Bookmarks
[]Quick access to frequently used folders
[]Custom folder bookmarks in sidebar
[]Show size comparison when copying
[]No display showing source vs destination size
[]No synchronized scrolling option
[] Metrics Panel: Add a new Settings section that shows logged file operation stats (total data moved, number of operations, average speeds).
[]No "Copy to other pane" quick action
[]No "Move to other pane" quick acti
[]Zoom doesn't apply to all views. 

# Start Page - Remaining Features & Enhancements

## ✅ Completed (MVP)

- [x] Design system (`StartDesignSystem.swift`)
- [x] Base widget class (`StartWidgetView.swift`)
- [x] Welcome widget with dismissal
- [x] Favorites/My Computer widget with placeholder folders
- [x] Quick Actions widget (New Folder, Terminal, Storage Analyzer, Eject)
- [x] Getting Started checklist with task tracking
- [x] Storage Overview widget with permission placeholders
- [x] Contextual Permission Manager
- [x] Main Start View Controller with widget coordination

## 🚧 Phase 2: Enhanced Widgets

### Recent Apps Widget
**File**: `RecentAppsWidgetView.swift`
- [ ] Use `NSWorkspace.shared.runningApplications` to show recently used apps
- [ ] Display app icons in a horizontal scrollable list
- [ ] Click to reveal app in Finder (if permissions granted)
- [ ] Show app name and last used time
- [ ] Limit to 8-10 most recent apps

### Quick Start Guide Widget
**File**: `QuickStartWidgetView.swift`
- [ ] Expandable/collapsible detailed guide
- [ ] Visual step-by-step walkthrough with icons
- [ ] Steps:
  - Pin Your Favorite Folders (with example)
  - Try Dual-Pane View (screenshot/animation)
  - Discover Storage Analyzer (feature highlight)
  - Customize Toolbar (link to settings)
- [ ] Progress dots showing which step user is on

## 🎨 Phase 3: Full-Featured Dashboard

### Recent Files Widget
**File**: `RecentFilesWidgetView.swift`
**Requirements**: File access permissions
- [ ] Track recently opened files across granted folders
- [ ] Use `NSMetadataQuery` for system-wide recent files
- [ ] Display file thumbnails (for images/documents)
- [ ] Show file name, size, last modified
- [ ] Quick actions: Open, Reveal, Quick Look
- [ ] Filter by file type (All, Documents, Images, etc.)

### Smart Folders Widget
**File**: `SmartFoldersWidgetView.swift`
- [ ] Predefined smart search queries
- [ ] User can pin/unpin searches
- [ ] Click to run search and show results in main browser
- [ ] Badge showing item count for each search
- [ ] Custom smart folder creation

### Enhanced Storage Widget
- [ ] Show live mini storage chart (pie chart)
- [ ] Category breakdown with percentages
- [ ] Click category to filter in Storage Analyzer
- [ ] Trend indicator (disk usage growing/shrinking)

### Live Favorites with Badges
- [ ] Show item count badge on each folder card
- [ ] Display "last modified" timestamp
- [ ] Show folder size (if accessible)
- [ ] Thumbnail preview of recent files in folder

## ⚙️ Phase 4: Customization & Settings

- [ ] Widget customization mode
- [ ] Settings integration panel
- [ ] Drag & drop widget reordering
- [ ] Show/hide individual widgets

## 🔔 Phase 5: Permission & Notification Enhancements

- [ ] Permission change notifications in PermissionsManager
- [ ] Visual permission guides with screenshots
- [ ] Auto-refresh on permission changes

## 🎬 Phase 6: Animations & Polish

- [ ] Staggered widget animations
- [ ] Dark mode support
- [ ] Empty state illustrations
- [ ] Loading skeletons

## 🧪 Phase 7: Testing & Quality

- [ ] Unit tests for widgets
- [ ] Integration tests
- [ ] Accessibility (VoiceOver, keyboard navigation)
- [ ] Performance optimization

See full details in this file for complete specifications.
