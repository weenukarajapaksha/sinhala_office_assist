import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'screens/onboarding_screen.dart';
import 'screens/root_screen.dart';
import 'services/background_recording_service.dart';
import 'services/settings_repository.dart';
import 'services/theme_controller.dart';
import 'theme/app_theme.dart';

void main() {
  if (BackgroundRecordingService.isSupported) {
    FlutterForegroundTask.initCommunicationPort();
  }
  BackgroundRecordingService.init();
  runApp(const SinhalaOfficeAssistApp());
}

class SinhalaOfficeAssistApp extends StatefulWidget {
  const SinhalaOfficeAssistApp({super.key});

  @override
  State<SinhalaOfficeAssistApp> createState() =>
      _SinhalaOfficeAssistAppState();
}

class _SinhalaOfficeAssistAppState extends State<SinhalaOfficeAssistApp> {
  final ThemeController _themeController = ThemeController(
    SettingsRepository(),
  );

  @override
  void initState() {
    super.initState();
    _themeController.addListener(_onThemeChanged);
    unawaited(_themeController.load());
  }

  @override
  void dispose() {
    _themeController.removeListener(_onThemeChanged);
    _themeController.dispose();
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Lekam',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeController.themeMode,
      home: AppEntryPoint(themeController: _themeController),
    );
  }
}

class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({required this.themeController, super.key});

  final ThemeController themeController;

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  final SettingsRepository _settings = SettingsRepository();
  bool? _hasSeenOnboarding;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seen = await _settings.hasSeenOnboarding();
    if (!mounted) return;
    setState(() => _hasSeenOnboarding = seen);
  }

  void _finishOnboarding() {
    unawaited(_settings.setOnboardingSeen());
    setState(() => _hasSeenOnboarding = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasSeenOnboarding == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    return _hasSeenOnboarding!
        ? RootScreen(themeController: widget.themeController)
        : OnboardingScreen(onFinished: _finishOnboarding);
  }
}
