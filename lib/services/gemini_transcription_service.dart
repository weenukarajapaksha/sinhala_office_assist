import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class GeminiTranscriptionException implements Exception {
  GeminiTranscriptionException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Transcribes Sinhala audio via the Gemini API's audio understanding.
///
/// Audio is sent as inline base64 data labeled `audio/ogg`; recordings are
/// captured with the Opus codec, which Gemini's documented audio formats
/// cover via an Ogg/Opus container.
class GeminiTranscriptionService {
  static const _model = 'gemini-3.5-flash';

  Future<String> transcribe({
    required String apiKey,
    required Uint8List audioBytes,
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
                    'Transcribe this Sinhala audio recording verbatim. '
                    'Return only the transcript text in Sinhala script, '
                    'with no commentary, labels, or translation.',
              },
              {
                'inline_data': {
                  'mime_type': 'audio/ogg',
                  'data': base64Encode(audioBytes),
                },
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw GeminiTranscriptionException(
        'Gemini API error (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw GeminiTranscriptionException(
        'Gemini returned no transcription result.',
      );
    }

    final content = (candidates.first as Map<String, dynamic>)['content'];
    final parts = (content as Map<String, dynamic>)['parts'] as List<dynamic>;
    final text = parts
        .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
        .join();
    return text.trim();
  }
}
