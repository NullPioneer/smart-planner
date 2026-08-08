enum TaskPriority { low, medium, high }

enum TaskRepeatType { never, daily, weekly, monthly, everyXDays }

enum TaskAttachmentType { image, pdf, file }

final class PlannerTask {
  const PlannerTask({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.dueAt,
    required this.isPinned,
    required this.repeatType,
    required this.repeatInterval,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.completedAt,
    this.repeatEndDate,
    this.deletedAt,
    this.emergencyContactNumbers = const [],
    this.emergencyEmail = '',
    this.alarmEnabled = false,
  });

  final String id;
  final String title;
  final String description;
  final String? categoryId;
  final TaskPriority priority;
  final DateTime dueAt;
  final bool isPinned;
  final DateTime? completedAt;
  final TaskRepeatType repeatType;
  final int repeatInterval;
  final DateTime? repeatEndDate;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final List<String> emergencyContactNumbers;
  final String emergencyEmail;
  final bool alarmEnabled;

  bool get isCompleted => completedAt != null;
  bool get isDeleted => deletedAt != null;
  bool get isMedicineSafetyReminder =>
      priority == TaskPriority.high &&
      (categoryId == 'medicine' || isMedicineReminderTitle(title));
  bool get isOverdue => !isCompleted && dueAt.isBefore(DateTime.now());
  bool get isToday {
    final now = DateTime.now();
    return dueAt.year == now.year &&
        dueAt.month == now.month &&
        dueAt.day == now.day;
  }
}

final class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.dueAt,
    this.id,
    this.description = '',
    this.categoryId,
    this.priority = TaskPriority.medium,
    this.isPinned = false,
    this.repeatType = TaskRepeatType.never,
    this.repeatInterval = 1,
    this.repeatEndDate,
    this.notes = '',
    this.checklist = const [],
    this.reminderOffsetsMinutes = const [0],
    this.emergencyContactNumbers = const [],
    this.emergencyEmail = '',
    this.alarmEnabled = false,
  });

  final String? id;
  final String title;
  final String description;
  final String? categoryId;
  final TaskPriority priority;
  final DateTime dueAt;
  final bool isPinned;
  final TaskRepeatType repeatType;
  final int repeatInterval;
  final DateTime? repeatEndDate;
  final String notes;
  final List<ChecklistDraft> checklist;
  final List<int> reminderOffsetsMinutes;
  final List<String> emergencyContactNumbers;
  final String emergencyEmail;
  final bool alarmEnabled;
}

bool isMedicineReminderTitle(String title) => RegExp(
  r'\b(medicine|medication|medications|pill|pills|tablet|tablets|dose)\b',
  caseSensitive: false,
).hasMatch(title.trim());

final class ChecklistDraft {
  const ChecklistDraft({required this.title, this.id, this.isChecked = false});

  final String? id;
  final String title;
  final bool isChecked;
}

final class ChecklistItemModel {
  const ChecklistItemModel({
    required this.id,
    required this.taskId,
    required this.title,
    required this.isChecked,
    required this.position,
  });

  final String id;
  final String taskId;
  final String title;
  final bool isChecked;
  final int position;
}

/// Lightweight checklist counts used by dashboard progress calculations.
final class ChecklistProgressSummary {
  const ChecklistProgressSummary({required this.total, required this.checked});

  final int total;
  final int checked;
}

final class TaskCategory {
  const TaskCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconCodePoint,
    required this.isDefault,
  });

  final String id;
  final String name;
  final int colorValue;
  final int iconCodePoint;
  final bool isDefault;
}

final class TaskAttachment {
  const TaskAttachment({
    required this.id,
    required this.taskId,
    required this.type,
    required this.path,
    required this.displayName,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final TaskAttachmentType type;
  final String path;
  final String displayName;
  final DateTime createdAt;
}

final class TaskVoiceNote {
  const TaskVoiceNote({
    required this.id,
    required this.taskId,
    required this.path,
    required this.durationSeconds,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final String path;
  final int durationSeconds;
  final DateTime createdAt;
}

final class TaskReminderSchedule {
  const TaskReminderSchedule({
    required this.id,
    required this.taskId,
    required this.offsetMinutes,
    required this.scheduledFor,
    required this.notificationId,
    required this.isEnabled,
  });

  final String id;
  final String taskId;
  final int offsetMinutes;
  final DateTime scheduledFor;
  final int notificationId;
  final bool isEnabled;
}

final class TaskDetails {
  const TaskDetails({
    required this.task,
    required this.checklist,
    required this.attachments,
    required this.voiceNotes,
    required this.reminders,
  });

  final PlannerTask task;
  final List<ChecklistItemModel> checklist;
  final List<TaskAttachment> attachments;
  final List<TaskVoiceNote> voiceNotes;
  final List<TaskReminderSchedule> reminders;

  double get checklistProgress {
    if (checklist.isEmpty) return 0;
    return checklist.where((item) => item.isChecked).length / checklist.length;
  }
}

final class TaskStatistics {
  const TaskStatistics({
    required this.created,
    required this.completed,
    required this.pending,
    required this.overdue,
  });

  final int created;
  final int completed;
  final int pending;
  final int overdue;

  double get completionRate => created == 0 ? 0 : completed / created;
}

final class TaskHistoryItem {
  const TaskHistoryItem({
    required this.id,
    required this.action,
    required this.createdAt,
    this.taskId,
  });
  final String id;
  final String? taskId;
  final String action;
  final DateTime createdAt;
}
