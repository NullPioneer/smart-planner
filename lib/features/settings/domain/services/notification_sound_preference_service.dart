import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:smart_reminder/features/settings/domain/entities/notification_sound_option.dart';
import 'package:smart_reminder/features/settings/domain/repositories/notification_settings_repository.dart';

/// Tests whether a catalog entry is actually bundled with this application.
abstract interface class NotificationSoundAvailability {
  Future<bool> isAvailable(NotificationSoundOption sound);
}

final class AssetBundleNotificationSoundAvailability
    implements NotificationSoundAvailability {
  AssetBundleNotificationSoundAvailability({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  @override
  Future<bool> isAvailable(NotificationSoundOption sound) async {
    if (sound.isSystemDefault) return true;

    try {
      await _bundle.load(sound.assetPath!);
      return true;
    } on FlutterError {
      return false;
    } on Exception {
      return false;
    }
  }
}

/// Resolves persisted selections and guarantees a usable fallback.
final class NotificationSoundPreferenceService {
  NotificationSoundPreferenceService({
    required NotificationSettingsRepository repository,
    required NotificationSoundAvailability availability,
  }) : _repository = repository,
       _availability = availability;

  final NotificationSettingsRepository _repository;
  final NotificationSoundAvailability _availability;

  Future<NotificationSoundOption> load() async {
    final savedId = await _repository.readNotificationSoundId();
    final candidate = savedId == null
        ? NotificationSoundCatalog.appDefault
        : NotificationSoundCatalog.findById(savedId);

    if (candidate == null || !await _availability.isAvailable(candidate)) {
      await _persistSystemFallbackIfNeeded(savedId);
      return NotificationSoundCatalog.systemDefault;
    }

    if (savedId == null) {
      await _repository.writeNotificationSoundId(candidate.id);
    }

    return candidate;
  }

  /// Saves [requested], returning the actual selection after availability checks.
  Future<NotificationSoundOption> select(
    NotificationSoundOption requested,
  ) async {
    final selected = await _availability.isAvailable(requested)
        ? requested
        : NotificationSoundCatalog.systemDefault;
    await _repository.writeNotificationSoundId(selected.id);
    return selected;
  }

  Future<void> _persistSystemFallbackIfNeeded(String? savedId) async {
    if (savedId != NotificationSoundCatalog.systemDefault.id) {
      await _repository.writeNotificationSoundId(
        NotificationSoundCatalog.systemDefault.id,
      );
    }
  }
}
