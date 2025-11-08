# Permission Management System

## Overview

The Athena app uses a modular, protocol-based permission management system to handle various macOS permissions in a consistent and user-friendly way.

## Architecture

### Core Protocol: `PermissionManaging`

Located in `Services/Protocols/PermissionManaging.swift`, this protocol defines the standard interface for all permission managers:

```swift
@MainActor
protocol PermissionManaging {
    var authorizationStatus: PermissionStatus { get }
    var permissionDescription: String { get }
    func requestAuthorization() async -> PermissionRequestResult
    func openSystemSettings()
}
```

### Permission Managers

Each permission type has its own dedicated manager that conforms to `PermissionManaging`:

#### 1. ContactsPermissionManager
- **File**: `Services/Permissions/ContactsPermissionManager.swift`
- **Purpose**: Manages Contacts framework permissions
- **Usage**: Allows the app to look up contact information by name
- **System Settings**: Privacy & Security > Contacts

#### 2. MessagingPermissionManager
- **File**: `Services/Permissions/MessagingPermissionManager.swift`
- **Purpose**: Manages Apple Events (Automation) permissions for Messages app
- **Usage**: Enables automatic message sending via AppleScript
- **System Settings**: Privacy & Security > Automation

## Permission States

The system uses a unified `PermissionStatus` enum:

- `.notDetermined` - Permission has not been requested yet
- `.authorized` - Permission has been granted
- `.denied` - User explicitly denied permission
- `.restricted` - Permission is restricted by system policy

## User Interface Integration

### Settings View

The `PermissionsSettingsView` in `Views/Settings/SettingsView.swift` provides a unified interface for managing all permissions:

**Features:**
- **Status Indicators**: Color-coded circles (green = granted, red = denied, gray = not determined)
- **Smart Actions**: 
  - Shows "Grant Access" button when permission is `.notDetermined`
  - Shows "Open System Settings" button when permission is `.denied` or `.restricted`
- **Progress Indicators**: Loading states while requesting permissions
- **User Feedback**: Alert dialogs explaining the result of permission requests

### Component Structure

The settings view uses the reusable `PermissionSectionView` component:

```swift
PermissionSectionView(
    icon: "person.2",
    title: "Contacts Access",
    status: contactsStatus,
    statusColor: contactsStatusColor,
    isRequesting: isRequestingContacts
) {
    // Permission-specific actions
}
```

## Permission Request Flow

### 1. User Initiates Request
User clicks "Grant Access" button in Settings view

### 2. Permission Manager Handles Request
```swift
let result = await ContactsPermissionManager.shared.requestAuthorization()
```

### 3. System Prompt Appears
macOS displays native permission dialog

### 4. Result Handling
```swift
switch result {
case .granted:
    // Update UI, show success message
case .denied:
    // Show denial message, offer System Settings navigation
case .requiresSystemSettings:
    // Direct user to System Settings
case .error(let error):
    // Handle and display error
}
```

## Info.plist Configuration

Required usage descriptions are defined in `Info.plist`:

```xml
<key>NSContactsUsageDescription</key>
<string>Athena needs access to your contacts to send messages to people by name.</string>

<key>NSAppleEventsUsageDescription</key>
<string>Athena needs to control Messages to send messages automatically on your behalf.</string>
```

## Best Practices

### 1. Request Permissions Contextually
Only request permissions when the user attempts to use a feature that requires them.

### 2. Provide Clear Explanations
Use the `permissionDescription` property to explain why the permission is needed.

### 3. Handle All States
Always handle `.notDetermined`, `.authorized`, `.denied`, and `.restricted` states appropriately.

### 4. Offer Alternatives
When permissions are denied, provide alternative workflows or clear guidance to System Settings.

### 5. Update UI Dynamically
Refresh permission statuses when the view appears to reflect changes made in System Settings.

## Adding New Permission Types

To add a new permission type:

1. **Create Permission Manager**
   ```swift
   @MainActor
   final class NewPermissionManager: PermissionManaging {
       static let shared = NewPermissionManager()
       
       var authorizationStatus: PermissionStatus { ... }
       var permissionDescription: String { ... }
       func requestAuthorization() async -> PermissionRequestResult { ... }
       func openSystemSettings() { ... }
   }
   ```

2. **Add to SettingsView**
   ```swift
   PermissionSectionView(
       icon: "icon.name",
       title: "New Permission",
       status: newStatus,
       statusColor: newStatusColor,
       isRequesting: isRequestingNew
   ) {
       newPermissionActions
   }
   ```

3. **Add Usage Description to Info.plist**
   ```xml
   <key>NSNewPermissionUsageDescription</key>
   <string>Clear explanation of why this permission is needed.</string>
   ```

## Integration with Existing Services

Permission managers work alongside existing service implementations:

- **ContactsPermissionManager** wraps `ContactsService`
- **MessagingPermissionManager** works with `MessagingService`

This separation of concerns keeps permission logic isolated while maintaining service functionality.

## Testing Considerations

### Resetting Permissions
To test permission flows, reset app permissions:
```bash
tccutil reset All com.yourorg.Athena
```

### Debugging Permission States
All permission managers include logging:
```
[ContactsPermissionManager] 📇 Requesting Contacts authorization...
[ContactsPermissionManager] ✅ Contacts access granted
```

## Related Files

- `Services/Protocols/PermissionManaging.swift` - Core protocol
- `Services/Permissions/ContactsPermissionManager.swift` - Contacts permissions
- `Services/Permissions/MessagingPermissionManager.swift` - Messaging/Automation permissions
- `Views/Settings/SettingsView.swift` - UI implementation
- `Info.plist` - Usage descriptions

## Future Enhancements

Potential improvements:
- Microphone permission manager (for speech recognition)
- Speech recognition permission manager
- Full Disk Access permission manager
- Screen Recording permission manager

