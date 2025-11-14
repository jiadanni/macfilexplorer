Features


[] Item preview On right side 
Build a Superior, Persistent Preview Pane: Make it a toggle-able panel (like in Windows File Explorer) that can be shown on the right or bottom of any view (List, Column, or your new dual-pane view).

Make it Smarter: Your preview pane could show:

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
[] Indicate percentage on Zoom Slider.
[x] Context menu configuration. Ability to hide options - Implemented in Settings
[x] Easy Select/Checkboxes - Implemented with UserDefaults toggle
[x] Toolbar customization - Implemented: Settings to show/hide toolbar buttons
[x] View Options dialog - Implemented: Finder-style View Options with grouping, sorting, icon size, etc.
[x] Eject icon hover effect - Implemented: Circular background appears on hover
[]Storage Analyzer
[]Color should not be folder-specific but an option within settings.
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