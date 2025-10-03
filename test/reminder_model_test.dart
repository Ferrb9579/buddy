import 'package:buddy/models/reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reminder model', () {
    test('serializes and deserializes consistently', () {
      final reminder = Reminder(id: 42, title: 'Test Reminder', body: 'Study for the exam', scheduledAt: DateTime(2030, 1, 1, 9, 30), createdAt: DateTime(2029, 12, 31, 23, 59), originApp: 'com.example.calendar', groupId: 1001, leadMinutes: 30);

      final json = reminder.toJson();
      final decoded = Reminder.fromJson(json);

      expect(decoded.id, reminder.id);
      expect(decoded.title, reminder.title);
      expect(decoded.body, reminder.body);
      expect(decoded.scheduledAt, reminder.scheduledAt);
      expect(decoded.createdAt, reminder.createdAt);
      expect(decoded.originApp, reminder.originApp);
      expect(decoded.groupId, reminder.groupId);
      expect(decoded.leadMinutes, reminder.leadMinutes);
    });

    test('copyWith updates selected fields', () {
      final base = Reminder(id: 7, title: 'Original', body: 'Body', scheduledAt: DateTime.now().add(const Duration(hours: 1)), createdAt: DateTime.now());

      final updated = base.copyWith(title: 'Updated', leadMinutes: 15);

      expect(updated.id, base.id);
      expect(updated.title, 'Updated');
      expect(updated.body, base.body);
      expect(updated.leadMinutes, 15);
      expect(updated.groupId, base.groupId);
    });

    test('isInPast reflects scheduled time', () {
      final futureReminder = Reminder(id: 1, title: 'Future', body: '', scheduledAt: DateTime.now().add(const Duration(minutes: 5)), createdAt: DateTime.now());
      final pastReminder = futureReminder.copyWith(scheduledAt: DateTime.now().subtract(const Duration(minutes: 5)));

      expect(futureReminder.isInPast, isFalse);
      expect(pastReminder.isInPast, isTrue);
    });
  });
}
