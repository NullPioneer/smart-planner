import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_reminder/core/theme/app_theme.dart';
import 'package:smart_reminder/core/providers/app_providers.dart';
import 'package:smart_reminder/features/navigation/presentation/planner_shell.dart';
import 'package:smart_reminder/shared/widgets/glass_panel.dart';
import 'package:go_router/go_router.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const _LogoRevealScreen()),
    GoRoute(path: '/home', builder: (_, _) => const PlannerShell()),
  ],
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SmartReminderApp()));
}

class SmartReminderApp extends ConsumerWidget {
  const SmartReminderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isTestEnvironmentProvider)) {
      ref.watch(taskNotificationCoordinatorProvider);
      ref.watch(appEngagementServiceProvider);
      ref.watch(completedTaskCleanupProvider);
    }
    return MaterialApp.router(
      title: 'Smart Planner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: _router,
    );
  }
}

class _LogoRevealScreen extends StatefulWidget {
  const _LogoRevealScreen();

  @override
  State<_LogoRevealScreen> createState() => _LogoRevealScreenState();
}

class _LogoRevealScreenState extends State<_LogoRevealScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      if (mounted) context.go('/home');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final enter = Curves.easeOutCubic.transform(
            _phase(_controller.value, 0, .55),
          );
          final nameEnter = Curves.easeOutCubic.transform(
            _phase(_controller.value, .52, .72),
          );
          final calendarEnter = Curves.easeOutBack.transform(
            _phase(_controller.value, .1, .46),
          );
          final reminderEnter = Curves.easeOutBack.transform(
            _phase(_controller.value, .2, .56),
          );
          final taskEnter = Curves.easeOutBack.transform(
            _phase(_controller.value, .28, .5),
          );
          final taskCheck = Curves.easeOutBack.transform(
            _phase(_controller.value, .48, .66),
          );
          final exit = Curves.easeInCubic.transform(
            _phase(_controller.value, .86, 1),
          );
          final opacity = (1 - exit).clamp(0.0, 1.0);

          return AtmosphericBackground(
            child: Center(
              child: Opacity(
                opacity: opacity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 330,
                      height: 226,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            top: 58,
                            child: _PlannerMomentBadge(
                              progress: calendarEnter,
                              entryOffset: const Offset(-52, 18),
                              icon: Icons.calendar_month_rounded,
                              title: 'Today',
                              subtitle: 'Plan the day',
                              accent: theme.colorScheme.secondary,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 36,
                            child: _PlannerMomentBadge(
                              progress: reminderEnter,
                              entryOffset: const Offset(54, -12),
                              icon: Icons.notifications_active_rounded,
                              title: 'Reminder',
                              subtitle: 'Right on time',
                              accent: theme.colorScheme.primary,
                            ),
                          ),
                          Align(
                            alignment: const Alignment(0, -.45),
                            child: _PlannerLogo(enter: enter, exit: exit),
                          ),
                          Positioned(
                            left: 66,
                            bottom: 0,
                            child: _TaskCompletionMoment(
                              progress: taskEnter,
                              completion: taskCheck,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: nameEnter,
                      child: Transform.translate(
                        offset: Offset(0, 22 * (1 - nameEnter)),
                        child: Column(
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: 'Smart '),
                                  TextSpan(
                                    text: 'Planner',
                                    style: TextStyle(
                                      color: theme.colorScheme.secondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.7,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'Plan clearly. Remember effortlessly.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlannerLogo extends StatelessWidget {
  const _PlannerLogo({required this.enter, required this.exit});

  final double enter;
  final double exit;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, 34 * (1 - enter) - 10 * exit),
      child: Transform.scale(
        scale: .72 + (.28 * enter) - (.05 * exit),
        child: Container(
          width: 112,
          height: 112,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.asset(
              'assets/branding/smart_planner_logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskCompletionMoment extends StatelessWidget {
  const _TaskCompletionMoment({
    required this.progress,
    required this.completion,
  });

  final double progress;
  final double completion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleProgress = progress.clamp(0.0, 1.0);
    final checkedProgress = completion.clamp(0.0, 1.0);
    final checkPulse = 1 + (.08 * 4 * checkedProgress * (1 - checkedProgress));

    return Opacity(
      opacity: visibleProgress,
      child: Transform.translate(
        offset: Offset(0, 54 * (1 - progress)),
        child: Transform.scale(
          scale: (.78 + (.22 * progress)) * checkPulse,
          child: Container(
            width: 198,
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: .72),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 1 - checkedProgress,
                        child: Icon(
                          Icons.radio_button_unchecked_rounded,
                          size: 30,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Opacity(
                        opacity: checkedProgress,
                        child: Transform.scale(
                          scale: .35 + (.65 * checkedProgress),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            size: 34,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Task complete',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Great work — checked off!',
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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

class _PlannerMomentBadge extends StatelessWidget {
  const _PlannerMomentBadge({
    required this.progress,
    required this.entryOffset,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final double progress;
  final Offset entryOffset;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleProgress = progress.clamp(0.0, 1.0);
    return Opacity(
      opacity: visibleProgress,
      child: Transform.translate(
        offset: entryOffset * (1 - progress),
        child: Transform.scale(
          scale: .76 + (.24 * progress),
          child: Container(
            width: 124,
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: .5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 19, color: accent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 9,
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

double _phase(double value, double start, double end) =>
    ((value - start) / (end - start)).clamp(0.0, 1.0).toDouble();
