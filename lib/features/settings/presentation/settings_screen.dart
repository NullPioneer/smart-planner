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
    final notificationHealth = ref.watch(notificationHealthProvider);

    return SingleChildScrollView(
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 14, 16, 36)
          : const EdgeInsets.fromLTRB(16, 16, 16, 92),
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
              SizedBox(height: compact ? 12 : 14),
              SectionLabel(
                'Notifications',
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 10),
              GlassPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsTile(
                      key: const Key('notification-health-setting'),
                      icon: notificationHealth.value?.isHealthy == false
                          ? Icons.warning_amber_rounded
                          : Icons.verified_outlined,
                      title: 'Notification health',
                      subtitle: notificationHealth.when(
                        data: (health) => health.isHealthy
                            ? 'Ready for reminders and alarms'
                            : 'Permission needs attention',
                        loading: () => 'Checking permissions…',
                        error: (_, _) => 'Tap to check permissions',
                      ),
                      onTap: () => _showNotificationHealth(context, ref),
                    ),
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
              const SizedBox(height: 14),
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
                        'Planner Copy, Share Planner Copy, or Encrypted Planner '
                        'Copy. Readable reports are not password-protected. The '
                        'encrypted option uses a password that is never stored by '
                        'Smart Planner and can be saved through your chosen cloud '
                        'or email app.\n\n'
                        'Medicine-safety contacts also stay on this device. Call and '
                        'Email buttons only open your phone or email app; nothing is '
                        'called or sent unless you complete the action yourself.',
                  ),
                ),
              ),
              const SizedBox(height: 14),
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
                      key: const Key('encrypted-backup-setting'),
                      icon: Icons.lock_outline,
                      title: 'Encrypted Planner Copy',
                      subtitle: 'Password-protected copy for your cloud',
                      onTap: () => _encryptedBackupOptions(context, ref),
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
                      key: const Key('completed-cleanup-setting'),
                      icon: Icons.auto_delete_outlined,
                      title: 'Completed task cleanup',
                      subtitle: appSettings?.completedCleanupLabel ?? 'Off',
                      onTap: () => _pickCompletedCleanup(
                        context,
                        ref,
                        appSettings?.completedCleanupDays ?? 0,
                      ),
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
                      subtitle: 'Version 1.5.1',
                      showDivider: false,
                      onTap: () => _info(
                        context,
                        'About Smart Planner',
                        'Offline-first reminder and task planner\nVersion 1.5.1',
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

  void _openPage(BuildContext context, Widget page) {
    final navigator = Navigator.of(context);
    if (compact) navigator.pop();
    Future<void>.delayed(
      Duration.zero,
      () => navigator.push(MaterialPageRoute<void>(builder: (_) => page)),
    );
  }

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

  Future<void> _showNotificationHealth(
    BuildContext context,
    WidgetRef ref,
  ) async {
    var health = await ref.read(notificationHealthProvider.future);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Notification health'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HealthRow(
                label: 'Reminder notifications',
                enabled: health.notificationsEnabled,
              ),
              const SizedBox(height: 10),
              _HealthRow(
                label: 'Exact high-priority alarms',
                enabled: health.exactAlarmsEnabled,
              ),
              const SizedBox(height: 12),
              const Text(
                'Exact-alarm access is used only when you enable an alarm for '
                'a high-priority task.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            if (!health.isHealthy)
              FilledButton.icon(
                onPressed: () async {
                  health = await ref
                      .read(localNotificationServiceProvider)
                      .requestMissingHealthPermissions();
                  ref.invalidate(notificationHealthProvider);
                  if (dialogContext.mounted) setDialogState(() {});
                },
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Fix permissions'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCompletedCleanup(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Completed task cleanup'),
              subtitle: Text(
                'Old completed tasks move to Trash and can still be restored.',
              ),
            ),
            for (final option in const [0, 30, 90, 180])
              ListTile(
                leading: Icon(
                  current == option
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(option == 0 ? 'Off' : 'After $option days'),
                onTap: () => Navigator.pop(sheetContext, option),
              ),
          ],
        ),
      ),
    );
    if (selected == null || selected == current || !context.mounted) return;
    if (selected > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Enable completed task cleanup?'),
          content: Text(
            'Completed tasks older than $selected days will move to Trash. '
            'They are not deleted immediately and can still be restored.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Enable'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await ref
        .read(appSettingsControllerProvider.notifier)
        .setCompletedCleanupDays(selected);
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

  Future<void> _encryptedBackupOptions(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Encrypted Planner Copy'),
              subtitle: Text(
                'The password stays with you and is never stored by the app.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Create and share encrypted copy'),
              subtitle: const Text('Save to Drive, email, or another app'),
              onTap: () => Navigator.pop(sheetContext, 'create'),
            ),
            ListTile(
              leading: const Icon(Icons.lock_open_outlined),
              title: const Text('Unlock an encrypted copy'),
              subtitle: const Text('Create a readable text copy'),
              onTap: () => Navigator.pop(sheetContext, 'unlock'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    final password = await _requestBackupPassword(
      context,
      confirm: action == 'create',
    );
    if (password == null || !context.mounted) return;
    try {
      if (action == 'unlock') {
        final path = await ref
            .read(backupServiceProvider)
            .unlockEncryptedBackup(password);
        if (path != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unlocked copy saved to $path')),
          );
        }
        return;
      }
      final file = await ref
          .read(backupServiceProvider)
          .createEncryptedBackup(password);
      if (!context.mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          subject: 'Smart Planner encrypted copy',
          text:
              'Password-protected Smart Planner copy. Keep the password private.',
          files: [XFile(file.path, mimeType: 'application/octet-stream')],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Encrypted copy failed: $error')),
        );
      }
    }
  }

  Future<String?> _requestBackupPassword(
    BuildContext context, {
    required bool confirm,
  }) => showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BackupPasswordDialog(confirm: confirm),
  );

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

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog({required this.confirm});

  final bool confirm;

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.confirm ? 'Protect your copy' : 'Unlock your copy'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('encrypted-backup-password'),
            controller: _password,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              helperText: 'At least 8 characters',
            ),
          ),
          if (widget.confirm) ...[
            const SizedBox(height: 10),
            TextField(
              key: const Key('encrypted-backup-confirm-password'),
              controller: _confirmation,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm password'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_password.text.length < 8) {
            setState(() => _error = 'Use at least 8 characters.');
            return;
          }
          if (widget.confirm && _password.text != _confirmation.text) {
            setState(() => _error = 'Passwords do not match.');
            return;
          }
          Navigator.pop(context, _password.text);
        },
        child: Text(widget.confirm ? 'Create' : 'Unlock'),
      ),
    ],
  );
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        enabled ? Icons.check_circle : Icons.error_outline,
        color: enabled
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(label)),
      Text(enabled ? 'Ready' : 'Off'),
    ],
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
    this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary.withValues(alpha: .11),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 21),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
