import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_reminder/core/providers/app_providers.dart';
import 'package:smart_reminder/core/theme/app_theme.dart';
import 'package:smart_reminder/features/settings/application/app_settings_controller.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';
import 'package:smart_reminder/features/tasks/presentation/attachment_capture_flow.dart';
import 'package:smart_reminder/shared/widgets/glass_panel.dart';

class AddTaskScreen extends ConsumerStatefulWidget {
  const AddTaskScreen({super.key, this.initialDate, this.existing});
  final DateTime? initialDate;
  final TaskDetails? existing;
  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _PendingAttachment {
  const _PendingAttachment(this.path, this.name, this.type);
  final String path;
  final String name;
  final TaskAttachmentType type;
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _notes = TextEditingController();
  final _emergencyContacts = List.generate(3, (_) => TextEditingController());
  final _emergencyEmail = TextEditingController();
  final List<TextEditingController> _checklist = [];
  final List<_PendingAttachment> _pendingAttachments = [];
  late DateTime _date;
  late TimeOfDay _time;
  TaskPriority _priority = TaskPriority.medium;
  TaskRepeatType _repeat = TaskRepeatType.never;
  int _repeatInterval = 2;
  DateTime? _repeatEnd;
  String? _categoryId;
  bool _pinned = false;
  bool _alarmEnabled = false;
  bool _saving = false;
  bool _recording = false;
  (String path, int seconds)? _pendingVoice;
  final Set<int> _reminders = {0, 15};

  static const _reminderOptions = [0, 5, 15, 30, 60, 120, 360, 720, 1440];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final settingTime = ref
        .read(appSettingsControllerProvider)
        .value
        ?.defaultTime;
    final now = DateTime.now();
    final defaultDue = settingTime == null
        ? now.add(const Duration(hours: 1))
        : DateTime(
            now.year,
            now.month,
            now.day,
            settingTime.hour,
            settingTime.minute,
          );
    final adjustedDefault = defaultDue.isAfter(now)
        ? defaultDue
        : defaultDue.add(const Duration(days: 1));
    final due = existing?.task.dueAt ?? widget.initialDate ?? adjustedDefault;
    _date = DateTime(due.year, due.month, due.day);
    _time = TimeOfDay.fromDateTime(due);
    if (existing != null) {
      final task = existing.task;
      _title.text = task.title;
      _description.text = task.description;
      _notes.text = task.notes;
      for (var i = 0; i < task.emergencyContactNumbers.length && i < 3; i++) {
        _emergencyContacts[i].text = task.emergencyContactNumbers[i];
      }
      _emergencyEmail.text = task.emergencyEmail;
      _priority = task.priority;
      _repeat = task.repeatType;
      _repeatInterval = task.repeatInterval;
      _repeatEnd = task.repeatEndDate;
      _categoryId = task.categoryId;
      _pinned = task.isPinned;
      _alarmEnabled = task.alarmEnabled;
      _reminders
        ..clear()
        ..addAll(existing.reminders.map((r) => r.offsetMinutes));
      for (final item in existing.checklist) {
        _checklist.add(_checklistController(item.title));
      }
    }
    _title.addListener(_markChanged);
    _description.addListener(_markChanged);
    _notes.addListener(_markChanged);
    for (final controller in _emergencyContacts) {
      controller.addListener(_markChanged);
    }
    _emergencyEmail.addListener(_markChanged);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _notes.dispose();
    for (final controller in _emergencyContacts) {
      controller.dispose();
    }
    _emergencyEmail.dispose();
    for (final c in _checklist) {
      c.dispose();
    }
    super.dispose();
  }

  void _markChanged() {
    if (mounted) setState(() {});
  }

  TextEditingController _checklistController([String text = '']) {
    final controller = TextEditingController(text: text);
    controller.addListener(_markChanged);
    return controller;
  }

  bool get _medicineSafetyEnabled =>
      _priority == TaskPriority.high &&
      (_categoryId == 'medicine' || isMedicineReminderTitle(_title.text));

  List<String> get _effectiveEmergencyContacts => _medicineSafetyEnabled
      ? _emergencyContacts
            .map((controller) => controller.text.trim())
            .where((number) => number.isNotEmpty)
            .toList()
      : const [];

  String get _effectiveEmergencyEmail =>
      _medicineSafetyEnabled ? _emergencyEmail.text.trim() : '';

  bool get _effectiveAlarmEnabled =>
      _priority == TaskPriority.high && _alarmEnabled;

  bool get _hasChanges {
    final existing = widget.existing;
    if (existing == null) return true;
    final task = existing.task;
    final due = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    final checklist = _checklist
        .map((controller) => controller.text.trim())
        .where((title) => title.isNotEmpty)
        .toList();
    final originalChecklist = existing.checklist
        .map((item) => item.title.trim())
        .toList();
    final reminders = _reminders.toList()..sort();
    final originalReminders =
        existing.reminders.map((reminder) => reminder.offsetMinutes).toList()
          ..sort();
    return _title.text.trim() != task.title ||
        _description.text.trim() != task.description ||
        _notes.text.trim() != task.notes ||
        !_sameStrings(
          _effectiveEmergencyContacts,
          task.emergencyContactNumbers,
        ) ||
        _effectiveEmergencyEmail != task.emergencyEmail ||
        _categoryId != task.categoryId ||
        _priority != task.priority ||
        !_sameMinute(due, task.dueAt) ||
        _pinned != task.isPinned ||
        _effectiveAlarmEnabled != task.alarmEnabled ||
        _repeat != task.repeatType ||
        _repeatInterval != task.repeatInterval ||
        !_sameNullableDate(_repeatEnd, task.repeatEndDate) ||
        !_sameStrings(checklist, originalChecklist) ||
        !_sameInts(reminders, originalReminders) ||
        _pendingAttachments.isNotEmpty ||
        _pendingVoice != null;
  }

  bool _sameStrings(List<String> a, List<String> b) =>
      a.length == b.length &&
      List.generate(
        a.length,
        (index) => a[index] == b[index],
      ).every((same) => same);

  bool _sameInts(List<int> a, List<int> b) =>
      a.length == b.length &&
      List.generate(
        a.length,
        (index) => a[index] == b[index],
      ).every((same) => same);

  bool _sameMinute(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;

  bool _sameNullableDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(taskCategoriesProvider).value ?? const <TaskCategory>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Create Task' : 'Edit Reminder'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (widget.existing == null) ...[
              _templates(categories),
              const SizedBox(height: 10),
            ],
            _panel('Task details', Icons.edit_note, [
              TextFormField(
                key: const Key('task-title-field'),
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  prefixIcon: Icon(Icons.task_alt),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a task title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add custom category',
                    onPressed: _addCategory,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const SectionLabel('Priority'),
              const SizedBox(height: 8),
              SegmentedButton<TaskPriority>(
                segments: TaskPriority.values
                    .map(
                      (p) => ButtonSegment(
                        value: p,
                        label: Text(_cap(p.name)),
                        icon: Icon(
                          p == TaskPriority.high
                              ? Icons.priority_high
                              : p == TaskPriority.medium
                              ? Icons.bolt
                              : Icons.low_priority,
                        ),
                      ),
                    )
                    .toList(),
                selected: {_priority},
                onSelectionChanged: (v) => setState(() => _priority = v.first),
              ),
              if (_priority == TaskPriority.high) ...[
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SwitchListTile(
                    key: const Key('high-priority-alarm-switch'),
                    secondary: const Icon(Icons.alarm_rounded),
                    title: const Text('Alarm at due time'),
                    subtitle: const Text(
                      'Optional. Rings with Stop, Snooze, and Open Task actions.',
                    ),
                    value: _alarmEnabled,
                    onChanged: (value) => setState(() => _alarmEnabled = value),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 10),
            _panel('Schedule', Icons.event, [
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Date'),
                      subtitle: Text(DateFormat('EEE, d MMM y').format(_date)),
                      onTap: _pickDate,
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule),
                      title: const Text('Time'),
                      subtitle: Text(_time.format(context)),
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<TaskRepeatType>(
                initialValue: _repeat,
                decoration: const InputDecoration(labelText: 'Repeat'),
                items: TaskRepeatType.values
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(
                          r == TaskRepeatType.everyXDays
                              ? 'Every X days'
                              : _cap(r.name),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _repeat = v ?? TaskRepeatType.never),
              ),
              if (_repeat == TaskRepeatType.everyXDays) ...[
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: '$_repeatInterval',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Repeat every (days)',
                  ),
                  onChanged: (v) => setState(
                    () => _repeatInterval = int.tryParse(v)?.clamp(1, 365) ?? 1,
                  ),
                ),
              ],
              if (_repeat != TaskRepeatType.never)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_busy),
                  title: const Text('End date'),
                  subtitle: Text(
                    _repeatEnd == null
                        ? 'Never ending'
                        : DateFormat('d MMM y').format(_repeatEnd!),
                  ),
                  trailing: _repeatEnd == null
                      ? null
                      : IconButton(
                          onPressed: () => setState(() => _repeatEnd = null),
                          icon: const Icon(Icons.close),
                        ),
                  onTap: _pickRepeatEnd,
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pin to dashboard'),
                secondary: const Icon(Icons.push_pin_outlined),
                value: _pinned,
                onChanged: (v) => setState(() => _pinned = v),
              ),
            ]),
            const SizedBox(height: 10),
            _panel('Reminder timings', Icons.notifications_active_outlined, [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final minutes in _reminderOptions)
                    FilterChip(
                      label: Text(_reminderLabel(minutes)),
                      selected: _reminders.contains(minutes),
                      onSelected: (selected) => setState(
                        () => selected
                            ? _reminders.add(minutes)
                            : _reminders.remove(minutes),
                      ),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 17),
                    label: const Text('Custom'),
                    onPressed: _customReminder,
                  ),
                ],
              ),
              if (_reminders.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'No notification will be scheduled.',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
            ]),
            const SizedBox(height: 10),
            _panel('Checklist', Icons.checklist, [
              for (var i = 0; i < _checklist.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _checklist[i],
                          decoration: InputDecoration(
                            labelText: 'Item ${i + 1}',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          final c = _checklist.removeAt(i);
                          c.dispose();
                          setState(() {});
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _checklist.add(_checklistController())),
                icon: const Icon(Icons.add),
                label: const Text('Add checklist item'),
              ),
            ]),
            const SizedBox(height: 10),
            if (_medicineSafetyEnabled) ...[
              _panel('Medicine safety', Icons.health_and_safety_outlined, [
                const Text(
                  'Add optional contacts for quick access. Smart Planner never calls or emails anyone automatically.',
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _emergencyContacts.length; i++) ...[
                  TextFormField(
                    key: Key('emergency-contact-${i + 1}'),
                    controller: _emergencyContacts[i],
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Emergency contact ${i + 1}',
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  if (i < _emergencyContacts.length - 1)
                    const SizedBox(height: 10),
                ],
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('emergency-email'),
                  controller: _emergencyEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Emergency email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isNotEmpty &&
                        !RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(email)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'In Notes, add only medicine, dosage, and prescription instructions verified with a healthcare professional. For an emergency, contact local emergency services.',
                  style: TextStyle(color: AppColors.onSurfaceVariant),
                ),
              ]),
              const SizedBox(height: 10),
            ],
            _panel('Attachments & voice', Icons.attach_file, [
              for (final item in _pendingAttachments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: item.type == TaskAttachmentType.image
                      ? const Icon(Icons.image)
                      : const Icon(Icons.insert_drive_file),
                  title: Text(item.name),
                  trailing: IconButton(
                    tooltip: 'Delete attachment',
                    onPressed: () => _confirmDeletePendingAttachment(item),
                    icon: const Icon(Icons.close),
                  ),
                ),
              if (_pendingVoice != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mic),
                  title: Text('Voice note • ${_pendingVoice!.$2}s'),
                  trailing: IconButton(
                    tooltip: 'Delete voice note',
                    onPressed: _confirmDeletePendingVoice,
                    icon: const Icon(Icons.close),
                  ),
                ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _captureImages,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery / document'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('PDF/Word'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _toggleRecording,
                    icon: Icon(_recording ? Icons.stop : Icons.mic),
                    label: Text(_recording ? 'Stop' : 'Record'),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 10),
            _panel('Notes', Icons.notes, [
              TextFormField(
                controller: _notes,
                minLines: 4,
                maxLines: 12,
                decoration: const InputDecoration(
                  hintText: 'Unlimited notes…',
                  alignLabelWithHint: true,
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  key: const Key('save-task'),
                  onPressed: _saving || !_hasChanges ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save Reminder'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _templates(List<TaskCategory> categories) {
    const items = [
      (
        'Medicine',
        Icons.medication,
        'medicine',
        TaskPriority.high,
        TaskRepeatType.daily,
        15,
      ),
      (
        'Meeting',
        Icons.groups,
        'work',
        TaskPriority.high,
        TaskRepeatType.never,
        30,
      ),
      (
        'Assignment',
        Icons.school,
        'study',
        TaskPriority.high,
        TaskRepeatType.never,
        1440,
      ),
      (
        'Workout',
        Icons.fitness_center,
        'personal',
        TaskPriority.medium,
        TaskRepeatType.daily,
        30,
      ),
      (
        'Birthday',
        Icons.cake,
        'birthday',
        TaskPriority.medium,
        TaskRepeatType.monthly,
        1440,
      ),
      (
        'Shopping',
        Icons.shopping_cart,
        'shopping',
        TaskPriority.low,
        TaskRepeatType.never,
        60,
      ),
      (
        'Bills',
        Icons.receipt_long,
        'bills',
        TaskPriority.high,
        TaskRepeatType.monthly,
        1440,
      ),
    ];
    return _panel('Quick templates', Icons.auto_awesome, [
      SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final t = items[i];
            return ActionChip(
              avatar: Icon(t.$2, size: 17),
              label: Text(t.$1),
              onPressed: () => setState(() {
                _title.text = t.$1;
                _categoryId = categories
                    .where((c) => c.id == t.$3)
                    .firstOrNull
                    ?.id;
                _priority = t.$4;
                _repeat = t.$5;
                _reminders
                  ..clear()
                  ..addAll({0, t.$6});
              }),
            );
          },
        ),
      ),
    ]);
  }

  GlassPanel _panel(String title, IconData icon, List<Widget> children) =>
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
  String _cap(String s) => s[0].toUpperCase() + s.substring(1);
  String _reminderLabel(int m) => m == 0
      ? 'Exact time'
      : m < 60
      ? '$m min before'
      : m < 1440
      ? '${m ~/ 60} hr before'
      : '${m ~/ 1440} day before';

  Future<void> _pickDate() async {
    final v = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (v != null) setState(() => _date = v);
  }

  Future<void> _pickTime() async {
    final v = await showTimePicker(context: context, initialTime: _time);
    if (v != null) setState(() => _time = v);
  }

  Future<void> _pickRepeatEnd() async {
    final v = await showDatePicker(
      context: context,
      initialDate: _repeatEnd ?? _date.add(const Duration(days: 30)),
      firstDate: _date,
      lastDate: _date.add(const Duration(days: 3650)),
    );
    if (v != null) setState(() => _repeatEnd = v);
  }

  Future<void> _customReminder() async {
    final c = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom reminder'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutes before'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    c.dispose();
    if (value != null && value >= 0) setState(() => _reminders.add(value));
  }

  Future<void> _addCategory() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    c.dispose();
    if (name != null && name.isNotEmpty) {
      final id = await ref
          .read(taskRepositoryProvider)
          .addCategory(
            name: name,
            colorValue: AppColors.primary.toARGB32(),
            iconCodePoint: Icons.label_outline.codePoint,
          );
      setState(() => _categoryId = id);
    }
  }

  Future<void> _pickImage() async {
    final attachments = await pickGalleryTaskAttachments(
      context,
      ref.read(localMediaServiceProvider),
    );
    if (attachments.isEmpty || !mounted) return;
    setState(() {
      _pendingAttachments.addAll(
        attachments.map(
          (attachment) => _PendingAttachment(
            attachment.path,
            attachment.name,
            attachment.type,
          ),
        ),
      );
    });
  }

  Future<void> _captureImages() async {
    final attachments = await captureTaskAttachments(
      context,
      ref.read(localMediaServiceProvider),
    );
    if (attachments.isEmpty || !mounted) return;
    setState(() {
      _pendingAttachments.addAll(
        attachments.map(
          (attachment) => _PendingAttachment(
            attachment.path,
            attachment.name,
            attachment.type,
          ),
        ),
      );
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx'],
    );
    final file = result?.files.single;
    if (file?.path == null) return;
    final path = await ref
        .read(localMediaServiceProvider)
        .importFile(file!.path!);
    setState(
      () => _pendingAttachments.add(
        _PendingAttachment(
          path,
          file.name,
          file.extension?.toLowerCase() == 'pdf'
              ? TaskAttachmentType.pdf
              : TaskAttachmentType.file,
        ),
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final result = await ref.read(localMediaServiceProvider).stopRecording();
      if (mounted) {
        setState(() {
          _recording = false;
          _pendingVoice = result;
        });
      }
    } else {
      final ok = await ref.read(localMediaServiceProvider).startRecording();
      if (mounted) {
        setState(() => _recording = ok);
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required.')),
          );
        }
      }
    }
  }

  Future<void> _confirmDeletePendingVoice() async {
    final voice = _pendingVoice;
    if (voice == null) return;
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
    await ref.read(localMediaServiceProvider).deleteIfOwned(voice.$1);
    if (mounted) setState(() => _pendingVoice = null);
  }

  Future<void> _confirmDeletePendingAttachment(
    _PendingAttachment attachment,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete attachment?'),
        content: Text(
          '“${attachment.name}” will be removed from this reminder and its '
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
    await ref.read(localMediaServiceProvider).deleteIfOwned(attachment.path);
    if (mounted) setState(() => _pendingAttachments.remove(attachment));
  }

  Future<void> _save() async {
    if (!_hasChanges) return;
    if (!_formKey.currentState!.validate()) return;
    final due = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    final repo = ref.read(taskRepositoryProvider);
    final conflicts = await repo.findConflicts(
      due,
      excludeId: widget.existing?.task.id,
    );
    if (conflicts.isNotEmpty && mounted) {
      final alternatives = [
        due.add(const Duration(minutes: 30)),
        due.add(const Duration(hours: 1)),
      ];
      final choice = await showDialog<DateTime?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Conflict Detected'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('“${conflicts.first.title}” is scheduled near this time.'),
              const SizedBox(height: 12),
              const Text('Suggested alternatives:'),
              for (final time in alternatives)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, time),
                  child: Text(DateFormat('h:mm a').format(time)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Choose another time'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, due),
              child: const Text('Ignore'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      _date = DateTime(choice.year, choice.month, choice.day);
      _time = TimeOfDay.fromDateTime(choice);
    }
    setState(() => _saving = true);
    try {
      final id = await repo.saveTask(
        TaskDraft(
          id: widget.existing?.task.id,
          title: _title.text,
          description: _description.text,
          categoryId: _categoryId,
          priority: _priority,
          dueAt: DateTime(
            _date.year,
            _date.month,
            _date.day,
            _time.hour,
            _time.minute,
          ),
          isPinned: _pinned,
          alarmEnabled: _effectiveAlarmEnabled,
          repeatType: _repeat,
          repeatInterval: _repeatInterval,
          repeatEndDate: _repeatEnd,
          notes: _notes.text,
          emergencyContactNumbers: _effectiveEmergencyContacts,
          emergencyEmail: _effectiveEmergencyEmail,
          checklist: [
            for (var i = 0; i < _checklist.length; i++)
              if (_checklist[i].text.trim().isNotEmpty)
                ChecklistDraft(
                  id: i < (widget.existing?.checklist.length ?? 0)
                      ? widget.existing!.checklist[i].id
                      : null,
                  title: _checklist[i].text,
                  isChecked: i < (widget.existing?.checklist.length ?? 0)
                      ? widget.existing!.checklist[i].isChecked
                      : false,
                ),
          ],
          reminderOffsetsMinutes: _reminders.toList(),
        ),
      );
      for (final item in _pendingAttachments) {
        await repo.addAttachment(
          taskId: id,
          type: item.type,
          path: item.path,
          displayName: item.name,
        );
      }
      if (_pendingVoice != null) {
        await repo.addVoiceNote(
          taskId: id,
          path: _pendingVoice!.$1,
          durationSeconds: _pendingVoice!.$2,
        );
      }
      await ref.read(taskNotificationCoordinatorProvider).syncTask(id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('“${_title.text.trim()}” saved.')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save reminder: $e')));
      }
    }
  }
}
