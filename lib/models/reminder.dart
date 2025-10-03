import 'package:flutter/foundation.dart';

@immutable
class Reminder {
  const Reminder({required this.id, required this.title, required this.body, required this.scheduledAt, required this.createdAt, this.originApp, this.groupId, this.leadMinutes});

  final int id;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final DateTime createdAt;
  final String? originApp;
  final int? groupId;
  final int? leadMinutes;

  bool get isInPast => scheduledAt.isBefore(DateTime.now());

  Reminder copyWith({int? id, String? title, String? body, DateTime? scheduledAt, DateTime? createdAt, String? originApp, int? groupId, int? leadMinutes}) {
    return Reminder(id: id ?? this.id, title: title ?? this.title, body: body ?? this.body, scheduledAt: scheduledAt ?? this.scheduledAt, createdAt: createdAt ?? this.createdAt, originApp: originApp ?? this.originApp, groupId: groupId ?? this.groupId, leadMinutes: leadMinutes ?? this.leadMinutes);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'body': body, 'scheduledAt': scheduledAt.toIso8601String(), 'createdAt': createdAt.toIso8601String(), if (originApp != null) 'originApp': originApp, if (groupId != null) 'groupId': groupId, if (leadMinutes != null) 'leadMinutes': leadMinutes};
  }

  static Reminder fromJson(Map<String, dynamic> json) {
    return Reminder(id: _parseInt(json['id']), title: (json['title'] ?? '').toString(), body: (json['body'] ?? '').toString(), scheduledAt: _parseDate(json['scheduledAt']), createdAt: _parseDate(json['createdAt']), originApp: json['originApp']?.toString(), groupId: _tryParseInt(json['groupId']), leadMinutes: _tryParseInt(json['leadMinutes']));
  }

  static int _parseInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? DateTime.now().millisecondsSinceEpoch;
  }

  static int? _tryParseInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString());
  }

  static DateTime _parseDate(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}
