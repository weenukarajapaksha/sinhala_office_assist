import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  static const _apiKeyPrefsKey = 'gemini_api_key';

  Future<String?> getGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_apiKeyPrefsKey);
    return (key == null || key.isEmpty) ? null : key;
  }

  Future<void> saveGeminiApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPrefsKey, apiKey);
  }
}
