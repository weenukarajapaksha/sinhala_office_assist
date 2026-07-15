import 'dart:typed_data';

Future<String> resolveRecordTarget(String fileName) async => fileName;

Future<Uint8List?> captureBytes(String recordedPath) async => null;

Future<void> deleteRecordedFile(String? filePath) async {}

Future<Uint8List> readRecordedFile(String filePath) async => Uint8List(0);
