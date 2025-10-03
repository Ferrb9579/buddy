import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:buddy/models/reminder.dart';
import 'package:buddy/services/notification_ingest_service.dart';
import 'package:buddy/services/reminder_service.dart';
import 'package:intl/intl.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  final _ingest = NotificationIngestService();
  final _reminders = ReminderService();
  bool _enabled = true;
  bool _android = false;
  List<Reminder> _scheduledReminders = const [];
  List<AppInfo> _installedApps = const [];
  Set<String> _allowedApps = <String>{};
  bool _loadingApps = false;

  @override
  void initState() {
    super.initState();
    _android = !kIsWeb && Platform.isAndroid;
    _init();
  }

  Future<void> _init() async {
    await _reminders.initialize();
    final en = await _ingest.getEnabled();
    final scheduled = await _reminders.getScheduledReminders();
    final allowedApps = await _ingest.getAllowedApps();
    if (_android && _installedApps.isEmpty) {
      await _loadInstalledApps();
    }
    if (!mounted) return;
    setState(() {
      _enabled = en;
      _scheduledReminders = scheduled;
      _allowedApps = allowedApps.toSet();
    });
  }

  Future<void> _toggle(bool v) async {
    await _ingest.setEnabled(v);
    await _init();
  }

  Future<void> _openNotificationAccessSettings() async {
    if (!_android) return;
    final intent = AndroidIntent(action: 'android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS');
    await intent.launch();
  }

  Future<void> _testReminder() async {
    await _reminders.initialize();
    await _reminders.showImmediate(id: DateTime.now().millisecondsSinceEpoch % 100000, title: 'Test Reminder', body: 'This is a test');
    await _init();
  }

  Future<void> _loadInstalledApps({void Function(void Function())? modalSetState}) async {
    if (!_android) return;
    setState(() {
      _loadingApps = true;
    });
    modalSetState?.call(() {});
    List<AppInfo> apps = const [];
    try {
      final installed = await InstalledApps.getInstalledApps();
      apps = List<AppInfo>.from(installed)..sort((a, b) => _appLabel(a).toLowerCase().compareTo(_appLabel(b).toLowerCase()));
    } catch (_) {
      apps = const [];
    }
    if (!mounted) return;
    setState(() {
      _installedApps = apps;
      _loadingApps = false;
    });
    modalSetState?.call(() {});
  }

  String _appLabel(AppInfo info) {
    final name = info.name.trim();
    if (name.isNotEmpty) return name;
    final package = info.packageName.trim();
    if (package.isNotEmpty) return package;
    return 'Unknown app';
  }

  Future<void> _toggleApp(String packageName, bool enabled) async {
    if (packageName.isEmpty) return;
    final updated = Set<String>.from(_allowedApps);
    if (enabled) {
      updated.add(packageName);
    } else {
      updated.remove(packageName);
    }
    setState(() {
      _allowedApps = updated;
    });
    await _ingest.setAllowedApps(updated.toList());
  }

  void _showAppFilterSheet() {
    if (!_android) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unavailable'),
          content: const Text('Installed-app filtering is available only on Android devices.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        var requestedModalLoad = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> handleToggle(String package, bool enabled) async {
              if (package.isEmpty) return;
              final navigator = Navigator.of(context);
              await _toggleApp(package, enabled);
              if (!navigator.mounted) return;
              setModalState(() {});
            }

            Future<void> refreshApps() async {
              await _loadInstalledApps(modalSetState: setModalState);
            }

            if (!requestedModalLoad && _installedApps.isEmpty && !_loadingApps) {
              requestedModalLoad = true;
              Future.microtask(refreshApps);
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.apps),
                      const SizedBox(width: 8),
                      Text('Notification Sources', style: theme.textTheme.titleLarge),
                      const Spacer(),
                      IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Choose which apps Buddy can monitor to create reminders.', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: _loadingApps
                        ? const Center(child: CircularProgressIndicator())
                        : _installedApps.isEmpty
                        ? const Center(child: Text('No installed apps found or access not granted.', textAlign: TextAlign.center))
                        : ListView.separated(
                            itemCount: _installedApps.length,
                            separatorBuilder: (context, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final app = _installedApps[index];
                              final package = app.packageName.trim();
                              final label = _appLabel(app);
                              final toggled = _allowedApps.contains(package);
                              return SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(label), subtitle: package.isEmpty ? null : Text(package), value: toggled, onChanged: (value) => handleToggle(package, value));
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(onPressed: _loadingApps ? null : refreshApps, icon: const Icon(Icons.refresh), label: const Text('Refresh list')),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editReminder(Reminder reminder) async {
    final titleController = TextEditingController(text: reminder.title);
    final bodyController = TextEditingController(text: reminder.body);
    DateTime when = reminder.scheduledAt.isAfter(DateTime.now().subtract(const Duration(minutes: 1))) ? reminder.scheduledAt : DateTime.now().add(const Duration(minutes: 10));
    final picked = await showDatePicker(context: context, initialDate: when, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (!mounted) return;
    if (picked == null) return;
    final timeOfDay = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(when));
    if (!mounted) return;
    if (timeOfDay == null) return;
    final newWhen = DateTime(picked.year, picked.month, picked.day, timeOfDay.hour, timeOfDay.minute);
    final title = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit title'),
        content: TextField(controller: titleController),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, titleController.text), child: const Text('Save')),
        ],
      ),
    );
    if (!mounted) return;
    if (title == null) return;
    final body = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit body'),
        content: TextField(controller: bodyController),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, bodyController.text), child: const Text('Save')),
        ],
      ),
    );
    if (!mounted) return;
    if (body == null) return;
    await _reminders.updateReminder(id: reminder.id, title: title, body: body, when: newWhen, groupId: reminder.groupId, app: reminder.originApp, leadMinutes: reminder.leadMinutes);
    await _init();
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    await _reminders.cancel(reminder.id);
    await _init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders & Notifications')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(child: Text('Listen to notifications (Android only)')),
                Switch(value: _enabled, onChanged: _android ? _toggle : null),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _showAppFilterSheet, icon: const Icon(Icons.apps), label: const Text('Select notification apps')),
            const SizedBox(height: 12),
            if (_android) ...[
              Row(
                children: [
                  const Icon(Icons.info_outline),
                  TextButton.icon(
                    onPressed: () async {
                      await _reminders.cancelAll();
                      await _init();
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear all'),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Notification access must be granted in system settings.')),
                  TextButton(onPressed: _openNotificationAccessSettings, child: const Text('Open Settings')),
                ],
              ),
            ] else ...[
              const Text('iOS/web: Notification ingestion is not available due to platform limits.'),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(onPressed: _testReminder, icon: const Icon(Icons.notification_add), label: const Text('Send test reminder now')),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('Scheduled reminders'),
                const Spacer(),
                IconButton(tooltip: 'Refresh', onPressed: _init, icon: const Icon(Icons.refresh)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _scheduledReminders.isEmpty
                  ? const Center(child: Text('No pending reminders'))
                  : ListView.separated(
                      itemCount: _scheduledReminders.length,
                      separatorBuilder: (context, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final reminder = _scheduledReminders[index];
                        final title = reminder.title.trim().isNotEmpty ? reminder.title : 'Reminder';
                        final body = reminder.body;
                        final fmt = DateFormat('EEE, MMM d • h:mm a');
                        final trailing = fmt.format(reminder.scheduledAt);
                        return ListTile(
                          dense: true,
                          title: Text(title),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (body.isNotEmpty) Text(body), if ((reminder.originApp ?? '').isNotEmpty) Text('App: ${reminder.originApp}'), if (reminder.leadMinutes != null) Text('Lead: ${reminder.leadMinutes} min')]),
                          trailing: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(trailing, style: Theme.of(context).textTheme.bodySmall),
                              IconButton(tooltip: 'Edit', onPressed: () => _editReminder(reminder), icon: const Icon(Icons.edit_outlined)),
                              IconButton(tooltip: 'Delete', onPressed: () => _deleteReminder(reminder), icon: const Icon(Icons.delete_outline)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
