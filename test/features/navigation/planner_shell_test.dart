import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reminder/core/providers/app_providers.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';
import 'package:smart_reminder/main.dart';

void main() {
  testWidgets('bottom navigation switches between supplied frontend screens', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SmartReminderApp()));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.byKey(const Key('dashboard-full-overview')), findsOneWidget);
    expect(find.text('Pinned tasks'), findsOneWidget);
    expect(find.text("Today's timeline"), findsOneWidget);

    await tester.tap(find.byKey(const Key('dashboard-full-overview')));
    await tester.pumpAndSettle();
    expect(find.text('OVERALL COMPLETION'), findsOneWidget);
    expect(find.text('PRODUCTIVITY SCORE • 0–5'), findsOneWidget);
    expect(find.text('Pinned tasks'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-calendar')));
    await tester.pumpAndSettle();
    expect(find.text('MONTHLY OVERVIEW'), findsOneWidget);
    expect(find.byKey(const Key('calendar-filter')), findsOneWidget);
    expect(find.byKey(const Key('calendar-new-event')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-tasks')));
    await tester.pumpAndSettle();
    expect(find.text('Task Stream'), findsOneWidget);

    expect(find.byKey(const Key('nav-settings')), findsNothing);
    await tester.tap(find.byKey(const Key('open-side-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Quick settings'), findsOneWidget);
    expect(find.byKey(const Key('quick-theme-switch')), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-full-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Personalize your planner experience'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.byKey(const Key('privacy-storage-setting')), findsOneWidget);
  });

  testWidgets('new task action opens the adapted creation screen', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SmartReminderApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-tasks')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tasks-new-task')));
    await tester.pumpAndSettle();

    expect(find.text('Create Task'), findsWidgets);
    expect(find.byKey(const Key('task-title-field')), findsOneWidget);
    expect(find.text('PRIORITY'), findsOneWidget);
  });

  testWidgets('dashboard summary cards open their matching task filters', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SmartReminderApp()));
    await tester.pumpAndSettle();

    final routes = <Key, String>{
      const Key('stat-completed-today'): 'Completed today',
      const Key('stat-pending'): 'Pending',
      const Key('stat-overdue'): 'Overdue',
    };

    for (final route in routes.entries) {
      await tester.tap(find.byKey(route.key));
      await tester.pumpAndSettle();

      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, route.value),
      );
      expect(chip.selected, isTrue);

      await tester.tap(find.byKey(const Key('nav-dashboard')));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const Key('stat-daily-progress')));
    await tester.pumpAndSettle();
    expect(find.text('Productivity Insights'), findsOneWidget);
    expect(find.byKey(const Key('productivity-daily-report')), findsOneWidget);
  });

  testWidgets('tasks screen renders persisted task cards', (tester) async {
    final now = DateTime.now();
    final task = PlannerTask(
      id: 'visible-task',
      title: 'Visible task card',
      description: 'Must render below the filters',
      priority: TaskPriority.medium,
      dueAt: now.add(const Duration(hours: 1)),
      isPinned: false,
      repeatType: TaskRepeatType.never,
      repeatInterval: 1,
      notes: '',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeTasksProvider.overrideWith((ref) => Stream.value([task])),
        ],
        child: const SmartReminderApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-tasks')));
    await tester.pumpAndSettle();

    expect(find.text('Visible task card'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pinned task due today also appears in today timeline', (
    tester,
  ) async {
    final now = DateTime.now();
    final task = PlannerTask(
      id: 'pinned-today',
      title: 'Pinned today reminder',
      description: '',
      priority: TaskPriority.high,
      dueAt: now.add(const Duration(minutes: 30)),
      isPinned: true,
      repeatType: TaskRepeatType.never,
      repeatInterval: 1,
      notes: '',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeTasksProvider.overrideWith((ref) => Stream.value([task])),
        ],
        child: const SmartReminderApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pinned today reminder'), findsNWidgets(2));
    expect(find.text('Your day is clear.'), findsNothing);
  });

  testWidgets('daily progress includes checklist completion units', (
    tester,
  ) async {
    final now = DateTime.now();
    final completedTask = PlannerTask(
      id: 'checklist-progress-task',
      title: 'Checklist weighted task',
      description: '',
      priority: TaskPriority.medium,
      dueAt: now.add(const Duration(minutes: 30)),
      isPinned: false,
      completedAt: now,
      repeatType: TaskRepeatType.never,
      repeatInterval: 1,
      notes: '',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeTasksProvider.overrideWith(
            (ref) => Stream.value([completedTask]),
          ),
          checklistProgressProvider.overrideWith(
            (ref) => Stream.value(const {
              'checklist-progress-task': ChecklistProgressSummary(
                total: 4,
                checked: 2,
              ),
            }),
          ),
          taskDetailsProvider.overrideWith(
            (ref, id) async => TaskDetails(
              task: completedTask,
              checklist: const [
                ChecklistItemModel(
                  id: 'step-1',
                  taskId: 'checklist-progress-task',
                  title: 'Finished step one',
                  isChecked: true,
                  position: 0,
                ),
                ChecklistItemModel(
                  id: 'step-2',
                  taskId: 'checklist-progress-task',
                  title: 'Finished step two',
                  isChecked: true,
                  position: 1,
                ),
                ChecklistItemModel(
                  id: 'step-3',
                  taskId: 'checklist-progress-task',
                  title: 'First unfinished step',
                  isChecked: false,
                  position: 2,
                ),
                ChecklistItemModel(
                  id: 'step-4',
                  taskId: 'checklist-progress-task',
                  title: 'Second unfinished step',
                  isChecked: false,
                  position: 3,
                ),
              ],
              attachments: const [],
              voiceNotes: const [],
              reminders: const [],
            ),
          ),
        ],
        child: const SmartReminderApp(),
      ),
    );
    await tester.pumpAndSettle();

    // One completed task + two checked items out of five total daily units.
    expect(
      find.descendant(
        of: find.byKey(const Key('stat-daily-progress')),
        matching: find.text('60%'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('stat-daily-progress')));
    await tester.pumpAndSettle();
    expect(find.text('Why your completion rate is 60%'), findsOneWidget);
    expect(find.textContaining('still unchecked'), findsWidgets);

    final stepsComplete = find.byKey(const Key('daily-steps-complete'));
    await tester.ensureVisible(stepsComplete);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: stepsComplete, matching: find.text('3 / 5')),
      findsOneWidget,
    );

    await tester.tap(stepsComplete);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.text('Reminder Details'), findsOneWidget);
    expect(find.text('First unfinished step'), findsOneWidget);
    final focusedStep = find.byKey(
      const Key('focused-incomplete-checklist-item'),
    );
    expect(focusedStep, findsOneWidget);
    final zoom = tester.widget<AnimatedScale>(
      find
          .ancestor(of: focusedStep, matching: find.byType(AnimatedScale))
          .first,
    );
    expect(zoom.scale, greaterThan(1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });
}
