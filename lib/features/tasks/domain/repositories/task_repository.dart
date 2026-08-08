import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';

abstract interface class TaskRepository {
  Stream<List<PlannerTask>> watchActiveTasks();
  Stream<List<PlannerTask>> watchTrash();
  Stream<List<TaskCategory>> watchCategories();
  Stream<List<TaskHistoryItem>> watchHistory();
  Stream<Map<String, ChecklistProgressSummary>> watchChecklistProgress();
  Future<TaskDetails?> getTaskDetails(String id);
  Future<String> saveTask(TaskDraft draft);
  Future<void> setCompleted(String id, {required bool completed});
  Future<void> setPinned(String id, {required bool pinned});
  Future<void> moveToTrash(String id);
  Future<void> restoreFromTrash(String id);
  Future<void> permanentlyDelete(String id);
  Future<int> moveCompletedBeforeToTrash(DateTime cutoff);
  Future<void> setChecklistItemChecked(String id, {required bool checked});
  Future<String> addCategory({
    required String name,
    required int colorValue,
    required int iconCodePoint,
  });
  Future<List<PlannerTask>> findConflicts(DateTime dueAt, {String? excludeId});
  Future<void> addAttachment({
    required String taskId,
    required TaskAttachmentType type,
    required String path,
    required String displayName,
  });
  Future<void> removeAttachment(String id);
  Future<void> addVoiceNote({
    required String taskId,
    required String path,
    required int durationSeconds,
  });
  Future<void> removeVoiceNote(String id);
  Future<void> clearAllData();
}
