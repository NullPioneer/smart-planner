import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_reminder/core/providers/app_providers.dart';
import 'package:smart_reminder/core/theme/app_theme.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';
import 'package:smart_reminder/features/tasks/presentation/add_task_screen.dart';
import 'package:smart_reminder/features/tasks/presentation/task_details_screen.dart';
import 'package:smart_reminder/shared/widgets/glass_panel.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focused = DateTime.now(), _selected = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;
  bool _dayOnly = false;
  bool _calendarExpanded = false;
  TaskPriority? _priorityFilter;
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final tasks = ref.watch(activeTasksProvider).value ?? const <PlannerTask>[];
    final categories =
        ref.watch(taskCategoriesProvider).value ?? const <TaskCategory>[];
    final visibleTasks = tasks
        .where(
          (task) =>
              (_priorityFilter == null || task.priority == _priorityFilter) &&
              (_categoryFilter == null || task.categoryId == _categoryFilter),
        )
        .toList();
    final selected =
        visibleTasks.where((t) => isSameDay(t.dueAt, _selected)).toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final now = DateTime.now();
    final activeCategories = tasks
        .where((task) => !task.isCompleted && task.categoryId != null)
        .map((task) => task.categoryId)
        .toSet()
        .length;
    final approaching = tasks
        .where(
          (task) =>
              !task.isCompleted &&
              task.dueAt.isAfter(now) &&
              task.dueAt.isBefore(now.add(const Duration(days: 3))),
        )
        .length;
    return ListView(
      padding: isCompact
          ? const EdgeInsets.fromLTRB(16, 12, 16, 92)
          : const EdgeInsets.fromLTRB(16, 16, 16, 92),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final heading = Row(
                      children: [
                        IconButton.filledTonal(
                          key: const Key('open-calendar-picker'),
                          tooltip: _calendarExpanded
                              ? 'Hide calendar'
                              : 'Show calendar',
                          onPressed: () => setState(
                            () => _calendarExpanded = !_calendarExpanded,
                          ),
                          icon: const Icon(Icons.calendar_month_rounded),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Calendar',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                '$activeCategories categories • $approaching deadlines soon',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                    final selector = Visibility(
                      visible: _calendarExpanded,
                      child: SegmentedButton<int>(
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: const [
                          ButtonSegment(value: 0, label: Text('Month')),
                          ButtonSegment(value: 1, label: Text('Week')),
                          ButtonSegment(value: 2, label: Text('Day')),
                        ],
                        selected: {
                          _dayOnly
                              ? 2
                              : _format == CalendarFormat.week
                              ? 1
                              : 0,
                        },
                        onSelectionChanged: (v) => setState(() {
                          _dayOnly = v.first == 2;
                          _format = v.first == 1
                              ? CalendarFormat.week
                              : CalendarFormat.month;
                        }),
                      ),
                    );
                    if (constraints.maxWidth < 610) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          heading,
                          if (_calendarExpanded) ...[
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: selector,
                            ),
                          ],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: heading),
                        if (_calendarExpanded) ...[
                          const SizedBox(width: 12),
                          selector,
                        ],
                      ],
                    );
                  },
                ),
                SizedBox(height: isCompact ? 10 : 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('calendar-filter'),
                      onPressed: () => _showFilters(categories),
                      icon: const Icon(Icons.filter_list),
                      label: Text(
                        _priorityFilter == null && _categoryFilter == null
                            ? 'Filter'
                            : 'Filter • ${(_priorityFilter != null ? 1 : 0) + (_categoryFilter != null ? 1 : 0)}',
                      ),
                    ),
                    FilledButton.tonalIcon(
                      key: const Key('calendar-new-event'),
                      onPressed: () => _add(_selected),
                      icon: const Icon(Icons.add),
                      label: const Text('New event'),
                    ),
                  ],
                ),
                if (_calendarExpanded) ...[
                  SizedBox(height: isCompact ? 10 : 14),
                  SectionLabel(
                    _dayOnly
                        ? 'Day view'
                        : _format == CalendarFormat.week
                        ? 'Week view'
                        : 'Month view',
                  ),
                  SizedBox(height: isCompact ? 6 : 10),
                ],
                if (_calendarExpanded && !_dayOnly)
                  GlassPanel(
                    padding: EdgeInsets.all(isCompact ? 10 : 20),
                    child: TableCalendar<PlannerTask>(
                      firstDay: DateTime.utc(2020),
                      lastDay: DateTime.utc(2040),
                      focusedDay: _focused,
                      calendarFormat: _format,
                      rowHeight: isCompact ? 40 : 52,
                      daysOfWeekHeight: isCompact ? 24 : 28,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Month',
                        CalendarFormat.week: 'Week',
                      },
                      selectedDayPredicate: (d) => isSameDay(d, _selected),
                      eventLoader: (d) => visibleTasks
                          .where((t) => isSameDay(t.dueAt, d))
                          .toList(),
                      onDaySelected: (s, f) => setState(() {
                        _selected = s;
                        _focused = f;
                      }),
                      onDayLongPressed: (s, f) => _add(s),
                      onPageChanged: (f) => _focused = f,
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        headerPadding: EdgeInsets.symmetric(
                          vertical: isCompact ? 3 : 8,
                        ),
                        leftChevronPadding: EdgeInsets.zero,
                        rightChevronPadding: EdgeInsets.zero,
                        titleTextStyle: TextStyle(
                          fontSize: isCompact ? 16 : 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (c, d, f) =>
                            _heatCell(c, d, visibleTasks),
                        outsideBuilder: (c, d, f) => Opacity(
                          opacity: .35,
                          child: _heatCell(c, d, visibleTasks),
                        ),
                        markerBuilder: (c, d, events) {
                          if (events.isEmpty) return null;
                          final high = events.any(
                                (t) =>
                                    t.priority == TaskPriority.high &&
                                    !t.isCompleted,
                              ),
                              completed = events.every((t) => t.isCompleted);
                          return Positioned(
                            bottom: 4,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: completed
                                    ? Theme.of(c).colorScheme.primary
                                    : high
                                    ? AppColors.error
                                    : Theme.of(c).colorScheme.secondary,
                              ),
                            ),
                          );
                        },
                      ),
                      calendarStyle: CalendarStyle(
                        cellMargin: EdgeInsets.all(isCompact ? 2 : 4),
                        defaultTextStyle: TextStyle(
                          fontSize: isCompact ? 12 : 14,
                        ),
                        weekendTextStyle: TextStyle(
                          fontSize: isCompact ? 12 : 14,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                if (_calendarExpanded && _dayOnly)
                  GlassPanel(
                    padding: EdgeInsets.all(isCompact ? 10 : 20),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(
                            () => _selected = _selected.subtract(
                              const Duration(days: 1),
                            ),
                          ),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: _pickDay,
                            onLongPress: () => _add(_selected),
                            child: Padding(
                              padding: EdgeInsets.all(isCompact ? 10 : 16),
                              child: Column(
                                children: [
                                  Text(
                                    DateFormat('EEEE').format(_selected),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  Text(
                                    DateFormat('d MMMM y').format(_selected),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(
                            () => _selected = _selected.add(
                              const Duration(days: 1),
                            ),
                          ),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: isCompact ? 12 : 16),
                GlassPanel(
                  padding: EdgeInsets.all(isCompact ? 14 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.view_timeline_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('EEEE, d MMMM').format(_selected),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Add reminder',
                            onPressed: () => _add(_selected),
                            icon: const Icon(Icons.add_circle),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (selected.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('No reminders on this date.'),
                          ),
                        )
                      else
                        for (final task in selected)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 4,
                              height: 42,
                              color: task.isCompleted
                                  ? Theme.of(context).colorScheme.primary
                                  : task.priority == TaskPriority.high
                                  ? AppColors.error
                                  : Theme.of(context).colorScheme.secondary,
                            ),
                            title: Text(task.title),
                            subtitle: Text(
                              DateFormat('h:mm a').format(task.dueAt),
                            ),
                            trailing: Icon(
                              task.isCompleted
                                  ? Icons.check_circle
                                  : Icons.chevron_right,
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    TaskDetailsScreen(taskId: task.id),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _heatCell(
    BuildContext context,
    DateTime day,
    List<PlannerTask> tasks,
  ) {
    final count = tasks.where((t) => isSameDay(t.dueAt, day)).length;
    return Container(
      margin: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 1 : 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: count == 0
            ? Colors.transparent
            : Theme.of(context).colorScheme.secondary.withValues(
                alpha: (.10 + count * .09).clamp(.1, .65),
              ),
      ),
      child: Text('${day.day}'),
    );
  }

  Future<void> _add(DateTime day) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => AddTaskScreen(initialDate: day)),
  );

  Future<void> _showFilters(List<TaskCategory> categories) async {
    var priority = _priorityFilter;
    var categoryId = _categoryFilter;
    final filters = await showModalBottomSheet<_CalendarFilters>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Filter calendar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                const SectionLabel('Priority'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Any'),
                      selected: priority == null,
                      onSelected: (_) => setSheetState(() => priority = null),
                    ),
                    for (final value in TaskPriority.values)
                      ChoiceChip(
                        label: Text(
                          value.name[0].toUpperCase() + value.name.substring(1),
                        ),
                        selected: priority == value,
                        onSelected: (_) =>
                            setSheetState(() => priority = value),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                SectionLabel(
                  'Category',
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Any'),
                      selected: categoryId == null,
                      onSelected: (_) => setSheetState(() => categoryId = null),
                    ),
                    for (final category in categories)
                      ChoiceChip(
                        label: Text(category.name),
                        selected: categoryId == category.id,
                        onSelected: (_) =>
                            setSheetState(() => categoryId = category.id),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(sheetContext, const _CalendarFilters()),
                      child: const Text('Clear'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(
                        sheetContext,
                        _CalendarFilters(
                          priority: priority,
                          categoryId: categoryId,
                        ),
                      ),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (filters == null || !mounted) return;
    setState(() {
      _priorityFilter = filters.priority;
      _categoryFilter = filters.categoryId;
    });
  }

  Future<void> _pickDay() async {
    final v = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (v != null) setState(() => _selected = v);
  }
}

class _CalendarFilters {
  const _CalendarFilters({this.priority, this.categoryId});

  final TaskPriority? priority;
  final String? categoryId;
}
