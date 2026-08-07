import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_reminder/core/providers/app_providers.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';
import 'package:smart_reminder/features/tasks/domain/services/productivity_reward_service.dart';
import 'package:smart_reminder/features/tasks/presentation/task_details_screen.dart';
import 'package:smart_reminder/shared/widgets/glass_panel.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(activeTasksProvider).value ?? const <PlannerTask>[];
    final categories =
        ref.watch(taskCategoriesProvider).value ?? const <TaskCategory>[];
    final checklistProgress =
        ref.watch(checklistProgressProvider).value ??
        const <String, ChecklistProgressSummary>{};
    final completed = tasks.where((t) => t.isCompleted).length;
    final pending = tasks.where((t) => !t.isCompleted).length;
    final overdue = tasks.where((t) => t.isOverdue).length;
    var overallUnits = tasks.length;
    var overallCompletedUnits = completed;
    var uncheckedChecklistItems = 0;
    for (final task in tasks) {
      final checklist = checklistProgress[task.id];
      if (checklist == null) continue;
      overallUnits += checklist.total;
      overallCompletedUnits += checklist.checked;
      uncheckedChecklistItems += checklist.total - checklist.checked;
    }
    final rate = overallUnits == 0 ? 0.0 : overallCompletedUnits / overallUnits;
    final now = DateTime.now();
    final todayTasks = tasks.where((task) => task.isToday).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    var dailyUnits = todayTasks.length;
    var dailyCompletedUnits = todayTasks
        .where((task) => task.isCompleted)
        .length;
    var dailyUncheckedChecklistItems = 0;
    for (final task in todayTasks) {
      final checklist = checklistProgress[task.id];
      if (checklist == null) continue;
      dailyUnits += checklist.total;
      dailyCompletedUnits += checklist.checked;
      dailyUncheckedChecklistItems += checklist.total - checklist.checked;
    }
    final dailyProgress = dailyUnits == 0
        ? 0.0
        : dailyCompletedUnits / dailyUnits;
    PlannerTask? incompleteChecklistTask;
    for (final task in todayTasks) {
      final checklist = checklistProgress[task.id];
      if (checklist != null && checklist.checked < checklist.total) {
        incompleteChecklistTask = task;
        break;
      }
    }
    final incompleteTask = todayTasks
        .where((task) => !task.isCompleted)
        .firstOrNull;
    final stepsTarget = incompleteChecklistTask ?? incompleteTask;
    final rewards = ProductivityRewards.summarize(tasks, now: now);
    final byDay = <int, int>{for (var i = 1; i <= 7; i++) i: 0};
    for (final task in tasks.where((t) => t.isCompleted)) {
      byDay[task.completedAt!.weekday] = byDay[task.completedAt!.weekday]! + 1;
    }
    final productive = byDay.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    final busiest = <String, int>{};
    for (final task in tasks) {
      final key = DateFormat('EEE, d MMM').format(task.dueAt);
      busiest[key] = (busiest[key] ?? 0) + 1;
    }
    final busiestDay = busiest.isEmpty
        ? '—'
        : busiest.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final maxWeekly = byDay.values.fold<int>(1, (m, v) => v > m ? v : m);
    final monthly = <FlSpot>[
      for (var i = 0; i < 30; i++)
        FlSpot(
          i.toDouble(),
          tasks
              .where((task) {
                final date = now.subtract(Duration(days: 29 - i));
                final completedAt = task.completedAt;
                return completedAt != null &&
                    completedAt.year == date.year &&
                    completedAt.month == date.month &&
                    completedAt.day == date.day;
              })
              .length
              .toDouble(),
        ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Productivity Insights')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _stat(context, 'Created', '${tasks.length}'),
              _stat(context, 'Completed', '$completed'),
              _stat(context, 'Pending', '$pending'),
              _stat(context, 'Overdue', '$overdue'),
              _stat(context, 'Completion', '${(rate * 100).round()}%'),
              _stat(
                context,
                'Star rating',
                '${rewards.totalStars.toStringAsFixed(1)} / 5',
              ),
              _stat(context, 'Current streak', '${rewards.currentStreak} days'),
            ],
          ),
          const SizedBox(height: 14),
          if (uncheckedChecklistItems > 0) ...[
            GlassPanel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Why your completion rate is ${(rate * 100).round()}%',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$uncheckedChecklistItems checklist ${uncheckedChecklistItems == 1 ? 'item is' : 'items are'} still unchecked. Open the relevant task, complete each remaining step, and tick its checkbox. The percentage will update immediately.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          GlassPanel(
            key: const Key('productivity-daily-report'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.today_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Today's report",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Text(
                      '${(dailyProgress * 100).round()}%',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: dailyProgress,
                    minHeight: 10,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: .35),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _dailyMetric(
                      context,
                      Icons.checklist_rounded,
                      '$dailyCompletedUnits / $dailyUnits',
                      'Steps complete',
                      key: const Key('daily-steps-complete'),
                      onTap: stepsTarget == null
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => TaskDetailsScreen(
                                  taskId: stepsTarget.id,
                                  focusIncompleteChecklist:
                                      incompleteChecklistTask != null,
                                ),
                              ),
                            ),
                    ),
                    _dailyMetric(
                      context,
                      Icons.task_alt_rounded,
                      '${rewards.completedToday}',
                      'Tasks completed',
                    ),
                    _dailyMetric(
                      context,
                      Icons.schedule_rounded,
                      '${rewards.earlyToday + rewards.onTimeToday}',
                      'On time or early',
                    ),
                    _dailyMetric(
                      context,
                      Icons.star_rounded,
                      '${rewards.starsToday.toStringAsFixed(1)} / 5',
                      'Star rating today',
                    ),
                    _dailyMetric(
                      context,
                      Icons.local_fire_department_rounded,
                      '${rewards.currentStreak} days',
                      'Current streak',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _dailyRemark(dailyProgress, rewards),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (dailyUncheckedChecklistItems > 0) ...[
                  const SizedBox(height: 9),
                  Text(
                    'Action needed: Open today’s task and tick the $dailyUncheckedChecklistItems completed checklist ${dailyUncheckedChecklistItems == 1 ? 'item' : 'items'}. Unchecked items are reducing today’s percentage.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly trend',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 210,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: 29,
                      minY: 0,
                      lineBarsData: [
                        LineChartBarData(
                          spots: monthly,
                          isCurved: true,
                          color: Theme.of(context).colorScheme.secondary,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Theme.of(
                              context,
                            ).colorScheme.secondary.withValues(alpha: .12),
                          ),
                        ),
                      ],
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category distribution',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(
                  height: 230,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 45,
                      sections: [
                        for (final category in categories)
                          if (tasks.any((t) => t.categoryId == category.id))
                            PieChartSectionData(
                              value: tasks
                                  .where((t) => t.categoryId == category.id)
                                  .length
                                  .toDouble(),
                              title: category.name,
                              color: Color(category.colorValue),
                              radius: 65,
                              titleStyle: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly completions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      maxY: (maxWeekly + 1).toDouble(),
                      barGroups: [
                        for (var i = 1; i <= 7; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: byDay[i]!.toDouble(),
                                color: Theme.of(context).colorScheme.primary,
                                width: 18,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ],
                          ),
                      ],
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) => Text(
                              const ['', 'M', 'T', 'W', 'T', 'F', 'S', 'S'][v
                                  .toInt()],
                            ),
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Highlights',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  'Most productive day: ${const ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][productive.key]}',
                ),
                Text('Busiest date: $busiestDay'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) => SizedBox(
    width: 150,
    child: GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(label),
        ],
      ),
    ),
  );

  Widget _dailyMetric(
    BuildContext context,
    IconData icon,
    String value,
    String label, {
    Key? key,
    VoidCallback? onTap,
  }) {
    final borderRadius = BorderRadius.circular(14);
    return Semantics(
      button: onTap != null,
      label: onTap == null
          ? '$label, $value'
          : '$label, $value. Open the first incomplete step.',
      child: Material(
        key: key,
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Ink(
            width: 148,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .08),
              borderRadius: borderRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 19,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    if (onTap != null) ...[
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _dailyRemark(double progress, ProductivityRewardSummary rewards) {
    if (progress >= 1) return 'Excellent! You completed your full daily plan.';
    if (progress >= .75) return 'Great job! The finish line is close.';
    if (progress >= .5) return 'Good progress! Keep the momentum going.';
    if (rewards.completedToday > 0) {
      return 'Nice start! Every completed task moves the day forward.';
    }
    return 'Complete a task to begin today’s productivity story.';
  }
}
