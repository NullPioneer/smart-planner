import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:smart_reminder/core/providers/app_providers.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';
import 'package:smart_reminder/features/tasks/presentation/add_task_screen.dart';
import 'package:smart_reminder/features/tasks/presentation/attachment_viewer_screen.dart';
import 'package:smart_reminder/features/tasks/presentation/completion_reward_feedback.dart';
import 'package:smart_reminder/shared/widgets/glass_panel.dart';
import 'package:url_launcher/url_launcher.dart';

enum _FileAction { play, saveCopy, share, delete }

class TaskDetailsScreen extends ConsumerStatefulWidget {
  const TaskDetailsScreen({
    required this.taskId,
    this.focusIncompleteChecklist = false,
    super.key,
  });

  final String taskId;
  final bool focusIncompleteChecklist;
  @override
  ConsumerState<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends ConsumerState<TaskDetailsScreen> {
  String? _playing;
  final AudioPlayer _player = AudioPlayer();
  final GlobalKey _focusedIncompleteKey = GlobalKey();
  bool _focusScheduled = false;
  bool _highlightIncomplete = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskDetailsProvider(widget.taskId));
    return Scaffold(
      appBar: AppBar(title: const Text('Reminder Details')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load reminder: $e')),
        data: (details) => details == null
            ? const Center(child: Text('This reminder no longer exists.'))
            : _content(details),
      ),
    );
  }

  Widget _content(TaskDetails d) {
    final task = d.task;
    final firstIncompleteItem = widget.focusIncompleteChecklist
        ? d.checklist.where((item) => !item.isChecked).firstOrNull
        : null;
    _scheduleIncompleteFocus(firstIncompleteItem?.id);
    final category = ref
        .watch(taskCategoriesProvider)
        .value
        ?.where((c) => c.id == task.categoryId)
        .firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(task.priority.name.toUpperCase())),
                  if (category != null) Chip(label: Text(category.name)),
                  if (task.isPinned)
                    const Chip(
                      avatar: Icon(Icons.push_pin, size: 16),
                      label: Text('Pinned'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                task.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(task.description),
              ],
              const Divider(height: 28),
              _Info(
                Icons.event,
                DateFormat('EEEE, d MMMM y').format(task.dueAt),
              ),
              _Info(Icons.schedule, DateFormat('h:mm a').format(task.dueAt)),
              if (task.priority == TaskPriority.high && task.alarmEnabled)
                const _Info(
                  Icons.alarm_rounded,
                  'Alarm enabled at the due time',
                ),
              _Info(
                Icons.notifications_active,
                d.reminders
                    .map(
                      (r) => r.offsetMinutes == 0
                          ? 'At due time'
                          : '${r.offsetMinutes} min before',
                    )
                    .join(', '),
              ),
              if (task.repeatType != TaskRepeatType.never)
                _Info(
                  Icons.repeat,
                  task.repeatType == TaskRepeatType.everyXDays
                      ? 'Every ${task.repeatInterval} days'
                      : task.repeatType.name,
                ),
              if (task.notes.isNotEmpty) ...[
                const Divider(height: 28),
                Text('Notes', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                Text(task.notes),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (task.isMedicineSafetyReminder) ...[
          _section('Medicine safety', Icons.health_and_safety_outlined, [
            const Text(
              'These details were entered by the user for quick access. Smart Planner never calls or emails anyone automatically.',
            ),
            const SizedBox(height: 10),
            if (task.emergencyContactNumbers.isEmpty &&
                task.emergencyEmail.isEmpty)
              const Text('No emergency contacts saved. Tap Edit to add them.'),
            for (final number in task.emergencyContactNumbers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined),
                title: Text(number),
                subtitle: const Text('Opens the phone dialler'),
                trailing: FilledButton.tonalIcon(
                  onPressed: () => _dialEmergencyContact(number),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call'),
                ),
              ),
            if (task.emergencyEmail.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined),
                title: Text(task.emergencyEmail),
                subtitle: const Text(
                  'Opens a pre-filled email for you to review',
                ),
                trailing: FilledButton.tonalIcon(
                  onPressed: () => _composeMedicineEmail(task),
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Email'),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Verify medicine and dosage information with a healthcare professional. For an emergency, contact local emergency services.',
              style: TextStyle(fontSize: 12),
            ),
          ]),
          const SizedBox(height: 14),
        ],
        _section('Checklist', Icons.checklist, [
          if (d.checklist.isEmpty) const Text('No checklist items.'),
          for (final item in d.checklist)
            _checklistTile(
              item,
              isFocusTarget: item.id == firstIncompleteItem?.id,
            ),
          if (d.checklist.isNotEmpty)
            LinearProgressIndicator(value: d.checklistProgress),
        ]),
        const SizedBox(height: 14),
        _section('Attachments', Icons.attach_file, [
          if (d.attachments.isEmpty)
            const Text('No attachments. Tap Edit to add one.'),
          for (final item in d.attachments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  item.type == TaskAttachmentType.image &&
                      File(item.path).existsSync()
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(item.path),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.insert_drive_file),
              title: Text(item.displayName),
              subtitle: Text(
                item.type == TaskAttachmentType.pdf
                    ? 'PDF document • Tap to view'
                    : item.displayName.toLowerCase().endsWith('.docx')
                    ? 'Word document • Tap to view'
                    : item.type == TaskAttachmentType.image
                    ? 'Image • Tap to view'
                    : 'File • Tap to view',
              ),
              onTap: () => _openAttachment(item),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<_FileAction>(
                    tooltip: 'Attachment options',
                    onSelected: (action) =>
                        _handleAttachmentAction(item, action),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _FileAction.saveCopy,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.download_outlined),
                          title: Text('Save a copy'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _FileAction.share,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.share_outlined),
                          title: Text('Share'),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Delete attachment',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteAttachment(item),
                  ),
                ],
              ),
            ),
        ]),
        const SizedBox(height: 14),
        _section('Voice Notes', Icons.mic_none, [
          if (d.voiceNotes.isEmpty)
            const Text('No voice notes. Tap Edit to record one.'),
          for (final note in d.voiceNotes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: IconButton(
                icon: Icon(_playing == note.id ? Icons.stop : Icons.play_arrow),
                onPressed: () => _play(note),
              ),
              title: Text('Voice note • ${note.durationSeconds}s'),
              subtitle: Text(
                '${DateFormat('d MMM, h:mm a').format(note.createdAt)} • Tap for details',
              ),
              onTap: () => _showVoiceNote(note),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<_FileAction>(
                    tooltip: 'Voice note options',
                    onSelected: (action) => _handleVoiceAction(note, action),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _FileAction.saveCopy,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.download_outlined),
                          title: Text('Save a copy'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _FileAction.share,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.share_outlined),
                          title: Text('Share'),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Delete voice note',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteVoice(note),
                  ),
                ],
              ),
            ),
        ]),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () => _edit(d),
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
            ),
            OutlinedButton.icon(
              onPressed: () => _snooze(task),
              icon: const Icon(Icons.snooze),
              label: const Text('Snooze'),
            ),
            OutlinedButton.icon(
              onPressed: () => ref
                  .read(taskRepositoryProvider)
                  .setPinned(task.id, pinned: !task.isPinned)
                  .then(
                    (_) => ref.invalidate(taskDetailsProvider(widget.taskId)),
                  ),
              icon: const Icon(Icons.push_pin_outlined),
              label: Text(task.isPinned ? 'Unpin' : 'Pin'),
            ),
            FilledButton.icon(
              onPressed: () => _toggleCompleted(task),
              icon: const Icon(Icons.check),
              label: Text(task.isCompleted ? 'Reopen' : 'Complete'),
            ),
            TextButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        ),
      ],
    );
  }

  GlassPanel _section(String title, IconData icon, List<Widget> children) =>
      GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );

  Future<void> _dialEmergencyContact(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone app could open this number.')),
      );
    }
  }

  Future<void> _composeMedicineEmail(PlannerTask task) async {
    final prescriptionNotes = task.notes.trim().isEmpty
        ? 'No prescribed medicine information was added to Notes.'
        : task.notes.trim();
    final body =
        '''Medicine reminder: ${task.title}
Due: ${DateFormat('d MMM y, h:mm a').format(task.dueAt)}

Prescribed medicine information entered in Smart Planner:
$prescriptionNotes

Please verify this information with the prescribing healthcare professional.''';
    final uri = Uri(
      scheme: 'mailto',
      path: task.emergencyEmail,
      query: _encodeQueryParameters({
        'subject': 'Medicine information - ${task.title}',
        'body': body,
      }),
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email app could create this message.'),
        ),
      );
    }
  }

  String _encodeQueryParameters(Map<String, String> parameters) => parameters
      .entries
      .map(
        (entry) =>
            '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
      )
      .join('&');

  Widget _checklistTile(
    ChecklistItemModel item, {
    required bool isFocusTarget,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedScale(
      key: isFocusTarget ? _focusedIncompleteKey : null,
      scale: isFocusTarget && _highlightIncomplete ? 1.045 : 1,
      alignment: Alignment.center,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        key: isFocusTarget
            ? const Key('focused-incomplete-checklist-item')
            : null,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isFocusTarget && _highlightIncomplete
              ? colorScheme.primary.withValues(alpha: .16)
              : Colors.transparent,
          border: isFocusTarget && _highlightIncomplete
              ? Border.all(
                  color: colorScheme.primary.withValues(alpha: .75),
                  width: 1.5,
                )
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: CheckboxListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(item.title),
          value: item.isChecked,
          onChanged: (value) async {
            await ref
                .read(taskRepositoryProvider)
                .setChecklistItemChecked(item.id, checked: value ?? false);
            ref.invalidate(taskDetailsProvider(widget.taskId));
          },
        ),
      ),
    );
  }

  void _scheduleIncompleteFocus(String? itemId) {
    if (!widget.focusIncompleteChecklist || itemId == null || _focusScheduled) {
      return;
    }
    _focusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      final targetContext = _focusedIncompleteKey.currentContext;
      if (targetContext == null || !targetContext.mounted) return;
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        alignment: .34,
      );
      if (!mounted) return;
      setState(() => _highlightIncomplete = true);
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (mounted) setState(() => _highlightIncomplete = false);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(taskDetailsProvider(widget.taskId));
  }

  Future<void> _deleteAttachment(TaskAttachment item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete attachment?'),
        content: Text(
          '“${item.displayName}” will be removed from this reminder and its '
          'private app copy will be deleted. Any separate copy you saved to '
          'a folder will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    await ref.read(taskRepositoryProvider).removeAttachment(item.id);
    await ref.read(localMediaServiceProvider).deleteIfOwned(item.path);
    await _refresh();
  }

  Future<void> _openAttachment(TaskAttachment item) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AttachmentViewerScreen(attachment: item),
        ),
      );

  Future<void> _handleAttachmentAction(
    TaskAttachment item,
    _FileAction action,
  ) async {
    switch (action) {
      case _FileAction.play:
        await _openAttachment(item);
        return;
      case _FileAction.saveCopy:
        await _saveFileCopy(item.path, item.displayName);
        return;
      case _FileAction.share:
        await _shareFile(item.path, item.displayName);
        return;
      case _FileAction.delete:
        await _deleteAttachment(item);
        return;
    }
  }

  Future<void> _handleVoiceAction(
    TaskVoiceNote note,
    _FileAction action,
  ) async {
    switch (action) {
      case _FileAction.play:
        await _play(note);
        return;
      case _FileAction.saveCopy:
        await _saveFileCopy(
          note.path,
          'Smart_Planner_voice_${note.createdAt.millisecondsSinceEpoch}${p.extension(note.path)}',
        );
        return;
      case _FileAction.share:
        await _shareFile(note.path, 'Smart Planner voice note');
        return;
      case _FileAction.delete:
        await _deleteVoice(note);
        return;
    }
  }

  Future<void> _showVoiceNote(TaskVoiceNote note) async {
    final action = await showModalBottomSheet<_FileAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                child: Icon(
                  _playing == note.id ? Icons.graphic_eq : Icons.mic_rounded,
                  size: 34,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Voice note',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '${note.durationSeconds} seconds • ${DateFormat('d MMM y, h:mm a').format(note.createdAt)}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.pop(sheetContext, _FileAction.play),
                    icon: Icon(
                      _playing == note.id ? Icons.stop : Icons.play_arrow,
                    ),
                    label: Text(_playing == note.id ? 'Stop' : 'Play'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pop(sheetContext, _FileAction.saveCopy),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Save copy'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pop(sheetContext, _FileAction.share),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share'),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pop(sheetContext, _FileAction.delete),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (action != null && mounted) await _handleVoiceAction(note, action);
  }

  Future<void> _saveFileCopy(String sourcePath, String displayName) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      _showFileError('This file is missing from app storage.');
      return;
    }
    try {
      final rawExtension = p.extension(displayName).isNotEmpty
          ? p.extension(displayName)
          : p.extension(sourcePath);
      final extension = rawExtension.replaceFirst('.', '').toLowerCase();
      final destination = await FilePicker.saveFile(
        dialogTitle: 'Save a copy',
        fileName: displayName,
        type: extension.isEmpty ? FileType.any : FileType.custom,
        allowedExtensions: extension.isEmpty ? null : [extension],
        bytes: await source.readAsBytes(),
      );
      if (destination == null || !mounted) return;
      final output = File(destination);
      if (!await output.exists()) {
        await source.copy(destination);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A copy was saved to your folder.')),
        );
      }
    } catch (error) {
      _showFileError('Could not save this file: $error');
    }
  }

  Future<void> _shareFile(String path, String displayName) async {
    final file = File(path);
    if (!await file.exists()) {
      _showFileError('This file is missing from app storage.');
      return;
    }
    if (!mounted) return;
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          subject: displayName,
          text: 'Shared from Smart Planner',
          files: [XFile(path, name: displayName)],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error) {
      _showFileError('Could not share this file: $error');
    }
  }

  void _showFileError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _play(TaskVoiceNote note) async {
    if (_playing == note.id) {
      await _player.stop();
      setState(() => _playing = null);
      return;
    }
    try {
      await _player.setFilePath(note.path);
      setState(() => _playing = note.id);
      await _player.play();
      if (mounted) setState(() => _playing = null);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice file is missing or unavailable.'),
          ),
        );
      }
    }
  }

  Future<void> _deleteVoice(TaskVoiceNote note) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete voice note?'),
        content: const Text(
          'This recording will be permanently removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    await _player.stop();
    await ref.read(taskRepositoryProvider).removeVoiceNote(note.id);
    await ref.read(localMediaServiceProvider).deleteIfOwned(note.path);
    await _refresh();
  }

  Future<void> _edit(TaskDetails d) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => AddTaskScreen(existing: d)),
    );
    await _refresh();
  }

  Future<void> _delete() async {
    await ref.read(taskRepositoryProvider).moveToTrash(widget.taskId);
    await ref
        .read(taskNotificationCoordinatorProvider)
        .cancelTask(widget.taskId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleCompleted(PlannerTask task) async {
    final completing = !task.isCompleted;
    final completion = DateTime.now();
    await ref
        .read(taskRepositoryProvider)
        .setCompleted(task.id, completed: !task.isCompleted);
    if (task.isCompleted) {
      await ref.read(taskNotificationCoordinatorProvider).syncTask(task.id);
    } else {
      await ref.read(taskNotificationCoordinatorProvider).cancelTask(task.id);
    }
    if (completing && mounted) {
      showCompletionRewardFeedback(
        context,
        task: task,
        allTasks: ref.read(activeTasksProvider).value ?? const <PlannerTask>[],
        completedAt: completion,
      );
    }
    await _refresh();
  }

  Future<void> _snooze(PlannerTask task) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Snooze reminder')),
            for (final option in const [
              (5, '5 minutes'),
              (15, '15 minutes'),
              (30, '30 minutes'),
              (60, '1 hour'),
              (1440, 'Tomorrow'),
            ])
              ListTile(
                title: Text(option.$2),
                onTap: () => Navigator.pop(sheet, option.$1),
              ),
            ListTile(
              title: const Text('Custom…'),
              onTap: () async {
                final controller = TextEditingController();
                final value = await showDialog<int>(
                  context: sheet,
                  builder: (dialog) => AlertDialog(
                    title: const Text('Custom snooze'),
                    content: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Minutes'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(
                          dialog,
                          int.tryParse(controller.text),
                        ),
                        child: const Text('Snooze'),
                      ),
                    ],
                  ),
                );
                controller.dispose();
                if (sheet.mounted && value != null) Navigator.pop(sheet, value);
              },
            ),
          ],
        ),
      ),
    );
    if (minutes == null || minutes < 1) return;
    await ref
        .read(localNotificationServiceProvider)
        .snooze(taskId: task.id, title: task.title, minutes: minutes);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Snoozed for $minutes minutes.')));
    }
  }
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(text.isEmpty ? 'None' : text)),
      ],
    ),
  );
}
