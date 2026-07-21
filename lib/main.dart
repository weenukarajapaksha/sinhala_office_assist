import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'screens/root_screen.dart';
import 'services/background_recording_service.dart';
import 'theme/app_theme.dart';

void main() {
  if (BackgroundRecordingService.isSupported) {
    FlutterForegroundTask.initCommunicationPort();
  }
  BackgroundRecordingService.init();
  runApp(const SinhalaOfficeAssistApp());
}

class SinhalaOfficeAssistApp extends StatelessWidget {
  const SinhalaOfficeAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Lekam',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const RootScreen(),
    );
  }
}

