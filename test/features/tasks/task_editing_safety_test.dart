import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reminder/core/providers/app_providers.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';
import 'package:smart_reminder/features/tasks/presentation/add_task_screen.dart';
import 'package:smart_reminder/features/tasks/presentation/task_details_screen.dart';

void main() {
  PlannerTask task() => PlannerTask(
    id: 'safe-edit',
    title: 'Original title',
    description: 'Description',
    priority: TaskPriority.medium,
    dueAt: DateTime(2026, 8, 8, 9),
    isPinned: false,
    repeatType: TaskRepeatType.never,
    repeatInterval: 1,
    notes: '',
    createdAt: DateTime(2026, 8, 7),
    updatedAt: DateTime(2026, 8, 7),
  );

  testWidgets('Save is disabled until an existing task changes', (
    tester,
  ) async {
    final details = TaskDetails(
      task: task(),
      checklist: const [],
      attachments: const [],
      voiceNotes: const [],
      reminders: const [],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: AddTaskScreen(existing: details)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -2600));
    await tester.pumpAndSettle();
    FilledButton saveButton() =>
        tester.widget<FilledButton>(find.byKey(const Key('save-task')));
    expect(saveButton().onPressed, isNull);

    await tester.drag(find.byType(ListView), const Offset(0, 2600));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('task-title-field')),
      'Updated title',
    );
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -2600));
    await tester.pumpAndSettle();
    expect(saveButton().onPressed, isNotNull);
  });

  testWidgets('deleting a voice note asks for confirmation', (tester) async {
    final details = TaskDetails(
      task: task(),
      checklist: const [],
      attachments: const [],
      voiceNotes: [
        TaskVoiceNote(
          id: 'voice-1',
          taskId: 'safe-edit',
          path: 'missing.m4a',
          durationSeconds: 5,
          createdAt: DateTime(2026, 8, 7),
        ),
      ],
      reminders: const [],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskDetailsProvider.overrideWith((ref, id) async => details),
        ],
        child: const MaterialApp(home: TaskDetailsScreen(taskId: 'safe-edit')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voice note • 5s'));
    await tester.pumpAndSettle();
    expect(find.text('Save copy'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Delete'), findsWidgets);
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete voice note'));
    await tester.pumpAndSettle();
    expect(find.text('Delete voice note?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('deleting an attachment asks for confirmation', (tester) async {
    final details = TaskDetails(
      task: task(),
      checklist: const [],
      attachments: [
        TaskAttachment(
          id: 'attachment-1',
          taskId: 'safe-edit',
          type: TaskAttachmentType.pdf,
          path: 'missing.pdf',
          displayName: 'Project notes.pdf',
          createdAt: DateTime(2026, 8, 7),
        ),
      ],
      voiceNotes: const [],
      reminders: const [],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskDetailsProvider.overrideWith((ref, id) async => details),
        ],
        child: const MaterialApp(home: TaskDetailsScreen(taskId: 'safe-edit')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Delete attachment'));
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsNothing);
    expect(find.text('Gallery'), findsNothing);
    expect(find.text('PDF / Word'), findsNothing);
    expect(find.text('Record voice note'), findsNothing);

    await tester.tap(find.byTooltip('Attachment options'));
    await tester.pumpAndSettle();
    expect(find.text('Save a copy'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete attachment'));
    await tester.pumpAndSettle();

    expect(find.text('Delete attachment?'), findsOneWidget);
    expect(
      find.textContaining(
        'Any separate copy you saved to a folder will remain',
      ),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
  });
}
