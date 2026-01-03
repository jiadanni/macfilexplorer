12. TESTING RECOMMENDATIONS

Current Coverage: ~30% (needs improvement)

Critical Areas to Test

- **FileOperationsManager — copy/move/delete/rename**
  - Destination exists: overwrite, prompt, skip
  - File in use: lock detection, graceful retry or fail
  - Insufficient space: simulate low-disk conditions and ensure atomic failure handling
  - Permissions denied: user and system-level failures
  - Concurrent operations: parallel copy/move/delete on same/different targets
  - Cancelled operations: partial-copy cleanup and progress/state reporting
  - Path escaping: canonicalization to prevent traversal or duplication

- **FileItem — symlink resolution, lazy loading**
  - Circular symlinks: detect and avoid infinite recursion
  - Broken symlinks: surface as broken and avoid crashes
  - Permission denied when reading metadata or contents
  - Lazy loading race conditions: concurrent loads should be serialized or safely merged

- **FileBrowserViewController — view mode switching**
  - Switch modes during active data load and ensure UI remains consistent
  - Switch modes during file operations (copy/move/delete) and maintain proper progress display
  - Switch modes with empty directories — ensure empty-state handling is correct

- **PermissionsManager — access checks**
  - Subdirectory access checks inherit/deny correctly
  - Symlink access: ensure symlink resolution doesn't bypass permissions
  - Permission bypass attempts: test manipulated paths and canonicalization
  - Bookmark expiration and revoked access handling
  - Invalid and removed paths: graceful errors and recovery

- **Clipboard / Pasteboard**
  - Source validation: only accept supported types and verify origin
  - Malicious content: ensure pasted paths do not cause traversal attacks
  - Concurrent paste operations and paste-while-copy scenarios

Testing Strategy

- Unit tests (fast, deterministic)
  - Services and models: `FileItem`, `FileOperationsManager`, `SettingsStore`, `PermissionsManager`
  - Use temporary directories (`FileManager.default.temporaryDirectory`) and tear down cleanly
  - Mock external dependencies (UI, NSDocumentController, system dialogs)
  - Fail fast on resource errors and keep tests hermetic

- Integration tests (multi-component flows)
  - Coordinators: navigation, selection, preview, and operation coordinators together
  - Validate communication between view controllers and managers
  - Exercise common real-world flows (move + refresh, bulk delete + undo)

- UI tests (XCUITest)
  - Critical user flows: copy/paste/move/rename, view-mode switching, bookmark add/remove
  - Tests for dialogs, progress, and error handling
  - Use stable test accounts and test documents when possible

- Stress tests
  - Many files (10k+), deep directory trees, very large files (multi-GB) using mocked IO where practical
  - Measure memory, CPU, and responsiveness while performing batch operations

- Security tests
  - Symlink attacks: nested symlinks that point outside allowed directories
  - Path traversal attempts via crafted inputs (../ sequences, unicode tricks)
  - Permission bypass: revoked sandbox/bookmark edge cases

Test Cases (Quick Checklist)

- FileOperationsManager
  - [ ] Copy file where destination exists and user chooses overwrite
  - [ ] Move directory into one of its children (should be rejected)
  - [ ] Delete file in use (locked by another process)
  - [ ] Copy large file and cancel mid-transfer (verify cleanup)
  - [ ] Concurrent copy of same file to different destinations
  - [ ] Copy with insufficient disk space (simulate using disk images or mocks)

- FileItem
  - [ ] Resolve circular symlink (detect and mark)
  - [ ] Broken symlink representation
  - [ ] Concurrent `loadChildren()` calls do not race
  - [ ] Permission denied while reading attributes handled

- FileBrowserViewController
  - [ ] Switch view mode during directory load
  - [ ] Start a move operation and change view mode mid-operation
  - [ ] Open empty folder and ensure empty-state UI is shown

- PermissionsManager
  - [ ] Access to subdirectory allowed when parent is allowed
  - [ ] Symlink pointing outside access scope is blocked
  - [ ] Bookmark expiration is detected and surfaced

- Clipboard/Pasteboard
  - [ ] Paste with invalid data types is rejected
  - [ ] Paste with paths that attempt traversal is rejected
  - [ ] Simultaneous paste operations handled safely

Implementation Notes

- Existing tests: `MacFileExplorerTests` already contains many service-level tests (`FileOperationsManagerTests.swift`, `FileItemTests.swift`, `PermissionsManagerTests.swift`). Use them as templates to add new scenarios.

- Use these helpers/patterns repeatedly:
  - Create temporary sandbox folders per-test and delete them in `tearDownWithError()`
  - Use `XCTestExpectation` for async operations and timeouts
  - Inject mocks for `NSPasteboard`, `NSFileCoordinator`, and delegates
  - Use deterministic UUIDs or seeded randomness for reproducibility

CI and Coverage

- Add a CI job (GitHub Actions, Jenkins, or your CI of choice) to run the test suite on macOS runners.
  - Use `xcodebuild` with `-enableCodeCoverage YES` to collect coverage data
  - Convert coverage to Cobertura or Codecov format to upload to coverage tools
  - Fail CI if coverage drops below a target (e.g., 80%) or if new tests are not added for critical areas

- Example `xcodebuild` command for CI:

```bash
xcodebuild test -scheme MacFileExplorer -destination 'platform=macOS' -enableCodeCoverage YES
``` 

- Use `slather` or Xcode's `xccov` tools to extract and post coverage reports.

Prioritization (MVP first)

1. Add unit tests covering destination validation, path traversal, and overwrite behavior in `FileOperationsManager`.
2. Add symlink/circular symlink and broken symlink tests in `FileItem`.
3. Add a small set of XCUITests for copy/paste and view-mode switching.
4. Add integration coordinator tests for navigation + operations.
5. Add stress and security tests (can be lower priority but important for releases).

Next Steps (recommendations for you or I can implement)

- I can open a PR that adds the `TestCases` unit tests for `FileOperationsManager` and `FileItem` using existing test helpers.
- I can scaffold a basic GitHub Actions CI job that runs `xcodebuild test` and uploads coverage.
- I can add a small XCUITest that exercises copy/paste and mode switching.

If you want, tell me which of the next steps to start and I'll implement it.
