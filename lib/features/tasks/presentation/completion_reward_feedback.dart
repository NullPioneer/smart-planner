import 'package:flutter/material.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';
import 'package:smart_reminder/features/tasks/domain/services/productivity_reward_service.dart';

void showCompletionRewardFeedback(
  BuildContext context, {
  required PlannerTask task,
  required Iterable<PlannerTask> allTasks,
  DateTime? completedAt,
}) {
  final completion = completedAt ?? DateTime.now();
  final streak = ProductivityRewards.streakIncludingCompletion(
    allTasks,
    completion,
  );
  final reward = ProductivityRewards.rewardFor(
    task,
    completedAt: completion,
    consistencyStreak: streak,
  );
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.stars_rounded, color: Color(0xFFFFD166)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.remark,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(reward.detail),
                ],
              ),
            ),
            Text(
              '${reward.stars.toStringAsFixed(1)} / 5 ★',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
}
