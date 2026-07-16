import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../models/recording.dart';

/// `record` ignores the path on web, so there's nothing to resolve.
Future<String> resolveRecordTarget(String fileName) async => fileName;

/// The `record` package hands back a blob: URL on web, which is only valid
/// for the current page session. Fetch the underlying bytes so they can be
/// persisted (e.g. base64 in SharedPreferences) and survive a reload.
Future<Uint8List?> captureBytes(String recordedPath) async {
  final response = await web.window.fetch(recordedPath.toJS).toDart;
  final buffer = await response.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

/// Audio bytes on web live inline in SharedPreferences (via [captureBytes]),
/// so removing the recording from the saved list is enough; there's no
/// separate file to clean up.
Future<void> deleteRecordedFile(String? filePath) async {}

Future<Uint8List> readAudioBytes(Recording recording) async =>
    recording.bytes!;
