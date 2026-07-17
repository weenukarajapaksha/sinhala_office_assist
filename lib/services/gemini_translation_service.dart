import 'dart:convert';

import 'package:http/http.dart' as http;

class GeminiTranslationException implements Exception {
  GeminiTranslationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Translates text Sinhala->English or English->Sinhala via Gemini,
/// auto-detecting which direction based on the input's dominant script.
class GeminiTranslationService {
  static const _model = 'gemini-3.5-flash';

  Future<String> translate({required String apiKey, required String text}) async {
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
                    'If the following text is predominantly in Sinhala, translate it to natural '
                    'English. If it is predominantly in English, translate it to natural Sinhala. '
                    'Return only the translated text, with no commentary, labels, or the original '
                    'text repeated.\n\n$text',
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw GeminiTranslationException(
        'Gemini API error (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw GeminiTranslationException('Gemini returned no translation.');
    }
    final content = (candidates.first as Map<String, dynamic>)['content'];
    final parts = (content as Map<String, dynamic>)['parts'] as List<dynamic>;
    return parts
        .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
        .join()
        .trim();
  }
}
