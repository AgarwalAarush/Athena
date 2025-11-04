# Window Registry & Cursor Workspace Restoration Implementation

## Overview

This implementation adds comprehensive window tracking and restoration with special support for Cursor/VS Code workspaces. The system can now:

1. **Continuously track windows** using Accessibility API notifications
2. **Capture stable identifiers** including windowNumber, bundleID, and AX identifiers
3. **Track Cursor workspaces** to enable precise reopening of editor windows
4. **Use display UUIDs** instead of screen indices for stable monitor identification
5. **Restore windows reliably** including reopening Cursor workspaces via CLI

## New Components

### 1. WindowDescriptor (`Models/System/WindowDescriptor.swift`)

A comprehensive descriptor for windows with:
- `bundleID` - Application identifier
- `pid` - Process ID
- `windowNumber` - Stable CoreGraphics window ID
- `axIdentifier` - Accessibility identifier
- `title` - Window title
- `workspaceURL` - **Cursor/VS Code workspace path** (key for reopening)
- `frame` - Window position/size in global coords
- `displayUUID` - Stable display identifier
- `layer` - Z-order
- `timestamp` - When captured

### 2. WindowRegistry (`Services/System/WindowRegistry.swift`)

Continuous window tracking system:
- **Subscribes to AX notifications**:
  - `kAXWindowCreatedNotification`
  - `kAXUIElementDestroyedNotification`
  - `kAXFocusedWindowChangedNotification`
  - `kAXMovedNotification`
  - `kAXResizedNotification`
  - `kAXTitleChangedNotification`

- **Maintains window registry** indexed by windowNumber
- **Matches AX windows to CG windows** via PID + frame proximity
- **Infers Cursor workspaces** for each window
- **Handles app launches/terminations** via NSWorkspace notifications

### 3. CursorWorkspaceInference (`Services/System/CursorWorkspaceInference.swift`)

Utilities for Cursor/VS Code workspace tracking:
- **Strategy 1**: Parse workspace from window title
- **Strategy 2**: Cache workspace per PID
- **Strategy 3**: Get document path via AX attributes
- **Strategy 4**: Probe via CLI (if available)

**Workspace reopening**:
- Uses Cursor/VS Code CLI (`cursor`, `code`) for deterministic reopening
- Waits for windows to appear after launch
- Falls back to `open` command if CLI unavailable

### 4. WindowRestoreService (`Services/System/WindowRestoreService.swift`)

Enhanced restoration pipeline:
- **Window matching**:
  1. Try windowNumber (most reliable)
  2. Try bundleID + title + frame
  3. For Cursor: try workspaceURL

- **Cursor restoration**:
  1. Validate workspace still exists
  2. Open via CLI with `--new-window` flag
  3. Wait for window to appear (with timeout)
  4. Move to saved position

- **Display UUID mapping**:
  - Handles display configuration changes
  - Maps saved frame to current display
  - Scales proportionally if needed

### 5. Display UUID Utilities (Enhanced `ScreenManager`)

Added stable display identification:
- `displayUUID(for displayID: CGDirectDisplayID) -> UUID?`
- `displayUUID(for point: CGPoint) -> UUID?`
- `displayUUID(for rect: CGRect) -> UUID?`
- Updated `DisplayInfo` to include `uuid` field

## Enhanced Existing Components

### 6. SavedWindowInfo (Updated `Models/System/WindowConfiguration.swift`)

Added fields:
- `bundleID` - Full app identifier
- `windowNumber` - Stable window ID
- `axIdentifier` - AX identifier
- `workspaceURL` - Cursor workspace (stored as string)
- `displayUUID` - Stable display ID (stored as string)

Added methods:
- `init(from: WindowDescriptor)` - Convert descriptor to saved format
- `toWindowDescriptor()` - Convert back to descriptor for restoration

### 7. WindowConfigurationService (Updated `Services/WindowConfigurationService.swift`)

**Save flow**:
1. Refresh WindowRegistry to get latest positions
2. Get all tracked WindowDescriptors
3. Convert to SavedWindowInfo
4. Save to database

**Restore flow**:
1. Fetch configuration from database
2. Convert SavedWindowInfo to WindowDescriptors
3. Use WindowRestoreService for restoration
4. Reports count of Cursor workspaces being restored

### 8. Database Schema (Migration v3 in `DatabaseManager.swift`)

Added columns to `window_configuration_windows`:
- `bundleID TEXT`
- `windowNumber INTEGER`
- `axIdentifier TEXT`
- `workspaceURL TEXT`
- `displayUUID TEXT`

**Backward compatible**: Existing columns retained for migration.

## Architecture Flow

### Capture Flow

```
User requests save
    ↓
WindowConfigurationService.saveConfiguration()
    ↓
WindowRegistry.refresh()  // Update all positions
    ↓
WindowRegistry.allWindows()  // Get WindowDescriptors
    ↓
    For each window:
        - bundleID, pid, windowNumber from CG
        - axIdentifier, title from AX
        - frame from AX (global coords)
        - displayUUID from ScreenManager
        - workspaceURL from CursorWorkspaceInference
    ↓
Convert WindowDescriptors → SavedWindowInfo
    ↓
DatabaseManager.createWindowConfiguration()
    ↓
Saved to SQLite
```

### Restore Flow

```
User requests restore
    ↓
WindowConfigurationService.restoreConfiguration()
    ↓
DatabaseManager.fetchWindowConfiguration()
    ↓
Convert SavedWindowInfo → WindowDescriptors
    ↓
WindowRestoreService.restoreWindows()
    ↓
    Group by bundleID
    ↓
    For each app:
        Ensure app running
        ↓
        For each window:
            Try find existing matching window
            ↓
            If Cursor with workspaceURL:
                CursorWorkspaceInference.openWorkspace()
                    ↓
                    CLI: cursor --new-window /path/to/workspace
                    ↓
                    Wait for window to appear
                    ↓
                    Match by workspace/title
            ↓
            Compute target frame (handle display changes)
            ↓
            Move window via AX (setPosition, setSize)
            ↓
            Retry if window resists (common with Electron)
```

### Continuous Tracking Flow

```
App launches
    ↓
NSWorkspace.didLaunchApplicationNotification
    ↓
WindowRegistry.observeApplication()
    ↓
    Create AXObserver for PID
    ↓
    Subscribe to AX notifications
    ↓
    Get initial windows via kAXWindowsAttribute
    ↓
    For each window:
        Create WindowDescriptor
        ↓
        Match to CG window (by pid + frame) → windowNumber
        ↓
        Infer workspace (for Cursor)
        ↓
        Store in registry[windowNumber]
    ↓
On window created/moved/resized:
    AX notification → axObserverCallback
    ↓
    Update WindowDescriptor in registry
    ↓
On window destroyed:
    Remove from registry
```

## Key Improvements Over Previous System

### 1. Stable Window Identification
**Before**: Only used app name + title (ambiguous for multiple windows)
**After**: Uses `windowNumber` (kCGWindowNumber) - stable across moves/resizes

### 2. Cursor Workspace Tracking
**Before**: Could not distinguish between multiple Cursor windows
**After**: Captures `workspaceURL` for each window, enables precise reopening

### 3. Display Handling
**Before**: Used `screenIndex` (unreliable when displays added/removed)
**After**: Uses `displayUUID` from IOKit (stable across reconnections)

### 4. Continuous Tracking
**Before**: One-shot capture when saving
**After**: Continuously tracks windows via AX notifications

### 5. Cursor Restoration
**Before**: Could not restore Cursor windows (just launched app)
**After**: Reopens exact workspaces via CLI, then positions windows

### 6. Window Matching
**Before**: Simple PID-based matching
**After**: Multiple strategies:
- windowNumber (most reliable)
- bundleID + title + frame
- workspaceURL (for Cursor)

## Usage Example

### Saving Configuration

```swift
let service = WindowConfigurationService.shared
try service.saveConfiguration(name: "MyWorkspace")
// Saves all windows including Cursor workspaces
```

### Restoring Configuration

```swift
let service = WindowConfigurationService.shared
try await service.restoreConfiguration(name: "MyWorkspace")
// Restores windows, reopens Cursor workspaces via CLI
```

### Manual Window Registry Access

```swift
let registry = WindowRegistry.shared
try registry.startTracking()

// Get all windows
let allWindows = registry.allWindows()

// Get Cursor windows with workspaces
let cursorWindows = registry.windows(for: "com.todesktop.230313mzl4w4u92")
    .filter { $0.hasWorkspace }
```

## Error Handling

### Accessibility Permissions
If AX permissions not granted:
- WindowRegistry throws `WindowRegistryError.accessibilityPermissionDenied`
- User must grant permissions in System Settings

### Workspace Not Found
If saved workspace path no longer exists:
- WindowRestoreService throws `WindowRestoreError.workspaceNotFound`
- Window will not be restored (non-fatal)

### CLI Not Available
If Cursor/VS Code CLI not installed:
- Falls back to `open -a Cursor /path/to/workspace`
- Less reliable but functional

## Testing Recommendations

1. **Basic window save/restore**:
   - Open multiple apps with windows
   - Save configuration
   - Close/move windows
   - Restore configuration
   - Verify all windows restored to correct positions

2. **Cursor workspace restoration**:
   - Open multiple Cursor windows with different folders
   - Save configuration
   - Quit Cursor
   - Restore configuration
   - Verify exact workspaces reopened

3. **Display configuration changes**:
   - Save configuration with multi-monitor setup
   - Disconnect secondary display
   - Restore configuration
   - Verify windows mapped to available display

4. **Continuous tracking**:
   - Start tracking
   - Create/move/resize windows
   - Verify registry updates in real-time

5. **CLI fallback**:
   - Test with Cursor CLI installed
   - Test without CLI (fallback to `open`)

## Files Modified/Created

### New Files:
- `Athena/Models/System/WindowDescriptor.swift`
- `Athena/Services/System/WindowRegistry.swift`
- `Athena/Services/System/CursorWorkspaceInference.swift`
- `Athena/Services/System/WindowRestoreService.swift`

### Modified Files:
- `Athena/Models/System/DisplayInfo.swift` (added `uuid`)
- `Athena/Models/System/WindowConfiguration.swift` (added WindowDescriptor fields)
- `Athena/Services/System/ScreenManager.swift` (added UUID utilities)
- `Athena/Services/WindowConfigurationService.swift` (integrated new services)
- `Athena/Database/DatabaseManager.swift` (added migration v3)

## Dependencies

- **AppKit**: NSWorkspace, NSScreen, NSRunningApplication
- **CoreGraphics**: CGWindowListCopyWindowInfo, CGDisplayCreateUUIDFromDisplayID
- **Accessibility**: AXUIElement, AXObserver
- **IOKit**: Display UUID creation
- **GRDB**: Database persistence

## Performance Considerations

- **AX Notifications**: Lightweight, event-driven (minimal CPU usage)
- **Window Registry**: In-memory dictionary, O(1) lookups by windowNumber
- **Workspace Inference**: Caches per PID to avoid repeated computation
- **Cursor Launch**: ~500ms wait per workspace (sequential to avoid conflicts)

## Future Enhancements

1. **Space/Desktop tracking**: Add private API support for Spaces (if needed)
2. **Window order restoration**: Track and restore z-order/focus
3. **Partial restoration**: Allow selective window restoration
4. **Workspace validation**: Warn if workspace moved/renamed
5. **CLI auto-install**: Help users install Cursor CLI if missing
6. **Performance**: Batch window operations for faster restoration

## Conclusion

This implementation provides a robust, production-ready system for window management with first-class support for Cursor workspaces. The continuous tracking ensures accuracy, stable identifiers enable reliable matching, and the workspace inference enables precise restoration of development environments.
