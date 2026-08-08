import 'dart:async';

import 'package:smart_reminder/core/services/local_notification_service.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';
import 'package:smart_reminder/features/tasks/domain/repositories/task_repository.dart';

/// Keeps persisted reminder schedules and Android notifications synchronized.
final class TaskNotificationCoordinator {
  TaskNotificationCoordinator({
    required TaskRepository repository,
    required LocalNotificationService notifications,
  }) : _repository = repository,
       _notifications = notifications;
  final TaskRepository _repository;
  final LocalNotificationService _notifications;
  StreamSubscription<ReminderNotificationAction>? _subscription;
  final _openRequests = StreamController<void>.broadcast();
  String? _pendingOpenTaskId;

  Stream<void> get openTaskRequests => _openRequests.stream;

  String? takePendingOpenTask() {
    final taskId = _pendingOpenTaskId;
    _pendingOpenTaskId = null;
    return taskId;
  }

  void start() {
    _subscription ??= _notifications.actions.listen(handleAction);
    _initializeExisting();
  }

  Future<void> _initializeExisting() async {
    try {
      await _notifications.initialize();
      final tasks = await _repository.watchActiveTasks().first;
      for (final task in tasks.where((task) => !task.isCompleted)) {
        await syncTask(task.id);
      }
    } catch (_) {
      // Desktop/web and tests may not expose native Android notification APIs.
    }
  }

  Future<void> syncTask(String taskId) async {
    await _notifications.cancelForTask(taskId);
    final details = await _repository.getTaskDetails(taskId);
    if (details == null || details.task.isCompleted || details.task.isDeleted) {
      return;
    }
    final occurrences = _occurrences(details.task, count: 20);
    for (
      var occurrenceIndex = 0;
      occurrenceIndex < occurrences.length;
      occurrenceIndex++
    ) {
      final occurrence = occurrences[occurrenceIndex];
      for (
        var reminderIndex = 0;
        reminderIndex < details.reminders.length;
        reminderIndex++
      ) {
        final reminder = details.reminders[reminderIndex];
        if (!reminder.isEnabled) continue;
        if (details.task.priority == TaskPriority.high &&
            details.task.alarmEnabled &&
            reminder.offsetMinutes == 0) {
          // An enabled high-priority alarm replaces a duplicate notification
          // at the exact due time. Earlier reminders remain unchanged.
          continue;
        }
        final when = occurrence.subtract(
          Duration(minutes: reminder.offsetMinutes),
        );
        final id =
            (reminder.notificationId + occurrenceIndex * 1009) & 0x7fffffff;
        await _notifications.scheduleReminder(
          id: id,
          taskId: taskId,
          title: details.task.title,
          body: _body(details.task, occurrence),
          scheduledFor: when,
        );
      }
      if (details.task.priority == TaskPriority.high &&
          details.task.alarmEnabled) {
        await _notifications.scheduleAlarm(
          id: _alarmNotificationId(taskId, occurrenceIndex),
          taskId: taskId,
          title: details.task.title,
          body: details.task.description.isEmpty
              ? 'This high-priority task is due now.'
              : details.task.description,
          scheduledFor: occurrence,
        );
      }
    }
  }

  Future<void> cancelTask(String taskId) =>
      _notifications.cancelForTask(taskId);
  Future<void> handleAction(ReminderNotificationAction action) async {
    final details = await _repository.getTaskDetails(action.taskId);
    if (details == null) return;
    if (action.actionId == LocalNotificationService.completeAction) {
      await _repository.setCompleted(action.taskId, completed: true);
      await cancelTask(action.taskId);
      if (action.notificationId != null) {
        await _notifications.cancel(action.notificationId!);
      }
      return;
    }
    if (action.actionId == LocalNotificationService.snoozeAction) {
      await _notifications.snooze(
        taskId: action.taskId,
        title: details.task.title,
        asAlarm: action.isAlarm,
      );
      if (action.notificationId != null) {
        await _notifications.cancel(action.notificationId!);
      }
      return;
    }
    if (action.actionId == LocalNotificationService.stopAlarmAction) {
      if (action.notificationId != null) {
        await _notifications.cancel(action.notificationId!);
      }
      return;
    }
    if (action.actionId == LocalNotificationService.openAction) {
      if (action.notificationId != null) {
        await _notifications.cancel(action.notificationId!);
      }
      _pendingOpenTaskId = action.taskId;
      _openRequests.add(null);
    }
  }

  List<DateTime> _occurrences(PlannerTask task, {required int count}) {
    final values = <DateTime>[];
    var value = task.dueAt;
    while (values.length < count &&
        (task.repeatEndDate == null || !value.isAfter(task.repeatEndDate!))) {
      values.add(value);
      value = switch (task.repeatType) {
        TaskRepeatType.never => value.add(const Duration(days: 36500)),
        TaskRepeatType.daily => value.add(const Duration(days: 1)),
        TaskRepeatType.weekly => value.add(const Duration(days: 7)),
        TaskRepeatType.monthly => DateTime(
          value.year,
          value.month + 1,
          value.day,
          value.hour,
          value.minute,
        ),
        TaskRepeatType.everyXDays => value.add(
          Duration(days: task.repeatInterval),
        ),
      };
      if (task.repeatType == TaskRepeatType.never) break;
    }
    return values;
  }

  String _body(PlannerTask task, DateTime due) => task.description.isEmpty
      ? 'Due at ${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}'
      : task.description;

  int _alarmNotificationId(String taskId, int occurrenceIndex) {
    var hash = 0x811c9dc5;
    for (final codeUnit in taskId.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x3fffffff;
    }
    return 0x40000000 | ((hash + occurrenceIndex * 1009) & 0x3fffffff);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _openRequests.close();
  }
}
