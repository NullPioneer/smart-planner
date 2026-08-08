import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_reminder/core/providers/app_providers.dart';
import 'package:smart_reminder/core/theme/app_theme.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';
import 'package:smart_reminder/features/tasks/presentation/add_task_screen.dart';
import 'package:smart_reminder/features/tasks/presentation/completion_reward_feedback.dart';
import 'package:smart_reminder/features/tasks/presentation/task_details_screen.dart';
import 'package:smart_reminder/shared/widgets/glass_panel.dart';

enum TaskListFilter {
  all,
  pending,
  today,
  tomorrow,
  thisWeek,
  upcoming,
  completed,
  completedToday,
  overdue,
  pinned,
}

enum _TaskSort { newest, oldest, priority, alphabetical }

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key, this.searchRequests, this.filterRequests});

  final ValueNotifier<int>? searchRequests;
  final ValueNotifier<TaskListFilter?>? filterRequests;

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  TaskListFilter _filter = TaskListFilter.all;
  _TaskSort _sort = _TaskSort.newest;
  TaskPriority? _priority;
  String? _categoryId;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _filterKeys = {
    for (final filter in TaskListFilter.values) filter: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    widget.searchRequests?.addListener(_focusSearch);
    widget.filterRequests?.addListener(_applyRequestedFilter);
  }

  @override
  void didUpdateWidget(covariant TasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchRequests != widget.searchRequests) {
      oldWidget.searchRequests?.removeListener(_focusSearch);
      widget.searchRequests?.addListener(_focusSearch);
    }
    if (oldWidget.filterRequests != widget.filterRequests) {
      oldWidget.filterRequests?.removeListener(_applyRequestedFilter);
      widget.filterRequests?.addListener(_applyRequestedFilter);
    }
  }

  @override
  void dispose() {
    widget.searchRequests?.removeListener(_focusSearch);
    widget.filterRequests?.removeListener(_applyRequestedFilter);
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _focusSearch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _applyRequestedFilter() {
    final requested = widget.filterRequests?.value;
    if (requested == null || !mounted) return;
    setState(() => _filter = requested);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final filterContext = _filterKeys[requested]?.currentContext;
      if (mounted && filterContext != null) {
        Scrollable.ensureVisible(
          filterContext,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: .5,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filterFill = Color.lerp(
      theme.colorScheme.surface,
      theme.colorScheme.onSurface,
      theme.brightness == Brightness.light ? .18 : .10,
    );
    final tasksState = ref.watch(activeTasksProvider);
    final categories =
        ref.watch(taskCategoriesProvider).value ?? const <TaskCategory>[];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tasks',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  FilledButton.icon(
                    key: const Key('tasks-new-task'),
                    onPressed: _openAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('New Task'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _search,
                focusNode: _searchFocus,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search title, description, notes or category',
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 42,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (
                        var index = 0;
                        index < TaskListFilter.values.length;
                        index++
                      ) ...[
                        Builder(
                          key: _filterKeys[TaskListFilter.values[index]],
                          builder: (context) {
                            final value = TaskListFilter.values[index];
                            return ChoiceChip(
                              label: Text(_label(value.name)),
                              selected: value == _filter,
                              onSelected: (_) =>
                                  setState(() => _filter = value),
                            );
                          },
                        ),
                        if (index < TaskListFilter.values.length - 1)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Theme(
                data: theme.copyWith(
                  inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                    fillColor: filterFill,
                  ),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    DropdownMenu<TaskPriority?>(
                      width: 170,
                      initialSelection: _priority,
                      label: const Text('Priority'),
                      dropdownMenuEntries: [
                        const DropdownMenuEntry(
                          value: null,
                          label: 'Any priority',
                        ),
                        ...TaskPriority.values.map(
                          (p) => DropdownMenuEntry(
                            value: p,
                            label: _label(p.name),
                          ),
                        ),
                      ],
                      onSelected: (value) => setState(() => _priority = value),
                    ),
                    DropdownMenu<String?>(
                      width: 180,
                      initialSelection: _categoryId,
                      label: const Text('Category'),
                      dropdownMenuEntries: [
                        const DropdownMenuEntry(
                          value: null,
                          label: 'Any category',
                        ),
                        ...categories.map(
                          (c) => DropdownMenuEntry(value: c.id, label: c.name),
                        ),
                      ],
                      onSelected: (value) =>
                          setState(() => _categoryId = value),
                    ),
                    DropdownMenu<_TaskSort>(
                      width: 170,
                      initialSelection: _sort,
                      label: const Text('Sort'),
                      dropdownMenuEntries: _TaskSort.values
                          .map(
                            (s) => DropdownMenuEntry(
                              value: s,
                              label: _label(s.name),
                            ),
                          )
                          .toList(),
                      onSelected: (value) {
                        if (value != null) setState(() => _sort = value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              tasksState.when(
                loading: () => const _EmptyState(
                  icon: Icons.hourglass_empty,
                  title: 'Loading tasks',
                  subtitle: 'Preparing your offline planner…',
                ),
                error: (error, _) => _EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load tasks',
                  subtitle: '$error',
                ),
                data: (all) {
                  final tasks = _filtered(all, categories);
                  if (tasks.isEmpty)
                    return _EmptyState(
                      icon: Icons.task_alt,
                      title: 'No matching tasks',
                      subtitle: 'Create a reminder or change your filters.',
                      action: _openAdd,
                    );
                  return Column(
                    children: [
                      for (var i = 0; i < tasks.length; i++) ...[
                        _TaskCard(
                          task: tasks[i],
                          category: categories
                              .where((c) => c.id == tasks[i].categoryId)
                              .firstOrNull,
                          onOpen: () => _openDetails(tasks[i].id),
                          onAction: (action) => _handle(tasks[i], action),
                        ),
                        if (i < tasks.length - 1) const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PlannerTask> _filtered(
    List<PlannerTask> source,
    List<TaskCategory> categories,
  ) {
    final now = DateTime.now();
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final query = _search.text.trim().toLowerCase();
    final names = {for (final c in categories) c.id: c.name.toLowerCase()};
    final result = source.where((task) {
      final matchesTab = switch (_filter) {
        TaskListFilter.all => true,
        TaskListFilter.pending => !task.isCompleted,
        TaskListFilter.today => task.isToday,
        TaskListFilter.tomorrow =>
          task.dueAt.year == tomorrow.year &&
              task.dueAt.month == tomorrow.month &&
              task.dueAt.day == tomorrow.day &&
              !task.isCompleted,
        TaskListFilter.thisWeek =>
          task.dueAt.isAfter(DateTime(now.year, now.month, now.day)) &&
              task.dueAt.isBefore(
                DateTime(
                  now.year,
                  now.month,
                  now.day,
                ).add(Duration(days: 8 - now.weekday)),
              ) &&
              !task.isCompleted,
        TaskListFilter.upcoming =>
          task.dueAt.isAfter(tomorrow) && !task.isCompleted,
        TaskListFilter.completed => task.isCompleted,
        TaskListFilter.completedToday => task.isToday && task.isCompleted,
        TaskListFilter.overdue => task.isOverdue,
        TaskListFilter.pinned => task.isPinned,
      };
      final searchable =
          '${task.title} ${task.description} ${task.notes} ${names[task.categoryId] ?? ''}'
              .toLowerCase();
      return matchesTab &&
          (_priority == null || task.priority == _priority) &&
          (_categoryId == null || task.categoryId == _categoryId) &&
          (query.isEmpty || searchable.contains(query));
    }).toList();
    result.sort((a, b) {
      final pin = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
      if (pin != 0) return pin;
      return switch (_sort) {
        _TaskSort.newest => b.createdAt.compareTo(a.createdAt),
        _TaskSort.oldest => a.createdAt.compareTo(b.createdAt),
        _TaskSort.priority => b.priority.index.compareTo(a.priority.index),
        _TaskSort.alphabetical => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
      };
    });
    return result;
  }

  Future<void> _handle(PlannerTask task, String action) async {
    final repo = ref.read(taskRepositoryProvider);
    switch (action) {
      case 'complete':
        final completing = !task.isCompleted;
        final completion = DateTime.now();
        await repo.setCompleted(task.id, completed: !task.isCompleted);
        if (task.isCompleted) {
          await ref.read(taskNotificationCoordinatorProvider).syncTask(task.id);
        } else {
          await ref
              .read(taskNotificationCoordinatorProvider)
              .cancelTask(task.id);
        }
        if (completing && mounted) {
          showCompletionRewardFeedback(
            context,
            task: task,
            allTasks:
                ref.read(activeTasksProvider).value ?? const <PlannerTask>[],
            completedAt: completion,
          );
        }
      case 'pin':
        await repo.setPinned(task.id, pinned: !task.isPinned);
      case 'delete':
        final shouldDelete = await _confirmMoveToTrash(task);
        if (!shouldDelete) return;
        await repo.moveToTrash(task.id);
        if (!ref.read(isTestEnvironmentProvider)) {
          await ref
              .read(taskNotificationCoordinatorProvider)
              .cancelTask(task.id);
        }
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('“${task.title}” moved to Trash.'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () async {
                    await repo.restoreFromTrash(task.id);
                    if (!ref.read(isTestEnvironmentProvider)) {
                      await ref
                          .read(taskNotificationCoordinatorProvider)
                          .syncTask(task.id);
                    }
                  },
                ),
              ),
            );
        }
      case 'edit':
        _openDetails(task.id);
    }
  }

  Future<void> _openAdd() async => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const AddTaskScreen()));
  Future<void> _openDetails(String id) async => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => TaskDetailsScreen(taskId: id)),
  );

  Future<bool> _confirmMoveToTrash(PlannerTask task) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Move reminder to Trash?'),
          content: Text(
            '“${task.title}” will be moved to Trash. You can restore it '
            'for up to 30 days.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Move to Trash'),
            ),
          ],
        ),
      ) ??
      false;

  String _label(String value) {
    final spaced = value.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)!.toLowerCase()}',
    );
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onOpen,
    required this.onAction,
    this.category,
  });
  final PlannerTask task;
  final TaskCategory? category;
  final VoidCallback onOpen;
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) {
    final color = task.isOverdue
        ? AppColors.error
        : switch (task.priority) {
            TaskPriority.high => AppColors.error,
            TaskPriority.medium => Theme.of(context).colorScheme.secondary,
            TaskPriority.low => Theme.of(context).colorScheme.primary,
          };
    return Semantics(
      button: true,
      label: 'Open ${task.title}',
      child: GlassPanel(
        padding: EdgeInsets.zero,
        onTap: onOpen,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              constraints: const BoxConstraints(minHeight: 110),
              color: color,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (task.isPinned)
                          Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: Icon(
                              Icons.push_pin,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        Text(
                          task.isCompleted
                              ? 'COMPLETED'
                              : task.isOverdue
                              ? 'OVERDUE'
                              : task.priority.name.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const Spacer(),
                        PopupMenuButton<String>(
                          tooltip: 'Task actions',
                          onSelected: onAction,
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'complete',
                              child: Text(
                                task.isCompleted
                                    ? 'Mark pending'
                                    : 'Mark complete',
                              ),
                            ),
                            PopupMenuItem(
                              value: 'pin',
                              child: Text(task.isPinned ? 'Unpin' : 'Pin'),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Open details'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Move to trash'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    _TaskChecklistProgress(taskId: task.id),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        if (category != null)
                          _Meta(
                            icon: IconData(
                              category!.iconCodePoint,
                              fontFamily: 'MaterialIcons',
                            ),
                            text: category!.name,
                          ),
                        _Meta(
                          icon: Icons.schedule,
                          text: DateFormat(
                            'EEE, d MMM • h:mm a',
                          ).format(task.dueAt),
                        ),
                        _Meta(
                          icon: Icons.hourglass_bottom_rounded,
                          text: _remainingLabel(task.dueAt),
                        ),
                        if (task.repeatType != TaskRepeatType.never)
                          _Meta(icon: Icons.repeat, text: _repeatLabel(task)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _repeatLabel(PlannerTask task) =>
      task.repeatType == TaskRepeatType.everyXDays
      ? 'Every ${task.repeatInterval} days'
      : task.repeatType.name;

  String _remainingLabel(DateTime dueAt) {
    final difference = dueAt.difference(DateTime.now());
    final duration = difference.abs();
    final amount = duration.inDays > 0
        ? '${duration.inDays}d'
        : duration.inHours > 0
        ? '${duration.inHours}h'
        : '${duration.inMinutes.clamp(1, 59)}m';
    return difference.isNegative ? '$amount overdue' : '$amount remaining';
  }
}

class _TaskChecklistProgress extends ConsumerWidget {
  const _TaskChecklistProgress({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(taskDetailsProvider(taskId));
    return details.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (value) {
        if (value == null || value.checklist.isEmpty) {
          return const SizedBox.shrink();
        }
        final checked = value.checklist.where((item) => item.isChecked).length;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Checklist progress',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '$checked/${value.checklist.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: value.checklistProgress,
                minHeight: 5,
                borderRadius: BorderRadius.circular(3),
                backgroundColor: AppColors.outlineVariant.withValues(
                  alpha: .45,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 5),
      Text(text, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => GlassPanel(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text(subtitle, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: action,
                icon: const Icon(Icons.add),
                label: const Text('Create task'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
