import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:smart_reminder/core/providers/app_providers.dart';
import 'package:smart_reminder/core/theme/app_theme.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';
import 'package:smart_reminder/features/tasks/presentation/statistics_screen.dart';

void main() {
  testWidgets('daily productivity can move to another date or open a picker', (
    tester,
  ) async {
    final now = DateTime.now();
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    final task = PlannerTask(
      id: 'yesterday-task',
      title: 'Yesterday task',
      description: '',
      priority: TaskPriority.medium,
      dueAt: yesterday.add(const Duration(hours: 12)),
      isPinned: false,
      completedAt: yesterday.add(const Duration(hours: 11)),
      repeatType: TaskRepeatType.never,
      repeatInterval: 1,
      notes: '',
      createdAt: yesterday,
      updatedAt: yesterday,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeTasksProvider.overrideWith((ref) => Stream.value([task])),
          taskCategoriesProvider.overrideWith(
            (ref) => Stream.value(const <TaskCategory>[]),
          ),
          checklistProgressProvider.overrideWith(
            (ref) => Stream.value(const <String, ChecklistProgressSummary>{}),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const StatisticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('insights-date-picker')), findsOneWidget);
    await tester.tap(find.byKey(const Key('insights-previous-day')));
    await tester.pumpAndSettle();

    final selectedDate = tester.widget<Text>(
      find.byKey(const Key('insights-selected-date')),
    );
    expect(selectedDate.data, DateFormat('EEE, d MMM y').format(yesterday));
    expect(find.text('1 / 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('insights-date-picker')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('category-distribution-panel')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('category-distribution-chart')),
      findsOneWidget,
    );
    expect(find.byType(PieChart), findsOneWidget);

    expect(find.byKey(const Key('weekly-completions-panel')), findsOneWidget);
    expect(find.byKey(const Key('weekly-completions-chart')), findsOneWidget);
    final weeklyValue = tester.widget<Text>(
      find.byKey(
        Key('weekly-value-${DateFormat('yyyyMMdd').format(yesterday)}'),
      ),
    );
    expect(weeklyValue.data, '100%');
    expect(find.text('Highlights'), findsNothing);
  });

  testWidgets('category overview stays capped and opens the complete list', (
    tester,
  ) async {
    final now = DateTime.now();
    final categories = [
      for (var index = 0; index < 6; index++)
        TaskCategory(
          id: 'category-$index',
          name: 'Category ${index + 1}',
          colorValue: Color.lerp(
            AppColors.primary,
            AppColors.tertiary,
            index / 5,
          )!.toARGB32(),
          iconCodePoint: Icons.label_outline.codePoint,
          isDefault: false,
        ),
    ];
    final tasks = [
      for (var index = 0; index < categories.length; index++)
        PlannerTask(
          id: 'category-task-$index',
          title: 'Category task ${index + 1}',
          description: '',
          categoryId: categories[index].id,
          priority: TaskPriority.medium,
          dueAt: now.add(Duration(days: index + 1)),
          isPinned: false,
          repeatType: TaskRepeatType.never,
          repeatInterval: 1,
          notes: '',
          createdAt: now,
          updatedAt: now,
        ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeTasksProvider.overrideWith((ref) => Stream.value(tasks)),
          taskCategoriesProvider.overrideWith(
            (ref) => Stream.value(categories),
          ),
          checklistProgressProvider.overrideWith(
            (ref) => Stream.value(const <String, ChecklistProgressSummary>{}),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const StatisticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('category-distribution-panel')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byKey(const Key('view-all-categories')), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    expect(find.byType(PieChart), findsOneWidget);
    await tester.tap(find.byKey(const Key('view-all-categories')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('all-category-distribution')), findsOneWidget);
    expect(find.text('Category 6'), findsOneWidget);
  });
}
