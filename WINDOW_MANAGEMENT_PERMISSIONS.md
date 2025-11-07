# Window Management & Accessibility Permissions

## Overview

The window management and configuration system in Athena requires **Accessibility permissions** to manipulate windows on your Mac. This document explains how permissions are handled, what was implemented, and how to troubleshoot permission issues.

## What Permissions Are Needed

### Accessibility Permission
- **Purpose**: Required to move, resize, focus, and tile windows from other applications
- **System Location**: System Settings > Privacy & Security > Accessibility
- **When Requested**: Automatically when you first try to:
  - Restore a window configuration
  - Move/tile a window (e.g., "move Chrome to the left")
  - Focus a window

### Reading Window Information
- **No Special Permission Required**: Listing current windows and their positions uses CoreGraphics APIs that don't require accessibility permissions
- This means you can **save** window configurations without any special permissions
- You only need accessibility permissions when **restoring** or **manipulating** windows

## How Permission Requests Work

### Automatic Permission Flow
Following the same pattern as microphone/speech permissions in Athena:

1. **First Attempt**: When you try to restore a config or manipulate a window
2. **Permission Check**: Athena checks if accessibility permission is granted
3. **System Prompt**: If not granted, macOS shows the standard accessibility permission dialog
4. **Verification**: After the dialog, Athena checks again if permission was granted
5. **Error Message**: If denied, you'll see a clear error explaining how to grant permission

### Code Pattern (Similar to SpeechService)
```swift
// Check accessibility permission
guard service.hasAccessibilityPermission else {
    print("Accessibility permission not granted, requesting...")
    service.requestAccessibilityPermission()
    
    // Check again after requesting
    guard service.hasAccessibilityPermission else {
        print("Accessibility permission denied. Cannot manipulate window.")
        return
    }
}
```

## What Was Implemented

### 1. Info.plist Updates
Added the required usage description for accessibility:

```xml
<key>NSAppleEventsUsageDescription</key>
<string>Athena needs accessibility permissions to manage and position windows on your behalf.</string>
```

This description appears in the system permission dialog.

### 2. WindowConfigurationService Enhancements
Added permission management methods:

- `hasAccessibilityPermission: Bool` - Property to check current permission state
- `requestAccessibilityPermission() -> Bool` - Method to request permission with system prompt

### 3. Permission Checks in All Window Manipulation Operations

**Orchestrator Methods Updated:**
- `executeTileWindow()` - Checks permission before tiling windows
- `executeFocusWindow()` - Checks permission before focusing windows

**WindowConfigurationService Methods Updated:**
- `restoreConfiguration()` - Checks permission before restoring saved layouts

**SystemWindowManager Operations (Underlying):**
All these operations require accessibility permission:
- `moveWindow(pid:to:size:)` - Move/resize window
- `resizeWindow(pid:to:)` - Resize window
- `focusWindow(pid:)` - Bring window to front
- `tileWindow(pid:position:screen:)` - Tile to preset position

## User Experience

### When Permission is NOT Granted

**User says:** "Athena, open my Home configuration"

**What happens:**
1. System shows accessibility permission dialog
2. If user denies: Error logged, operation aborted
3. User sees: "Accessibility permission required to position windows. Please grant permission in System Settings..."

### When Permission IS Granted

**User says:** "Athena, move Chrome to the left side"

**What happens:**
1. Permission check passes silently
2. Chrome window moves immediately to left half
3. User sees: Operation completes smoothly

## Troubleshooting

### Permission Dialog Doesn't Appear
- This happens if the app is already in the Accessibility list (either granted or denied)
- Solution: Go to System Settings > Privacy & Security > Accessibility
- Find "Athena" in the list and toggle the permission

### Operations Fail After Granting Permission
- Try restarting Athena after granting permission
- Check that Athena appears in Accessibility list with checkmark enabled
- Check Console logs for specific error messages

### "App Not Responding" When Moving Windows
- Some apps protect their windows from external manipulation
- Athena includes retry logic and proper error handling
- Check that the app name matches (case-insensitive matching is supported)

## Security & Privacy

### What Athena Can Do With Accessibility Permission
- Read window positions and sizes
- Move and resize windows
- Focus (bring to front) windows
- Read window titles and application names

### What Athena CANNOT Do
- Read window contents or take screenshots (requires separate permission)
- Access data inside applications
- Perform keyboard/mouse input (not implemented)
- Control system-level UI elements

### Privacy Considerations
- All window manipulation happens locally on your Mac
- No window information is sent to AI providers
- Window configurations are stored in local SQLite database
- Accessibility permission can be revoked anytime in System Settings

## Testing Checklist

### Basic Permission Flow
- [ ] First-time restore configuration triggers permission dialog
- [ ] Denying permission shows clear error message
- [ ] Granting permission allows operation to proceed
- [ ] Permission persists across app restarts

### Save Configuration (No Permission Required)
- [ ] Can save window configuration without accessibility permission
- [ ] Saved configs include all visible windows
- [ ] Window positions are correctly captured

### Restore Configuration (Permission Required)
- [ ] Requests permission if not granted
- [ ] Launches missing applications
- [ ] Positions all windows correctly
- [ ] Handles errors gracefully

### Direct Window Manipulation (Permission Required)
- [ ] "Move Chrome to left" requests permission if needed
- [ ] Windows tile to correct positions
- [ ] Focus commands work properly
- [ ] Fuzzy app name matching works

## References

### Permission Pattern Based On
- `SpeechService.swift` - Microphone and speech recognition permission handling
- `EngineAudioInput.swift` - Permission verification before accessing hardware
- `WakeWordTranscriptionManager.swift` - Automatic permission requests

### Key Files Modified
- `Info.plist` - Added NSAppleEventsUsageDescription
- `WindowConfigurationService.swift` - Added permission checks
- `Orchestrator.swift` - Added permission checks to execution methods
- `AccessibilityManager.swift` - Already had permission methods (no changes needed)

## Future Enhancements

### Potential Improvements
1. **UI Indicator**: Show accessibility permission status in settings
2. **Detailed Errors**: Show which specific operation failed and why
3. **Retry Logic**: Automatically retry operations after permission granted
4. **Permission Guide**: In-app guide showing how to grant accessibility permission
5. **Partial Restore**: Continue restoring other windows even if one fails

### Not Planned
- Keyboard/mouse automation (security risk, not needed for current features)
- Screen recording permission (not needed for window management)
- System Events permission (accessibility covers our needs)

