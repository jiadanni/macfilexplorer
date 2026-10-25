# MacFileExplorer — Security, Performance & Concepts Review

**Date:** 2026-10-25
**Method:** Static read-through of the Swift sources, entitlements, build settings, scripts, tests and `docs/`. The review environment was Linux, so **nothing was compiled, run or profiled**. Performance items are reasoning from the code, not measurements. Items marked **[verify on macOS]** depend on AppKit/Foundation behaviour I could not execute.
**Not covered in depth:** `Settings/` UI view controllers, `Start/` widgets, `Toolbar/`, `Sidebar/` rendering, `MainMenu.xib`, localisation files.

Severity: **High** = data loss, privilege/trust-boundary failure, or a feature that does not work · **Medium** = real defect with limited blast radius · **Low** = hardening / polish.

---

## Remediation status (added after the first fixes)

> The findings below describe the code **as reviewed**. A follow-up change set addressed most of them. **None of it has been compiled or run** (the work was done in a Linux environment without Swift/Xcode), so treat it as unverified until the new CI workflow (`.github/workflows/ci.yml`) and the added tests pass on macOS.

**Fixed:** S2 (bounded, regular-file-only text preview; single image source), S3 (password prompts are collected privately and never rendered/recorded; no history for input to running programs), S4 (per-session marker nonce, un-exported from child processes; managed `mfe-integration.zsh`; injected commands skip history), S5 + R5 (single allowlisted/type-checked `SettingsPortability`; `Data` exported as base64), S6 + R1 (POSIX-based copy: symlinks copied as links, broken links kept, `O_EXCL`, 0600/0700 until finished, `copyfile` metadata/xattrs/ACLs, partial-destination cleanup, errors instead of silent skips), S7 (file-URL-only pasteboard reads, favorites index check), S8 (file IDs captured at request time), S9 (pinned npm dep, no quarantine stripping), R2 (shared `FileDropTransfer`: honest cursor, validation, no overwrite, error sheet, ⌥/cross-volume copy), R3 (rename persists, conflict + extension-change checks), R4 (moving into the same folder is a no-op), R6 (keychain write checked before dropping the defaults copy), R7 (granted-folder containment), R9 (per-scan generation token, stateful pause control, inode-based cycle detection, mount-point exclusion, bounded cache, throttled progress, visible trash errors), R10 (cut marker constant), R11 (extended SGR colours, split-sequence buffering, partial writes, SIGHUP on close, validated shell, Ctrl-C/D/Z forwarding, multi-line paste flattening), P2/P3/P4/P7 (name-precomputed sorting, package skipping, strict date ordering, no directory pre-walk for moves, shared byte formatter, bounded sort-preference table, scrollback/history caps), C9 (CI, working SwiftLint config, regression tests for the above).

**Not done — needs a decision or a larger change:**
- **S1/C1** trust model: whether to stay unsandboxed (recommended) is a product decision; the dead sandbox-era code (`URLValidation`, bookmark/keychain paths, Camera/Mic rows) is still there. Removing files also needs Xcode-project edits.
- **C2** a single `FileOperationService` actor (the engines are now consistent in behaviour, but still separate).
- **C3** replacing the terminal with an emulator (e.g. SwiftTerm). Not fixed: Tab completion, full-screen TUI apps, and a proper controlling TTY for job control (Ctrl-C forwarding is best effort **[verify on macOS]**).
- **R8** live refresh via `FileSystemMonitor`: not wired in, because a reload resets list state and that needs interactive testing.
- **P1** output coalescing, **P5** analyzer double metadata fetch and whole-tree memory, **P6** main-thread `loadChildren` in the tree/column views, **C4** strict concurrency, **C6** undo, **C7/C8** settings model and localisation.
- Smaller: Get Info stub, paste clearing the cut before the operation finishes, folder-size feature has no caller, `isHidden` vs `.skipsHiddenFiles`, "Founder" strings (may be an intentional rename), `findDuplicates` heuristics.

---

## 0. Summary

The code is tidier than the docs make it sound (off-main directory loading with generation tokens, bounded history, `trashItem` for deletes, correct single-quote shell escaping, hardened runtime on). The problems are mostly **conceptual**: the app has a security story it does not actually implement, and the same file operation is implemented five different ways with different safety properties.

### Top 12 (in suggested fix order)

| # | Finding | Sev | Section |
|---|---|---|---|
| 1 | Default copy/move engine (`FileCopyMoveDialog`) can silently skip items and then **delete the source** on cross-volume moves; dereferences symlinks; drops metadata | High | R1 |
| 2 | Sidebar/outline drops show a **copy** cursor but **move** the files, bypassing all validation and error UI | High | R2 |
| 3 | **Rename never reaches the filesystem** (no commit code found) | High | R3 |
| 4 | App is **not sandboxed**, yet the permission layer, bookmarks, keychain storage and docs assume it is; `URLValidation` is never called | High | S1, C1 |
| 5 | Text preview trusts a cached size and reads unbounded: a FIFO or `symlink → /dev/zero` named `x.txt` hangs/exhausts the app on selection | High | S2 |
| 6 | Terminal records **password prompts** (typed visibly into an `NSTextView`) into recallable command history | Med | S3 |
| 7 | Terminal prompt/idle detection is forgeable by any program output → app types `cd …` into ssh/sudo/vim | Med | S4 |
| 8 | Settings import writes **any key** from a JSON file into `UserDefaults`; export can crash on `Data` values | Med | S5, R5 |
| 9 | Dropping/pasting a file into its own folder **renames it** (`name (1)`) instead of doing nothing | Med | R4 |
| 10 | Terminal: unbounded buffers + per-chunk main-actor hop; escape sequences split across 4 KB reads corrupt state | Med | P1, R11 |
| 11 | `FileItem` is heavy (3+ syscalls, 2 `NSLock`s per instance); storage analyzer builds one per file twice-over and caches whole trees forever | Med | P2, P5 |
| 12 | No CI, placeholder lint config, no tests for any of the above | Med | C9 |

---

## 1. Security

### S1 — App sandbox is off; the "sandbox-aware" permission layer is inert · High
- `Supporting Files/MacFileExplorer.entitlements:5-6` sets `com.apple.security.app-sandbox = false`. The `files.user-selected`, `files.downloads` and `bookmarks.app-scope` entitlements next to it have no effect without the sandbox.
- `PermissionsManager.isSandboxed()` (`PermissionsManager.swift:468`) keys off the `APP_SANDBOX_CONTAINER_ID` env var, so every branch behind it (`ensureAccess`, `startAccessingAllSecurityScoped`, bookmark migration, `URLValidation`'s `outOfScope`, `navigateToURL`'s grant check at `FileBrowserViewController.swift:527-531`) is dead in the shipped configuration.
- `docs/STRUCTURED_PROJECT_REVIEW_2026.md` lists "Security-First Design — proper sandbox awareness, security-scoped bookmarks" as a strength. In practice the only runtime boundary is macOS TCC.
- Consequence: everything the app parses (images, PDFs, media, text, file names) is parsed **in-process with full user privileges**. A memory-corruption bug in ImageIO/PDFKit/AVFoundation is a full user-level compromise, not a sandbox-contained one.
- **Fix:** decide (see C1). If staying unsandboxed (needed for the terminal and unrestricted browsing), render previews out of process (`QLPreviewView` / `QLThumbnailGenerator`), sign with Developer ID + notarize, and delete the dead layers.

### S2 — Preview can hang or exhaust the app via special files · High
`Preview/PreviewHandlers.swift:191-206` (`TextPreviewHandler`):
- The 1 MB cap is decided from `file.size`, which `FileItem.init` cached earlier from metadata. If `size <= 1 MB` it calls `String(contentsOf:encoding:)`, which is unbounded.
- A FIFO named `x.txt` (size 0) blocks the main thread forever at `open()`. A symlink `x.txt → /dev/zero` (or `/dev/urandom`) reads until memory is gone. Both can arrive inside an extracted archive.
- Same file also: a file that grows after listing bypasses the cap; non-UTF-8 text returns `nil` and renders a blank view with no message.
- `createView` runs on the main thread for every selection change (`PreviewPaneViewController.previewFile`), with no debounce or cancellation, so arrowing through a folder parses every file in turn.
- **Fix:** `open(O_RDONLY|O_NONBLOCK|O_NOFOLLOW)`, `fstat` → require regular file, then read at most N bytes from the fd; decode off-main; show a message for unsupported encodings.

Related, same handler file: `ImagePreviewHandler` opens the image **three times** (thumbnail at `:111`, metadata at `:85`, `attributesOfItem`) and decodes up to 4096 px on the main thread; `PDFDocument(url:)` (`:133`) loads synchronously on the main thread.

### S3 — Terminal stores passwords in command history · Medium
`TerminalViewController.swift:139` (`textView.isEditable = true`), `:218-223` (tty `ECHO` disabled, so the text view does local echo), `:932-943` (`insertNewline` appends **whatever was typed** to `commandHistory` and writes it to the shell).
When `sudo`/`ssh` prints `Password:`, the user types into the same text view. The password is displayed in clear text on screen, appended to `commandHistory`, and is recallable with ↑. There is no check of the tty's echo state.
- **Fix:** query `tcgetattr` on the master before recording history (ECHO off ⇒ don't record, don't render), or adopt a real terminal emulator (C3).

### S4 — Prompt/idle markers are forgeable → keystroke injection into foreground programs · Medium
- `applySemanticMarkers` (`:431-453`) sets `isAtPrompt = true` on **any** `ESC ] 133 ; B BEL` in the output stream, and `processOutput` (`:355`) treats the fixed string `MFE_SENTINEL_12345` (`:32`) as proof of a prompt. Any program output (`cat evil.txt`, a remote host over ssh, a build log) can emit these.
- `changeDirectory` (`:770-792`) then writes `cd -- '<path>'; printf "MFE_SENTINEL_12345\n"` into the PTY. If the real foreground process is `ssh`, `sudo`, `python`, `vim` or a remote shell, it receives that text as input: local path names leak to the remote side, and a remote shell executes it.
- Quoting itself is correct (`escapeShellArgument` `:755-768`, control characters rejected `:794-796`); the weakness is the trust placed in unauthenticated markers.
- Side effect: every sync also lands in the user's **real** `~/.zsh_history` (`default-terminal.zshrc:39-42`, `HISTFILE=~/.zsh_history`, `SHARE_HISTORY`).
- **Fix:** include a per-session random nonce in the markers (`133;B;<nonce>`) and ignore markers without it; run the cwd change through a shell function (`mfe_cd`) with `HIST_IGNORE_SPACE`/`fc -p`; or avoid typing into the PTY entirely (e.g. a `chpwd`/`precmd` hook that reads a private FIFO).

### S5 — Settings import accepts arbitrary keys and types · Medium
`Settings/SettingsWindowController.swift:324` and `Settings/AdvancedSettingsViewController.swift:272`: `for (key, value) in dict { settingsStore.setValue(value, forKey: key) }` with no allowlist and no type check.
A shared "settings.json" can overwrite `grantedDirectories` (the permission allow-list), `startupFolder`, `sidebarOrder`, **and any non-app defaults** such as `NSUserKeyEquivalents` (re-bind menu shortcuts) or `NSInitialToolTipDelay`. Wrong types silently fall back through `as? … ?? default`.
- **Fix:** accept only keys in `UserDefaults.Keys`, validate each value's type/range, show a diff before applying. Also de-duplicate the two copies (the Advanced one omits `SidebarFavorites` on export).

### S6 — Custom copy engine weakens file protections · Medium
`FileCopy/FileCopyMoveDialog.swift:559-617`
- Destination files are created with the default umask (`OutputStream(url:append:false)`, `:566`) and only get the source's permissions in a final `setAttributes` (`:615`); directories likewise (`:538` → `:553`). A `0600` private key copied into a shared folder is world-readable while it is being written.
- Extended attributes are not copied explicitly. If they are not carried by the `attributesOfItem`→`setAttributes` round-trip, **`com.apple.quarantine` is lost**, so a copy of a downloaded app is no longer Gatekeeper-checked. **[verify on macOS with `xattr -l`]**
- **Fix:** use `copyfile(3)` / `FileManager.copyItem` (see R1).

### S7 — Pasteboard/drag input is not constrained · Low
- Every `readObjects(forClasses:[NSURL.self], options:nil)` (`FileBrowserDragDropHandler.swift:29,54`, `FileBrowserSupportTypes.swift:153`, `FileBrowserContextMenuProvider.swift:326`, sidebar/outline handlers) accepts non-file URLs. `.path` of `https://x/etc/passwd` is `/etc/passwd`. Pass `[.urlReadingFileURLsOnly: true]`.
- `FavoritesViewController.swift:276-279`: secure unarchiving is used on read (good), but `favoriteItems[draggedRow]` is not bounds-checked, so a crafted pasteboard payload (or a stale index after the list changes) crashes the app.
- The archived `IndexSet` is written with `requiringSecureCoding: false` under the `.string` pasteboard type (`:258-260`); use a private type with secure coding so it cannot be dropped into text fields (including the terminal).

### S8 — Security helpers that are never used, and checks that cannot protect · Low (but misleading)
- `URLValidation.validateUserBrowsingURL` has **no callers**. `FileSystemHelpers.resolveSymlinkSafe` and `openSafeNoFollow` are only called from tests. `SecurityIntegrationTests` therefore test the helpers, not the app.
- `FileOperationsManager.execute` captures the file ID and re-validates it a few instructions later (`:178-188`, `:224`). That cannot detect replacement between *selection → confirmation dialog → execution*, which is the real window, and it is check-then-act anyway.
- `navigateToURL`'s `"/../"` check (`FileBrowserViewController.swift:522-526`) is cosmetic: the user may browse anywhere, and `resolvingSymlinksInPath()` collapses it afterwards.
- **Fix:** delete the dead helpers or wire them in; capture IDs at selection time; use `O_NOFOLLOW`/`openat` where it matters.

### S9 — Release/supply-chain hygiene · Low
- `install-release.sh` does `sudo rm -rf /Applications/MacFileExplorer.app` and `sudo xattr -cr` (strips quarantine) on an ad-hoc-signed local build (`DEVELOPMENT_TEAM = ""`). Fine for a dev loop, not a distribution path; no notarization step exists.
- `package.json` pulls `@utcp/code-mode@^1.0.5` into a Swift project with `package-lock.json` gitignored: unpinned, unreproducible, unused by the build. Remove or pin.
- `AppDelegate.swift:451-453` comment says http/https are rejected; the set allows `http`, `https`, `ftp`, `webdav` (plaintext). Align the comment and the list.

### S10 — Privacy footprint · Low
`UserDefaults` persists visited folder paths (`folderSortPreferences`, unbounded, never pruned), search history (50 terms), last filter criteria, and Google-Drive/favorites paths in plaintext plist. I found no "clear history" action. The terminal's `.zshrc` lives in a user-writable path executed on each start (same trust as `~/.zshrc`, but note it also replaces `ZDOTDIR`, so the user's own `.zshenv/.zprofile` are not read — a likely source of PATH surprises).

---

## 2. Data integrity & correctness

### R1 — Default copy/move engine is unsafe · High
`confirmCopyOperations` / `confirmMoveOperations` default to **true** (`SettingsStore.swift:410-418`), so by default every copy/move goes through `FileCopyMoveDialog`/`FileOperation`, not `FileManager`.
1. **Silent skip, then delete (`:535`, `:495`).** `processRecursively` does `guard fileExists(...) else { return }`. A broken symlink (or any entry `fileExists` rejects) is skipped without error, and for a cross-volume **move** the whole source is then `removeItem`'d. Those entries are lost.
2. **Symlinks are dereferenced (`:535-548`).** `fileExists` follows links, so a link to a directory is copied as a full directory tree (including targets outside the source), and a cycle (`loop → ..`) recurses until `ENAMETOOLONG`, leaving a deep partial tree.
3. **Metadata loss / no clone.** Stream copy defeats APFS `clonefile` and drops xattrs/ACLs/flags/tags unless the round-trip carries them. `setAttributes` with the full source attribute dict may throw (e.g. `ownerAccountID` for a different user on an external volume), aborting the whole operation *after* the data was copied **[verify on macOS]**.
4. **No verification** before deleting the source; partial destinations are only cleaned on cancel (`:498-501`), not on I/O error.
5. Minor: `outputStream.write` returning `0` loops forever (`:598-604`); `bytesRead % (10 * bufferSize) == 0` (`:609`) is never true, so the intended `Task.yield()` never runs; the first failure aborts all remaining items (`:503-504`) and skips the refresh callback.
- **Fix:** single operation service built on `copyfile(3)` with `COPYFILE_ALL | COPYFILE_CLONE | COPYFILE_NOFOLLOW_SRC` and a state callback for progress/cancel; same-volume move = `rename`; cross-volume move = copy → verify (size/`copyfile` result) → unlink; explicit symlink policy; per-item error collection and a summary.

### R2 — Sidebar/outline drops say "copy", do "move", and bypass everything · High
`FolderOutlineViewController.swift:268-271` returns `.copy` from `validateDrop`, then `acceptDrop` calls `FileManager.moveItem` (`:285`). Same pattern in `FavoritesViewController.swift:266 → :303` and `LocationsViewController.swift:323 → :341`. These handlers skip `isValidDestination`, confirmation, conflict handling and error UI (failures only `debugLog`, which is compiled out in release), and report `false` for the whole drop if any item failed even though earlier ones moved.
- **Fix:** route all three through the same operation service as the main browser; return the operation the service will actually perform.

### R3 — Rename is not wired to the filesystem · High (I found no code path)
`FileBrowserContextMenuProvider.swift:336-348`: `handleRename` only sets `textField.isEditable = true` and focuses it. There is no `controlTextDidEndEditing`, no text-field action/delegate in `FileBrowser/`, and no `moveItem`/`setResourceValue(.nameKey)` for renames anywhere. `FileBrowserDialogHelper.showRenameDialog` (with proper validation) has **no callers**. The `warnOnExtensionChange` setting is read by nothing outside Settings. The shim also passes a `FileItem` where `handleRename(_ sender: Any)` is expected, and `getOutlineView()` limits it to list mode.
Please confirm in the running app; if rename really is a no-op, it is the most visible functional gap.

### R4 — Moving/pasting into the item's own folder renames the item · Medium
Neither engine treats "destination == source's parent" as a no-op. `FileCopyMoveDialog.swift:474-481`: `fileExists(dest/name)` is true because it is the source itself, so with auto-rename on, `generateUniqueURL` yields `name (1)` and the move succeeds as a rename. `FileOperationsManager.execute` has the equivalent path (`moveItem(a→a)` throws "exists", then retries as `name 1`) **[verify on macOS]**. `isValidDestination` only rejects destination-inside-source.
Also: the two engines use different suffix styles (`name 1` vs `name (1)`).

### R5 — Settings export can crash the app · Medium
`SettingsWindowController.swift:294` and `AdvancedSettingsViewController.swift:244` call `JSONSerialization.data(withJSONObject:)` on raw `UserDefaults` values. `globalFolderColor` is stored as `Data` (`ColorManager.swift:72`), and `Data` is not JSON-serialisable: Foundation raises an Objective-C `NSInvalidArgumentException`, which Swift's `do/catch` cannot catch. **[verify on macOS: set a global folder colour, then Export]**
- **Fix:** check `JSONSerialization.isValidJSONObject`, or export via `PropertyListSerialization`, or build a typed `Codable` settings snapshot.

### R6 — Bookmark storage can destroy its only copy · Medium (sandbox-only)
`SettingsStore.swift:832-853`: legacy bookmarks are saved to the keychain with the result **ignored** (`_ = KeychainStore.saveData…`) and the `UserDefaults` copy is removed regardless; the setter does the same. If the keychain write fails (ad-hoc signature changes between builds, user denies the prompt, locked keychain), the bookmarks are gone. Bookmarks are not secrets; `UserDefaults` or a file in Application Support is sufficient.

### R7 — Sandbox-mode permission checks disagree · Medium (latent)
`PermissionsManager.hasGrantedDirectory` (`:240-249`) requires an **exact** path match, while `ensureAccess` (`:317-332`) uses prefix containment. Under a sandbox, `navigateToURL` (`FileBrowserViewController.swift:529`) would reject every subfolder of a granted folder.

### R8 — No live refresh: `FileSystemMonitor` is not used by the app · Medium
`FileSystemMonitor` is only referenced from `ColorManagerAndMonitorTests.swift`; no production code creates one. A recent commit ("Rebuild FileSystemMonitor on DispatchSource…") fixed a component the app never calls. If it is wired in later: a directory `O_EVTONLY` descriptor reports entry add/remove/rename, **not** content changes of files inside; there is no coalescing (a 10 000-file copy fires 10 000 callbacks); each monitor costs a file descriptor against the 256 soft limit and `init` silently degrades to no monitoring on `EMFILE`.

### R9 — Storage analyzer concurrency and logic · Medium
- `StorageAnalyzerEngine.swift:118`: the *new* task resets the shared `isCancelled` flag after `scanTask?.cancel()`; the old scan (which only checks the flag) can resume and run concurrently, publishing stale results to the delegate. Use a per-scan token.
- `ScanControl.wait()` (`:59-63`) suspends unconditionally because `pause()` keeps no state (`:47-49`). If `resume()`/`cancel()` runs before the scanner reaches `wait()`, the continuation is appended after `resumeAll()` and never resumed (lost wake-up).
- Cycle detection is path-string based (`:251`); with `followSymlinks` on, `loop → ..` produces ever-new paths and is bounded only by `maxRecursionDepth = 100`, so work grows exponentially with the number of such links. `FileSystemHelpers.fileID` (unused) is exactly the right tool.
- No volume-boundary check: scanning `/` crosses firmlinks, `/Volumes/*` and network mounts.
- `findDuplicates` matches on name + size only (`:371-381`); not wired to any UI today, but would be dangerous next to a "Move to Trash" action.
- Trash failures are only `debugLog`'d; success triggers a **full rescan**. "Show in Main Viewer" is a TODO that shows an informational alert. The window and tab controllers duplicate the same action code.

### R10 — Small defects
- `FileIconItem.swift:297` checks pasteboard type `com.macfileexplorer.cutOperation`; producers write `AppConfig.Pasteboard.cutMarkerType` = `com.macfileexplorer.cutMarker`, so cut items are never dimmed in icon view.
- `handlePaste` clears the pasteboard (`:333`) before the (possibly cancelled) operation finishes, so a cancelled cut cannot be retried.
- `handleGetInfo` is an empty stub; "Show in Finder" with no selection does nothing.
- User-facing strings say **"Founder"** (`ContextualPermissionManager.swift:24,58,93,95`).
- `PermissionType` (and the permissions settings pane built from it) lists Camera and Microphone, but nothing in the app requests or uses either.
- `FileItem.calculateFolderSize` (both variants) has no callers, and `sizeString` shows a folder size only when `size > 0`, so "Show folder sizes" can never display anything.
- `isHidden` is `name.hasPrefix(".")` while enumeration uses `.skipsHiddenFiles` (which honours the `UF_HIDDEN` flag): the two definitions disagree.

### R11 — Terminal behaviour gaps · Medium
- Only Return, ↑, ↓ and Tab are handled (`:932-968`). Tab sends `"\t"` **without** the text typed so far, so completion cannot work. There is no Ctrl-C/Ctrl-D/Esc/arrow forwarding, and cursor-control CSI sequences are stripped, so TUIs (the shipped `.zshrc` aliases `vi → vim`) are unusable.
- `Process` is used to spawn the shell on a PTY slave without `setsid`/`TIOCSCTTY`, so tty-generated signals (Ctrl-C) and job control probably do not work even if keys were forwarded **[verify on macOS]**. Shutdown sends SIGTERM to the shell only (`:659`); interactive shells commonly ignore it and children are not signalled.
- Escape sequences split across 4096-byte reads (`:304`) are mishandled: `stripControlSequences` discards an unterminated OSC to the end of the chunk and the remainder is printed as text; a split `133;B` is lost, leaving `isAtPrompt` stuck false and directory syncs deferred indefinitely.
- SGR parsing splits on `;` and ignores extended colour: `38;5;31` is read as codes `38`, `5`, `31` ⇒ red (`:509-536`); `22`, `39`, `49` are unhandled although `COLORTERM=truecolor` is advertised.
- `writeToShell` ignores `write`'s result (`:640-647`) on a non-blocking descriptor: partial writes/`EAGAIN` silently drop input.
- Pasted multi-line text executes line by line on one Return (`shouldChangeTextIn` only blocks a bare `"\n"`).

---

## 3. Performance (static analysis — profile before acting)

### P1 — Terminal output path · Medium
Unbounded `AsyncStream` (`:292`) plus one `await processOutput` main-actor hop per 4 KB read, each doing `replacingOccurrences`, `components(separatedBy:)`, a fresh `NSFont` per run (`:550`), a `textStorage.append` and `scrollToEndOfDocument`. `yes` or `cat big.log` will saturate the main thread. The text view has **no scrollback cap**, and `commandHistory` is unbounded.
- **Fix:** coalesce to ≤60 Hz, cache attribute dictionaries, bound buffer + scrollback, or use a purpose-built emulator view.

### P2 — `FileItem` per-item cost · Medium
`Core/Models/FileItem.swift`
- `init` (`:150-236`): `fileExists` (stat) + `resourceValues` for 8 keys (including `contentType` and `tagNames`, which are not cheap) + symlink resolution; it is a class with two `NSLock` objects (`:39`, `:76`) ⇒ 3+ allocations and several syscalls per file. The directory enumerator pre-fetches a *different* key set (`:374`), so most of that prefetch is wasted.
- Sorting recomputes `URL.lastPathComponent` inside the comparator (`:318`, `:387`).
- Recursive search (`:338-368`) creates a `FileItem` for **every** file under the root before filtering, does `fileURL.path.contains(fragment)` per entry, and lacks `.skipsPackageDescendants`.
- **Fix:** an immutable value-type listing entry built from one bulk call (`getattrlistbulk`/enumerator-prefetched keys); lazy tags/kind/owner; drop per-instance locks (immutable after load); filter during enumeration.

### P3 — Sorting on the main actor · Medium
`FileBrowserDataSource.swift:172` uses `localizedStandardCompare` (ICU) for every comparison; sorting by Kind (`:184`) calls `localizedTypeDescription` (Launch Services) lazily per item inside the comparator; the date comparators return `false` when either date is `nil` (`:178-181`), which is not a strict weak ordering. Precompute collation/kind keys off-main and sort stably.

### P4 — File operations do redundant work · Medium
- `FileOperationsManager.execute` walks every directory twice (`calculateDirectorySize`, `:201-205`) solely for the metrics log, even when the operation is an O(1) same-volume `rename`. `calculateDirectorySize` also skips hidden files (`FileItem.swift:539`) so sizes under-report, and double-counts hard links.
- `FileCopyMoveDialog` pre-enumerates the whole tree into `filesToProcess` (all URLs in memory) before starting.
- Stream copy forfeits APFS clones (R1).
- Progress is per item, not per byte, in the non-dialog path.

### P5 — Storage analyzer memory & scan cost · Medium
- Each entry gets `resourceValues` (`:297`) **and then** `FileItem(url:)` (`:315`) which stats it again with a different key set, then a `StorageItem` wrapper.
- The whole tree is retained as heavyweight nodes; `cacheStore` is a static, process-lifetime dictionary (`:104`) with no eviction or memory bound, and it hands out the live mutable tree.
- `itemsScanned % progressBatchSize == 0` (`:334`) is evaluated for directory entries too, where `itemsScanned` doesn't change, so while the count sits on a multiple of 100 (including 0 at the start), **each** directory entry fires an `await MainActor.run`.
- **Fix:** bulk attribute calls, aggregate tiny files into per-directory totals, LRU cache with a cost limit and snapshot (immutable) results, time-based progress.

### P6 — Main-thread directory loads in tree/column views · Medium
`FolderOutlineViewController.swift:34,120,264,293`, `FileBrowserOutlineCoordinator.swift:22,34`, `FileBrowserColumnCoordinator.swift:29` call `loadChildren` synchronously. Expanding a node on a network or cloud volume (the code special-cases Google Drive) blocks the UI. The main list path (`FileBrowserDataSource.loadData`) is correctly detached and generation-guarded — reuse it.

### P7 — Smaller items · Low
- `UserDefaults` hot paths: `folderSortPreferences` is read in full on each navigation and rewritten in full on each change; `FileItem.sizeString` reads `SettingsStore.shared` per row and uses `ByteCountFormatter.string(fromByteCount:…)` (allocates a formatter per call) although a shared formatter exists in `FileBrowserActionHelper`.
- `IconCache` keys every directory as `"dir"` (all folders share one icon; loses special-folder and custom icons) and keys extension-less files by full path, which will thrash the 512-entry `NSCache` in bin directories.
- `OperationMetricsManager.append` reads, decodes, appends, encodes and writes up to 200 records each operation, non-atomically across threads.
- Initial sort uses non-localised `caseInsensitiveCompare` (`FileItem.swift:318,387`), later sorts use localised compare ⇒ visible reorder and double sorting.

---

## 4. Concepts & architecture

### C1 — Pick a trust model and make code, entitlements and docs agree
Today: unsandboxed + hardened runtime + a 471-line permission manager, bookmarks, keychain storage, "contextual permission" copy and entitlements that only make sense sandboxed. A sandboxed build cannot host the integrated terminal or unrestricted browsing, so **unsandboxed + Developer ID + notarization** is the coherent choice. Then: remove bookmark/keychain/`isSandboxed` paths, `URLValidation` and the Camera/Mic rows; keep the Full-Disk-Access guidance; document honestly that TCC is the boundary; compensate with out-of-process previews (S1/S2).

### C2 — One operation engine, not five
Copy/move/delete/duplicate exist in: `FileOperationsManager.execute`, `FileOperation` (dialog), three direct `moveItem` drop handlers, `FileBrowserActionHelper.duplicate`, and two analyzer trash implementations. They differ on symlinks, conflicts, confirmation, errors, metrics and cancellation. Build one `FileOperationService` (actor) with a policy struct (conflict, symlink, metadata, verify), `NSProgress`-style reporting, cancellation, per-item results and an undo record; make the dialog and drop handlers thin clients. Also pass a `resultingItemURL` to `trashItem` (currently `nil`) so "Put Back"/undo is possible.

### C3 — The terminal is a heuristic state machine, not a terminal
Sentinel strings, suppress/timeout flags, `promptLocation` guessing and local echo are the root of S3, S4 and most of R11. Either embed an established emulator (e.g. SwiftTerm with `LocalProcess`, which handles PTY setup, VT parsing, selection, scrollback, raw keys) or reduce scope to "Open in Terminal.app/iTerm". If kept as is, add the nonce, echo-state check, bounded scrollback and chunk-boundary-safe parsing.

### C4 — Concurrency model is ad hoc
`SWIFT_VERSION = 5.9` with no strict-concurrency setting; a mix of `NSLock`-per-field, an `@Atomic` wrapper, detached tasks, `DispatchQueue`, and actors; mutable global hooks for DI (`FileItem.permissionsManager`, `PreviewHandlerSettings.store`); `FileItem` is a mutable reference type shared across threads (`hasLoadedChildren`, `size`, `_permissions`, `_owner` are written without locks while `_kind`/`children` have them). Suggested direction: immutable `Sendable` listing snapshots produced off-main, `@MainActor` view models, enable `SWIFT_STRICT_CONCURRENCY=complete` module-by-module, run tests under TSan.

### C5 — Dead and duplicated code crowds out live code
Unused: `URLValidation`, `FileSystemMonitor`, `resolveSymlinkSafe`, `openSafeNoFollow`, `showRenameDialog`, both `calculateFolderSize`, `findDuplicates`. Duplicated: settings import/export (×2), analyzer action handlers (×2: window and tab controllers), settings UI (`SettingsWindowController` vs `SettingsSplitPaneViewController`, the window and tab variants, each with its own button bar). `docs/` (16 files, several over 400 lines) contains status claims that no longer match the code (e.g. `OUTSTANDING_ISSUES.md` describes a kqueue monitor; the code uses `DispatchSource` and nothing calls it). Delete or archive; keep one short architecture doc that is true.

### C6 — Missing fundamentals for a file manager
No undo (Edit→Undo is wired to `undo:` but no `UndoManager` records file operations), no operation history UI, rename (R3), Get Info (stub), folder sizes (dead), live refresh (R8). These matter more to users than the visual redesign work in the recent commits.

### C7 — Settings sprawl
About 75 `UserDefaults.Keys` cases (plus ad-hoc string keys such as `SidebarFavorites`, `GlobalFolderColors`, `LastAsked_*`), a 946-line `SettingsStore`, a 495-line groups facade, a protocol, plus `PendingSettings` staging, and some keys with no consumer. A single `Codable` settings model with a schema version would make import/export, reset (which currently resets only `Keys.allCases`, not `SidebarFavorites`/`GlobalFolderColors`) and migration straightforward and safe (S5, R5).

### C8 — Localisation/consistency
`L10n.text` is used in some places while alerts and menus elsewhere are hard-coded English (`FileOperationsManager`, `AppDelegate` menus, analyzer alerts). Release builds hide all failures (`debugLog` only), so users get no feedback for several failure paths (R2, R9). Replace with `os.Logger` (privacy-annotated) plus user-visible error reporting.

### C9 — Process: build, test, CI
- No `.github/` workflows; nothing runs tests or lint on push.
- `run-tests.sh` copies sources into a temporary SwiftPM package and deletes `AppDelegate.swift`: it tests a different build graph from the Xcode target.
- `.swiftlint.yml` is the stock "Example" file; the custom rule is under `rule:` (SwiftLint expects `custom_rules:`) and its regex `!\s*as\s+` would not match `as!` anyway ⇒ effectively no lint config.
- 243 tests exist, mostly settings/coordinators (`SettingsStoreTests` 42, `TerminalViewControllerTests` 24). There are effectively **none** for: copy engine edge cases (symlinks, broken links, cross-volume), drag/drop and sidebar moves, rename, special-file previews, hostile settings import, terminal sequence splitting, same-folder move. Several monitor tests rely on `Thread.sleep`.
- **Fix:** GitHub Actions on a macOS runner (`xcodebuild test`, SwiftLint, warnings-as-errors); add Address/Thread Sanitizer test plans; add the missing test categories above (each of R1–R4 has a cheap temp-directory test); fuzz the OSC/CSI parser.

---

## 5. What is already good (keep)
- Hardened runtime enabled with no exception entitlements.
- No `Process`/`NSTask`/AppleScript outside the terminal; terminal path quoting is correct and rejects control characters.
- Deletes use `trashItem` (recoverable); name conflicts never overwrite silently.
- Directory loading for the main list is off-main with cancellation + generation guards; recursive search skips heavy trees and honours cancellation.
- Secure unarchiving (`unarchivedObject(ofClasses:)`) for in-app drag payloads; `debugLog` compiles out of release builds; navigation history is bounded; observers are removed in `deinit`.
- Connect-to-Server uses an allow-list of schemes and mounts asynchronously via NetFS (system handles credentials).

## 6. Suggested sequence
1. **Stop the bleeding (small, high value):** R2 (return `.move`, or better route through the service), R4 (no-op guard), R5 (`isValidJSONObject`), S2 (fd-based bounded read), S5 (allowlist), R10 cut-marker constant.
2. **Operation service (C2/R1):** `copyfile`-based engine + tests for symlinks, broken links, cross-volume, same-folder, name conflicts; route drops, paste, dialog and analyzer through it.
3. **Rename (R3)** and undo hooks.
4. **Decide trust model (C1)**; remove dead layers; move previews to Quick Look; fix docs.
5. **Terminal (C3/S3/S4/R11/P1):** adopt an emulator or apply the nonce/echo/bounded-buffer fixes.
6. **Performance pass (P2–P6)** with Instruments (Time Profiler, Allocations) on a 100 k-file folder and a full-disk analyzer scan.
7. **CI + lint + sanitizers (C9)** so the above stays fixed.
