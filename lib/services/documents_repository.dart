import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/scanned_document.dart';

class DocumentsRepository {
  static const _prefsKey = 'scanned_documents_v1';

  Future<List<ScannedDocument>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    return raw.map((entry) {
      final map = jsonDecode(entry) as Map<String, dynamic>;
      return ScannedDocument(
        id: map['id'] as String,
        scannedAt: DateTime.parse(map['scannedAt'] as String),
        imageBytes: base64Decode(map['imageBase64'] as String),
        title: map['title'] as String?,
        extractedText: map['extractedText'] as String?,
      );
    }).toList();
  }

  Future<void> save(List<ScannedDocument> documents) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = documents
        .map(
          (d) => jsonEncode({
            'id': d.id,
            'scannedAt': d.scannedAt.toIso8601String(),
            'imageBase64': base64Encode(d.imageBytes),
            if (d.title != null) 'title': d.title,
            if (d.extractedText != null) 'extractedText': d.extractedText,
          }),
        )
        .toList();
    await prefs.setStringList(_prefsKey, raw);
  }
}
