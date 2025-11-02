# Calendar Filtering Implementation Guide

## Overview

This document describes the comprehensive calendar filtering system implemented in Athena, allowing users to select which calendars they want to display and have those preferences persist across app launches.

## Architecture

### Core Components

1. **CalendarService (ObservableObject)**
   - Location: `Athena/Services/CalendarService.swift`
   - Manages all calendar operations and user preferences
   - Published properties automatically notify SwiftUI views of changes

2. **CalendarSettingsView**
   - Location: `Athena/Views/Calendar/CalendarSettingsView.swift`
   - Standalone settings UI for calendar selection
   - Can be used independently or integrated into main settings

3. **SettingsView Integration**
   - Location: `Athena/Views/Settings/SettingsView.swift`
   - Includes `CalendarSelectionSettingsView` component
   - Seamlessly integrated with existing settings sections

4. **DayViewModel Integration**
   - Location: `Athena/ViewModels/DayViewModel.swift`
   - Automatically refetches events when calendar selection changes
   - Example of how to integrate filtering into existing views

## Key Features

### 1. Calendar Management

**Published Properties:**
```swift
@Published private(set) var allEventCalendars: [EKCalendar]
@Published private(set) var selectedCalendarIDs: Set<String>
```

- `allEventCalendars`: All available event calendars, sorted alphabetically
- `selectedCalendarIDs`: User's selected calendar identifiers

**Computed Property:**
```swift
var selectedCalendars: [EKCalendar]
```
Returns the actual `EKCalendar` objects for selected calendars.

### 2. Persistence

**UserDefaults Integration:**
- Key: `"CalendarService.selectedCalendarIDs"`
- Automatically saves whenever selection changes
- Loads on app launch
- Defaults to ALL calendars on first run

### 3. Auto-Refresh

**EventKit Change Notifications:**
- Subscribes to `EKEventStoreChanged` notifications
- Automatically reconciles selections when calendars are added/removed
- Falls back to all calendars if reconciliation results in zero selections
- Ensures data consistency with system calendar changes

### 4. Filtered Event Fetching

**Modified `fetchEvents()` Method:**
```swift
func fetchEvents(from startDate: Date, to endDate: Date, completion: ...)
```

- Only queries selected calendars
- Returns empty array if no calendars selected
- Uses standard EventKit predicate with calendar filtering
- Maintains backward compatibility with existing code

### 5. Selection Management

**Helper Methods:**

```swift
// Enable/disable individual calendar
func setCalendar(_ calendar: EKCalendar, enabled: Bool)

// Bulk operations
func selectAllCalendars()
func deselectAllCalendars()
```

All methods automatically persist changes to UserDefaults.

## Integration Guide

### Observing Calendar Changes in ViewModels

Any view that displays calendar events should observe `selectedCalendarIDs` and refetch when it changes:

```swift
class MyViewModel: ObservableObject {
    private let calendarService = CalendarService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observe calendar selection changes
        calendarService.$selectedCalendarIDs
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                Task { @MainActor in
                    print("📅 Calendar selection changed - refetching events")
                    await self?.fetchEvents()
                }
            }
            .store(in: &cancellables)
    }
}
```

**Key Points:**
- Use `.dropFirst()` to avoid fetching twice on initialization
- Run on `@MainActor` for UI updates
- Weak self reference to prevent retain cycles

### Using in SwiftUI Views

**Option 1: Observe CalendarService Directly**

```swift
struct MyCalendarView: View {
    @ObservedObject var calendarService = CalendarService.shared
    
    var body: some View {
        // View automatically updates when selectedCalendarIDs changes
        Text("\(calendarService.selectedCalendarIDs.count) calendars selected")
    }
}
```

**Option 2: Use `.onChange()` Modifier**

```swift
struct MyCalendarView: View {
    @ObservedObject var calendarService = CalendarService.shared
    @State private var events: [CalendarEvent] = []
    
    var body: some View {
        // Your view content
    }
    .onChange(of: calendarService.selectedCalendarIDs) { _ in
        refetchEvents()
    }
}
```

### Displaying Calendar Settings

**In Main Settings:**

The calendar selection UI is already integrated into `SettingsView`. Users can access it through the app's main settings panel.

**As Standalone Sheet:**

```swift
struct MyView: View {
    @State private var showCalendarSettings = false
    
    var body: some View {
        Button("Calendar Settings") {
            showCalendarSettings = true
        }
        .sheet(isPresented: $showCalendarSettings) {
            CalendarSettingsView()
        }
    }
}
```

## UI Components

### CalendarSettingsView

**Features:**
- Full calendar list with toggles
- Color-coded calendar indicators
- Source badges (iCloud, Google, etc.)
- Select All / Deselect All buttons
- Authorization state handling
- Empty state for no calendars

**States:**
1. **Not Authorized**: Prompts user to grant access
2. **No Calendars**: Shows message to add calendars
3. **Ready**: Displays calendar list with selection controls

### CalendarSelectionSettingsView

**Features:**
- Integrated into main `SettingsView`
- Matches existing settings UI styling
- Shows selection count
- Scrollable list (max height 300pt)
- Info messages for different states

**Layout:**
```
Calendar Selection
├── Authorization check
├── Selection summary (X of Y calendars)
├── Select All / Deselect All buttons
├── Calendar list (scrollable)
│   ├── Checkbox
│   ├── Color indicator
│   ├── Calendar name
│   └── Source badge
└── Info text
```

## Data Flow

```
User Action
    ↓
CalendarService.setCalendar()
    ↓
selectedCalendarIDs updated (published)
    ↓
    ├→ UserDefaults.save()
    ├→ SwiftUI views refresh
    └→ ViewModels receive Combine notification
        ↓
        fetchEvents() called
        ↓
        Only selected calendars queried
        ↓
        UI displays filtered events
```

## EventKit Change Handling

```
System Calendar App Change
    ↓
EKEventStoreChanged notification
    ↓
CalendarService.refreshCalendars()
    ↓
    ├→ Reload all calendars
    ├→ Sort alphabetically
    ├→ Reconcile selections (remove deleted calendar IDs)
    └→ If zero selections → select all
        ↓
allEventCalendars published
selectedCalendarIDs published
    ↓
UI automatically updates
```

## Testing Scenarios

### 1. Initial Launch
- All calendars selected by default
- Preferences saved to UserDefaults
- Events from all calendars displayed

### 2. Calendar Selection
- Toggle calendars in settings
- Changes persist immediately
- Calendar views refresh automatically
- Events filtered in real-time

### 3. System Calendar Changes
- Add calendar in System Calendar app
- New calendar appears in Athena
- Existing selections preserved
- New calendar unselected by default

### 4. Calendar Deletion
- Delete calendar in System Calendar app
- Removed from selection automatically
- If last calendar removed, all remaining selected
- No stale IDs in UserDefaults

### 5. Authorization Changes
- Revoke access in System Settings
- App shows authorization prompt
- Calendar list cleared
- Graceful error handling

## Debug Logging

The implementation includes comprehensive logging:

```
📅 CalendarService initialized
📅 Refreshed calendars: 5 total, 3 selected
📅 Saved 3 selected calendars to UserDefaults
📅 Loaded 3 selected calendars from UserDefaults
📅 No calendars selected - returning empty event list
📅 Fetched 15 events from 3 selected calendar(s)
📅 Calendar selection changed - refetching events
```

Look for these messages in Xcode console to track behavior.

## Performance Considerations

1. **Efficient Updates**: Only refetches events when selection actually changes
2. **Batch Operations**: `selectAllCalendars()` updates once, not per calendar
3. **Memory**: Calendar list kept in memory (typically small dataset)
4. **Persistence**: Minimal UserDefaults writes (only on selection change)
5. **Threading**: EventKit notifications dispatched to main thread

## Future Enhancements

Potential improvements (not implemented in this version):

1. **Group by Source**
   - Section headers for iCloud, Google, Exchange
   - Source-level enable/disable

2. **Calendar Colors**
   - Custom color picker for calendars
   - Override system colors

3. **Smart Filters**
   - "Work calendars only"
   - "Personal calendars only"
   - Custom saved filters

4. **Statistics**
   - Event count per calendar
   - Visual breakdown

5. **Search/Filter**
   - Search calendars by name
   - Filter by source

## Troubleshooting

### Events Not Updating

**Check:**
1. Are calendars selected? (Settings → Calendar Selection)
2. Is authorization granted? (Settings → Permissions)
3. Check console for `📅` debug logs
4. Verify `selectedCalendarIDs` is not empty

### Settings Not Persisting

**Check:**
1. UserDefaults key: `CalendarService.selectedCalendarIDs`
2. Console should show "Saved X selected calendars"
3. Check file system permissions

### Calendars Not Appearing

**Check:**
1. Do calendars exist in System Calendar app?
2. Are they event calendars (not reminders)?
3. Is full access granted (macOS 14+)?
4. Check `allEventCalendars.count` in debugger

## Summary

The calendar filtering system provides:

✅ Complete user control over which calendars to display  
✅ Persistent preferences across app launches  
✅ Automatic synchronization with system calendar changes  
✅ Reactive UI that updates in real-time  
✅ Clean integration with existing code  
✅ Comprehensive error handling and edge cases  
✅ Detailed debug logging for troubleshooting  

All requirements from the original specification have been implemented successfully.

