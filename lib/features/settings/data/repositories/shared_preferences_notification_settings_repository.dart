import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_reminder/features/settings/domain/repositories/notification_settings_repository.dart';

/// Stores the sound selection in the platform's local preferences store.
final class SharedPreferencesNotificationSettingsRepository
    implements NotificationSettingsRepository {
  SharedPreferencesNotificationSettingsRepository({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences;

  // Versioned once so existing installs adopt the bundled WhatsApp sound as
  // their new default. Choices made after this migration remain persisted.
  static const _notificationSoundKey = 'settings.notification_sound_id_v2';

  final SharedPreferencesAsync? _preferences;

  @override
  Future<String?> readNotificationSoundId() async {
    if (_preferences != null)
      return _preferences.getString(_notificationSoundKey);
    return (await SharedPreferences.getInstance()).getString(
      _notificationSoundKey,
    );
  }

  @override
  Future<void> writeNotificationSoundId(String id) async {
    if (_preferences != null) {
      await _preferences.setString(_notificationSoundKey, id);
      return;
    }
    await (await SharedPreferences.getInstance()).setString(
      _notificationSoundKey,
      id,
    );
  }
}
