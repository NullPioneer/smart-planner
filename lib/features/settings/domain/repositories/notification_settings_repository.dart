/// Persistence boundary for notification-related settings.
abstract interface class NotificationSettingsRepository {
  Future<String?> readNotificationSoundId();

  Future<void> writeNotificationSoundId(String id);
}
