import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:pdf/widgets.dart' as pw;

import '../theme/app_theme.dart';

/// Renders Sinhala text as a rasterized image using Flutter's own text
/// engine, instead of the `pdf` package's native vector text.
///
/// The `pdf` package doesn't implement OpenType shaping (GSUB/GPOS), which
/// Sinhala (and other Brahmic scripts) need to reorder vowel signs and form
/// conjuncts correctly — left as native PDF text, letters render
/// overlapping or out of order. Flutter's own text engine already shapes
/// this correctly (it's how the in-app UI renders), so rasterizing through
/// it and embedding the result as an image sidesteps the bug entirely.
///
/// Trade-off: the resulting PDF text is a picture, not selectable/
/// searchable text.
class SinhalaPdfTextRenderer {
  static const double _pixelsPerPoint = 3.0;

  /// Renders a single block of text (wrapped to [maxWidthPoints]) as one
  /// PDF image widget.
  static Future<pw.Widget> render(
    String text, {
    required double fontSize,
    required double maxWidthPoints,
    FontWeight fontWeight = FontWeight.normal,
    Color color = const Color(0xFF000000),
    double lineHeightFactor = 1.5,
  }) async {
    if (text.trim().isEmpty) return pw.SizedBox();

    final maxWidthPx = maxWidthPoints * _pixelsPerPoint;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: fontSize * _pixelsPerPoint,
          fontWeight: fontWeight,
          color: color,
          height: lineHeightFactor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidthPx);

    final width = maxWidthPx;
    final height = painter.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    painter.paint(canvas, Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.ceil(), height.ceil());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    return pw.Image(
      pw.MemoryImage(pngBytes),
      width: width / _pixelsPerPoint,
      height: height / _pixelsPerPoint,
    );
  }

  /// Splits [text] into paragraphs and renders each as its own image widget
  /// (with spacing after each), so the PDF's normal page-flow can still
  /// break between paragraphs rather than needing one huge, unbreakable
  /// image for a whole transcript.
  static Future<List<pw.Widget>> renderParagraphs(
    String text, {
    required double fontSize,
    required double maxWidthPoints,
    FontWeight fontWeight = FontWeight.normal,
    Color color = const Color(0xFF000000),
    double lineHeightFactor = 1.5,
    double paragraphSpacing = 8,
  }) async {
    final paragraphs = text
        .split(RegExp(r'\n+'))
        .where((p) => p.trim().isNotEmpty);

    final widgets = <pw.Widget>[];
    for (final paragraph in paragraphs) {
      widgets.add(
        await render(
          paragraph,
          fontSize: fontSize,
          maxWidthPoints: maxWidthPoints,
          fontWeight: fontWeight,
          color: color,
          lineHeightFactor: lineHeightFactor,
        ),
      );
      widgets.add(pw.SizedBox(height: paragraphSpacing));
    }
    return widgets;
  }
}
