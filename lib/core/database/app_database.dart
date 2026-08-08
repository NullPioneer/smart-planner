import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('TaskRecord')
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 300)();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get priority => text().withDefault(const Constant('medium'))();
  DateTimeColumn get dueAt => dateTime()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get alarmEnabled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get repeatType => text().withDefault(const Constant('never'))();
  IntColumn get repeatInterval => integer().withDefault(const Constant(1))();
  DateTimeColumn get repeatEndDate => dateTime().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get emergencyContact1 => text().withDefault(const Constant(''))();
  TextColumn get emergencyContact2 => text().withDefault(const Constant(''))();
  TextColumn get emergencyContact3 => text().withDefault(const Constant(''))();
  TextColumn get emergencyEmail => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CategoryRecord')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  IntColumn get colorValue => integer()();
  IntColumn get iconCodePoint => integer()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ChecklistRecord')
class ChecklistItems extends Table {
  TextColumn get id => text()();
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 300)();
  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AttachmentRecord')
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()();
  TextColumn get path => text()();
  TextColumn get displayName => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('VoiceNoteRecord')
class VoiceNotes extends Table {
  TextColumn get id => text()();
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get path => text()();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ReminderScheduleRecord')
class ReminderSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get offsetMinutes => integer()();
  DateTimeColumn get scheduledFor => dateTime()();
  IntColumn get notificationId => integer().unique()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get occurrenceKey => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('HistoryRecord')
class History extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().nullable()();
  TextColumn get action => text()();
  TextColumn get snapshotJson => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SettingRecord')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Tasks,
    Categories,
    ChecklistItems,
    Attachments,
    VoiceNotes,
    ReminderSchedules,
    History,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'smart_planner'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _seedDefaultCategories();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(tasks, tasks.emergencyContact1);
        await migrator.addColumn(tasks, tasks.emergencyContact2);
        await migrator.addColumn(tasks, tasks.emergencyContact3);
        await migrator.addColumn(tasks, tasks.emergencyEmail);
      }
      if (from < 3) {
        await migrator.addColumn(tasks, tasks.alarmEnabled);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _purgeExpiredTrash();
    },
  );

  Future<void> _seedDefaultCategories() async {
    const defaults = <(String, String, int, int)>[
      ('study', 'Study', 0xFF4CD7F6, 0xe80c),
      ('work', 'Work', 0xFF4EDEA3, 0xe11c),
      ('shopping', 'Shopping', 0xFFFFC857, 0xe8cc),
      ('birthday', 'Birthday', 0xFFE1BEE7, 0xeb41),
      ('medicine', 'Medicine', 0xFFFF8A80, 0xf109),
      ('bills', 'Bills', 0xFFFFB74D, 0xef6e),
      ('personal', 'Personal', 0xFF90CAF9, 0xe7fd),
    ];
    final now = DateTime.now();
    await batch((batch) {
      batch.insertAll(categories, [
        for (final item in defaults)
          CategoriesCompanion.insert(
            id: item.$1,
            name: item.$2,
            colorValue: item.$3,
            iconCodePoint: item.$4,
            isDefault: const Value(true),
            createdAt: now,
          ),
      ], mode: InsertMode.insertOrIgnore);
    });
  }

  Future<void> _purgeExpiredTrash() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    await (delete(
      tasks,
    )..where((task) => task.deletedAt.isSmallerThanValue(cutoff))).go();
  }
}
