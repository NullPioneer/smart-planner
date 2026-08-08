import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_reminder/core/providers/app_providers.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';
import 'package:smart_reminder/features/tasks/domain/services/productivity_reward_service.dart';
import 'package:smart_reminder/features/tasks/presentation/task_details_screen.dart';
import 'package:smart_reminder/shared/widgets/glass_panel.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  DateTime _selectedDate = _dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
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
    final todayTasks =
        tasks.where((task) => _sameDay(task.dueAt, _selectedDate)).toList()
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
    final selectedRewards = ProductivityRewards.summarize(
      tasks,
      now: _selectedDate,
    );
    final weeklyDays = [
      for (var offset = 6; offset >= 0; offset--)
        _dateOnly(now.subtract(Duration(days: offset))),
    ];
    final weeklyCompletionRates = <DateTime, double>{};
    for (final day in weeklyDays) {
      final dayTasks = tasks
          .where((task) => _sameDay(task.dueAt, day))
          .toList();
      var units = dayTasks.length;
      var completedUnits = dayTasks.where((task) => task.isCompleted).length;
      for (final task in dayTasks) {
        final checklist = checklistProgress[task.id];
        if (checklist == null) continue;
        units += checklist.total;
        completedUnits += checklist.checked;
      }
      weeklyCompletionRates[day] = units == 0 ? 0 : completedUnits / units;
    }
    final categorySlices = _buildCategorySlices(context, tasks, categories);
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
      body: AtmosphericBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            SizedBox(
              height: 84,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _stat(context, 'Created', '${tasks.length}'),
                  const SizedBox(width: 8),
                  _stat(context, 'Completed', '$completed'),
                  const SizedBox(width: 8),
                  _stat(context, 'Pending', '$pending'),
                  const SizedBox(width: 8),
                  _stat(context, 'Overdue', '$overdue'),
                  const SizedBox(width: 8),
                  _stat(context, 'Completion', '${(rate * 100).round()}%'),
                  const SizedBox(width: 8),
                  _stat(
                    context,
                    'Star rating',
                    '${rewards.totalStars.toStringAsFixed(1)} / 5',
                  ),
                  const SizedBox(width: 8),
                  _stat(
                    context,
                    'Current streak',
                    '${rewards.currentStreak} days',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
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
              const SizedBox(height: 10),
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
                  const SizedBox(height: 8),
                  _dateNavigator(context),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: dailyProgress,
                      minHeight: 7,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: .35),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 104,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
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
                        const SizedBox(width: 8),
                        _dailyMetric(
                          context,
                          Icons.task_alt_rounded,
                          '${selectedRewards.completedToday}',
                          'Tasks completed',
                        ),
                        const SizedBox(width: 8),
                        _dailyMetric(
                          context,
                          Icons.schedule_rounded,
                          '${selectedRewards.earlyToday + selectedRewards.onTimeToday}',
                          'On time or early',
                        ),
                        const SizedBox(width: 8),
                        _dailyMetric(
                          context,
                          Icons.star_rounded,
                          '${selectedRewards.starsToday.toStringAsFixed(1)} / 5',
                          'Star rating today',
                        ),
                        const SizedBox(width: 8),
                        _dailyMetric(
                          context,
                          Icons.local_fire_department_rounded,
                          '${selectedRewards.currentStreak} days',
                          'Current streak',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    _dailyRemark(dailyProgress, selectedRewards),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (dailyUncheckedChecklistItems > 0) ...[
                    const SizedBox(height: 9),
                    Text(
                      'Action needed: Open the task and tick the $dailyUncheckedChecklistItems completed checklist ${dailyUncheckedChecklistItems == 1 ? 'item' : 'items'}. Unchecked items are reducing the selected day’s percentage.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly trend',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150,
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
            const SizedBox(height: 10),
            GlassPanel(
              key: const Key('category-distribution-panel'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Category distribution',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (categorySlices.length > 4)
                        TextButton(
                          key: const Key('view-all-categories'),
                          onPressed: () => _showAllCategories(
                            context,
                            categorySlices,
                            tasks.length,
                          ),
                          child: const Text('View all'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _categoryDistributionChart(
                    context,
                    categorySlices,
                    tasks.length,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GlassPanel(
              key: const Key('weekly-completions-panel'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Weekly completions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        '${DateFormat('d MMM').format(weeklyDays.first)} - ${DateFormat('d MMM').format(weeklyDays.last)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 146,
                    child: _weeklyCompletionChart(
                      context,
                      weeklyCompletionRates,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_CategorySlice> _buildCategorySlices(
    BuildContext context,
    List<PlannerTask> tasks,
    List<TaskCategory> categories,
  ) {
    final categoryIds = categories.map((category) => category.id).toSet();
    final slices = <_CategorySlice>[
      for (final category in categories)
        if (tasks.where((task) => task.categoryId == category.id).isNotEmpty)
          _CategorySlice(
            label: category.name,
            count: tasks.where((task) => task.categoryId == category.id).length,
            color: Color(category.colorValue),
          ),
    ];
    final uncategorized = tasks
        .where(
          (task) =>
              task.categoryId == null || !categoryIds.contains(task.categoryId),
        )
        .length;
    if (uncategorized > 0) {
      slices.add(
        _CategorySlice(
          label: 'Uncategorized',
          count: uncategorized,
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }
    slices.sort((a, b) => b.count.compareTo(a.count));

    return slices;
  }

  Widget _categoryDistributionChart(
    BuildContext context,
    List<_CategorySlice> slices,
    int totalTasks,
  ) {
    final visible = slices.length <= 4
        ? slices
        : [
            ...slices.take(3),
            _CategorySlice(
              label: 'Other',
              count: slices
                  .skip(3)
                  .fold<int>(0, (total, slice) => total + slice.count),
              color: Theme.of(context).colorScheme.secondary,
            ),
          ];
    if (visible.isEmpty) {
      return const Center(
        key: Key('category-distribution-chart'),
        child: Text('No categorized tasks yet.'),
      );
    }
    return SizedBox(
      key: const Key('category-distribution-chart'),
      height: 142,
      child: Row(
        children: [
          SizedBox(
            width: 134,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 34,
                sectionsSpace: 2,
                sections: [
                  for (final slice in visible)
                    PieChartSectionData(
                      value: slice.count.toDouble(),
                      color: slice.color,
                      radius: 36,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < visible.length; index++) ...[
                  _categoryLegendRow(context, visible[index], totalTasks),
                  if (index < visible.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryLegendRow(
    BuildContext context,
    _CategorySlice slice,
    int totalTasks,
  ) {
    final ratio = totalTasks == 0 ? 0.0 : slice.count / totalTasks;
    return Semantics(
      label:
          '${slice.label}: ${slice.count} tasks, ${(ratio * 100).round()} percent',
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: slice.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${(ratio * 100).round()}%',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryRow(
    BuildContext context,
    _CategorySlice slice,
    int totalTasks,
  ) {
    final ratio = totalTasks == 0 ? 0.0 : slice.count / totalTasks;
    return Semantics(
      label:
          '${slice.label}: ${slice.count} tasks, ${(ratio * 100).round()} percent',
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: slice.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  slice.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(
                '${slice.count} / ${(ratio * 100).round()}%',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              color: slice.color,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: .45),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAllCategories(
    BuildContext context,
    List<_CategorySlice> slices,
    int totalTasks,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: .72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Category distribution',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  key: const Key('all-category-distribution'),
                  itemCount: slices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) =>
                      _categoryRow(sheetContext, slices[index], totalTasks),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _weeklyCompletionChart(
    BuildContext context,
    Map<DateTime, double> completions,
  ) {
    final theme = Theme.of(context);
    return Semantics(
      key: const Key('weekly-completions-chart'),
      label: 'Completions over the last seven days',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in completions.entries)
            Expanded(
              child: Semantics(
                label:
                    '${DateFormat('EEEE, d MMMM').format(entry.key)}: ${(entry.value * 100).round()} percent complete',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: [
                      Text(
                        '${(entry.value * 100).round()}%',
                        key: Key(
                          'weekly-value-${DateFormat('yyyyMMdd').format(entry.key)}',
                        ),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: entry.value == 0
                                ? .04
                                : entry.value.clamp(.06, 1.0),
                            child: Container(
                              width: 22,
                              decoration: BoxDecoration(
                                color: entry.value == 0
                                    ? theme.colorScheme.outlineVariant
                                    : theme.colorScheme.primary,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        DateFormat('E').format(entry.key).substring(0, 1),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        DateFormat('d').format(entry.key),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) => SizedBox(
    width: 116,
    child: GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );

  Widget _dateNavigator(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = _sameDay(_selectedDate, DateTime.now());
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .4),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          IconButton(
            key: const Key('insights-previous-day'),
            tooltip: 'Previous day',
            visualDensity: VisualDensity.compact,
            onPressed: () => _moveSelectedDate(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: TextButton.icon(
              key: const Key('insights-date-picker'),
              onPressed: () => _pickDate(context),
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text(
                isToday
                    ? 'Today - ${DateFormat('d MMM y').format(_selectedDate)}'
                    : DateFormat('EEE, d MMM y').format(_selectedDate),
                key: const Key('insights-selected-date'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            key: const Key('insights-next-day'),
            tooltip: 'Next day',
            visualDensity: VisualDensity.compact,
            onPressed: () => _moveSelectedDate(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  void _moveSelectedDate(int days) {
    setState(() {
      _selectedDate = _dateOnly(_selectedDate.add(Duration(days: days)));
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = _dateOnly(picked));
  }

  Widget _dailyMetric(
    BuildContext context,
    IconData icon,
    String value,
    String label, {
    Key? key,
    VoidCallback? onTap,
  }) {
    final borderRadius = BorderRadius.circular(4);
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
            width: 142,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
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
    return 'Complete a task to begin this day’s productivity story.';
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _sameDay(DateTime value, DateTime day) =>
      value.year == day.year &&
      value.month == day.month &&
      value.day == day.day;
}

final class _CategorySlice {
  const _CategorySlice({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;
}
