import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reminder/core/database/app_database.dart';
import 'package:smart_reminder/core/services/backup_service.dart';
import 'package:smart_reminder/features/tasks/data/repositories/drift_task_repository.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';

void main() {
  test('backup is a readable text report instead of raw JSON', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftTaskRepository(database);
    await repository.saveTask(
      TaskDraft(
        title: 'Prepare presentation',
        dueAt: DateTime(2026, 8, 8, 10),
        checklist: const [
          ChecklistDraft(title: 'Review the slides'),
          ChecklistDraft(title: 'Practice the introduction', isChecked: true),
        ],
      ),
    );

    final report = await BackupService(database).createReadableBackupText();

    expect(report, startsWith('SMART PLANNER BACKUP'));
    expect(report, contains('Prepare presentation'));
    expect(report, contains('[ ] Review the slides'));
    expect(report, contains('[x] Practice the introduction'));
    expect(report, contains('for your personal records'));
    expect(report, isNot(contains('APP RECOVERY COPY')));
    expect(report, isNot(contains('BEGIN_SMART_PLANNER_RESTORE_DATA')));
    expect(report, isNot(contains('END_SMART_PLANNER_RESTORE_DATA')));
    expect(report.trimLeft(), isNot(startsWith('{')));
  });
}
