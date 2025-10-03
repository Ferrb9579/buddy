# buddy

Buddy is a cross-platform productivity assistant that ingests device notifications, summarises important events, and schedules actionable reminders on your behalf.

## Reminder system (September 2025)

The reminder pipeline was rebuilt from scratch to provide deterministic scheduling, richer metadata, and safer persistence. The core primitives now live in `lib/services/reminder_service.dart` and expose a high-level API:

- Call `await ReminderService().initialize()` once during app start (already wired in `main.dart`).
- Create reminders with `scheduleReminder`, which returns a `Reminder` model containing the generated notification ID, scheduled time, and optional metadata such as the originating app or lead time.
- Retrieve the current queue with `getScheduledReminders()`. The service merges pending notifications from the OS with locally persisted copies so the UI stays in sync, even if the OS rehydrates reminders after a reboot.
- Update or cancel reminders through `updateReminder` and `cancel`/`cancelAll` respectively. Persistence is handled automatically.

`lib/pages/reminders_page.dart` surfaces these APIs with a management UI, while `NotificationIngestService` classifies incoming notifications and feeds the scheduler.

### Key behaviour changes

- Time zones are initialised once and cached; fallbacks default to UTC to prevent crashes when the platform API is unavailable.
- Reminder metadata is stored under the new `buddy_reminders_v2` key with automatic migration from legacy payloads.
- Pending reminders are deduplicated with the platform notification store, avoiding orphaned entries after system restarts.
- Lead reminders inherit the primary reminder ID as their `groupId`, simplifying clean-up and display logic.

## Development

Standard Flutter tooling applies:

```powershell
flutter pub get
flutter analyze
flutter test
```

Widget tests live under `test/`. See `test/reminder_model_test.dart` for an example covering the reminder data model.
