# Outstanding Issues

This file is a placeholder index of outstanding issues and work items referenced by the documentation.

## High Priority
- FileCopyMoveDialog duplicate `isCancelled` variable — Risk: data corruption. File: MacFileExplorer/Sources/FileCopyMoveDialog.swift
- Terminal focus race condition (use of arbitrary sleep) — File: MacFileExplorer/Sources/SplitViewController.swift
- Preview pane triple state desynchronization — Files: FileBrowserPreviewPaneCoordinator.swift, FileBrowserViewController.swift, SettingsStore.swift

## Medium Priority
- Hidden files state split between `FileBrowserDataSource` and `SettingsStore`
- View mode race conditions during fast switching

## Notes
- These issues are documented in more detail in DESYNC_PATTERNS_ANALYSIS.md and WEEK_2_3_IMPLEMENTATION_PLAN.md
- To begin addressing critical bugs, create branch: `week2-3-ssot-refactor`

