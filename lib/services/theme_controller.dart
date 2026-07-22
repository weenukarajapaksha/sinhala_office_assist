import 'package:flutter/material.dart';

import 'settings_repository.dart';

/// Holds the app's current theme mode and persists changes, so the
/// Settings screen's dark-mode toggle can update the whole app immediately.
class ThemeController extends ChangeNotifier {
  ThemeController(this._settings);

  final SettingsRepository _settings;
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> load() async {
    final darkMode = await _settings.getDarkMode();
    _themeMode = darkMode ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setDarkMode(bool enabled) async {
    _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    await _settings.setDarkMode(enabled);
  }
}
