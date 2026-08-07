import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_reminder/core/providers/app_providers.dart';
import 'package:smart_reminder/core/theme/app_theme.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';
import 'package:smart_reminder/features/tasks/domain/services/productivity_reward_service.dart';
import 'package:smart_reminder/features/tasks/presentation/add_task_screen.dart';
import 'package:smart_reminder/features/tasks/presentation/statistics_screen.dart';
import 'package:smart_reminder/features/tasks/presentation/task_details_screen.dart';
import 'package:smart_reminder/shared/widgets/glass_panel.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({
    super.key,
    this.onCompletedToday,
    this.onPending,
    this.onOverdue,
    this.onDailyProgress,
  });

  final VoidCallback? onCompletedToday;
  final VoidCallback? onPending;
  final VoidCallback? onOverdue;
  final VoidCallback? onDailyProgress;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeTasksProvider);
    final checklistProgress =
        ref.watch(checklistProgressProvider).value ??
        const <String, ChecklistProgressSummary>{};
    return state.when(
      loading: () => _DashboardContent(
        tasks: const [],
        checklistProgress: checklistProgress,
        onCompletedToday: onCompletedToday,
        onPending: onPending,
        onOverdue: onOverdue,
        onDailyProgress: onDailyProgress,
      ),
      error: (e, _) => Center(child: Text('Could not load dashboard: $e')),
      data: (tasks) => _DashboardContent(
        tasks: tasks,
        checklistProgress: checklistProgress,
        onCompletedToday: onCompletedToday,
        onPending: onPending,
        onOverdue: onOverdue,
        onDailyProgress: onDailyProgress,
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.tasks,
    required this.checklistProgress,
    this.onCompletedToday,
    this.onPending,
    this.onOverdue,
    this.onDailyProgress,
  });
  final List<PlannerTask> tasks;
  final Map<String, ChecklistProgressSummary> checklistProgress;
  final VoidCallback? onCompletedToday;
  final VoidCallback? onPending;
  final VoidCallback? onOverdue;
  final VoidCallback? onDailyProgress;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final now = DateTime.now();
    final today = tasks.where((t) => t.isToday).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final completedToday = today.where((t) => t.isCompleted).length;
    final pending = tasks.where((t) => !t.isCompleted).length;
    final overdue = tasks.where((t) => t.isOverdue).length;
    final pinned =
        tasks.where((task) => task.isPinned && !task.isCompleted).toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final upcoming =
        tasks
            .where((t) => !t.isCompleted && !t.isPinned && t.dueAt.isAfter(now))
            .toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    var progressUnits = today.length;
    var completedUnits = completedToday;
    for (final task in today) {
      final checklist = checklistProgress[task.id];
      if (checklist == null) continue;
      progressUnits += checklist.total;
      completedUnits += checklist.checked;
    }
    final progress = progressUnits == 0 ? 0.0 : completedUnits / progressUnits;
    final rewards = ProductivityRewards.summarize(tasks, now: now);
    final openInsights =
        onDailyProgress ??
        () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const StatisticsScreen()),
        );
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isLight
            ? theme.colorScheme.primary
            : theme.colorScheme.secondaryContainer,
        foregroundColor: isLight
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSecondaryContainer,
        elevation: isLight ? 8 : 5,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const AddTaskScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Quick add'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 112),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: const _LiveGreeting()),
                      IconButton.filledTonal(
                        key: const Key('dashboard-full-overview'),
                        tooltip: 'Open full overview',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => _DashboardOverviewScreen(
                              tasks: tasks,
                              checklistProgress: checklistProgress,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.dashboard_customize_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (_, c) {
                      final compact = c.maxWidth < 760;
                      final width = compact ? 156.0 : (c.maxWidth - 36) / 4;
                      final cards = <Widget>[
                        _Stat(
                          key: const Key('stat-completed-today'),
                          width: width,
                          label: 'Completed today',
                          value: '$completedToday',
                          color: Theme.of(context).colorScheme.primary,
                          icon: Icons.check_circle_outline,
                          onTap: onCompletedToday,
                          compact: compact,
                        ),
                        _Stat(
                          key: const Key('stat-pending'),
                          width: width,
                          label: 'Pending',
                          value: '$pending',
                          color: Theme.of(context).colorScheme.secondary,
                          icon: Icons.pending_actions,
                          onTap: onPending,
                          compact: compact,
                        ),
                        _Stat(
                          key: const Key('stat-overdue'),
                          width: width,
                          label: 'Overdue',
                          value: '$overdue',
                          color: Theme.of(context).colorScheme.error,
                          icon: Icons.warning_amber,
                          onTap: onOverdue,
                          compact: compact,
                        ),
                        _Stat(
                          key: const Key('stat-daily-progress'),
                          width: width,
                          label: 'Daily progress',
                          value: '${(progress * 100).round()}%',
                          color: Theme.of(context).colorScheme.primary,
                          icon: Icons.donut_small_rounded,
                          onTap: openInsights,
                          compact: compact,
                        ),
                      ];
                      if (compact) {
                        return SizedBox(
                          height: 104,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: cards.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (_, index) => cards[index],
                          ),
                        );
                      }
                      return Wrap(spacing: 12, runSpacing: 12, children: cards);
                    },
                  ),
                  const SizedBox(height: 18),
                  _DailyProductivityReport(
                    progress: progress,
                    completedUnits: completedUnits,
                    totalUnits: progressUnits,
                    rewards: rewards,
                    onTap: openInsights,
                  ),
                  const SizedBox(height: 14),
                  _TaskSection(
                    title: 'Pinned tasks',
                    icon: Icons.push_pin_rounded,
                    tasks: pinned,
                    empty: 'Pin important tasks to keep them here.',
                  ),
                  const SizedBox(height: 14),
                  _TaskSection(
                    title: "Today's timeline",
                    icon: Icons.timeline,
                    tasks: today.where((t) => !t.isCompleted).toList(),
                    empty: 'Your day is clear.',
                  ),
                  const SizedBox(height: 14),
                  _TaskSection(
                    title: 'Next five reminders',
                    icon: Icons.upcoming,
                    tasks: upcoming.take(5).toList(),
                    empty: 'Nothing upcoming.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveGreeting extends StatefulWidget {
  const _LiveGreeting();

  @override
  State<_LiveGreeting> createState() => _LiveGreetingState();
}

class _LiveGreetingState extends State<_LiveGreeting> {
  DateTime _now = DateTime.now();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _scheduleNextMinute();
  }

  void _scheduleNextMinute() {
    final current = DateTime.now();
    final nextMinute = DateTime(
      current.year,
      current.month,
      current.day,
      current.hour,
      current.minute + 1,
    );
    _refreshTimer = Timer(nextMinute.difference(current), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _scheduleNextMinute();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _greeting(_now),
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          fontFamily: 'Lora',
          fontWeight: FontWeight.w700,
          letterSpacing: -1.1,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        DateFormat('EEEE, d MMMM y').format(_now),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).brightness == Brightness.light
              ? AppColors.lightOnSurface
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  String _greeting(DateTime now) => switch (now.hour) {
    < 5 => 'Good Night',
    < 12 => 'Good Morning',
    < 17 => 'Good Afternoon',
    < 21 => 'Good Evening',
    _ => 'Good Night',
  };
}

class _DashboardOverviewScreen extends StatelessWidget {
  const _DashboardOverviewScreen({
    required this.tasks,
    required this.checklistProgress,
  });

  final List<PlannerTask> tasks;
  final Map<String, ChecklistProgressSummary> checklistProgress;

  @override
  Widget build(BuildContext context) {
    final recent = tasks.where((task) => task.isCompleted).toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    return Scaffold(
      appBar: AppBar(title: const Text('Planner overview')),
      body: AtmosphericBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            _Summary(tasks: tasks),
            const SizedBox(height: 14),
            _TaskSection(
              title: 'Recently completed',
              icon: Icons.history,
              tasks: recent.take(3).toList(),
              empty: 'Completed tasks appear here.',
            ),
            const SizedBox(height: 14),
            _PlannerInsights(
              tasks: tasks,
              checklistProgress: checklistProgress,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlannerInsights extends StatelessWidget {
  const _PlannerInsights({
    required this.tasks,
    required this.checklistProgress,
  });

  final List<PlannerTask> tasks;
  final Map<String, ChecklistProgressSummary> checklistProgress;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final completed = tasks.where((task) => task.isCompleted).length;
    var completionUnits = tasks.length;
    var completedUnits = completed;
    var uncheckedChecklistItems = 0;
    for (final task in tasks) {
      final checklist = checklistProgress[task.id];
      if (checklist == null) continue;
      completionUnits += checklist.total;
      completedUnits += checklist.checked;
      uncheckedChecklistItems += checklist.total - checklist.checked;
    }
    final completion = completionUnits == 0
        ? 0.0
        : completedUnits / completionUnits;
    final activeCategories = tasks
        .where((task) => !task.isCompleted && task.categoryId != null)
        .map((task) => task.categoryId)
        .toSet()
        .length;
    final deadlineLimit = now.add(const Duration(days: 3));
    final approaching = tasks
        .where(
          (task) =>
              !task.isCompleted &&
              task.dueAt.isAfter(now) &&
              task.dueAt.isBefore(deadlineLimit),
        )
        .length;
    final days = [
      for (var offset = 6; offset >= 0; offset--)
        DateTime(now.year, now.month, now.day).subtract(Duration(days: offset)),
    ];
    final productivityScores = [for (final day in days) _scoreForDay(day)];

    return LayoutBuilder(
      builder: (context, constraints) {
        final completionPanel = GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Overall completion'),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox.square(
                    dimension: 82,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: completion,
                          strokeWidth: 9,
                          backgroundColor: Colors.white10,
                        ),
                        Text(
                          '${(completion * 100).round()}%',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$completed of ${tasks.length} tasks completed',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        _InsightLine(
                          icon: Icons.folder_outlined,
                          text: '$activeCategories active categories',
                        ),
                        const SizedBox(height: 6),
                        _InsightLine(
                          icon: Icons.event_note_outlined,
                          text: '$approaching deadlines within 3 days',
                        ),
                        if (uncheckedChecklistItems > 0) ...[
                          const SizedBox(height: 8),
                          _InsightLine(
                            icon: Icons.check_box_outline_blank_rounded,
                            text:
                                '$uncheckedChecklistItems unchecked checklist ${uncheckedChecklistItems == 1 ? 'item is' : 'items are'} lowering this rate. Open the task and tick each finished step.',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        final trendPanel = GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: SectionLabel('Productivity score • 0–5'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const StatisticsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.insights_outlined, size: 18),
                    label: const Text('Details'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ProductivityScoreGraph(days: days, values: productivityScores),
            ],
          ),
        );

        if (constraints.maxWidth < 780) {
          return Column(
            children: [completionPanel, const SizedBox(height: 14), trendPanel],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: completionPanel),
            const SizedBox(width: 14),
            Expanded(flex: 3, child: trendPanel),
          ],
        );
      },
    );
  }

  static bool _sameDay(DateTime? value, DateTime day) =>
      value != null &&
      value.year == day.year &&
      value.month == day.month &&
      value.day == day.day;

  double _scoreForDay(DateTime day) {
    final dayTasks = tasks.where((task) => _sameDay(task.dueAt, day)).toList();
    if (dayTasks.isEmpty) return 0;
    var units = dayTasks.length;
    var completedUnits = dayTasks.where((task) => task.isCompleted).length;
    for (final task in dayTasks) {
      final checklist = checklistProgress[task.id];
      if (checklist == null) continue;
      units += checklist.total;
      completedUnits += checklist.checked;
    }
    final completionScore = units == 0 ? 0.0 : completedUnits / units * 4;
    final completedTasks = dayTasks.where((task) => task.isCompleted).toList();
    final onTime = completedTasks
        .where((task) => !task.completedAt!.isAfter(task.dueAt))
        .length;
    final timingScore = completedTasks.isEmpty
        ? 0.0
        : onTime / completedTasks.length;
    return (completionScore + timingScore).clamp(0.0, 5.0);
  }
}

class _InsightLine extends StatelessWidget {
  const _InsightLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: Theme.of(context).colorScheme.secondary),
      const SizedBox(width: 7),
      Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
    ],
  );
}

class _ProductivityScoreGraph extends StatelessWidget {
  const _ProductivityScoreGraph({required this.days, required this.values});

  final List<DateTime> days;
  final List<double> values;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 174,
    child: LineChart(
      LineChartData(
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: 5,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map(
                  (spot) => LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)} / 5',
                    TextStyle(
                      color: Theme.of(context).colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        gridData: FlGridData(
          horizontalInterval: 1,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: .28),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 25,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, _) {
                final index = value.toInt();
                if (index < 0 || index >= days.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    DateFormat('E').format(days[index]).substring(0, 1),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var index = 0; index < values.length; index++)
                FlSpot(index.toDouble(), values[index]),
            ],
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: 3.5,
                color: Theme.of(context).colorScheme.secondary,
                strokeWidth: 1.5,
                strokeColor: Theme.of(context).colorScheme.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .12),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.width,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
    this.compact = false,
    super.key,
  });
  final double width;
  final String label, value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  final bool compact;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: GlassPanel(
      onTap: onTap,
      padding: EdgeInsets.all(compact ? 14 : 20),
      child: Row(
        children: [
          Icon(icon, color: color, size: compact ? 21 : 24),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: compact
                      ? Theme.of(context).textTheme.titleLarge
                      : Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _DailyProductivityReport extends StatelessWidget {
  const _DailyProductivityReport({
    required this.progress,
    required this.completedUnits,
    required this.totalUnits,
    required this.rewards,
    required this.onTap,
  });

  final double progress;
  final int completedUnits;
  final int totalUnits;
  final ProductivityRewardSummary rewards;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    final remark = switch (percent) {
      >= 100 => 'Excellent day — everything planned is complete!',
      >= 75 => 'Great work — you are almost there!',
      >= 50 => 'Good progress — keep the momentum going!',
      > 0 => 'A positive start — one step at a time.',
      _ => 'Your daily report will grow as tasks are completed.',
    };
    return GlassPanel(
      key: const Key('daily-productivity-report'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_graph_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Today's report",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                'View insights',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox.square(
                dimension: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: .35),
                    ),
                    Text(
                      '$percent%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      totalUnits == 0
                          ? 'No tasks planned for today'
                          : '$completedUnits of $totalUnits steps complete',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _ReportChip(
                          icon: Icons.star_rounded,
                          label:
                              '${rewards.starsToday.toStringAsFixed(1)} / 5 stars',
                        ),
                        _ReportChip(
                          icon: Icons.local_fire_department_rounded,
                          label: '${rewards.currentStreak}-day streak',
                        ),
                        _ReportChip(
                          icon: Icons.schedule_rounded,
                          label:
                              '${rewards.earlyToday + rewards.onTimeToday} on time',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(remark, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ReportChip extends StatelessWidget {
  const _ReportChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}

class _TaskSection extends StatelessWidget {
  const _TaskSection({
    required this.title,
    required this.icon,
    required this.tasks,
    required this.empty,
  });
  final String title, empty;
  final IconData icon;
  final List<PlannerTask> tasks;
  @override
  Widget build(BuildContext context) => GlassPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 10),
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text(empty)),
          )
        else
          for (final task in tasks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(
                DateFormat('h:mm').format(task.dueAt),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              title: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                task.isOverdue
                    ? 'Overdue'
                    : DateFormat('d MMM • h:mm a').format(task.dueAt),
              ),
              trailing: Icon(
                task.isCompleted ? Icons.check_circle : Icons.chevron_right,
                color: task.isOverdue ? AppColors.error : null,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => TaskDetailsScreen(taskId: task.id),
                ),
              ),
            ),
      ],
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.tasks});
  final List<PlannerTask> tasks;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    bool today(DateTime? d) =>
        d != null &&
        d.year == now.year &&
        d.month == now.month &&
        d.day == now.day;
    final completed = tasks.where((t) => today(t.completedAt)).length;
    final pending = tasks.where((t) => t.isToday && !t.isCompleted).length;
    final overdue = tasks.where((t) => t.isOverdue).length;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.summarize_outlined,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Daily summary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('$completed completed • $pending pending • $overdue overdue'),
          const SizedBox(height: 5),
          Text(
            completed > 0
                ? 'Nice progress today. Keep your remaining reminders in view.'
                : 'Complete a task to begin today’s summary.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
