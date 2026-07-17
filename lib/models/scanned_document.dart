import 'dart:typed_data';

class ScannedDocument {
  const ScannedDocument({
    required this.id,
    required this.scannedAt,
    required this.imageBytes,
    this.title,
    this.extractedText,
    this.translatedText,
    this.summaryText,
  });

  final String id;
  final DateTime scannedAt;

  /// JPEG/PNG bytes of the captured or picked document image.
  final Uint8List imageBytes;

  /// User-assigned name; falls back to a formatted timestamp when null.
  final String? title;

  /// Text extracted from the image via Gemini OCR, if generated.
  final String? extractedText;

  /// Sinhala<->English translation of [extractedText], if generated.
  final String? translatedText;

  /// Key-points summary of [extractedText], if generated.
  final String? summaryText;

  ScannedDocument copyWith({
    String? title,
    String? extractedText,
    String? translatedText,
    String? summaryText,
  }) => ScannedDocument(
    id: id,
    scannedAt: scannedAt,
    imageBytes: imageBytes,
    title: title ?? this.title,
    extractedText: extractedText ?? this.extractedText,
    translatedText: translatedText ?? this.translatedText,
    summaryText: summaryText ?? this.summaryText,
  );
}
