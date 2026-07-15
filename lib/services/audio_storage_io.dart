import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> resolveRecordTarget(String fileName) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'recordings'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return p.join(dir.path, fileName);
}

/// Files are already persisted on disk at [recordedPath], so there's no
/// need to duplicate the audio into SharedPreferences on this platform.
Future<Uint8List?> captureBytes(String recordedPath) async => null;

Future<void> deleteRecordedFile(String? filePath) async {
  if (filePath == null) return;
  final file = File(filePath);
  if (await file.exists()) {
    await file.delete();
  }
}
