import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// Copies user-selected media into app-owned offline storage and records voice notes.
final class LocalMediaService {
  LocalMediaService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final Uuid _uuid = const Uuid();
  DateTime? _recordingStarted;

  Future<String> importFile(String sourcePath) async {
    final directory = await _mediaDirectory('attachments');
    final name = '${_uuid.v4()}${p.extension(sourcePath)}';
    return (await File(sourcePath).copy(p.join(directory.path, name))).path;
  }

  Future<String> importBytes(
    Uint8List bytes, {
    required String extension,
  }) async {
    final directory = await _mediaDirectory('attachments');
    final normalizedExtension = extension.startsWith('.')
        ? extension
        : '.$extension';
    final file = File(
      p.join(directory.path, '${_uuid.v4()}$normalizedExtension'),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<bool> startRecording() async {
    if (!await _recorder.hasPermission()) return false;
    final directory = await _mediaDirectory('voice');
    final path = p.join(directory.path, '${_uuid.v4()}.m4a');
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    _recordingStarted = DateTime.now();
    return true;
  }

  Future<(String path, int durationSeconds)?> stopRecording() async {
    final path = await _recorder.stop();
    if (path == null) return null;
    final duration = DateTime.now()
        .difference(_recordingStarted ?? DateTime.now())
        .inSeconds;
    _recordingStarted = null;
    return (path, duration.clamp(1, 86400));
  }

  Future<void> deleteIfOwned(String path) async {
    final root = await getApplicationDocumentsDirectory();
    final normalized = p.normalize(path);
    if (!p.isWithin(root.path, normalized)) return;
    final file = File(normalized);
    if (await file.exists()) await file.delete();
  }

  Future<void> clearOwnedFiles() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'smart_planner'));
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<Directory> _mediaDirectory(String child) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'smart_planner', child));
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<void> dispose() => _recorder.dispose();
}
