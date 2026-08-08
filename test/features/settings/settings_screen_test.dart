import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reminder/core/providers/app_providers.dart';
import 'package:smart_reminder/features/settings/domain/entities/notification_sound_option.dart';
import 'package:smart_reminder/features/settings/domain/repositories/notification_settings_repository.dart';
import 'package:smart_reminder/features/settings/domain/services/notification_sound_preference_service.dart';
import 'package:smart_reminder/main.dart';

void main() {
  testWidgets('selects and persists a bundled notification sound', (
    tester,
  ) async {
    final repository = _MemoryRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationSettingsRepositoryProvider.overrideWithValue(repository),
          notificationSoundAvailabilityProvider.overrideWithValue(
            _Availability(),
          ),
        ],
        child: const SmartReminderApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-side-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-full-settings')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('notification-health-setting')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('encrypted-backup-setting')), findsOneWidget);
    expect(find.byKey(const Key('completed-cleanup-setting')), findsOneWidget);

    expect(
      find.text(NotificationSoundCatalog.whatsappReminder.label),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('notification-sound-setting')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        ValueKey('sound-option-${NotificationSoundCatalog.brightBell.id}'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.savedId, NotificationSoundCatalog.brightBell.id);
    expect(find.text(NotificationSoundCatalog.brightBell.label), findsWidgets);
  });

  testWidgets('encrypted copy and cleanup controls are user-facing', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SmartReminderApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-side-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-full-settings')));
    await tester.pumpAndSettle();

    final encrypted = find.byKey(const Key('encrypted-backup-setting'));
    await tester.ensureVisible(encrypted);
    await tester.pumpAndSettle();
    await tester.tap(encrypted);
    await tester.pumpAndSettle();
    expect(find.text('Create and share encrypted copy'), findsOneWidget);
    expect(find.text('Unlock an encrypted copy'), findsOneWidget);
    await tester.tap(find.text('Create and share encrypted copy'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('encrypted-backup-password')), findsOneWidget);
    expect(
      find.byKey(const Key('encrypted-backup-confirm-password')),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    final cleanup = find.byKey(const Key('completed-cleanup-setting'));
    await tester.ensureVisible(cleanup);
    await tester.pumpAndSettle();
    await tester.tap(cleanup);
    await tester.pumpAndSettle();
    expect(find.text('After 30 days'), findsOneWidget);
    expect(find.text('After 90 days'), findsOneWidget);
    expect(find.text('After 180 days'), findsOneWidget);
  });
}

final class _MemoryRepository implements NotificationSettingsRepository {
  String? savedId;

  @override
  Future<String?> readNotificationSoundId() async => savedId;

  @override
  Future<void> writeNotificationSoundId(String id) async {
    savedId = id;
  }
}

final class _Availability implements NotificationSoundAvailability {
  @override
  Future<bool> isAvailable(NotificationSoundOption sound) async => true;
}
