import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';

final class TaskCompletionReward {
  const TaskCompletionReward({
    required this.remark,
    required this.detail,
    required this.stars,
    required this.wasEarly,
    required this.wasOnTime,
  });

  final String remark;
  final String detail;
  final double stars;
  final bool wasEarly;
  final bool wasOnTime;
}

final class ProductivityRewardSummary {
  const ProductivityRewardSummary({
    required this.totalStars,
    required this.starsToday,
    required this.currentStreak,
    required this.longestStreak,
    required this.completedToday,
    required this.earlyToday,
    required this.onTimeToday,
    required this.lateToday,
  });

  final double totalStars;
  final double starsToday;
  final int currentStreak;
  final int longestStreak;
  final int completedToday;
  final int earlyToday;
  final int onTimeToday;
  final int lateToday;
}

abstract final class ProductivityRewards {
  static TaskCompletionReward rewardFor(
    PlannerTask task, {
    DateTime? completedAt,
    int consistencyStreak = 0,
  }) {
    final completion = completedAt ?? task.completedAt ?? DateTime.now();
    final wasEarly = completion.isBefore(task.dueAt);
    final wasOnTime = !completion.isAfter(task.dueAt);
    final timingStars = _timingStars(wasEarly, wasOnTime);
    final consistencyBoost = _streakBoost(consistencyStreak);
    final stars = (timingStars + consistencyBoost).clamp(0.0, 5.0);

    final remark = switch ((wasEarly, wasOnTime, consistencyStreak)) {
      (_, _, >= 7) => 'Outstanding!',
      (true, _, _) => 'Excellent!',
      (_, true, >= 3) => 'Fantastic!',
      (_, true, _) => 'Great job!',
      _ => 'Good job!',
    };
    final timingMessage = wasEarly
        ? 'Finished ahead of time'
        : wasOnTime
        ? 'Finished on time'
        : 'Another task checked off';
    final streakMessage = consistencyBoost == 0
        ? ''
        : ', including a ${consistencyBoost.toStringAsFixed(1)} consistency boost';

    return TaskCompletionReward(
      remark: remark,
      detail:
          '$timingMessage — ${stars.toStringAsFixed(1)} out of 5 stars$streakMessage.',
      stars: stars,
      wasEarly: wasEarly,
      wasOnTime: wasOnTime,
    );
  }

  static int streakIncludingCompletion(
    Iterable<PlannerTask> tasks,
    DateTime completion,
  ) {
    final days =
        tasks
            .where((task) => task.completedAt != null)
            .map((task) => _dateOnly(task.completedAt!))
            .toSet()
          ..add(_dateOnly(completion));
    return _streakEndingOn(days, _dateOnly(completion));
  }

  static ProductivityRewardSummary summarize(
    Iterable<PlannerTask> tasks, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = _dateOnly(current);
    final completed = tasks.where((task) => task.completedAt != null).toList();
    final completionDays = completed
        .map((task) => _dateOnly(task.completedAt!))
        .toSet();
    final sortedDays = completionDays.toList()..sort();

    var longestStreak = 0;
    var runningStreak = 0;
    DateTime? previous;
    final dailyStreakBoost = <DateTime, double>{};
    for (final day in sortedDays) {
      runningStreak = previous != null && day.difference(previous).inDays == 1
          ? runningStreak + 1
          : 1;
      previous = day;
      if (runningStreak > longestStreak) longestStreak = runningStreak;
      dailyStreakBoost[day] = _streakBoost(runningStreak);
    }

    var timingTotal = 0.0;
    var timingToday = 0.0;
    var completedToday = 0;
    var earlyToday = 0;
    var onTimeToday = 0;
    var lateToday = 0;
    for (final task in completed) {
      final completion = task.completedAt!;
      final wasEarly = completion.isBefore(task.dueAt);
      final wasOnTime = !completion.isAfter(task.dueAt);
      final timingStars = _timingStars(wasEarly, wasOnTime);
      timingTotal += timingStars;
      if (_sameDay(completion, today)) {
        completedToday++;
        timingToday += timingStars;
        if (wasEarly) {
          earlyToday++;
        } else if (wasOnTime) {
          onTimeToday++;
        } else {
          lateToday++;
        }
      }
    }

    var currentStreak = _streakEndingOn(completionDays, today);
    if (currentStreak == 0) {
      final yesterday = today.subtract(const Duration(days: 1));
      currentStreak = _streakEndingOn(completionDays, yesterday);
    }
    final totalStars = completed.isEmpty
        ? 0.0
        : (timingTotal / completed.length + _streakBoost(currentStreak)).clamp(
            0.0,
            5.0,
          );
    final starsToday = completedToday == 0
        ? 0.0
        : (timingToday / completedToday + (dailyStreakBoost[today] ?? 0.0))
              .clamp(0.0, 5.0);

    return ProductivityRewardSummary(
      totalStars: totalStars,
      starsToday: starsToday,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      completedToday: completedToday,
      earlyToday: earlyToday,
      onTimeToday: onTimeToday,
      lateToday: lateToday,
    );
  }

  static double _timingStars(bool wasEarly, bool wasOnTime) => wasEarly
      ? 5.0
      : wasOnTime
      ? 4.0
      : 2.5;

  static double _streakBoost(int streak) =>
      streak < 2 ? 0 : ((streak - 1) * .15).clamp(0.0, 1.0);

  static int _streakEndingOn(Set<DateTime> days, DateTime end) {
    if (!days.contains(end)) return 0;
    var streak = 0;
    var cursor = end;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _sameDay(DateTime value, DateTime day) =>
      value.year == day.year &&
      value.month == day.month &&
      value.day == day.day;
}
