# Calendar Permission Testing Guide

## What Was Changed

### 1. **CalendarService.swift** - Enhanced Authorization
- Added `requestAccessWithActivation()` method that temporarily switches the app to `.regular` activation policy
- Added `hasReadAccess` property that correctly handles macOS 14+ authorization states (fullAccess, writeOnly, etc.)
- Added `authorizationStatusDescription` property for user-friendly status display
- Added `openCalendarPrivacySettings()` method to open System Preferences
- Added debug logging to verify Info.plist strings are loaded at runtime

### 2. **SettingsView.swift** - New Permissions Tab
- Added a new "Permissions" tab to Settings
- Created `PermissionsSettingsView` with:
  - Real-time calendar authorization status display
  - "Grant Access" button (appears when status is `.notDetermined`)
  - "Open System Settings" button (appears when status is `.denied`)
  - "Upgrade to Full Access" button (appears when status is `.writeOnly` on macOS 14+)
  - Status indicator (green/orange/red/gray) showing current state
  - Privacy information card

## How the Fix Works

### The Problem
macOS menu-bar/accessory apps (`LSUIElement=1` or `.accessory` activation policy) **cannot show TCC permission dialogs**. The system requires apps to be "foreground" apps to display these security prompts.

### The Solution
When the user clicks "Grant Access" in Settings:
1. App switches to `.regular` activation policy (becomes a regular app)
2. App activates to foreground
3. Calendar access is requested → **system dialog appears**
4. After user responds, app reverts to `.accessory` policy (back to menu-bar mode)

## Testing Steps

### 1. Reset Calendar Permissions (if needed)
If you've already denied or granted access, reset it first:
```bash
tccutil reset Calendar com.aarushagarwal.Athena
```

### 2. Launch Athena
Check the console for debug output:
```
📅 CalendarService initialized
NSCalendarsUsageDescription: Optional(Athena needs access to your calendar to display and manage events.)
NSCalendarsFullAccessUsageDescription: Optional(Athena needs full calendar access to read and display your events.)
```

If these are `nil`, there's a problem with your Info.plist.

### 3. Open Settings → Permissions Tab
- You should see "Calendar Access" status as "Not Requested"
- Status indicator should be gray
- "Grant Access" button should be visible

### 4. Click "Grant Access"
Watch for these logs:
```
📅 Current authorization status: 0  (0 = notDetermined)
📅 Switching to .regular activation policy
📅 Requesting full access (macOS 14+)
📅 Access granted: true
📅 Reverting to .accessory activation policy
```

**The system calendar permission dialog should appear!**

### 5. Grant Permission
- Click "OK" or "Allow" in the system dialog
- You should see an alert: "Calendar access granted! You can now view and manage your events."
- Status should update to "Full Access" (macOS 14+) or "Authorized" (macOS 13-)
- Status indicator should turn green
- "Grant Access" button should disappear

### 6. Verify Calendar Access
- Go to the Calendar/Day view
- You should now see your calendar events loading

## Troubleshooting

### Dialog Still Not Appearing?

1. **Check Info.plist keys**:
   ```bash
   plutil -p Athena/Info.plist | grep Calendar
   ```
   Should show:
   - `NSCalendarsUsageDescription`
   - `NSCalendarsFullAccessUsageDescription`
   - `NSCalendarsWriteOnlyAccessUsageDescription`

2. **Check App Sandbox entitlements** (`Athena.entitlements`):
   ```xml
   <key>com.apple.security.personal-information.calendars</key>
   <true/>
   ```

3. **Clean build and reinstall**:
   ```bash
   # In Xcode: Product → Clean Build Folder (⇧⌘K)
   # Then rebuild and run
   ```

4. **Check if you're on macOS 14+ but permission shows "Write Only"**:
   - This means the app only has write access
   - Click "Upgrade to Full Access" to open System Settings
   - Manually change to "Full Access" in Privacy & Security → Calendars

### If You Accidentally Denied

1. Status will show "Denied" with a red indicator
2. Click "Open System Settings"
3. In System Settings → Privacy & Security → Calendars:
   - Find "Athena"
   - Toggle it on or select "Full Access" (macOS 14+)

## macOS Version Differences

### macOS 14+ (Sonoma and later)
- Three permission levels: **Full Access**, **Add Events Only** (write-only), **None**
- To **read** calendar events, you need **Full Access**
- Write-only cannot read events (useful for apps that only create events)

### macOS 13 and earlier
- Two permission levels: **Authorized** or **Not Authorized**
- Single authorization grants both read and write access

## Code Architecture Notes

### Why `requestAccessWithActivation()` instead of plain `requestAccess()`?

The original `requestAccess()` is kept as a private method for internal use. The public `requestAccessWithActivation()` wraps it with the activation policy dance. This:
- Maintains backward compatibility
- Provides explicit intent when calling from UI
- Separates concerns (permission request vs. permission request with UI handling)

### Why the 0.3s delay?

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
```

`setActivationPolicy()` and `activate()` are asynchronous under the hood. The small delay ensures the app is fully activated before showing the system dialog. Without it, the dialog might not appear.

### Why check `.notDetermined` before requesting?

```swift
guard currentStatus == .notDetermined else {
    completion(hasReadAccess, nil)
    return
}
```

- If already granted/denied, no need to show dialog again
- Avoids unnecessary activation policy switching
- Provides immediate feedback for already-determined states

## Next Steps

Once this works, you can:
1. Remove debug logging if you want (all the `print()` statements)
2. Add a similar permission UI for other privacy-sensitive features (e.g., Microphone in Speech settings)
3. Consider showing a "Grant Calendar Access" button in the Calendar view itself if not authorized



