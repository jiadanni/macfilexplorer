Features

[x]Divide the sidebar into three equal parts. Each section should occupy identical space.
[x]Zoom issues. Spacing and scale.
directory
[] Support for search in subdirectories
[] Filter by file type, size, date modified 
[] Columns View Mode - incomplete
[] Folder color and accent color not implemented. Apply button should be un-grayed out once a new color has been selected. 

[] Advanced Copy/Move Dialog: A dialog with a progress graph, transfer speed, pause button, and a detailed file queue.
[] app icon
[] export/import not implemented

[x]Copy/move files between split panes with drag & drop


[]No warning when destination has less free space

[]No comparison of total file sizes between panes
[]No "Available space: X / Required space: Y" indicator
[]No "Copy to other pane" quick action
[]No "Move to other pane" quick action

[]Storage Analyzer

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
