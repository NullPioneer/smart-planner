import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reminder/core/database/app_database.dart';
import 'package:smart_reminder/features/tasks/data/repositories/drift_task_repository.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';

void main() {
  late AppDatabase database;
  late DriftTaskRepository repository;
  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftTaskRepository(database);
  });
  tearDown(() => database.close());

  test('persists task, reminders, checklist and detects conflicts', () async {
    final due = DateTime.now().add(const Duration(days: 1));
    final id = await repository.saveTask(
      TaskDraft(
        title: 'Submit report',
        description: 'Final copy',
        categoryId: 'work',
        priority: TaskPriority.high,
        alarmEnabled: true,
        dueAt: due,
        checklist: const [
          ChecklistDraft(title: 'Proofread'),
          ChecklistDraft(title: 'Attach PDF'),
        ],
        reminderOffsetsMinutes: const [0, 15, 60],
      ),
    );
    final details = await repository.getTaskDetails(id);
    expect(details?.task.title, 'Submit report');
    expect(details?.task.alarmEnabled, isTrue);
    expect(details?.checklist, hasLength(2));
    final initialProgress = await repository.watchChecklistProgress().first;
    expect(initialProgress[id]?.total, 2);
    expect(initialProgress[id]?.checked, 0);
    expect(
      details?.reminders.map((r) => r.offsetMinutes),
      containsAll([0, 15, 60]),
    );
    expect(
      await repository.findConflicts(due.add(const Duration(minutes: 10))),
      hasLength(1),
    );
    await repository.setChecklistItemChecked(
      details!.checklist.first.id,
      checked: true,
    );
    expect((await repository.getTaskDetails(id))!.checklistProgress, .5);
    final updatedProgress = await repository.watchChecklistProgress().first;
    expect(updatedProgress[id]?.checked, 1);
  });

  test('complete, trash and restore lifecycle is persisted', () async {
    final id = await repository.saveTask(
      TaskDraft(
        title: 'Medicine',
        dueAt: DateTime.now().add(const Duration(hours: 2)),
      ),
    );
    await repository.setCompleted(id, completed: true);
    expect((await repository.getTaskDetails(id))!.task.isCompleted, isTrue);
    await repository.moveToTrash(id);
    expect(await repository.watchTrash().first, hasLength(1));
    await repository.restoreFromTrash(id);
    expect(await repository.watchTrash().first, isEmpty);
    expect(
      (await repository.watchHistory().first).map((h) => h.action),
      containsAll(['created', 'completed', 'deleted', 'restored']),
    );
  });

  test('pinned tasks are returned before other active tasks', () async {
    await repository.saveTask(
      TaskDraft(
        title: 'Earlier task',
        dueAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    await repository.saveTask(
      TaskDraft(
        title: 'Pinned task',
        dueAt: DateTime.now().add(const Duration(days: 2)),
        isPinned: true,
      ),
    );

    final tasks = await repository.watchActiveTasks().first;

    expect(tasks.first.title, 'Pinned task');
    expect(tasks.first.isPinned, isTrue);
  });

  test('medicine safety contacts are stored locally with the task', () async {
    final id = await repository.saveTask(
      TaskDraft(
        title: 'Medicine dose',
        categoryId: 'medicine',
        priority: TaskPriority.high,
        dueAt: DateTime.now().add(const Duration(hours: 2)),
        notes: 'Prescribed tablet: follow the clinician instructions.',
        emergencyContactNumbers: const [
          '1111111111',
          '2222222222',
          '3333333333',
        ],
        emergencyEmail: 'trusted@example.com',
      ),
    );

    final saved = (await repository.getTaskDetails(id))!.task;
    expect(saved.isMedicineSafetyReminder, isTrue);
    expect(saved.alarmEnabled, isFalse);
    expect(saved.emergencyContactNumbers, [
      '1111111111',
      '2222222222',
      '3333333333',
    ]);
    expect(saved.emergencyEmail, 'trusted@example.com');
  });
}
