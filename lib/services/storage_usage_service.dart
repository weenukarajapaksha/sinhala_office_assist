import 'audio_storage.dart';
import 'documents_repository.dart';
import 'recordings_repository.dart';

/// Estimates how much local storage the app's saved recordings and scanned
/// documents are using, so the Settings screen can show a rough total.
class StorageUsageService {
  final RecordingsRepository _recordingsRepository = RecordingsRepository();
  final DocumentsRepository _documentsRepository = DocumentsRepository();

  Future<int> totalBytes() async {
    final recordings = await _recordingsRepository.load();
    final documents = await _documentsRepository.load();

    var total = 0;
    for (final recording in recordings) {
      if (recording.bytes != null) {
        total += recording.bytes!.length;
      } else if (recording.filePath != null) {
        total += await fileSizeBytes(recording.filePath!);
      }
    }
    for (final document in documents) {
      total += document.imageBytes.length;
    }
    return total;
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }
}
