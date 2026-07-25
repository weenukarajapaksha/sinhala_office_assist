import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart' show Color;
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;

import '../models/recording.dart';
import '../models/scanned_document.dart';
import 'sinhala_pdf_text_renderer.dart';

class SessionReportException implements Exception {
  SessionReportException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Summarizes a group of recordings' transcripts and scanned documents'
/// extracted text via Gemini, then renders the summary plus full source
/// text into a downloadable PDF.
///
/// All Sinhala text in the PDF is rasterized via [SinhalaPdfTextRenderer]
/// rather than drawn as native PDF text — see that class for why.
class SessionReportService {
  static const _model = 'gemini-3.5-flash';
  static const _contentWidth = 481.0; // PdfPageFormat.a4.availableWidth

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

  Future<pw.Widget> _heading(String text) => SinhalaPdfTextRenderer.render(
    text,
    fontSize: 14,
    maxWidthPoints: _contentWidth,
  );

  Future<pw.Widget> _title(String text) => SinhalaPdfTextRenderer.render(
    text,
    fontSize: 22,
    maxWidthPoints: _contentWidth,
  );

  Future<pw.Widget> _caption(String text) => SinhalaPdfTextRenderer.render(
    text,
    fontSize: 10,
    color: const Color(0xFF616161),
    maxWidthPoints: _contentWidth,
  );

  Future<pw.Widget> _label(String text) => SinhalaPdfTextRenderer.render(
    text,
    fontSize: 12,
    maxWidthPoints: _contentWidth,
  );

  Future<pw.Widget> _bullet(String text) => SinhalaPdfTextRenderer.render(
    text,
    fontSize: 11,
    maxWidthPoints: _contentWidth,
  );

  Future<List<pw.Widget>> _body(String text) =>
      SinhalaPdfTextRenderer.renderParagraphs(
        text,
        fontSize: 11,
        maxWidthPoints: _contentWidth,
      );

  Future<pw.Document> _newDocument() async => pw.Document();

  Future<Uint8List> buildPdf({
    required String summary,
    List<Recording> recordings = const [],
    List<ScannedDocument> documents = const [],
  }) async {
    final doc = await _newDocument();

    final children = <pw.Widget>[
      await _title('සැසි වාර්තාව'),
      pw.SizedBox(height: 4),
      await _caption('සකස් කළේ: ${_formatDateTime(DateTime.now())}'),
    ];

    if (recordings.isNotEmpty) {
      children.add(pw.SizedBox(height: 16));
      children.add(await _heading('ඇතුළත් පටිගත කිරීම්'));
      children.add(pw.SizedBox(height: 6));
      for (final r in recordings) {
        children.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: await _bullet(
              '• ${r.title ?? r.id} — ${_formatDateTime(r.recordedAt)} (${_formatDuration(r.duration)})',
            ),
          ),
        );
      }
    }

    if (documents.isNotEmpty) {
      children.add(pw.SizedBox(height: 16));
      children.add(await _heading('ඇතුළත් ලේඛන'));
      children.add(pw.SizedBox(height: 6));
      for (final d in documents) {
        children.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: await _bullet(
              '• ${d.title ?? d.id} — ${_formatDateTime(d.scannedAt)}',
            ),
          ),
        );
      }
    }

    children.add(pw.SizedBox(height: 16));
    children.add(await _heading('සාරාංශය'));
    children.add(pw.SizedBox(height: 6));
    children.addAll(await _body(summary));

    if (recordings.isNotEmpty) {
      children.add(pw.SizedBox(height: 12));
      children.add(await _heading('සම්පූර්ණ පිටපත්'));
      children.add(pw.SizedBox(height: 6));
      for (final r in recordings) {
        children.add(await _label(r.title ?? r.id));
        children.add(pw.SizedBox(height: 4));
        children.addAll(await _body(r.transcript ?? ''));
        children.add(pw.SizedBox(height: 10));
      }
    }

    if (documents.isNotEmpty) {
      children.add(pw.SizedBox(height: 12));
      children.add(await _heading('ලේඛනවල සම්පූර්ණ පෙළ'));
      children.add(pw.SizedBox(height: 6));
      for (final d in documents) {
        children.add(await _label(d.title ?? d.id));
        children.add(pw.SizedBox(height: 4));
        children.addAll(await _body(d.extractedText ?? ''));
        children.add(pw.SizedBox(height: 10));
      }
    }

    doc.addPage(pw.MultiPage(build: (context) => children));

    return doc.save();
  }

  /// Renders a single scanned document's extracted text (plus translation
  /// and summary, if generated) as a standalone PDF for direct download.
  Future<Uint8List> buildSingleDocumentPdf(ScannedDocument document) async {
    final doc = await _newDocument();

    final children = <pw.Widget>[
      await _title(document.title ?? document.id),
      pw.SizedBox(height: 4),
      await _caption('ලේඛනගත කළේ: ${_formatDateTime(document.scannedAt)}'),
      pw.SizedBox(height: 16),
      await _heading('උපුටාගත් පෙළ'),
      pw.SizedBox(height: 6),
      ...await _body(document.extractedText ?? ''),
    ];

    if (document.translatedText != null) {
      children.add(pw.SizedBox(height: 12));
      children.add(await _heading('පරිවර්තනය'));
      children.add(pw.SizedBox(height: 6));
      children.addAll(await _body(document.translatedText!));
    }

    if (document.summaryText != null) {
      children.add(pw.SizedBox(height: 12));
      children.add(await _heading('සාරාංශය'));
      children.add(pw.SizedBox(height: 6));
      children.addAll(await _body(document.summaryText!));
    }

    doc.addPage(pw.MultiPage(build: (context) => children));

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
