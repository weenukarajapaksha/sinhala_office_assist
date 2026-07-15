import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recording.dart';
import 'audio_storage.dart';

class RecordingsRepository {
  static const _prefsKey = 'recordings_v1';

  Future<String> pathForNewRecording(String fileName) =>
      resolveRecordTarget(fileName);

  Future<Recording> finalize({
    required String id,
    required String recordedPath,
    required DateTime recordedAt,
    required Duration duration,
  }) async {
    final bytes = await captureBytes(recordedPath);
    return Recording(
      id: id,
      recordedAt: recordedAt,
      duration: duration,
      filePath: bytes == null ? recordedPath : null,
      bytes: bytes,
    );
  }

  Future<List<Recording>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    return raw.map((entry) {
      final map = jsonDecode(entry) as Map<String, dynamic>;
      final audioBase64 = map['audioBase64'] as String?;
      return Recording(
        id: map['id'] as String,
        recordedAt: DateTime.parse(map['recordedAt'] as String),
        duration: Duration(milliseconds: map['durationMs'] as int),
        filePath: map['filePath'] as String?,
        bytes: audioBase64 != null ? base64Decode(audioBase64) : null,
        title: map['title'] as String?,
      );
    }).toList();
  }

  Future<void> delete(Recording recording) => deleteRecordedFile(recording.filePath);

  Future<void> save(List<Recording> recordings) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = recordings
        .map(
          (r) => jsonEncode({
            'id': r.id,
            'recordedAt': r.recordedAt.toIso8601String(),
            'durationMs': r.duration.inMilliseconds,
            if (r.filePath != null) 'filePath': r.filePath,
            if (r.bytes != null) 'audioBase64': base64Encode(r.bytes!),
            if (r.title != null) 'title': r.title,
          }),
        )
        .toList();
    await prefs.setStringList(_prefsKey, raw);
  }
}
