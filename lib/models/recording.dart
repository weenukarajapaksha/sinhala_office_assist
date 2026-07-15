import 'dart:typed_data';

class Recording {
  const Recording({
    required this.id,
    required this.recordedAt,
    required this.duration,
    this.filePath,
    this.bytes,
    this.title,
    this.transcript,
  }) : assert(filePath != null || bytes != null);

  final String id;
  final DateTime recordedAt;
  final Duration duration;

  /// Absolute file path on platforms with a real filesystem (io targets).
  final String? filePath;

  /// Raw audio bytes, used on web where recordings only exist as blob URLs
  /// that don't survive a page reload.
  final Uint8List? bytes;

  /// User-assigned name; falls back to a formatted duration/timestamp when null.
  final String? title;

  /// Sinhala transcript from cloud speech-to-text, if generated.
  final String? transcript;

  Recording copyWith({String? title, String? transcript}) => Recording(
    id: id,
    recordedAt: recordedAt,
    duration: duration,
    filePath: filePath,
    bytes: bytes,
    title: title ?? this.title,
    transcript: transcript ?? this.transcript,
  );
}
