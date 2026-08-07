# Smart Reminder & Task Planner

Offline-first Flutter planner built with Riverpod, Drift SQLite, Material 3,
GoRouter, `table_calendar`, `fl_chart`, and Android local notifications.

## Included

- Dashboard with daily timeline, progress, pinned/upcoming/overdue tasks, recent
  completions, and daily summary
- Month/week/day calendar, deadline heatmap, colored task markers, and
  long-press creation
- Task CRUD, search, categories, priorities, sorting, filters, pinning,
  completion, conflict suggestions, and quick templates
- Multiple notification offsets, recurrence/end dates, Complete/Open/Snooze
  actions, boot rescheduling, exact-alarm fallback, and overdue detection
- Unlimited checklist and notes, local image/PDF/file attachments, and voice
  recording/playback/deletion
- History, 30-day trash, restore/permanent delete, productivity statistics,
  pie/bar/line charts, and JSON import/restore plus JSON/SQLite export
- Persistent light/dark/system theme, default reminder time, and notification
  sound preference
- Bundled WhatsApp reminder audio with graceful system-default fallback

## Run on Android

Start an Android emulator in Android Studio's Device Manager (or connect a
phone with USB debugging), then run:

```powershell
flutter devices --device-timeout 60
flutter run -d <android-device-id>
```

If the emulator ID disappears, restart it and run `flutter devices` again;
device IDs such as `emulator-5554` are only valid while that emulator is alive.

The ready-to-install debug APK is at:

`build/app/outputs/flutter-apk/app-debug.apk`

## Check reminders and sound

1. Allow notification, exact-alarm, and microphone permissions when prompted.
2. Open Settings → Notification Sound and choose **WhatsApp Reminder**.
3. Tap **Send test notification**.
4. Create a task 2–3 minutes in the future with **Exact time** selected.
5. Background the app and verify the sound plus Complete, Snooze, and Open
   actions.

Android 8+ locks a channel's sound after creation. Every bundled sound therefore
uses a separate stable channel ID. Audio files are in
`assets/notification_sounds/raw/` and are also packaged as Android `res/raw`
resources.

## Verification

```powershell
dart analyze
flutter test --concurrency=1
flutter build apk --debug
```
