import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:buddy/services/notification_ingest_service.dart';
import 'package:buddy/services/reminder_service.dart';
import 'package:intl/intl.dart';
import 'package:android_intent_plus/android_intent.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  final _ingest = NotificationIngestService();
  final _reminders = ReminderService();
  bool _enabled = true;
  bool _hasPermission = false;
  bool _android = false;
  List<Map<String, String>> _pending = const [];
  List<Map<String, dynamic>> _meta = const [];
  final _appFilterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _android = !kIsWeb && Platform.isAndroid;
    _init();
  }

  Future<void> _init() async {
    await _reminders.initialize();
    final en = await _ingest.getEnabled();
    // notifications package doesn't expose direct permission state reliably; keep cached flag only
    bool perm = _hasPermission;
    final pending = await _reminders.listPending();
    final meta = await _reminders.getScheduledMeta();
    final allowedApps = await _ingest.getAllowedApps();
    _appFilterController.text = allowedApps.join(', ');
    setState(() {
      _enabled = en;
      _hasPermission = perm;
      _pending = pending;
      _meta = meta;
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

  Future<void> _editReminder(Map<String, dynamic> meta) async {
    final id = meta['id'] as int?;
    if (id == null) return;
    final titleController = TextEditingController(text: (meta['title'] ?? '').toString());
    final bodyController = TextEditingController(text: (meta['body'] ?? '').toString());
    final whenStr = (meta['when'] ?? '').toString();
    DateTime? when = DateTime.tryParse(whenStr)?.toLocal();
    if (when == null) when = DateTime.now().add(const Duration(minutes: 10));
    final picked = await showDatePicker(context: context, initialDate: when, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked == null) return;
    final timeOfDay = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(when));
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
    if (body == null) return;
    await _reminders.updateReminder(id: id, title: title, body: body, when: newWhen);
    await _init();
  }

  Future<void> _deleteReminder(Map<String, dynamic> meta) async {
    final id = meta['id'] as int?;
    if (id == null) return;
    await _reminders.cancel(id);
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
            Row(
              children: [
                const Text('App filter for listener (manual): '),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _appFilterController,
                    decoration: const InputDecoration(hintText: 'e.g. com.whatsapp, com.google.android.gm'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final parts = _appFilterController.text.split(',');
                    final list = parts.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                    await _ingest.setAllowedApps(list);
                    setState(() {});
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
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
              child: _pending.isEmpty
                  ? const Center(child: Text('No pending reminders'))
                  : ListView.separated(
                      itemCount: _pending.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final it = _pending[index];
                        final id = it['id'] ?? '';
                        final title = it['title']?.trim().isNotEmpty == true ? it['title']! : 'Reminder';
                        final body = it['body'] ?? '';
                        final meta = _meta.firstWhere((m) => m['id']?.toString() == id, orElse: () => const {});
                        final whenStr = meta['when']?.toString();
                        String trailing = '#$id';
                        if (whenStr != null) {
                          final dt = DateTime.tryParse(whenStr)?.toLocal();
                          if (dt != null) {
                            final fmt = DateFormat('EEE, MMM d • h:mm a');
                            trailing = fmt.format(dt);
                          }
                        }
                        return ListTile(
                          dense: true,
                          title: Text(title),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (body.isNotEmpty) Text(body), if (meta.isNotEmpty && meta['app'] != null) Text('App: ${meta['app']}'), if (meta.isNotEmpty && meta['leadMinutes'] != null) Text('Lead: ${meta['leadMinutes']} min')]),
                          trailing: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(trailing, style: Theme.of(context).textTheme.bodySmall),
                              IconButton(tooltip: 'Edit', onPressed: meta.isNotEmpty ? () => _editReminder(meta) : null, icon: const Icon(Icons.edit_outlined)),
                              IconButton(tooltip: 'Delete', onPressed: meta.isNotEmpty ? () => _deleteReminder(meta) : null, icon: const Icon(Icons.delete_outline)),
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
