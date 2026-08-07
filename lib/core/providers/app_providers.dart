import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_reminder/core/database/app_database.dart';
import 'package:smart_reminder/core/services/local_notification_service.dart';
import 'package:smart_reminder/core/services/local_media_service.dart';
import 'package:smart_reminder/core/services/backup_service.dart';
import 'package:smart_reminder/core/services/app_engagement_service.dart';
import 'package:smart_reminder/features/settings/data/repositories/shared_preferences_notification_settings_repository.dart';
import 'package:smart_reminder/features/settings/domain/repositories/notification_settings_repository.dart';
import 'package:smart_reminder/features/settings/domain/services/notification_sound_preference_service.dart';
import 'package:smart_reminder/features/tasks/data/repositories/drift_task_repository.dart';
import 'package:smart_reminder/features/tasks/application/task_notification_coordinator.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';
import 'package:smart_reminder/features/tasks/domain/repositories/task_repository.dart';

final isTestEnvironmentProvider = Provider<bool>(
  (ref) => Platform.environment['FLUTTER_TEST'] == 'true',
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(
    Platform.environment['FLUTTER_TEST'] == 'true'
        ? NativeDatabase.memory()
        : null,
  );
  ref.onDispose(database.close);
  return database;
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return DriftTaskRepository(ref.watch(appDatabaseProvider));
});

final activeTasksProvider = StreamProvider<List<PlannerTask>>((ref) {
  if (ref.watch(isTestEnvironmentProvider)) return Stream.value(const []);
  return ref.watch(taskRepositoryProvider).watchActiveTasks();
});

final checklistProgressProvider =
    StreamProvider<Map<String, ChecklistProgressSummary>>((ref) {
      if (ref.watch(isTestEnvironmentProvider)) {
        return Stream.value(const <String, ChecklistProgressSummary>{});
      }
      return ref.watch(taskRepositoryProvider).watchChecklistProgress();
    });

final trashTasksProvider = StreamProvider<List<PlannerTask>>((ref) {
  if (ref.watch(isTestEnvironmentProvider)) return Stream.value(const []);
  return ref.watch(taskRepositoryProvider).watchTrash();
});

final taskCategoriesProvider = StreamProvider<List<TaskCategory>>((ref) {
  if (ref.watch(isTestEnvironmentProvider)) return Stream.value(const []);
  return ref.watch(taskRepositoryProvider).watchCategories();
});

final taskHistoryProvider = StreamProvider<List<TaskHistoryItem>>((ref) {
  if (ref.watch(isTestEnvironmentProvider)) return Stream.value(const []);
  return ref.watch(taskRepositoryProvider).watchHistory();
});

final taskDetailsProvider = FutureProvider.family<TaskDetails?, String>((
  ref,
  id,
) {
  return ref.watch(taskRepositoryProvider).getTaskDetails(id);
});

final localMediaServiceProvider = Provider<LocalMediaService>((ref) {
  final service = LocalMediaService();
  ref.onDispose(service.dispose);
  return service;
});

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(appDatabaseProvider)),
);

final notificationSettingsRepositoryProvider =
    Provider<NotificationSettingsRepository>((ref) {
      return SharedPreferencesNotificationSettingsRepository();
    });

final notificationSoundAvailabilityProvider =
    Provider<NotificationSoundAvailability>((ref) {
      return AssetBundleNotificationSoundAvailability();
    });

final notificationSoundPreferenceServiceProvider =
    Provider<NotificationSoundPreferenceService>((ref) {
      return NotificationSoundPreferenceService(
        repository: ref.watch(notificationSettingsRepositoryProvider),
        availability: ref.watch(notificationSoundAvailabilityProvider),
      );
    });

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  final service = LocalNotificationService(
    soundPreferences: ref.watch(notificationSoundPreferenceServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final appEngagementServiceProvider = Provider<AppEngagementService>((ref) {
  final service = AppEngagementService(
    notifications: ref.watch(localNotificationServiceProvider),
  );
  if (!ref.watch(isTestEnvironmentProvider)) {
    unawaited(service.recordVisit());
  }
  return service;
});

final taskNotificationCoordinatorProvider =
    Provider<TaskNotificationCoordinator>((ref) {
      final coordinator = TaskNotificationCoordinator(
        repository: ref.watch(taskRepositoryProvider),
        notifications: ref.watch(localNotificationServiceProvider),
      );
      coordinator.start();
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });
