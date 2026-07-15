import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class TranscriptionException implements Exception {
  TranscriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Transcribes recorded audio (webm/opus) via the Google Cloud
/// Speech-to-Text REST API using a simple API key.
class GoogleSpeechTranscriber {
  static const _endpoint = 'https://speech.googleapis.com/v1/speech:recognize';

  Future<String> transcribe({
    required String apiKey,
    required Uint8List audioBytes,
    String languageCode = 'si-LK',
  }) async {
    final response = await http.post(
      Uri.parse('$_endpoint?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'config': {
          'encoding': 'WEBM_OPUS',
          'sampleRateHertz': 48000,
          'languageCode': languageCode,
          'enableAutomaticPunctuation': true,
        },
        'audio': {'content': base64Encode(audioBytes)},
      }),
    );

    if (response.statusCode != 200) {
      throw TranscriptionException(
        'Google Speech API error (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      throw TranscriptionException('No speech detected in this recording.');
    }

    return results
        .map((result) {
          final alternatives =
              (result as Map<String, dynamic>)['alternatives'] as List<dynamic>;
          return (alternatives.first as Map<String, dynamic>)['transcript']
              as String;
        })
        .join(' ');
  }
}
