import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_reminder/core/services/local_notification_service.dart';

final class VisitStreakUpdate {
  const VisitStreakUpdate({
    required this.streak,
    required this.gapDays,
    required this.isFirstVisit,
    required this.isNewDay,
  });

  final int streak;
  final int gapDays;
  final bool isFirstVisit;
  final bool isNewDay;
}

final class AppEngagementService {
  AppEngagementService({
    required LocalNotificationService notifications,
    Future<SharedPreferences> Function()? preferences,
  }) : _notifications = notifications,
       _preferences = preferences ?? SharedPreferences.getInstance;

  static const _lastVisitKey = 'engagement_last_visit_day';
  static const _visitStreakKey = 'engagement_visit_streak';

  final LocalNotificationService _notifications;
  final Future<SharedPreferences> Function() _preferences;

  static VisitStreakUpdate calculateVisit({
    required DateTime now,
    required DateTime? lastVisit,
    required int previousStreak,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final previousDay = lastVisit == null
        ? null
        : DateTime(lastVisit.year, lastVisit.month, lastVisit.day);
    final gapDays = previousDay == null
        ? 0
        : today.difference(previousDay).inDays;
    final isNewDay = previousDay == null || gapDays > 0;
    final streak = previousDay == null
        ? 1
        : gapDays <= 0
        ? previousStreak.clamp(1, 1000000)
        : gapDays == 1
        ? previousStreak + 1
        : 1;
    return VisitStreakUpdate(
      streak: streak,
      gapDays: gapDays,
      isFirstVisit: previousDay == null,
      isNewDay: isNewDay,
    );
  }

  Future<VisitStreakUpdate> recordVisit({DateTime? at}) async {
    final now = at ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final preferences = await _preferences();
    final storedDate = preferences.getString(_lastVisitKey);
    final lastVisit = storedDate == null ? null : DateTime.tryParse(storedDate);
    final previousStreak = preferences.getInt(_visitStreakKey) ?? 0;
    final update = calculateVisit(
      now: now,
      lastVisit: lastVisit,
      previousStreak: previousStreak,
    );
    final gapDays = update.gapDays;
    final streak = update.streak;

    await preferences.setString(_lastVisitKey, today.toIso8601String());
    await preferences.setInt(_visitStreakKey, streak);
    await _notifications.cancelEngagementNotification();

    if (lastVisit != null && gapDays == 1) {
      await _notifications.showEngagementNotification(
        title: 'Welcome back! 🔥',
        body:
            'Your planner visit streak is now $streak ${streak == 1 ? 'day' : 'days'}. Keep showing up!',
      );
    } else if (lastVisit != null && gapDays >= 2) {
      await _notifications.showEngagementNotification(
        title: 'Welcome back',
        body:
            'You were away for $gapDays days, so your visit streak restarted. Today is a fresh day 1.',
      );
    }

    await _notifications.scheduleEngagementNotification(
      title: 'We miss you — what happened?',
      body: streak > 1
          ? 'Two days away will reset your $streak-day visit streak. Open Smart Planner and keep it going.'
          : 'It has been two days. Come back to Smart Planner and restart your planning rhythm.',
      scheduledFor: now.add(const Duration(days: 2)),
    );

    return update;
  }
}
