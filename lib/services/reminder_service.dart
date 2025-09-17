import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;

class ReminderService {
  static final ReminderService _instance = ReminderService._();
  ReminderService._();
  factory ReminderService() => _instance;

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static const String _storeKey = 'buddy_scheduled_reminders';

  Future<void> initialize() async {
    if (_initialized) return;
    // Timezone DB
    tz.initializeTimeZones();

    final androidInit = const AndroidInitializationSettings('@mipmap/launcher_icon');
    final initSettings = InitializationSettings(android: androidInit);
    await _fln.initialize(initSettings);

    // Android 13+ runtime notifications permission (if supported by plugin version)
    final androidImpl = _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      final dyn = androidImpl as dynamic;
      if (dyn != null) {
        await dyn.requestPermission();
      }
    } catch (_) {
      // Older plugin versions may not expose this API; ignore
    }

    // Create a default channel
    const androidChannel = AndroidNotificationChannel('buddy_reminders', 'Buddy Reminders', description: 'Reminders created by Buddy from notifications', importance: Importance.high);
    await _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(androidChannel);

    _initialized = true;
  }

  Future<void> scheduleReminder({required int id, required String title, required String body, required DateTime when, int? groupId, String? app, int? leadMinutes}) async {
    // If parsed time is already in the past, nudge it forward so it will fire
    final nowLocal = DateTime.now();
    if (!when.isAfter(nowLocal)) {
      when = nowLocal.add(const Duration(minutes: 1)); // If parsed time is already in the past, nudge it forward so it will fire
    }
    final details = NotificationDetails(
      android: AndroidNotificationDetails('buddy_reminders', 'Buddy Reminders', channelDescription: 'Reminders created by Buddy from notifications', priority: Priority.high, importance: Importance.high),
    );
    // Compute schedule time relative to now to avoid reliance on IANA zone mapping
    final nowTz = tz.TZDateTime.now(tz.local);
    final fireAt = nowTz.add(when.difference(DateTime.now()));
    await _fln.zonedSchedule(id, title, body, fireAt, details, androidAllowWhileIdle: true, uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime, matchDateTimeComponents: null);

    // Save metadata so UI can show when
    await _saveScheduledMeta(id: id, title: title, body: body, when: when, groupId: groupId, app: app, leadMinutes: leadMinutes);
  }

  Future<void> showImmediate({required int id, required String title, required String body}) async {
    final details = NotificationDetails(android: AndroidNotificationDetails('buddy_reminders', 'Buddy Reminders', channelDescription: 'Immediate reminder'));
    await _fln.show(id, title, body, details);
  }

  Future<List<Map<String, String>>> listPending() async {
    final reqs = await _fln.pendingNotificationRequests();
    return reqs.map((r) => {'id': r.id.toString(), 'title': r.title ?? '', 'body': r.body ?? ''}).toList();
  }

  Future<void> cancel(int id) async {
    await _fln.cancel(id);
    await removeScheduledMeta(id);
  }

  Future<void> cancelAll() async {
    await _fln.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storeKey);
  }

  Future<void> updateReminder({required int id, required String title, required String body, required DateTime when}) async {
    await _fln.cancel(id);
    await scheduleReminder(id: id, title: title, body: body, when: when);
  }

  // --- Persistence helpers for scheduled metadata ---
  Future<void> _saveScheduledMeta({required int id, required String title, required String body, required DateTime when, int? groupId, String? app, int? leadMinutes}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    List<Map<String, dynamic>> list = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final parsed = json.decode(raw);
        if (parsed is List) {
          list = parsed.whereType<Map>().map((m) => m.map((k, v) => MapEntry(k.toString(), v))).toList();
        }
      } catch (_) {}
    }
    // upsert by id
    final idx = list.indexWhere((e) => e['id'] == id);
    final entry = {'id': id, 'title': title, 'body': body, 'when': when.toIso8601String(), if (groupId != null) 'groupId': groupId, if (app != null) 'app': app, if (leadMinutes != null) 'leadMinutes': leadMinutes};
    if (idx >= 0) {
      list[idx] = entry;
    } else {
      list.add(entry);
    }
    // prune very old entries (> 1 day in past)
    final now = DateTime.now();
    list = list.where((e) {
      final w = DateTime.tryParse(e['when']?.toString() ?? '') ?? now;
      return w.isAfter(now.subtract(const Duration(days: 1)));
    }).toList();
    await prefs.setString(_storeKey, json.encode(list));
  }

  Future<List<Map<String, dynamic>>> getScheduledMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final parsed = json.decode(raw);
      if (parsed is List) {
        final list = parsed.whereType<Map>().map((m) => m.map((k, v) => MapEntry(k.toString(), v))).toList();
        // Only future (or just fired) items for display, sorted by when
        final now = DateTime.now();
        final filtered = list.where((e) {
          final w = DateTime.tryParse(e['when']?.toString() ?? '') ?? now;
          return w.isAfter(now.subtract(const Duration(minutes: 5)));
        }).toList();
        filtered.sort((a, b) {
          final aw = DateTime.tryParse(a['when']?.toString() ?? '') ?? now;
          final bw = DateTime.tryParse(b['when']?.toString() ?? '') ?? now;
          return aw.compareTo(bw);
        });
        return filtered;
      }
    } catch (_) {}
    return [];
  }

  Future<void> removeScheduledMeta(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final parsed = json.decode(raw);
      if (parsed is List) {
        final list = parsed.whereType<Map>().map((m) => m.map((k, v) => MapEntry(k.toString(), v))).toList();
        list.removeWhere((e) => e['id'] == id);
        await prefs.setString(_storeKey, json.encode(list));
      }
    } catch (_) {}
  }
}
