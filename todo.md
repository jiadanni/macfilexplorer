Features

Dynamic Menu Item Titles
Change "Show Preview Pane" to "Hide Preview Pane" when it's visible
Same for "Show Hidden Files" → "Hide Hidden Files"
This provides better visual feedback about the current state

Toolbar Customization
Add toolbar items for common actions (preview pane toggle, view modes, etc.)
Allow users to customize which buttons appear in the toolbar
Quick Look Integration
Add spacebar Quick Look support like Finder (press space on selected file)
This is in addition to the preview pane
 
Search Functionality
Add a search bar to filter/find files in current directory
Support for search in subdirectories
Filter by file type, size, date modified
 

 Advanced filters: ❌ Not Implemented (0%)

❌ File type filters
❌ Size filters
❌ Date filters

 ************
File Tags Support
Read and display macOS file tags (color labels)
Allow adding/removing tags from context menu

Breadcrumb Navigation
Show current path as clickable breadcrumbs
Quick navigation to parent folders
*****

Favorites/Bookmarks
Quick access to frequently used folders
Custom folder bookmarks in sidebar

Dual Pane Operations
Copy/move files between split panes with drag & drop
Show size comparison when copying

What's NOT Implemented:
1. ❌ Cross-Pane Drag & Drop

Cannot drag files from one split pane to another split pane
Drag & drop only works within the same pane or to external destinations
No visual feedback when dragging between panes
2. ❌ Size Comparison When Copying

No display showing source vs destination size
No warning when destination has less free space
No comparison of total file sizes between panes
No "Available space: X / Required space: Y" indicator
3. ❌ Enhanced Dual Pane Features

No synchronized scrolling option
No "Copy to other pane" quick action
No "Move to other pane" quick action
No visual indication of active pane during drag operations

**********

Performance & Polish
File Operations Feedback
Progress indicators for copy/move/delete operations
Confirmation dialogs with file counts and sizes

⚠️ Partially Implemented (15%):

Advanced FileCopyMoveDialog exists but unused
Move To has progress but no confirmation
Paste has no confirmation or progress
❌ Not Implemented (5%):

Drag & drop progress indicators
Paste operation confirmation
***********

Keyboard Shortcuts
Add more keyboard shortcuts (arrow keys for navigation, Enter to open, etc.)
Show shortcuts in context menus (you have the setting but not implemented)

Recent Folders
Track recently visited folders
Add to sidebar or Go menu

Smart Sorting
Remember sort preferences per folder
Natural sorting for numbers in filenames


[x] Item preview On right side 
 Persistent Preview Pane: Make it a toggle-able panel (like in Windows File Explorer) that can be shown on the right or bottom of any view (List, Column, or your new dual-pane view).

High-quality image previews.

Video playback with a scrubber.

Key document metadata (PDF page count, image dimensions, audio bitrate).

Quick actions (Rotate, Markup, Trim for video) without needing to open a separate app.

A "mini" Storage Analyzer for the selected folder, showing its size and contents at a glance.


[x] Drag and Drop favourites
[x] auto expand project explorer - Implemented: expandToCurrentDirectory() in sidebar
[x] add setting export/import - Implemented in Advanced Settings
[x] Terminal close button - Implemented: Close (X) button in terminal header
[x] Columns View Mode - Implemented: Miller columns (Finder-style) view with NSBrowser
[x] implement Settings - 
Sections:
- General
File Extension
Warn on extension change
- Tabs
Restore on reopen
- Sidebar
Order 
Visibilty
- Terminal
Open by default
- Context menu
list hotkeys in context menu.
Toggle options on off
- Advanced
settings export


[] Advanced Copy/Move Dialog: A dialog with a progress graph, transfer speed, pause button, and a detailed file queue.
[x] delayed click and f2 to rename
[x] Indicate percentage on Zoom Slider.
[x] Context menu configuration. Ability to hide options - Implemented in Settings
[x] Easy Select/Checkboxes - Implemented with UserDefaults toggle
[x] Toolbar customization - Implemented: Settings to show/hide toolbar buttons
[x] View Options dialog - Implemented: Finder-style View Options with grouping, sorting, icon size, etc.
[x] Eject icon hover effect - Implemented: Circular background appears on hover
[x] Improved folder color picker - Implemented: Preset color palette with instant feedback (replaces confusing color well)
[]Storage Analyzer
[x] Color should not be folder-specific but an option within settings - Implemented: Global folder color in General settings
[] app icon

Bugs
[x] Google Drive folders are not displayed correctly. - Fixed: Auto-redirect to "My Drive"
[x] Length issues with file types. Issues with wrapping and formatting. - Fixed: Changed to byTruncatingTail
[x] Labels disappear below a certain zoom level - Fixed: Added zoom scaling with minimum font size
[x] add eject icon to disk - Fixed: Added eject button for removable drives in sidebar
[x] open with context menu is shown for folder - Fixed: Hidden for folders and multiple selections
[] get info opens finder - Working as intended (shows custom dialog)
[x] Add shift click - Already working (NSOutlineView/NSCollectionView built-in)
[x] Auto expand - project explorer - Implemented: expandToCurrentDirectory() in sidebar
[x] folder colour not applying - Fixed: Global folder color reload implemented
[x] implement escape key
[x] copy to... menu - Implemented with folder picker
[x] move to... menu - Implemented with folder picker

Done
[x] Cmd+X There is not a clear distinction made to indicate that it has been cut. - Implemented: Dimmed appearance (50% alpha)
[x] status bar with file info or free space if no file selected - Implemented
[x] SplitPane close - Implemented: Close button (X) in toolbar for split panes
[x] Allow resizing of sidebar sections - Already working (NSSplitView built-in)