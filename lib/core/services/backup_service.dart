import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:smart_reminder/core/database/app_database.dart';

/// Creates a human-readable planner report for saving or sharing.
final class BackupService {
  BackupService(this._database);
  final AppDatabase _database;
  static const _tables = [
    'categories',
    'tasks',
    'checklist_items',
    'attachments',
    'voice_notes',
    'reminder_schedules',
    'history',
    'settings',
  ];
  static const _encryptedFormat = 'smart-planner-encrypted-copy';
  static const _encryptionIterations = 210000;

  Future<String?> exportTextBackup() async {
    final bytes = await _backupBytes();
    try {
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save Smart Planner backup',
        fileName: _backupFileName(),
        type: FileType.custom,
        allowedExtensions: ['txt'],
        bytes: bytes,
      );
      if (path != null && !await File(path).exists()) {
        await File(path).writeAsBytes(bytes, flush: true);
      }
      return path;
    } catch (_) {
      final directory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File(p.join(directory.path, _backupFileName()));
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }
  }

  Future<File> createShareableBackup() async {
    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, _backupFileName()));
    await file.writeAsBytes(await _backupBytes(), flush: true);
    return file;
  }

  Future<File> createEncryptedBackup(String password) async {
    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, _encryptedBackupFileName()));
    await file.writeAsBytes(await encryptReadableBackup(password), flush: true);
    return file;
  }

  Future<Uint8List> encryptReadableBackup(String password) async {
    if (password.length < 8) {
      throw const FormatException('Use at least 8 characters.');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _encryptionIterations,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
    final encrypted = await algorithm.encrypt(
      await _backupBytes(),
      secretKey: key,
      nonce: nonce,
    );
    final envelope = <String, Object>{
      'format': _encryptedFormat,
      'version': 1,
      'algorithm': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _encryptionIterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(encrypted.nonce),
      'cipherText': base64Encode(encrypted.cipherText),
      'mac': base64Encode(encrypted.mac.bytes),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  Future<String> decryptEncryptedBackup(
    Uint8List encryptedBytes,
    String password,
  ) async {
    try {
      final decoded = jsonDecode(utf8.decode(encryptedBytes));
      if (decoded is! Map<String, dynamic> ||
          decoded['format'] != _encryptedFormat ||
          decoded['version'] != 1) {
        throw const FormatException('Unsupported encrypted copy.');
      }
      final salt = base64Decode(decoded['salt'] as String);
      final iterations = decoded['iterations'] as int;
      if (iterations < 100000 || iterations > 1000000) {
        throw const FormatException('Unsupported encryption settings.');
      }
      final key = await Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
      final clearBytes = await AesGcm.with256bits().decrypt(
        SecretBox(
          base64Decode(decoded['cipherText'] as String),
          nonce: base64Decode(decoded['nonce'] as String),
          mac: Mac(base64Decode(decoded['mac'] as String)),
        ),
        secretKey: key,
      );
      return utf8.decode(clearBytes);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'The password is incorrect or the encrypted copy is damaged.',
      );
    }
  }

  Future<String?> unlockEncryptedBackup(String password) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['spbackup'],
      withData: true,
    );
    final item = picked?.files.single;
    if (item == null) return null;
    final encryptedBytes =
        item.bytes ??
        (item.path == null ? null : await File(item.path!).readAsBytes());
    if (encryptedBytes == null) {
      throw const FormatException('The encrypted copy could not be read.');
    }
    final text = await decryptEncryptedBackup(encryptedBytes, password);
    final bytes = Uint8List.fromList(utf8.encode(text));
    final fileName = _unlockedBackupFileName();
    try {
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save unlocked Smart Planner copy',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['txt'],
        bytes: bytes,
      );
      if (path != null && !await File(path).exists()) {
        await File(path).writeAsBytes(bytes, flush: true);
      }
      return path;
    } catch (_) {
      final directory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File(p.join(directory.path, fileName));
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }
  }

  Future<Uint8List> _backupBytes() async {
    return Uint8List.fromList(utf8.encode(await createReadableBackupText()));
  }

  Future<String> createReadableBackupText() async {
    final data = <String, Object?>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
    };
    for (final table in _tables) {
      data[table] = (await _database.customSelect('SELECT * FROM $table').get())
          .map((row) => _jsonSafeMap(row.data))
          .toList();
    }
    return _readableReport(data);
  }

  String _backupFileName() =>
      'smart_planner_copy_${DateTime.now().millisecondsSinceEpoch}.txt';

  String _encryptedBackupFileName() =>
      'smart_planner_encrypted_${DateTime.now().millisecondsSinceEpoch}.spbackup';

  String _unlockedBackupFileName() =>
      'smart_planner_unlocked_${DateTime.now().millisecondsSinceEpoch}.txt';

  Future<String?> exportSqlite() async {
    await _database.customStatement('PRAGMA wal_checkpoint(FULL)');
    final directory = await getApplicationDocumentsDirectory();
    final databaseFile = File(p.join(directory.path, 'smart_planner.sqlite'));
    if (!await databaseFile.exists()) {
      throw const FileSystemException('Database file is unavailable.');
    }
    final bytes = await databaseFile.readAsBytes();
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export SQLite backup',
      fileName: 'smart_planner_${DateTime.now().millisecondsSinceEpoch}.sqlite',
      type: FileType.custom,
      allowedExtensions: ['sqlite'],
      bytes: bytes,
    );
    if (path != null && !await File(path).exists()) {
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return path;
  }

  Future<void> importTextBackup() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'json'],
      withData: true,
    );
    final item = picked?.files.single;
    if (item == null) return;
    final bytes =
        item.bytes ??
        (item.path == null ? null : await File(item.path!).readAsBytes());
    if (bytes == null) {
      throw const FormatException('The selected backup could not be read.');
    }
    final contents = utf8.decode(bytes);
    final restorePayload = _extractRestorePayload(contents);
    final decoded = jsonDecode(restorePayload);
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const FormatException('Unsupported or corrupt backup.');
    }
    await _database.transaction(() async {
      await _database.customStatement('PRAGMA foreign_keys = OFF');
      for (final table in _tables.reversed) {
        await _database.customStatement('DELETE FROM $table');
      }
      for (final table in _tables) {
        final rows = decoded[table];
        if (rows is! List) continue;
        for (final raw in rows) {
          if (raw is! Map) continue;
          final row = raw.map((k, v) => MapEntry(k.toString(), v));
          if (row.isEmpty) continue;
          final columns = row.keys.toList();
          final placeholders = List.filled(columns.length, '?').join(',');
          await _database.customStatement(
            'INSERT INTO $table (${columns.join(',')}) VALUES ($placeholders)',
            [for (final c in columns) row[c]],
          );
        }
      }
      await _database.customStatement('PRAGMA foreign_keys = ON');
    });
  }

  Map<String, Object?> _jsonSafeMap(Map<String, Object?> row) =>
      row.map((key, value) => MapEntry(key, _jsonSafeValue(value)));

  Object? _jsonSafeValue(Object? value) {
    if (value is DateTime) return value.millisecondsSinceEpoch ~/ 1000;
    if (value is Uint8List) return base64Encode(value);
    return value;
  }

  String _readableReport(Map<String, Object?> data) {
    final tasks = _rows(data['tasks']);
    final categories = {
      for (final category in _rows(data['categories']))
        '${category['id']}': '${category['name']}',
    };
    final checklistByTask = <String, List<Map<String, Object?>>>{};
    for (final item in _rows(data['checklist_items'])) {
      checklistByTask.putIfAbsent('${item['task_id']}', () => []).add(item);
    }
    final attachmentsByTask = <String, List<Map<String, Object?>>>{};
    for (final item in _rows(data['attachments'])) {
      attachmentsByTask.putIfAbsent('${item['task_id']}', () => []).add(item);
    }
    final voicesByTask = <String, List<Map<String, Object?>>>{};
    for (final item in _rows(data['voice_notes'])) {
      voicesByTask.putIfAbsent('${item['task_id']}', () => []).add(item);
    }
    final completed = tasks
        .where((task) => task['completed_at'] != null)
        .length;
    final buffer = StringBuffer()
      ..writeln('SMART PLANNER BACKUP')
      ..writeln('====================')
      ..writeln('Created: ${data['exportedAt']}')
      ..writeln(
        'This is a readable copy of your planner for your personal records.',
      )
      ..writeln()
      ..writeln('SUMMARY')
      ..writeln('-------')
      ..writeln('Tasks: ${tasks.length}')
      ..writeln('Completed: $completed')
      ..writeln('Pending: ${tasks.length - completed}')
      ..writeln();

    if (tasks.isEmpty) {
      buffer
        ..writeln('TASKS')
        ..writeln('-----')
        ..writeln('No tasks were stored in this backup.')
        ..writeln();
    } else {
      buffer
        ..writeln('TASKS')
        ..writeln('-----');
      for (var index = 0; index < tasks.length; index++) {
        final task = tasks[index];
        final taskId = '${task['id']}';
        final taskChecklist = checklistByTask[taskId] ?? const [];
        final taskAttachments = attachmentsByTask[taskId] ?? const [];
        final taskVoices = voicesByTask[taskId] ?? const [];
        buffer
          ..writeln(
            '${index + 1}. [${task['completed_at'] == null ? 'PENDING' : 'COMPLETED'}] ${task['title']}',
          )
          ..writeln('   Due: ${_readableDate(task['due_at'])}')
          ..writeln('   Priority: ${task['priority']}')
          ..writeln(
            '   Category: ${categories['${task['category_id']}'] ?? 'None'}',
          );
        _writeIfPresent(buffer, 'Description', task['description']);
        _writeIfPresent(buffer, 'Notes', task['notes']);
        if (task['alarm_enabled'] == true) {
          buffer.writeln('   Due-time alarm: Enabled');
        }
        final emergencyContacts =
            [
                  task['emergency_contact1'],
                  task['emergency_contact2'],
                  task['emergency_contact3'],
                ]
                .where((value) => value?.toString().trim().isNotEmpty == true)
                .toList();
        if (emergencyContacts.isNotEmpty) {
          buffer.writeln(
            '   Emergency contacts: ${emergencyContacts.join(', ')}',
          );
        }
        _writeIfPresent(buffer, 'Emergency email', task['emergency_email']);
        if (taskChecklist.isNotEmpty) {
          buffer.writeln('   Checklist:');
          for (final item in taskChecklist) {
            buffer.writeln(
              '     [${_truthy(item['is_checked']) ? 'x' : ' '}] ${item['title']}',
            );
          }
        }
        if (taskAttachments.isNotEmpty) {
          buffer.writeln('   Attachments:');
          for (final item in taskAttachments) {
            buffer.writeln('     - ${item['display_name']} (${item['type']})');
          }
        }
        if (taskVoices.isNotEmpty) {
          buffer.writeln('   Voice notes: ${taskVoices.length}');
        }
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  List<Map<String, Object?>> _rows(Object? value) => value is List
      ? value.whereType<Map<String, Object?>>().toList()
      : const [];

  void _writeIfPresent(StringBuffer buffer, String label, Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) buffer.writeln('   $label: $text');
  }

  String _readableDate(Object? raw) {
    if (raw is String) {
      return DateTime.tryParse(raw)?.toLocal().toString() ?? raw;
    }
    if (raw is int) {
      final milliseconds = raw.abs() > 100000000000 ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
      ).toLocal().toString();
    }
    return raw?.toString() ?? 'Not set';
  }

  bool _truthy(Object? value) => value == true || value == 1 || value == '1';

  String _extractRestorePayload(String contents) {
    const begin = 'BEGIN_SMART_PLANNER_RESTORE_DATA';
    const end = 'END_SMART_PLANNER_RESTORE_DATA';
    final start = contents.indexOf(begin);
    final finish = contents.indexOf(end);
    if (start < 0 || finish <= start) return contents;
    final encoded = contents
        .substring(start + begin.length, finish)
        .replaceAll(RegExp(r'\s+'), '');
    return utf8.decode(base64Decode(encoded));
  }
}
