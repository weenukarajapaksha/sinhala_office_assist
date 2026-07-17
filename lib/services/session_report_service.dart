import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/recording.dart';
import '../models/scanned_document.dart';

class SessionReportException implements Exception {
  SessionReportException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Summarizes a group of recordings' transcripts and scanned documents'
/// extracted text via Gemini, then renders the summary plus full source
/// text into a downloadable PDF.
class SessionReportService {
  static const _model = 'gemini-3.5-flash';

  Future<String> generateSummary({
    required String apiKey,
    List<Recording> recordings = const [],
    List<ScannedDocument> documents = const [],
  }) async {
    final transcriptSection = recordings
        .map(
          (r) =>
              '### පටිගත කිරීම: ${r.title ?? r.id} (${_formatDateTime(r.recordedAt)})\n${r.transcript ?? ''}',
        )
        .join('\n\n');
    final documentSection = documents
        .map(
          (d) =>
              '### ලේඛනය: ${d.title ?? d.id} (${_formatDateTime(d.scannedAt)})\n${d.extractedText ?? ''}',
        )
        .join('\n\n');
    final sourceSection = [
      transcriptSection,
      documentSection,
    ].where((s) => s.isNotEmpty).join('\n\n');

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
                    'පහත දැක්වෙන්නේ එක් සැසියක පටිගත කිරීම්වල සිංහල පිටපත් (transcripts) සහ/හෝ '
                    'ලේඛනවලින් උපුටාගත් පෙළ කිහිපයකි. '
                    'මේවා පදනම් කරගෙන සිංහල භාෂාවෙන් සංක්ෂිප්ත වාර්තාවක් සකසන්න. '
                    'වාර්තාවේ මේ කොටස් තිබිය යුතුය: "සාරාංශය", "ප්‍රධාන කරුණු", "තීරණ", "ඉදිරි කටයුතු". '
                    'මූලාශ්‍රවල නොමැති අමතර අදහස්, පරිවර්තන හෝ ඉංග්‍රීසි වචන එක් නොකරන්න.\n\n$sourceSection',
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw SessionReportException(
        'Gemini API error (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw SessionReportException('Gemini returned no summary.');
    }
    final content = (candidates.first as Map<String, dynamic>)['content'];
    final parts = (content as Map<String, dynamic>)['parts'] as List<dynamic>;
    return parts
        .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
        .join()
        .trim();
  }

  Future<Uint8List> buildPdf({
    required String summary,
    List<Recording> recordings = const [],
    List<ScannedDocument> documents = const [],
  }) async {
    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansSinhala-VariableFont.ttf',
    );
    final sinhalaFont = pw.Font.ttf(fontData);
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: sinhalaFont,
        bold: sinhalaFont,
        italic: sinhalaFont,
        boldItalic: sinhalaFont,
      ),
    );

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('සැසි වාර්තාව', style: const pw.TextStyle(fontSize: 22)),
          pw.SizedBox(height: 4),
          pw.Text(
            'සකස් කළේ: ${_formatDateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          if (recordings.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'ඇතුළත් පටිගත කිරීම්',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.SizedBox(height: 6),
            ...recordings.map(
              (r) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  '• ${r.title ?? r.id} — ${_formatDateTime(r.recordedAt)} (${_formatDuration(r.duration)})',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
          if (documents.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('ඇතුළත් ලේඛන', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 6),
            ...documents.map(
              (d) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  '• ${d.title ?? d.id} — ${_formatDateTime(d.scannedAt)}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
          pw.SizedBox(height: 16),
          pw.Text('සාරාංශය', style: const pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 6),
          pw.Text(summary, style: const pw.TextStyle(fontSize: 11)),
          if (recordings.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text('සම්පූර්ණ පිටපත්', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 6),
            ...recordings.expand(
              (r) => [
                pw.Text(r.title ?? r.id, style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 4),
                pw.Text(
                  r.transcript ?? '',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 14),
              ],
            ),
          ],
          if (documents.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'ලේඛනවල සම්පූර්ණ පෙළ',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.SizedBox(height: 6),
            ...documents.expand(
              (d) => [
                pw.Text(d.title ?? d.id, style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 4),
                pw.Text(
                  d.extractedText ?? '',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 14),
              ],
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }
}
