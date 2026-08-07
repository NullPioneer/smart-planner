import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smart_reminder/core/providers/app_providers.dart';
import 'package:smart_reminder/features/settings/application/notification_sound_controller.dart';
import 'package:smart_reminder/features/settings/application/app_settings_controller.dart';
import 'package:smart_reminder/features/tasks/presentation/history_trash_screen.dart';
import 'package:smart_reminder/features/tasks/presentation/statistics_screen.dart';
import 'package:smart_reminder/features/settings/domain/entities/notification_sound_option.dart';
import 'package:smart_reminder/shared/widgets/glass_panel.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.compact = false, this.onClose});

  final bool compact;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSound = ref.watch(notificationSoundControllerProvider);
    final appSettings = ref.watch(appSettingsControllerProvider).value;

    return SingleChildScrollView(
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 14, 16, 36)
          : const EdgeInsets.fromLTRB(20, 26, 20, 112),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: compact ? 42 : 0,
                    height: compact ? 42 : 0,
                    margin: EdgeInsets.only(right: compact ? 11 : 0),
                    child: compact
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/branding/smart_planner_logo.png',
                            ),
                          )
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      'Settings',
                      style: compact
                          ? Theme.of(context).textTheme.headlineMedium
                          : Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      key: const Key('close-settings-drawer'),
                      tooltip: 'Close settings',
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Personalize your planner experience',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: compact ? 18 : 22),
              const SectionLabel('Appearance'),
              const SizedBox(height: 10),
              GlassPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.dark_mode_outlined,
                      title: 'Theme',
                      subtitle: _themeLabel(
                        appSettings?.themeMode ?? ThemeMode.dark,
                      ),
                      onTap: () => _showThemePicker(context, ref),
                    ),
                    _SettingsTile(
                      icon: Icons.accessibility_new_outlined,
                      title: 'Accessibility',
                      subtitle: 'Supports system text size and screen readers',
                      showDivider: false,
                      onTap: () => _info(
                        context,
                        'Accessibility',
                        'Smart Planner follows the device text scale, contrast, and screen-reader settings.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SectionLabel(
                'Notifications',
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 10),
              GlassPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    selectedSound.when(
                      data: (sound) => _SettingsTile(
                        key: const Key('notification-sound-setting'),
                        icon: Icons.notifications_active_outlined,
                        title: 'Notification Sound',
                        subtitle: sound.label,
                        onTap: () => _openSoundPicker(context, ref),
                      ),
                      loading: () => const ListTile(
                        leading: Icon(Icons.notifications_active_outlined),
                        title: Text('Notification Sound'),
                        subtitle: Text('Loading…'),
                        trailing: Icon(Icons.hourglass_empty),
                      ),
                      error: (error, stackTrace) => ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: const Text('Notification Sound'),
                        subtitle: const Text('Could not load setting'),
                        trailing: IconButton(
                          tooltip: 'Retry',
                          onPressed: () => ref.invalidate(
                            notificationSoundControllerProvider,
                          ),
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.schedule_outlined,
                      title: 'Default Reminder Time',
                      subtitle:
                          appSettings?.defaultTime.format(context) ??
                          '09:00 AM',
                      showDivider: false,
                      onTap: () => _pickDefaultTime(
                        context,
                        ref,
                        appSettings?.defaultTime ??
                            const TimeOfDay(hour: 9, minute: 0),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const SectionLabel('Privacy & security'),
              const SizedBox(height: 10),
              GlassPanel(
                padding: EdgeInsets.zero,
                child: _SettingsTile(
                  key: const Key('privacy-storage-setting'),
                  icon: Icons.shield_outlined,
                  title: 'Local-only storage',
                  subtitle: 'No account, cloud sync, or Internet access',
                  showDivider: false,
                  onTap: () => _info(
                    context,
                    'Your data stays private',
                    'Tasks, reminders, notes, and attachments are stored only '
                        'inside this app on your device. Smart Planner does not '
                        'request Internet access and cannot upload your data.\n\n'
                        'Android protects the app with its private sandbox and '
                        'device encryption while your phone is locked. The local '
                        'planner database is not separately password-encrypted.\n\n'
                        'A planner copy leaves the app only when you choose Save '
                        'Planner Copy or Share Planner Copy. Exported copies '
                        'are readable text reports and are not currently protected by '
                        'a separate password, so keep them in a private place.',
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const SectionLabel('Your data'),
              const SizedBox(height: 10),
              GlassPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.cloud_upload_outlined,
                      title: 'Save Planner Copy',
                      subtitle:
                          'Create a readable report on your phone or cloud',
                      onTap: () => _export(context, ref),
                    ),
                    _SettingsTile(
                      icon: Icons.forward_to_inbox_outlined,
                      title: 'Share Planner Copy',
                      subtitle: 'Send the readable report to another app',
                      onTap: () => _shareBackup(context, ref),
                    ),
                    _SettingsTile(
                      icon: Icons.insights_outlined,
                      title: 'Statistics',
                      subtitle: 'Charts and productivity insights',
                      onTap: () => _openPage(context, const StatisticsScreen()),
                    ),
                    _SettingsTile(
                      icon: Icons.history,
                      title: 'History & Trash',
                      subtitle: 'Restore or permanently delete reminders',
                      onTap: () =>
                          _openPage(context, const HistoryTrashScreen()),
                    ),
                    _SettingsTile(
                      icon: Icons.delete_forever_outlined,
                      title: 'Clear Data',
                      subtitle: 'Remove all reminders and history',
                      onTap: () => _clearData(context, ref),
                    ),
                    _SettingsTile(
                      icon: Icons.info_outline,
                      title: 'About Smart Planner',
                      subtitle: 'Version 1.0.0',
                      showDivider: false,
                      onTap: () => _info(
                        context,
                        'About Smart Planner',
                        'Offline-first reminder and task planner\nVersion 1.0.0',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => mode == ThemeMode.system
      ? 'System default'
      : mode.name[0].toUpperCase() + mode.name.substring(1);

  void _openPage(BuildContext context, Widget page) {
    final navigator = Navigator.of(context);
    if (compact) navigator.pop();
    Future<void>.delayed(
      Duration.zero,
      () => navigator.push(MaterialPageRoute<void>(builder: (_) => page)),
    );
  }

  Future<void> _showThemePicker(BuildContext context, WidgetRef ref) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in ThemeMode.values)
                ListTile(
                  leading: Icon(
                    mode == ThemeMode.light
                        ? Icons.light_mode
                        : mode == ThemeMode.dark
                        ? Icons.dark_mode
                        : Icons.settings_brightness,
                  ),
                  title: Text(_themeLabel(mode)),
                  onTap: () async {
                    await ref
                        .read(appSettingsControllerProvider.notifier)
                        .setTheme(mode);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      );
  Future<void> _pickDefaultTime(
    BuildContext context,
    WidgetRef ref,
    TimeOfDay initial,
  ) async {
    final time = await showTimePicker(context: context, initialTime: initial);
    if (time != null) {
      await ref
          .read(appSettingsControllerProvider.notifier)
          .setDefaultTime(time);
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final service = ref.read(backupServiceProvider);
      final path = await service.exportTextBackup();
      if (context.mounted && path != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Planner copy saved to $path')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _shareBackup(BuildContext context, WidgetRef ref) async {
    try {
      final file = await ref
          .read(backupServiceProvider)
          .createShareableBackup();
      if (!context.mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final result = await SharePlus.instance.share(
        ShareParams(
          subject: 'Smart Planner readable copy',
          text: 'A private, readable planner report created by Smart Planner.',
          files: [XFile(file.path, mimeType: 'text/plain')],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (context.mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Planner copy shared.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share backup: $error')),
        );
      }
    }
  }

  Future<void> _clearData(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'All reminders, files, and history will be removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await ref.read(taskRepositoryProvider).clearAllData();
      await ref.read(localMediaServiceProvider).clearOwnedFiles();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Planner data cleared.')));
      }
    }
  }

  Future<void> _info(BuildContext context, String title, String message) =>
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  Future<void> _showSoundPicker(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, child) {
          final soundState = ref.watch(notificationSoundControllerProvider);
          final selected = soundState.value;

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.78,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: Text(
                        'Notification Sound',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    for (final sound in NotificationSoundCatalog.values)
                      ListTile(
                        key: ValueKey('sound-option-${sound.id}'),
                        leading: Icon(
                          sound.isSystemDefault
                              ? Icons.phone_android
                              : Icons.music_note,
                        ),
                        title: Text(sound.label),
                        trailing: selected?.id == sound.id
                            ? const Icon(Icons.check_circle)
                            : null,
                        enabled: !soundState.isLoading,
                        onTap: () async {
                          final actual = await ref
                              .read(
                                notificationSoundControllerProvider.notifier,
                              )
                              .select(sound);
                          if (!sheetContext.mounted || actual == null) return;

                          if (actual.id != sound.id && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'That sound is unavailable. Using the system default.',
                                ),
                              ),
                            );
                          }
                          await _sendDemoNotification(context, ref);
                        },
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSoundPicker(BuildContext context, WidgetRef ref) async {
    await _sendDemoNotification(context, ref, showSuccess: false);
    if (context.mounted) await _showSoundPicker(context, ref);
  }

  Future<void> _sendDemoNotification(
    BuildContext context,
    WidgetRef ref, {
    bool showSuccess = true,
  }) async {
    try {
      final shown = await ref
          .read(localNotificationServiceProvider)
          .showDemoNotification();
      if (!context.mounted) return;
      if (shown && !showSuccess) return;
      final selected = ref.read(notificationSoundControllerProvider).value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shown
                ? 'Demo sent with ${selected?.label ?? 'the selected sound'}. '
                      'If it is silent, turn off Do Not Disturb and raise notification volume.'
                : 'Notification permission was not granted.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to send the demo notification.')),
      );
    }
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: theme.dividerColor))
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary.withValues(alpha: .11),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 21),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
