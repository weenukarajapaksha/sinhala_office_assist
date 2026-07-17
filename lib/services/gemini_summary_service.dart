import 'dart:convert';

import 'package:http/http.dart' as http;

class GeminiSummaryException implements Exception {
  GeminiSummaryException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Produces a short key-points summary of a document's extracted text,
/// in the same language as the source text.
class GeminiSummaryService {
  static const _model = 'gemini-3.5-flash';

  Future<String> summarize({required String apiKey, required String text}) async {
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
                    'Summarize the following document text as a short list of key points, in the '
                    'same language the text is written in. Return only the key points as a bulleted '
                    'list, with no commentary or repeated original text.\n\n$text',
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw GeminiSummaryException(
        'Gemini API error (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw GeminiSummaryException('Gemini returned no summary.');
    }
    final content = (candidates.first as Map<String, dynamic>)['content'];
    final parts = (content as Map<String, dynamic>)['parts'] as List<dynamic>;
    return parts
        .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
        .join()
        .trim();
  }
}
