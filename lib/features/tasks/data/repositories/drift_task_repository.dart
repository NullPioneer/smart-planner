import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:smart_reminder/core/database/app_database.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';
import 'package:smart_reminder/features/tasks/domain/repositories/task_repository.dart';
import 'package:uuid/uuid.dart';

final class DriftTaskRepository implements TaskRepository {
  DriftTaskRepository(this._database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  @override
  Stream<List<PlannerTask>> watchActiveTasks() {
    final query = _database.select(_database.tasks)
      ..where((task) => task.deletedAt.isNull())
      ..orderBy([
        (task) => OrderingTerm.desc(task.isPinned),
        (task) => OrderingTerm.asc(task.dueAt),
      ]);
    return query.watch().map((rows) => rows.map(_mapTask).toList());
  }

  @override
  Stream<List<PlannerTask>> watchTrash() {
    final query = _database.select(_database.tasks)
      ..where((task) => task.deletedAt.isNotNull())
      ..orderBy([(task) => OrderingTerm.desc(task.deletedAt)]);
    return query.watch().map((rows) => rows.map(_mapTask).toList());
  }

  @override
  Stream<List<TaskCategory>> watchCategories() {
    final query = _database.select(_database.categories)
      ..orderBy([(category) => OrderingTerm.asc(category.name)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => TaskCategory(
              id: row.id,
              name: row.name,
              colorValue: row.colorValue,
              iconCodePoint: row.iconCodePoint,
              isDefault: row.isDefault,
            ),
          )
          .toList(),
    );
  }

  @override
  Stream<List<TaskHistoryItem>> watchHistory() {
    final query = _database.select(_database.history)
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => TaskHistoryItem(
              id: row.id,
              taskId: row.taskId,
              action: row.action,
              createdAt: row.createdAt,
            ),
          )
          .toList(),
    );
  }

  @override
  Stream<Map<String, ChecklistProgressSummary>> watchChecklistProgress() {
    return _database.select(_database.checklistItems).watch().map((rows) {
      final totals = <String, int>{};
      final checked = <String, int>{};
      for (final row in rows) {
        totals.update(row.taskId, (value) => value + 1, ifAbsent: () => 1);
        if (row.isChecked) {
          checked.update(row.taskId, (value) => value + 1, ifAbsent: () => 1);
        }
      }
      return {
        for (final entry in totals.entries)
          entry.key: ChecklistProgressSummary(
            total: entry.value,
            checked: checked[entry.key] ?? 0,
          ),
      };
    });
  }

  @override
  Future<TaskDetails?> getTaskDetails(String id) async {
    final row = await (_database.select(
      _database.tasks,
    )..where((task) => task.id.equals(id))).getSingleOrNull();
    if (row == null) return null;

    final checklistQuery = _database.select(_database.checklistItems)
      ..where((item) => item.taskId.equals(id))
      ..orderBy([(item) => OrderingTerm.asc(item.position)]);
    final attachmentQuery = _database.select(_database.attachments)
      ..where((item) => item.taskId.equals(id));
    final voiceQuery = _database.select(_database.voiceNotes)
      ..where((item) => item.taskId.equals(id));
    final reminderQuery = _database.select(_database.reminderSchedules)
      ..where((item) => item.taskId.equals(id))
      ..orderBy([(item) => OrderingTerm.desc(item.offsetMinutes)]);

    final results = await Future.wait([
      checklistQuery.get(),
      attachmentQuery.get(),
      voiceQuery.get(),
      reminderQuery.get(),
    ]);
    final checklist = results[0] as List<ChecklistRecord>;
    final attachments = results[1] as List<AttachmentRecord>;
    final voices = results[2] as List<VoiceNoteRecord>;
    final reminders = results[3] as List<ReminderScheduleRecord>;

    return TaskDetails(
      task: _mapTask(row),
      checklist: checklist
          .map(
            (item) => ChecklistItemModel(
              id: item.id,
              taskId: item.taskId,
              title: item.title,
              isChecked: item.isChecked,
              position: item.position,
            ),
          )
          .toList(),
      attachments: attachments.map(_mapAttachment).toList(),
      voiceNotes: voices
          .map(
            (item) => TaskVoiceNote(
              id: item.id,
              taskId: item.taskId,
              path: item.path,
              durationSeconds: item.durationSeconds,
              createdAt: item.createdAt,
            ),
          )
          .toList(),
      reminders: reminders
          .map(
            (item) => TaskReminderSchedule(
              id: item.id,
              taskId: item.taskId,
              offsetMinutes: item.offsetMinutes,
              scheduledFor: item.scheduledFor,
              notificationId: item.notificationId,
              isEnabled: item.isEnabled,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<String> saveTask(TaskDraft draft) async {
    final now = DateTime.now();
    final id = draft.id ?? _uuid.v4();
    final existing = await (_database.select(
      _database.tasks,
    )..where((task) => task.id.equals(id))).getSingleOrNull();

    await _database.transaction(() async {
      await _database
          .into(_database.tasks)
          .insertOnConflictUpdate(
            TasksCompanion.insert(
              id: id,
              title: draft.title.trim(),
              description: Value(draft.description.trim()),
              categoryId: Value(draft.categoryId),
              priority: Value(draft.priority.name),
              dueAt: draft.dueAt,
              isPinned: Value(draft.isPinned),
              repeatType: Value(draft.repeatType.name),
              repeatInterval: Value(draft.repeatInterval.clamp(1, 365)),
              repeatEndDate: Value(draft.repeatEndDate),
              notes: Value(draft.notes.trim()),
              createdAt: existing?.createdAt ?? now,
              updatedAt: now,
            ),
          );

      await (_database.delete(
        _database.checklistItems,
      )..where((item) => item.taskId.equals(id))).go();
      for (var index = 0; index < draft.checklist.length; index++) {
        final item = draft.checklist[index];
        if (item.title.trim().isEmpty) continue;
        await _database
            .into(_database.checklistItems)
            .insert(
              ChecklistItemsCompanion.insert(
                id: item.id ?? _uuid.v4(),
                taskId: id,
                title: item.title.trim(),
                isChecked: Value(item.isChecked),
                position: Value(index),
              ),
            );
      }

      await (_database.delete(
        _database.reminderSchedules,
      )..where((item) => item.taskId.equals(id))).go();
      final offsets = draft.reminderOffsetsMinutes.toSet().toList()..sort();
      for (var index = 0; index < offsets.length; index++) {
        final offset = offsets[index];
        await _database
            .into(_database.reminderSchedules)
            .insert(
              ReminderSchedulesCompanion.insert(
                id: _uuid.v4(),
                taskId: id,
                offsetMinutes: offset,
                scheduledFor: draft.dueAt.subtract(Duration(minutes: offset)),
                notificationId: _notificationId(id, index),
              ),
            );
      }

      await _writeHistory(
        taskId: id,
        action: existing == null
            ? 'created'
            : existing.dueAt != draft.dueAt
            ? 'rescheduled'
            : 'edited',
        snapshot: _draftSnapshot(id, draft),
      );
    });
    return id;
  }

  @override
  Future<void> setCompleted(String id, {required bool completed}) async {
    await (_database.update(
      _database.tasks,
    )..where((task) => task.id.equals(id))).write(
      TasksCompanion(
        completedAt: Value(completed ? DateTime.now() : null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _writeHistory(
      taskId: id,
      action: completed ? 'completed' : 'reopened',
      snapshot: const {},
    );
  }

  @override
  Future<void> setPinned(String id, {required bool pinned}) async {
    await (_database.update(
      _database.tasks,
    )..where((task) => task.id.equals(id))).write(
      TasksCompanion(isPinned: Value(pinned), updatedAt: Value(DateTime.now())),
    );
  }

  @override
  Future<void> moveToTrash(String id) async {
    await (_database.update(
      _database.tasks,
    )..where((task) => task.id.equals(id))).write(
      TasksCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _writeHistory(taskId: id, action: 'deleted', snapshot: const {});
  }

  @override
  Future<void> restoreFromTrash(String id) async {
    await (_database.update(
      _database.tasks,
    )..where((task) => task.id.equals(id))).write(
      TasksCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _writeHistory(taskId: id, action: 'restored', snapshot: const {});
  }

  @override
  Future<void> permanentlyDelete(String id) async {
    await (_database.delete(
      _database.tasks,
    )..where((task) => task.id.equals(id))).go();
    await _writeHistory(
      taskId: id,
      action: 'permanently_deleted',
      snapshot: const {},
    );
  }

  @override
  Future<void> setChecklistItemChecked(String id, {required bool checked}) {
    return (_database.update(_database.checklistItems)
          ..where((item) => item.id.equals(id)))
        .write(ChecklistItemsCompanion(isChecked: Value(checked)));
  }

  @override
  Future<String> addCategory({
    required String name,
    required int colorValue,
    required int iconCodePoint,
  }) async {
    final id = _uuid.v4();
    await _database
        .into(_database.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            name: name.trim(),
            colorValue: colorValue,
            iconCodePoint: iconCodePoint,
            createdAt: DateTime.now(),
          ),
        );
    return id;
  }

  @override
  Future<List<PlannerTask>> findConflicts(
    DateTime dueAt, {
    String? excludeId,
  }) async {
    final start = dueAt.subtract(const Duration(minutes: 30));
    final end = dueAt.add(const Duration(minutes: 30));
    final query = _database.select(_database.tasks)
      ..where(
        (task) =>
            task.deletedAt.isNull() &
            task.completedAt.isNull() &
            task.dueAt.isBiggerOrEqualValue(start) &
            task.dueAt.isSmallerOrEqualValue(end),
      );
    if (excludeId != null) {
      query.where((task) => task.id.equals(excludeId).not());
    }
    return (await query.get()).map(_mapTask).toList();
  }

  @override
  Future<void> addAttachment({
    required String taskId,
    required TaskAttachmentType type,
    required String path,
    required String displayName,
  }) {
    return _database
        .into(_database.attachments)
        .insert(
          AttachmentsCompanion.insert(
            id: _uuid.v4(),
            taskId: taskId,
            type: type.name,
            path: path,
            displayName: displayName,
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<void> removeAttachment(String id) async {
    await (_database.delete(
      _database.attachments,
    )..where((item) => item.id.equals(id))).go();
  }

  @override
  Future<void> addVoiceNote({
    required String taskId,
    required String path,
    required int durationSeconds,
  }) {
    return _database
        .into(_database.voiceNotes)
        .insert(
          VoiceNotesCompanion.insert(
            id: _uuid.v4(),
            taskId: taskId,
            path: path,
            durationSeconds: Value(durationSeconds),
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<void> removeVoiceNote(String id) async {
    await (_database.delete(
      _database.voiceNotes,
    )..where((item) => item.id.equals(id))).go();
  }

  @override
  Future<void> clearAllData() async {
    await _database.transaction(() async {
      await _database.delete(_database.tasks).go();
      await _database.delete(_database.history).go();
      await (_database.delete(
        _database.categories,
      )..where((c) => c.isDefault.equals(false))).go();
    });
  }

  PlannerTask _mapTask(TaskRecord row) {
    return PlannerTask(
      id: row.id,
      title: row.title,
      description: row.description,
      categoryId: row.categoryId,
      priority: TaskPriority.values.byName(row.priority),
      dueAt: row.dueAt,
      isPinned: row.isPinned,
      completedAt: row.completedAt,
      repeatType: TaskRepeatType.values.byName(row.repeatType),
      repeatInterval: row.repeatInterval,
      repeatEndDate: row.repeatEndDate,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  TaskAttachment _mapAttachment(AttachmentRecord row) {
    return TaskAttachment(
      id: row.id,
      taskId: row.taskId,
      type: TaskAttachmentType.values.byName(row.type),
      path: row.path,
      displayName: row.displayName,
      createdAt: row.createdAt,
    );
  }

  Future<void> _writeHistory({
    required String taskId,
    required String action,
    required Map<String, Object?> snapshot,
  }) {
    return _database
        .into(_database.history)
        .insert(
          HistoryCompanion.insert(
            id: _uuid.v4(),
            taskId: Value(taskId),
            action: action,
            snapshotJson: jsonEncode(snapshot),
            createdAt: DateTime.now(),
          ),
        );
  }

  Map<String, Object?> _draftSnapshot(String id, TaskDraft draft) {
    return {
      'id': id,
      'title': draft.title,
      'description': draft.description,
      'categoryId': draft.categoryId,
      'priority': draft.priority.name,
      'dueAt': draft.dueAt.toIso8601String(),
      'isPinned': draft.isPinned,
      'repeatType': draft.repeatType.name,
      'repeatInterval': draft.repeatInterval,
      'repeatEndDate': draft.repeatEndDate?.toIso8601String(),
      'notes': draft.notes,
      'reminderOffsetsMinutes': draft.reminderOffsetsMinutes,
    };
  }

  int _notificationId(String taskId, int index) {
    return ((taskId.hashCode & 0x3fffffff) + index) & 0x7fffffff;
  }
}
