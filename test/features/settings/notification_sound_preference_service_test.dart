import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reminder/features/settings/domain/entities/notification_sound_option.dart';
import 'package:smart_reminder/features/settings/domain/repositories/notification_settings_repository.dart';
import 'package:smart_reminder/features/settings/domain/services/notification_sound_preference_service.dart';

void main() {
  group('NotificationSoundPreferenceService', () {
    test('uses the supplied audio for a first-time user', () async {
      final repository = _MemoryRepository();
      final service = NotificationSoundPreferenceService(
        repository: repository,
        availability: const _Availability.all(),
      );

      final result = await service.load();

      expect(result, same(NotificationSoundCatalog.whatsappReminder));
      expect(repository.savedId, NotificationSoundCatalog.whatsappReminder.id);
    });

    test('loads a persisted bundled sound', () async {
      final repository = _MemoryRepository(
        NotificationSoundCatalog.gentleChime.id,
      );
      final service = NotificationSoundPreferenceService(
        repository: repository,
        availability: const _Availability.all(),
      );

      final result = await service.load();

      expect(result.id, NotificationSoundCatalog.gentleChime.id);
    });

    test('falls back and repairs an unknown persisted id', () async {
      final repository = _MemoryRepository('removed_sound');
      final service = NotificationSoundPreferenceService(
        repository: repository,
        availability: const _Availability.all(),
      );

      final result = await service.load();

      expect(result, same(NotificationSoundCatalog.systemDefault));
      expect(repository.savedId, NotificationSoundCatalog.systemDefault.id);
    });

    test('falls back when a selected asset is unavailable', () async {
      final repository = _MemoryRepository();
      final service = NotificationSoundPreferenceService(
        repository: repository,
        availability: const _Availability.onlySystemDefault(),
      );

      final result = await service.select(NotificationSoundCatalog.brightBell);

      expect(result, same(NotificationSoundCatalog.systemDefault));
      expect(repository.savedId, NotificationSoundCatalog.systemDefault.id);
    });
  });
}

final class _MemoryRepository implements NotificationSettingsRepository {
  _MemoryRepository([this.savedId]);

  String? savedId;

  @override
  Future<String?> readNotificationSoundId() async => savedId;

  @override
  Future<void> writeNotificationSoundId(String id) async {
    savedId = id;
  }
}

final class _Availability implements NotificationSoundAvailability {
  const _Availability.all() : onlyDefault = false;

  const _Availability.onlySystemDefault() : onlyDefault = true;

  final bool onlyDefault;

  @override
  Future<bool> isAvailable(NotificationSoundOption sound) async {
    return !onlyDefault || sound.isSystemDefault;
  }
}
