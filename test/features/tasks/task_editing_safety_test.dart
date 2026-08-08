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

  testWidgets('high priority offers an opt-in due-time alarm', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AddTaskScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('high-priority-alarm-switch')), findsNothing);
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();

    final alarmFinder = find.byKey(const Key('high-priority-alarm-switch'));
    expect(alarmFinder, findsOneWidget);
    expect(tester.widget<SwitchListTile>(alarmFinder).value, isFalse);
    await tester.ensureVisible(alarmFinder);
    await tester.pumpAndSettle();
    await tester.tap(alarmFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(alarmFinder).value, isTrue);
    expect(find.textContaining('Stop, Snooze, and Open Task'), findsOneWidget);
  });

  testWidgets('high-priority medicine task shows three optional contacts', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AddTaskScreen())),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('task-title-field')),
      'Medicine dose',
    );
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    final moreOptions = find.byKey(const Key('task-more-options'));
    await tester.ensureVisible(moreOptions);
    await tester.pumpAndSettle();
    await tester.tap(moreOptions);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -1700));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('emergency-contact-1')), findsOneWidget);
    expect(find.byKey(const Key('emergency-contact-2')), findsOneWidget);
    expect(find.byKey(const Key('emergency-contact-3')), findsOneWidget);
    expect(find.byKey(const Key('emergency-email')), findsOneWidget);
    final callButton = find.byKey(const Key('call-emergency-contact-1'));
    final emailButton = find.byKey(const Key('email-emergency-contact'));
    expect(tester.widget<IconButton>(callButton).onPressed, isNull);
    expect(tester.widget<IconButton>(emailButton).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('emergency-contact-1')),
      '1111111111',
    );
    await tester.enterText(
      find.byKey(const Key('emergency-email')),
      'trusted@example.com',
    );
    await tester.pump();
    expect(tester.widget<IconButton>(callButton).onPressed, isNotNull);
    expect(tester.widget<IconButton>(emailButton).onPressed, isNotNull);
    expect(find.textContaining('never calls or emails'), findsOneWidget);
  });

  testWidgets('deleting a checklist item asks for confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AddTaskScreen())),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    final moreOptions = find.byKey(const Key('task-more-options'));
    await tester.ensureVisible(moreOptions);
    await tester.pumpAndSettle();
    await tester.tap(moreOptions);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -1300));
    await tester.pumpAndSettle();
    final addItem = find.text('Add checklist item');
    await tester.ensureVisible(addItem);
    await tester.pumpAndSettle();
    await tester.tap(addItem);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete checklist item'));
    await tester.pumpAndSettle();
    expect(find.text('Delete checklist item?'), findsOneWidget);
    expect(find.text('Cancel'), findsWidgets);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets(
    'medicine details expose user-controlled Call and Email actions',
    (tester) async {
      final medicineTask = PlannerTask(
        id: 'medicine-safety',
        title: 'Medicine dose',
        description: '',
        categoryId: 'medicine',
        priority: TaskPriority.high,
        dueAt: DateTime(2026, 8, 8, 9),
        isPinned: false,
        repeatType: TaskRepeatType.daily,
        repeatInterval: 1,
        notes: 'One prescribed tablet after food.',
        emergencyContactNumbers: const ['1111111111'],
        emergencyEmail: 'trusted@example.com',
        createdAt: DateTime(2026, 8, 7),
        updatedAt: DateTime(2026, 8, 7),
      );
      final details = TaskDetails(
        task: medicineTask,
        checklist: const [],
        attachments: const [],
        voiceNotes: const [],
        reminders: const [],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskDetailsProvider.overrideWith((ref, id) async => details),
          ],
          child: const MaterialApp(
            home: TaskDetailsScreen(taskId: 'medicine-safety'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Medicine safety'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.phone_in_talk_rounded), findsOneWidget);
      expect(find.byIcon(Icons.alternate_email_rounded), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      expect(find.textContaining('never calls or emails'), findsOneWidget);
    },
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

  testWidgets('deleting a reminder asks before moving it to Trash', (
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
        overrides: [
          taskDetailsProvider.overrideWith((ref, id) async => details),
        ],
        child: const MaterialApp(home: TaskDetailsScreen(taskId: 'safe-edit')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    final deleteButton = find.widgetWithText(TextButton, 'Delete');
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('Move reminder to Trash?'), findsOneWidget);
    expect(find.textContaining('restore it for up to 30 days'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Move to Trash'), findsOneWidget);
  });
}
