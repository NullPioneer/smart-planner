import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';
import 'package:smart_reminder/features/tasks/domain/services/productivity_reward_service.dart';

void main() {
  PlannerTask completedTask({
    required String id,
    required DateTime dueAt,
    required DateTime completedAt,
  }) => PlannerTask(
    id: id,
    title: id,
    description: '',
    priority: TaskPriority.medium,
    dueAt: dueAt,
    isPinned: false,
    completedAt: completedAt,
    repeatType: TaskRepeatType.never,
    repeatInterval: 1,
    notes: '',
    createdAt: dueAt.subtract(const Duration(days: 1)),
    updatedAt: completedAt,
  );

  test('completion rewards early, on-time, and late work progressively', () {
    final due = DateTime(2026, 8, 7, 12);
    final early = completedTask(
      id: 'early',
      dueAt: due,
      completedAt: due.subtract(const Duration(hours: 1)),
    );
    final onTime = completedTask(id: 'on-time', dueAt: due, completedAt: due);
    final late = completedTask(
      id: 'late',
      dueAt: due,
      completedAt: due.add(const Duration(minutes: 1)),
    );

    expect(ProductivityRewards.rewardFor(early).stars, 5);
    expect(ProductivityRewards.rewardFor(early).remark, 'Excellent!');
    expect(ProductivityRewards.rewardFor(onTime).stars, 4);
    expect(ProductivityRewards.rewardFor(late).stars, 2.5);
    expect(ProductivityRewards.rewardFor(late).remark, 'Good job!');
  });

  test('consistent completion days add streak stars', () {
    final tasks = <PlannerTask>[
      for (var day = 1; day <= 3; day++)
        completedTask(
          id: 'day-$day',
          dueAt: DateTime(2026, 8, day, 18),
          completedAt: DateTime(2026, 8, day, 17),
        ),
    ];

    final summary = ProductivityRewards.summarize(
      tasks,
      now: DateTime(2026, 8, 3, 20),
    );

    expect(summary.currentStreak, 3);
    expect(summary.longestStreak, 3);
    expect(summary.totalStars, 5); // Ratings are always capped at five.
    expect(summary.starsToday, 5);
  });
}
