# Persistent Notification (Foreground Service) Implementation

## Overview

I've added a persistent notification feature to prevent Android from killing your Buddy app in the background. This uses an "ongoing" notification that cannot be swiped away, which helps keep the app alive to monitor reminders and process notifications.

## Changes Made

### 1. AndroidManifest.xml (`android/app/src/main/AndroidManifest.xml`)

**Added Permissions:**
```xml
<!-- Foreground service permission (Android 9+) -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
```

**Added Foreground Service Declaration:**
```xml
<!-- Foreground service for flutter_local_notifications to keep app alive -->
<service
    android:name="com.dexterous.flutterlocalnotifications.ForegroundService"
    android:exported="false"
    android:stopWithTask="false"
    android:foregroundServiceType="specialUse">
    <property
        android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
        android:value="Keep notification listener active for reminders" />
</service>
```

### 2. ReminderService (`lib/services/reminder_service.dart`)

**Added Persistent Notification Management:**

- **`startPersistentNotification()`** - Starts a low-priority, ongoing notification that:
  - Shows "Buddy is active" in the notification tray
  - Cannot be swiped away (ongoing=true, autoCancel=false)
  - Uses low importance/priority to minimize distraction
  - Saves state to SharedPreferences

- **`stopPersistentNotification()`** - Removes the persistent notification and updates state

- **`isPersistentNotificationEnabled()`** - Checks if the persistent notification is currently enabled

**Implementation Details:**
- Uses notification ID 999999 to avoid conflicts with scheduled reminders
- Creates a separate notification channel "buddy_foreground_service" with low priority
- The notification is silent (no sound, vibration, or LED)
- State is persisted across app restarts

### 3. RemindersPage (`lib/pages/reminders_page.dart`)

**Added UI Controls:**
- New toggle switch: "Keep app running (persistent notification)"
- Helper text explaining it prevents Android from killing the app
- Positioned below the main notification listener toggle
- Calls `_togglePersistentNotification()` which manages the service state

### 4. main.dart (`lib/main.dart`)

**Added Auto-Restore:**
- On app startup, checks if persistent notification was previously enabled
- Automatically restores the persistent notification if it was active
- Ensures the notification survives app restarts

## How to Use

1. **Build and install the updated app:**
   ```powershell
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Enable the persistent notification:**
   - Open the app
   - Go to "Reminders & Notifications" page
   - Toggle ON: "Keep app running (persistent notification)"
   - You'll see a low-priority notification: "Buddy is active - Monitoring your reminders"

3. **Behavior:**
   - The notification appears in your notification tray
   - It cannot be swiped away
   - Android will be much less likely to kill your app
   - The notification persists even after closing the app
   - It automatically restores when you restart your device (if enabled)

4. **To disable:**
   - Toggle OFF the switch in the Reminders page
   - The notification will disappear

## Benefits

✅ **Prevents app termination**: Android is much less aggressive about killing apps with ongoing notifications

✅ **Reliable background processing**: Your notification listener and reminder scheduler stay active

✅ **Low distraction**: Uses low-priority notification channel that doesn't interrupt users

✅ **Persistent across restarts**: State is saved and restored automatically

✅ **User control**: Easy toggle on/off from the UI

## Technical Notes

### Why "ongoing" notification instead of true foreground service?

Flutter's `flutter_local_notifications` plugin doesn't directly expose the Android `Service.startForeground()` API. However, an "ongoing" notification (with `ongoing: true` and `autoCancel: false`) provides similar benefits:

- Prevents the system from killing the app aggressively
- Shows a persistent indicator to the user
- Much simpler to implement in Flutter
- Sufficient for most background task needs

### Android 14+ Foreground Service Types

For Android 14 (API level 34+), we use `specialUse` foreground service type, which is appropriate for apps that need to run in the background for functionality that doesn't fit other specific categories. The manifest includes the required `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` property.

### Battery Impact

The persistent notification does keep the app in memory, which may have a slight battery impact. However:
- The notification channel uses low priority (minimal wake locks)
- No sounds, vibrations, or LED notifications
- Users have full control to disable it when not needed

## Testing

1. **Enable persistent notification** via the UI toggle
2. **Lock your phone** or switch to another app for several minutes
3. **Scheduled reminders should still fire** even when app is in background
4. **Check notification shade** - you should see "Buddy is active"
5. **Try to swipe away the notification** - it should stay (can't be dismissed)
6. **Restart the app** - the persistent notification should automatically restore

## Troubleshooting

### Notification doesn't appear
- Ensure you've granted notification permissions in Android settings
- Check that "Buddy Service" notification channel is enabled
- Try toggling the switch off and on again

### App still gets killed
- Some aggressive battery optimization modes may still terminate apps
- Go to Settings → Apps → Buddy → Battery → "Not optimized"
- Some manufacturers (Xiaomi, Huawei) have extra aggressive optimization - check their specific settings

### Notification appears but app still stops
- This is expected behavior when the app is force-stopped or swiped away from recent apps
- The notification helps keep the app alive when in background, but can't prevent explicit termination
- The notification will restore on next app launch

## Future Improvements

Possible enhancements:
1. Add customizable notification text
2. Add tap action to open the app
3. Implement true foreground service for even stronger protection
4. Add statistics showing uptime/reliability
5. Smart auto-enable based on scheduled reminders

---

**Note**: This feature is Android-only. iOS handles background processing differently through its own notification and background task systems.
