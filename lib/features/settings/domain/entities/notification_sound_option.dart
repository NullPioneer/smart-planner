/// A notification sound that can be selected in application settings.
final class NotificationSoundOption {
  const NotificationSoundOption({
    required this.id,
    required this.label,
    this.androidResourceName,
    this.assetPath,
  }) : assert(
         (androidResourceName == null && assetPath == null) ||
             (androidResourceName != null && assetPath != null),
       );

  /// Stable value stored in local preferences.
  final String id;

  /// User-facing sound name.
  final String label;

  /// Android raw resource name, without its file extension.
  final String? androidResourceName;

  /// Flutter asset used to verify that the bundled sound is available.
  final String? assetPath;

  bool get isSystemDefault => androidResourceName == null;

  /// Android channel settings are immutable, so each sound owns a channel.
  // Android channel sound settings cannot be changed after creation. Keep the
  // version in the id so corrected sound settings reach existing installs.
  String get androidChannelId => 'reminders_sound_${id}_v3';
}

/// The single source of truth for sounds bundled with the application.
abstract final class NotificationSoundCatalog {
  static const systemDefault = NotificationSoundOption(
    id: 'system_default',
    label: 'Default system sound',
  );

  static const whatsappReminder = NotificationSoundOption(
    id: 'whatsapp_reminder',
    label: 'WhatsApp reminder',
    androidResourceName: 'whatsapp_reminder',
    assetPath: 'assets/notification_sounds/raw/whatsapp_reminder.mp3',
  );

  /// Sound selected automatically until the user makes an explicit choice.
  static const appDefault = whatsappReminder;

  static const gentleChime = NotificationSoundOption(
    id: 'gentle_chime',
    label: 'Gentle chime',
    androidResourceName: 'gentle_chime',
    assetPath: 'assets/notification_sounds/raw/gentle_chime.wav',
  );

  static const brightBell = NotificationSoundOption(
    id: 'bright_bell',
    label: 'Bright bell',
    androidResourceName: 'bright_bell',
    assetPath: 'assets/notification_sounds/raw/bright_bell.wav',
  );

  static const values = <NotificationSoundOption>[
    systemDefault,
    whatsappReminder,
    gentleChime,
    brightBell,
  ];

  static NotificationSoundOption? findById(String? id) {
    for (final sound in values) {
      if (sound.id == id) return sound;
    }
    return null;
  }
}
