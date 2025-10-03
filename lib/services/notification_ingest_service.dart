import 'dart:async';
import 'package:notifications/notifications.dart' as ntf;
import 'package:buddy/services/reminder_service.dart';
import 'package:buddy/services/openrouter_service.dart';
import 'package:buddy/services/toast_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class NotificationIngestService {
  static final NotificationIngestService _instance = NotificationIngestService._();
  NotificationIngestService._();
  factory NotificationIngestService() => _instance;

  final ntf.Notifications _notifications = ntf.Notifications();
  final OpenRouterService _ai = OpenRouterService();
  final ReminderService _reminders = ReminderService();
  StreamSubscription<ntf.NotificationEvent>? _sub;
  static const _enabledKey = 'notification_ingest_enabled';
  static const _allowedAppsKey = 'notification_ingest_allowed_apps';
  bool _enabled = true;
  Set<String> _allowedApps = <String>{};

  Future<void> initialize() async {
    // No-op: notifications package requires manifest service + user-granted access in settings
  }

  Future<void> start() async {
    if (!_enabled) return;
    await _reminders.initialize();
    // Load allowed apps from storage
    await _loadAllowedApps();
    _sub?.cancel();
    _sub = _notifications.notificationStream?.listen(_onEvent);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  // Permission must be granted by user in system settings (Notification Access)

  Future<bool> getEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? true;
    return _enabled;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = value;
    await prefs.setBool(_enabledKey, value);
    if (value) {
      await start();
    } else {
      await stop();
    }
  }

  Future<void> _onEvent(ntf.NotificationEvent e) async {
    final title = e.title ?? '';
    final text = e.message ?? '';
    final app = e.packageName ?? '';
    if (title.isEmpty && text.isEmpty) return;

    // Filter by allowed apps if configured
    if (_allowedApps.isNotEmpty && app.isNotEmpty && !_allowedApps.contains(app)) {
      return;
    }

    // Show a small toast to indicate we detected a notification
    ToastService().show('🔔 ${title.isNotEmpty ? title : app} ||| ${text.isNotEmpty ? text : app}');

    // Ask AI if this notification should trigger a reminder
    final classification = await _classify('$title\n$text', app: app);
    if (classification == null) return;

    if (classification['action'] == 'remind') {
      final whenIso = classification['when'] as String?; // ISO8601
      final desc = classification['description'] as String? ?? title;
      DateTime when;
      if (whenIso != null) {
        when = DateTime.tryParse(whenIso)?.toLocal() ?? DateTime.now().add(const Duration(minutes: 1));
      } else {
        when = DateTime.now().add(const Duration(minutes: 1));
      }
      try {
        // Primary reminder
        final primary = await _reminders.scheduleReminder(title: 'Reminder', body: desc.isEmpty ? text : desc, when: when, app: app);
        final groupId = primary.id;

        // Optional lead reminders for tasks like assignments; simple heuristic on keywords
        final lower = ('$title\n$text').toLowerCase();
        final shouldLead = lower.contains('assignment') || lower.contains('exam') || lower.contains('deadline') || lower.contains('submission');
        if (shouldLead) {
          final leads = <int>[120, 60, 10]; // minutes before
          for (final m in leads) {
            final leadTime = when.subtract(Duration(minutes: m));
            if (leadTime.isAfter(DateTime.now())) {
              await _reminders.scheduleReminder(title: 'Reminder', body: '${desc.isNotEmpty ? desc : title} (in ${m}m)', when: leadTime, groupId: groupId, app: app, leadMinutes: m);
            }
          }
        }
        final local = primary.scheduledAt;
        final formatted = DateFormat('MMM d • h:mm a').format(local);
        ToastService().show('⏰ ${desc.isNotEmpty ? desc : title} • $formatted');
      } catch (e) {
        ToastService().show('⚠️ Failed to set reminder');
      }
    }
  }

  Future<Map<String, dynamic>?> _classify(String content, {required String app}) async {
    try {
      return await _ai.classifyNotification(app: app, text: content);
    } catch (_) {
      return null;
    }
  }

  // --- Allowed apps persistence ---
  Future<void> _loadAllowedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_allowedAppsKey) ?? <String>[];
    _allowedApps = raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  Future<List<String>> getAllowedApps() async {
    await _loadAllowedApps();
    return _allowedApps.toList()..sort();
  }

  Future<void> setAllowedApps(List<String> apps) async {
    final cleaned = apps.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    _allowedApps = cleaned;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_allowedAppsKey, _allowedApps.toList());
  }
}
