import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

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
