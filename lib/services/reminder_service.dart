import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:buddy/models/reminder.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class ReminderService {
  factory ReminderService() => _instance;
  ReminderService._internal();

  static final ReminderService _instance = ReminderService._internal();

  static const String _channelId = 'buddy_reminders_v2';
  static const String _channelName = 'Buddy Reminders';
  static const String _channelDescription = 'Reminders scheduled by Buddy';

  static bool _timeZonesSeeded = false;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final _ReminderStore _store = _ReminderStore();
  final Random _random = Random();

  bool _initialized = false;
  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      _initialized = true;
      return;
    }

    await _prepareTimeZones();

    const initializationSettings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/launcher_icon'), iOS: DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true));

    // Initialize with notification response callback
    await _plugin.initialize(initializationSettings, onDidReceiveNotificationResponse: _onNotificationResponse, onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse);
    await _requestPermissions();
    await _ensureNotificationChannel();
    await _store.bootstrap();
    await _pruneOrphans();

    _initialized = true;
  }

  // Handler for foreground notification taps
  void _onNotificationResponse(NotificationResponse response) {
    debugPrint('ReminderService: Notification tapped - ID: ${response.id}, payload: ${response.payload}');
    // The app is already running, just log the interaction
  }

  // Handler for background notification taps (must be top-level or static)
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    debugPrint('ReminderService: Background notification tapped - ID: ${response.id}, payload: ${response.payload}');
    // Handle background notification tap
  }

  Future<void> _prepareTimeZones() async {
    if (kIsWeb) {
      return;
    }

    if (!_timeZonesSeeded) {
      tzdata.initializeTimeZones();
      _timeZonesSeeded = true;
    }

    try {
      final dynamic info = await FlutterTimezone.getLocalTimezone();
      String? identifier;
      if (info is String && info.isNotEmpty) {
        identifier = info;
      } else if (info != null) {
        final dynamic candidate = info.identifier;
        if (candidate is String && candidate.isNotEmpty) {
          identifier = candidate;
        }
      }
      tz.setLocalLocation(tz.getLocation(identifier ?? 'UTC'));
    } catch (err) {
      debugPrint('ReminderService: Failed to determine timezone ($err), defaulting to UTC');
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;

    final androidSpecific = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidSpecific != null) {
      final dynamic dyn = androidSpecific;
      try {
        await dyn.requestPermission();
      } catch (_) {
        try {
          await dyn.requestNotificationsPermission();
        } catch (err) {
          debugPrint('ReminderService: Android permission request skipped ($err)');
        }
      }
    }

    final iosSpecific = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosSpecific != null) {
      try {
        await iosSpecific.requestPermissions(alert: true, badge: true, sound: true);
      } catch (err) {
        debugPrint('ReminderService: iOS permission request failed ($err)');
      }
    }

    final macSpecific = _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
    if (macSpecific != null) {
      try {
        await macSpecific.requestPermissions(alert: true, badge: true, sound: true);
      } catch (err) {
        debugPrint('ReminderService: macOS permission request failed ($err)');
      }
    }
  }

  Future<void> _ensureNotificationChannel() async {
    final androidSpecific = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidSpecific == null) return;

    const channel = AndroidNotificationChannel(_channelId, _channelName, description: _channelDescription, importance: Importance.high, playSound: true, enableLights: true, enableVibration: true);

    await androidSpecific.createNotificationChannel(channel);
  }

  // Persistent notification management (keeps app from being killed)
  static const int _persistentNotificationId = 999999;
  static const String _persistentChannelId = 'buddy_foreground_service';
  static const String _persistentChannelName = 'Buddy Service';
  static const String _persistentChannelDescription = 'Keeps Buddy running in background';

  Future<void> startPersistentNotification() async {
    if (kIsWeb) return;
    await initialize();

    final androidSpecific = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidSpecific == null) return;

    // Create a separate low-priority channel for the persistent notification
    const persistentChannel = AndroidNotificationChannel(_persistentChannelId, _persistentChannelName, description: _persistentChannelDescription, importance: Importance.low, playSound: false, enableLights: false, enableVibration: false, showBadge: false);

    try {
      await androidSpecific.createNotificationChannel(persistentChannel);

      const androidDetails = AndroidNotificationDetails(
        _persistentChannelId,
        _persistentChannelName,
        channelDescription: _persistentChannelDescription,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true, // Makes it persistent (can't swipe away)
        autoCancel: false,
        icon: '@mipmap/launcher_icon',
        showWhen: false,
      );
      const notificationDetails = NotificationDetails(android: androidDetails);

      // Show persistent notification
      await _plugin.show(_persistentNotificationId, 'Buddy is active', 'Monitoring your reminders', notificationDetails);

      // Store the state in preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('buddy_foreground_service_enabled', true);

      debugPrint('ReminderService: Persistent notification started');
    } catch (err) {
      debugPrint('ReminderService: Failed to start persistent notification ($err)');
    }
  }

  Future<void> stopPersistentNotification() async {
    if (kIsWeb) return;

    try {
      // Cancel the persistent notification
      await _plugin.cancel(_persistentNotificationId);

      // Update the state in preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('buddy_foreground_service_enabled', false);

      debugPrint('ReminderService: Persistent notification stopped');
    } catch (err) {
      debugPrint('ReminderService: Failed to stop persistent notification ($err)');
    }
  }

  Future<bool> isPersistentNotificationEnabled() async {
    if (kIsWeb) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('buddy_foreground_service_enabled') ?? false;
  }

  Future<Reminder> scheduleReminder({int? id, required String title, required String body, required DateTime when, int? groupId, String? app, int? leadMinutes}) async {
    if (kIsWeb) {
      throw UnsupportedError('Reminder scheduling is not supported on web.');
    }
    await initialize();

    final existingReminders = await _store.load();
    final existingIds = existingReminders.map((e) => e.id).toSet();
    final reminderId = id ?? _generateId(existingIds);
    final sanitizedTitle = title.trim().isEmpty ? 'Reminder' : title.trim();
    final sanitizedBody = body.trim();

    final scheduledLocal = _sanitizeScheduledTime(when);
    final scheduledTz = tz.TZDateTime.from(scheduledLocal, tz.local);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(_channelId, _channelName, channelDescription: _channelDescription, category: AndroidNotificationCategory.reminder, importance: Importance.high, priority: Priority.high, ticker: sanitizedTitle),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );

    await _plugin.zonedSchedule(reminderId, sanitizedTitle, sanitizedBody.isEmpty ? null : sanitizedBody, scheduledTz, details, androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, payload: json.encode({'title': sanitizedTitle, 'body': sanitizedBody, if (groupId != null) 'groupId': groupId, if (app != null) 'app': app, if (leadMinutes != null) 'leadMinutes': leadMinutes, 'scheduledAt': scheduledLocal.toIso8601String()}));

    final reminder = Reminder(id: reminderId, title: sanitizedTitle, body: sanitizedBody, scheduledAt: scheduledLocal, createdAt: DateTime.now(), originApp: app, groupId: groupId, leadMinutes: leadMinutes);

    await _store.upsert(reminder, preload: existingReminders);
    return reminder;
  }

  Future<void> showImmediate({required int id, required String title, required String body}) async {
    if (kIsWeb) return;
    await initialize();

    final sanitizedTitle = title.trim().isEmpty ? 'Reminder' : title.trim();
    final sanitizedBody = body.trim();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(_channelId, _channelName, channelDescription: _channelDescription, importance: Importance.high, priority: Priority.high),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );

    await _plugin.show(id, sanitizedTitle, sanitizedBody.isEmpty ? null : sanitizedBody, details);
  }

  Future<List<Reminder>> getScheduledReminders({bool includePast = false}) async {
    if (kIsWeb) return const [];
    await initialize();
    await _pruneOrphans();

    final stored = await _store.load();
    final pending = await _plugin.pendingNotificationRequests();
    final storedById = {for (final reminder in stored) reminder.id: reminder};
    final reminders = <Reminder>[];

    for (final request in pending) {
      final payload = _decodePayload(request.payload);
      final storedReminder = storedById.remove(request.id);

      final titleFromRequest = request.title?.trim();
      final bodyFromRequest = request.body?.trim();
      final sanitizedTitle = (titleFromRequest != null && titleFromRequest.isNotEmpty) ? titleFromRequest : null;
      final sanitizedBody = (bodyFromRequest != null && bodyFromRequest.isNotEmpty) ? bodyFromRequest : null;

      final scheduledAt = _parseScheduledAt(payload['scheduledAt']) ?? storedReminder?.scheduledAt ?? DateTime.now();
      final originApp = payload['app']?.toString() ?? storedReminder?.originApp;
      final groupId = payload.containsKey('groupId') ? _parseOptionalInt(payload['groupId']) ?? storedReminder?.groupId : storedReminder?.groupId;
      final leadMinutes = payload.containsKey('leadMinutes') ? _parseOptionalInt(payload['leadMinutes']) ?? storedReminder?.leadMinutes : storedReminder?.leadMinutes;

      final baseReminder = storedReminder ?? Reminder(id: request.id, title: sanitizedTitle ?? 'Reminder', body: sanitizedBody ?? '', scheduledAt: scheduledAt, createdAt: DateTime.now(), originApp: originApp, groupId: groupId, leadMinutes: leadMinutes);

      final updated = baseReminder.copyWith(title: sanitizedTitle ?? baseReminder.title, body: sanitizedBody ?? baseReminder.body, scheduledAt: scheduledAt, originApp: originApp, groupId: groupId, leadMinutes: leadMinutes);

      reminders.add(updated);
    }

    // Include any stored reminders that didn't surface as pending (e.g. scheduled far ahead on platforms with delayed sync)
    reminders.addAll(storedById.values);

    final now = DateTime.now();
    final filtered = includePast ? reminders : reminders.where((reminder) => reminder.scheduledAt.isAfter(now.subtract(const Duration(minutes: 5)))).toList();

    filtered.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return filtered;
  }

  Future<List<Map<String, String>>> listPending() async {
    final reminders = await getScheduledReminders();
    return reminders.map((r) => {'id': r.id.toString(), 'title': r.title, 'body': r.body}).toList();
  }

  Future<List<Map<String, dynamic>>> getScheduledMeta() async {
    final reminders = await getScheduledReminders();
    return reminders.map((r) => {'id': r.id, 'title': r.title, 'body': r.body, 'when': r.scheduledAt.toIso8601String(), if (r.originApp != null) 'app': r.originApp, if (r.groupId != null) 'groupId': r.groupId, if (r.leadMinutes != null) 'leadMinutes': r.leadMinutes}).toList();
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancel(id);
    await _store.remove(id);
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancelAll();
    await _store.clear();
  }

  Future<Reminder> updateReminder({required int id, required String title, required String body, required DateTime when, int? groupId, String? app, int? leadMinutes}) async {
    await cancel(id);
    return scheduleReminder(id: id, title: title, body: body, when: when, groupId: groupId, app: app, leadMinutes: leadMinutes);
  }

  Future<void> removeScheduledMeta(int id) async {
    await _store.remove(id);
  }

  int _generateId(Set<int> reserved) {
    var candidate = _random.nextInt(0x7fffffff);
    while (reserved.contains(candidate) || candidate == 0) {
      candidate = _random.nextInt(0x7fffffff);
    }
    return candidate;
  }

  DateTime _sanitizeScheduledTime(DateTime when) {
    final local = when.toLocal();
    final now = DateTime.now();
    if (local.isAfter(now.add(const Duration(seconds: 20)))) {
      return local;
    }
    return now.add(const Duration(minutes: 1));
  }

  Map<String, dynamic> _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return const {};
    try {
      final decoded = json.decode(payload);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (err) {
      debugPrint('ReminderService: Failed to decode notification payload ($err)');
    }
    return const {};
  }

  DateTime? _parseScheduledAt(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  int? _parseOptionalInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString());
  }

  Future<void> _pruneOrphans() async {
    if (kIsWeb) return;
    final stored = await _store.load();
    if (stored.isEmpty) return;

    final pending = await _plugin.pendingNotificationRequests();
    final pendingIds = pending.map((e) => e.id).toSet();

    final now = DateTime.now();
    final orphanIds = <int>[];
    for (final reminder in stored) {
      if (!pendingIds.contains(reminder.id) && reminder.scheduledAt.isBefore(now.subtract(const Duration(minutes: 5)))) {
        orphanIds.add(reminder.id);
      }
    }

    if (orphanIds.isNotEmpty) {
      await _store.removeMany(orphanIds);
    }
  }
}

class _ReminderStore {
  static const String _storeKey = 'buddy_reminders_v2';
  static const String _legacyStoreKey = 'buddy_scheduled_reminders';

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey(_storeKey) && prefs.containsKey(_legacyStoreKey)) {
      final migrated = _migrateLegacy(prefs.getString(_legacyStoreKey));
      if (migrated.isNotEmpty) {
        await prefs.setString(_storeKey, json.encode(migrated.map((e) => e.toJson()).toList()));
      }
      await prefs.remove(_legacyStoreKey);
    }

    await pruneExpired();
  }

  Future<List<Reminder>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = json.decode(raw);
      if (decoded is List) {
        return decoded.whereType<Map>().map((m) => m.map((key, value) => MapEntry(key.toString(), value))).map(Reminder.fromJson).toList();
      }
    } catch (err) {
      debugPrint('ReminderService: Failed to parse persisted reminders ($err)');
    }
    return const [];
  }

  Future<void> upsert(Reminder reminder, {List<Reminder>? preload}) async {
    final items = preload ?? await load();
    final existingIndex = items.indexWhere((element) => element.id == reminder.id);
    if (existingIndex >= 0) {
      items[existingIndex] = reminder;
    } else {
      items.add(reminder);
    }
    await _persist(items);
  }

  Future<void> remove(int id) async {
    final items = await load();
    items.removeWhere((element) => element.id == id);
    await _persist(items);
  }

  Future<void> removeMany(Iterable<int> ids) async {
    final set = ids.toSet();
    final items = await load();
    items.removeWhere((element) => set.contains(element.id));
    await _persist(items);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storeKey);
  }

  Future<void> pruneExpired() async {
    final items = await load();
    if (items.isEmpty) return;
    final now = DateTime.now();
    items.removeWhere((element) => element.scheduledAt.isBefore(now.subtract(const Duration(days: 7))));
    await _persist(items);
  }

  Future<void> _persist(List<Reminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = reminders.map((e) => e.toJson()).toList();
    await prefs.setString(_storeKey, json.encode(payload));
  }

  List<Reminder> _migrateLegacy(String? payload) {
    if (payload == null || payload.isEmpty) return const [];
    try {
      final decoded = json.decode(payload);
      if (decoded is! List) return const [];
      final now = DateTime.now();
      final results = <Reminder>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = item.map((key, value) => MapEntry(key.toString(), value));
        final when = DateTime.tryParse(map['when']?.toString() ?? '') ?? now;
        if (when.isBefore(now.subtract(const Duration(days: 7)))) {
          continue;
        }

        final reminderJson = <String, dynamic>{'id': map['id'], 'title': map['title'] ?? '', 'body': map['body'] ?? '', 'scheduledAt': when.toIso8601String(), 'createdAt': now.toIso8601String(), if (map['app'] != null) 'originApp': map['app'], if (map['groupId'] != null) 'groupId': map['groupId'], if (map['leadMinutes'] != null) 'leadMinutes': map['leadMinutes']};
        results.add(Reminder.fromJson(reminderJson));
      }
      return results;
    } catch (err) {
      debugPrint('ReminderService: Failed to migrate legacy reminders ($err)');
      return const [];
    }
  }
}
