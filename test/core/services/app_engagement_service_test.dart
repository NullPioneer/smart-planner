import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reminder/core/services/app_engagement_service.dart';

void main() {
  test('daily visits grow the streak and a two-day gap resets it', () {
    final regular = AppEngagementService.calculateVisit(
      now: DateTime(2026, 8, 7, 10),
      lastVisit: DateTime(2026, 8, 6, 22),
      previousStreak: 4,
    );
    expect(regular.streak, 5);
    expect(regular.gapDays, 1);
    expect(regular.isNewDay, isTrue);

    final returning = AppEngagementService.calculateVisit(
      now: DateTime(2026, 8, 9, 10),
      lastVisit: DateTime(2026, 8, 7, 22),
      previousStreak: 5,
    );
    expect(returning.streak, 1);
    expect(returning.gapDays, 2);
  });

  test('reopening on the same day keeps the existing streak', () {
    final update = AppEngagementService.calculateVisit(
      now: DateTime(2026, 8, 7, 18),
      lastVisit: DateTime(2026, 8, 7, 8),
      previousStreak: 6,
    );
    expect(update.streak, 6);
    expect(update.isNewDay, isFalse);
  });
}
