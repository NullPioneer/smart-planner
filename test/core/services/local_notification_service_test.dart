import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reminder/core/services/local_notification_service.dart';
import 'package:smart_reminder/features/settings/domain/entities/notification_sound_option.dart';
import 'package:smart_reminder/features/settings/domain/repositories/notification_settings_repository.dart';
import 'package:smart_reminder/features/settings/domain/services/notification_sound_preference_service.dart';

void main() {
  late LocalNotificationService service;

  setUp(() {
    service = LocalNotificationService(
      soundPreferences: NotificationSoundPreferenceService(
        repository: _Repository(),
        availability: _Availability(),
      ),
    );
  });

  test('custom sounds map to an Android raw resource', () {
    final details = service.androidDetailsFor(
      NotificationSoundCatalog.gentleChime,
    );

    expect(
      details.channelId,
      contains(NotificationSoundCatalog.gentleChime.id),
    );
    expect(details.channelId, endsWith('_v3'));
    expect(details.sound, isA<RawResourceAndroidNotificationSound>());
    expect(details.sound?.sound, 'gentle_chime');
    expect(details.playSound, isTrue);
  });

  test('system default leaves Android sound unset', () {
    final details = service.androidDetailsFor(
      NotificationSoundCatalog.systemDefault,
    );

    expect(details.sound, isNull);
    expect(details.playSound, isTrue);
  });

  test('every catalog sound uses a distinct Android channel', () {
    final channelIds = NotificationSoundCatalog.values
        .map((sound) => service.androidDetailsFor(sound).channelId)
        .toSet();

    expect(channelIds, hasLength(NotificationSoundCatalog.values.length));
  });
}

final class _Repository implements NotificationSettingsRepository {
  @override
  Future<String?> readNotificationSoundId() async => null;

  @override
  Future<void> writeNotificationSoundId(String id) async {}
}

final class _Availability implements NotificationSoundAvailability {
  @override
  Future<bool> isAvailable(NotificationSoundOption sound) async => true;
}
