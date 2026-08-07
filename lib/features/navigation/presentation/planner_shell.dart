import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_reminder/core/providers/app_providers.dart';
import 'package:smart_reminder/features/calendar/presentation/calendar_screen.dart';
import 'package:smart_reminder/features/dashboard/presentation/dashboard_screen.dart';
import 'package:smart_reminder/features/settings/presentation/settings_screen.dart';
import 'package:smart_reminder/features/settings/application/app_settings_controller.dart';
import 'package:smart_reminder/features/tasks/presentation/tasks_screen.dart';
import 'package:smart_reminder/features/tasks/presentation/task_details_screen.dart';
import 'package:smart_reminder/features/tasks/presentation/statistics_screen.dart';
import 'package:smart_reminder/shared/widgets/glass_panel.dart';
import 'package:smart_reminder/shared/widgets/planner_top_bar.dart';

class PlannerShell extends ConsumerStatefulWidget {
  const PlannerShell({super.key});

  @override
  ConsumerState<PlannerShell> createState() => _PlannerShellState();
}

class _PlannerShellState extends ConsumerState<PlannerShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  final _searchRequests = ValueNotifier<int>(0);
  final _filterRequests = ValueNotifier<TaskListFilter?>(null);
  StreamSubscription<void>? _notificationOpenSubscription;
  late final List<Widget> _pages;

  static const _destinations = [
    NavigationDestination(
      key: Key('nav-dashboard'),
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard_rounded),
      label: 'Dashboard',
    ),
    NavigationDestination(
      key: Key('nav-calendar'),
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month_rounded),
      label: 'Calendar',
    ),
    NavigationDestination(
      key: Key('nav-tasks'),
      icon: Icon(Icons.assignment_outlined),
      selectedIcon: Icon(Icons.assignment_rounded),
      label: 'Tasks',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardScreen(
        onCompletedToday: () => _showTasks(TaskListFilter.completedToday),
        onPending: () => _showTasks(TaskListFilter.pending),
        onOverdue: () => _showTasks(TaskListFilter.overdue),
        onDailyProgress: _openProductivityInsights,
      ),
      const CalendarScreen(),
      TasksScreen(
        searchRequests: _searchRequests,
        filterRequests: _filterRequests,
      ),
    ];
    if (!ref.read(isTestEnvironmentProvider)) {
      final coordinator = ref.read(taskNotificationCoordinatorProvider);
      _notificationOpenSubscription = coordinator.openTaskRequests.listen(
        (_) => _queuePendingNotificationTask(),
      );
      _queuePendingNotificationTask();
    }
  }

  @override
  void dispose() {
    _notificationOpenSubscription?.cancel();
    _searchRequests.dispose();
    _filterRequests.dispose();
    super.dispose();
  }

  void _queuePendingNotificationTask() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final taskId = ref
          .read(taskNotificationCoordinatorProvider)
          .takePendingOpenTask();
      if (taskId == null) return;
      setState(() => _selectedIndex = 2);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TaskDetailsScreen(taskId: taskId),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final useRail = constraints.maxWidth >= 900;
        final content = IndexedStack(index: _selectedIndex, children: _pages);

        return Scaffold(
          key: _scaffoldKey,
          extendBody: true,
          drawer: _QuickSettingsDrawer(
            onClose: () => Navigator.of(context).pop(),
            onSettings: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              Future<void>.delayed(
                Duration.zero,
                () => navigator.push(
                  MaterialPageRoute<void>(
                    builder: (settingsContext) => Scaffold(
                      body: AtmosphericBackground(
                        child: SafeArea(
                          child: SettingsScreen(
                            onClose: () => Navigator.of(settingsContext).pop(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          appBar: PlannerTopBar(
            onMenu: () => _scaffoldKey.currentState?.openDrawer(),
            onSearch: () {
              setState(() => _selectedIndex = 2);
              _searchRequests.value++;
            },
          ),
          body: AtmosphericBackground(
            child: SafeArea(
              top: false,
              child: useRail
                  ? Row(
                      children: [
                        NavigationRail(
                          backgroundColor: theme.colorScheme.surface.withValues(
                            alpha: theme.brightness == Brightness.dark
                                ? .94
                                : .86,
                          ),
                          selectedIndex: _selectedIndex,
                          onDestinationSelected: _selectPage,
                          labelType: NavigationRailLabelType.all,
                          destinations: _destinations
                              .map(
                                (item) => NavigationRailDestination(
                                  icon: item.icon,
                                  selectedIcon: item.selectedIcon,
                                  label: Text(item.label),
                                ),
                              )
                              .toList(),
                        ),
                        Expanded(child: content),
                      ],
                    )
                  : content,
            ),
          ),
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectPage,
                  destinations: _destinations,
                ),
        );
      },
    );
  }

  void _selectPage(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  void _showTasks(TaskListFilter filter) {
    setState(() => _selectedIndex = 2);
    // Reset first so tapping the same dashboard card always reapplies its
    // filter, even when the user changed filters manually in the task view.
    _filterRequests.value = null;
    _filterRequests.value = filter;
  }

  void _openProductivityInsights() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const StatisticsScreen()));
  }
}

class _QuickSettingsDrawer extends ConsumerWidget {
  const _QuickSettingsDrawer({required this.onClose, required this.onSettings});

  final VoidCallback onClose;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsControllerProvider).value;
    final isDark = settings?.themeMode != ThemeMode.light;
    return Drawer(
      key: const Key('settings-drawer'),
      width: (MediaQuery.sizeOf(context).width * .84)
          .clamp(286.0, 350.0)
          .toDouble(),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: AtmosphericBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.asset(
                        'assets/branding/smart_planner_logo.png',
                        width: 46,
                        height: 46,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Quick settings',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('close-settings-drawer'),
                      tooltip: 'Close',
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                GlassPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const Key('quick-theme-switch'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        secondary: Icon(
                          isDark
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(isDark ? 'Dark mode' : 'Light mode'),
                        subtitle: const Text('Change the app appearance'),
                        value: isDark,
                        onChanged: (value) => ref
                            .read(appSettingsControllerProvider.notifier)
                            .setTheme(value ? ThemeMode.dark : ThemeMode.light),
                      ),
                      Divider(height: 1, color: theme.dividerColor),
                      ListTile(
                        key: const Key('open-full-settings'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        leading: Icon(
                          Icons.settings_rounded,
                          color: theme.colorScheme.secondary,
                        ),
                        title: const Text('Settings'),
                        subtitle: const Text(
                          'Notifications, data, privacy and more',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: onSettings,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 17,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Planner data stays on this device.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
