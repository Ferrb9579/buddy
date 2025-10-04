# Notifications Package - Null Safety Fix

## Problem

The original `notifications` package (v3.1.0) has a null pointer exception in the Android native code:

```
java.lang.NullPointerException: Attempt to invoke interface method 
'java.lang.String java.lang.CharSequence.toString()' on a null object reference
at dk.cachet.notifications.NotificationListener.onNotificationPosted
```

This occurs when a notification has null `title` or `message` fields.

## Solution

This directory contains a patched version of the `notifications` package with proper null safety checks in the Android native code.

### Changes Made

#### 1. `NotificationListener.java`
Added comprehensive null checks:
- Check if `Notification` is null
- Check if `Bundle extras` is null  
- Safely extract title with `CharSequence` null check
- Safely extract text with `CharSequence` null check
- Try `EXTRA_BIG_TEXT` if `EXTRA_TEXT` is empty
- Only send events if we have at least title or text
- Wrap everything in try-catch for safety

#### 2. `NotificationsPlugin.java`
Created the plugin bridge to send events to Flutter with null safety:
- Null checks on all string parameters
- Safe Map creation for events
- Error logging

#### 3. Dart Implementation
- `notifications.dart` - Main library export
- `notification_event.dart` - Event model with null safety
- `notifications.dart` (in src/) - Stream implementation

## Usage

The patched version is automatically used via `dependency_overrides` in the main `pubspec.yaml`:

```yaml
dependency_overrides:
  notifications:
    path: third_party/notifications_override/notifications
```

No code changes needed in your app - it's a drop-in replacement!

## Files Structure

```
third_party/notifications_override/notifications/
├── android/
│   ├── build.gradle
│   └── src/
│       └── main/
│           ├── AndroidManifest.xml
│           └── java/
│               └── dk/
│                   └── cachet/
│                       └── notifications/
│                           ├── NotificationListener.java (✅ Fixed)
│                           └── NotificationsPlugin.java (✅ New)
├── lib/
│   ├── notifications.dart
│   └── src/
│       ├── notification_event.dart
│       └── notifications.dart
└── pubspec.yaml
```

## Testing

After applying this fix:

1. Run `flutter pub get`
2. Clean and rebuild: `flutter clean && flutter build apk`
3. Test with various apps that send notifications
4. Check logs for: No more NullPointerException!

## Benefits

- ✅ Prevents app crashes from null notifications
- ✅ Handles edge cases (empty text, null bundles)
- ✅ Logs warnings for debugging
- ✅ Falls back gracefully
- ✅ No changes needed in Dart code

## Original Package

Original package: https://pub.dev/packages/notifications

This is a local patch until the upstream package is fixed.
