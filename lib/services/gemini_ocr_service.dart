import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class GeminiOcrException implements Exception {
  GeminiOcrException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Extracts text from a scanned document image via Gemini's vision input.
class GeminiOcrService {
  static const _model = 'gemini-3.5-flash';

  Future<String> extractText({
    required String apiKey,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text':
                    'Extract all text from this document image verbatim, preserving '
                    'line breaks and layout as closely as possible. Return only the '
                    'extracted text, with no commentary, labels, or translation. If '
                    'the text is in Sinhala, keep it in Sinhala script.',
              },
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Encode(imageBytes),
                },
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw GeminiOcrException(
        'Gemini API error (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw GeminiOcrException('Gemini returned no extraction result.');
    }

    final content = (candidates.first as Map<String, dynamic>)['content'];
    final parts = (content as Map<String, dynamic>)['parts'] as List<dynamic>;
    final text = parts
        .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
        .join();
    return text.trim();
  }
}
