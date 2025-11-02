# Calendar Filtering - Quick Start Guide

## For Users

### How to Select Calendars

1. Open Athena Settings (⌘,)
2. Scroll to "Calendar Selection" section
3. Toggle calendars on/off
4. Use "Select All" / "Deselect All" for bulk changes
5. Changes apply immediately

### What Gets Filtered

- ✅ Day view events
- ✅ All calendar queries
- ✅ Event counts
- ✅ All-day events and timed events

### Default Behavior

- **First launch**: All calendars selected
- **After changes**: Your preferences persist
- **After system changes**: Selections reconciled automatically

## For Developers

### Quick Integration in 3 Steps

**1. Observe Calendar Changes**

```swift
calendarService.$selectedCalendarIDs
    .dropFirst()
    .sink { [weak self] _ in
        await self?.refetchEvents()
    }
    .store(in: &cancellables)
```

**2. Fetch Events (Already Updated)**

```swift
// fetchEvents() now automatically filters by selected calendars
calendarService.fetchEvents(from: start, to: end) { events, error in
    // Only selected calendars' events returned
}
```

**3. Show Settings (Already Added)**

Settings already integrated in main `SettingsView`. No additional work needed.

### API Reference

```swift
// CalendarService Properties
.allEventCalendars: [EKCalendar]          // All available calendars
.selectedCalendarIDs: Set<String>         // Selected calendar IDs
.selectedCalendars: [EKCalendar]          // Selected calendar objects

// Methods
.setCalendar(_:enabled:)                  // Toggle single calendar
.selectAllCalendars()                     // Select all
.deselectAllCalendars()                   // Deselect all
```

### Testing Commands

```swift
// Print current state
print(CalendarService.shared.selectedCalendarIDs)
print(CalendarService.shared.allEventCalendars.map { $0.title })

// Reset to defaults
CalendarService.shared.selectAllCalendars()

// Clear all
CalendarService.shared.deselectAllCalendars()
```

## Files Modified/Created

### Modified
- ✅ `Athena/Services/CalendarService.swift` - Core filtering logic
- ✅ `Athena/ViewModels/DayViewModel.swift` - Auto-refresh integration
- ✅ `Athena/Views/Settings/SettingsView.swift` - Settings UI integration

### Created
- ✅ `Athena/Views/Calendar/CalendarSettingsView.swift` - Standalone settings view

## Configuration

### UserDefaults Key
```
CalendarService.selectedCalendarIDs
```

### Stored Format
```swift
// Array of calendar identifier strings
["7F3B9E2D-...", "A4C8D1F0-...", ...]
```

## Debug Logging

Look for `📅` emoji in console output:

```
📅 CalendarService initialized
📅 Refreshed calendars: 5 total, 3 selected
📅 Fetched 15 events from 3 selected calendar(s)
📅 Calendar selection changed - refetching events
```

## Common Patterns

### Check if Calendar is Selected

```swift
let isSelected = CalendarService.shared
    .selectedCalendarIDs
    .contains(calendar.calendarIdentifier)
```

### Get Selected Calendar Count

```swift
let count = CalendarService.shared.selectedCalendarIDs.count
```

### Filter Events Manually

```swift
let selectedIDs = CalendarService.shared.selectedCalendarIDs
let filtered = events.filter { event in
    selectedIDs.contains(event.calendar.calendarIdentifier)
}
```

*Note: Usually not needed - `fetchEvents()` already filters.*

## Edge Cases Handled

✅ No calendars selected → Returns empty array  
✅ Calendar deleted in system → Removed from selection  
✅ All selections removed → Defaults to all calendars  
✅ Authorization denied → Graceful error handling  
✅ No calendars exist → Empty state shown  

## Support

See `CALENDAR_FILTERING_IMPLEMENTATION.md` for comprehensive documentation.

