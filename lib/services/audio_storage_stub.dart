import 'dart:typed_data';

import '../models/recording.dart';

Future<String> resolveRecordTarget(String fileName) async => fileName;

Future<Uint8List?> captureBytes(String recordedPath) async => null;

Future<void> deleteRecordedFile(String? filePath) async {}

Future<Uint8List> readAudioBytes(Recording recording) async =>
    throw UnimplementedError('Audio transcription is not supported on this platform.');

Future<int> fileSizeBytes(String path) async => 0;
