import 'package:flutter/material.dart';

import '../services/settings_repository.dart';
import '../services/storage_usage_service.dart';
import '../services/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/icon_chip.dart';
import 'onboarding_screen.dart';

const String appVersion = '1.0.0';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.themeController, super.key});

  final ThemeController themeController;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsRepository _settings = SettingsRepository();
  final StorageUsageService _storageUsage = StorageUsageService();

  String? _apiKeyMasked;
  String _storageText = '...';
  bool _loadingStorage = true;

  @override
  void initState() {
    super.initState();
    widget.themeController.addListener(_onThemeChanged);
    _load();
  }

  @override
  void dispose() {
    widget.themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final key = await _settings.getGeminiApiKey();
    if (mounted) {
      setState(() => _apiKeyMasked = key == null ? null : _mask(key));
    }
    final bytes = await _storageUsage.totalBytes();
    if (!mounted) return;
    setState(() {
      _storageText = _storageUsage.formatBytes(bytes);
      _loadingStorage = false;
    });
  }

  String _mask(String key) {
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 4)}••••${key.substring(key.length - 4)}';
  }

  Future<void> _editApiKey() async {
    final controller = TextEditingController(
      text: await _settings.getGeminiApiKey() ?? '',
    );
    if (!mounted) return;
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gemini API Key'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'API key'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (saved == null || saved.isEmpty) return;
    await _settings.saveGeminiApiKey(saved);
    await _load();
  }

  Future<void> _replayOnboarding() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OnboardingScreen(
          onFinished: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('සැකසුම්')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Gemini', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const IconChip(
                  icon: Icons.key_outlined,
                  color: AppTheme.accentTeal,
                ),
                title: const Text('API Key'),
                subtitle: Text(_apiKeyMasked ?? 'සකසා නොමැත'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _editApiKey,
              ),
            ),
            const SizedBox(height: 24),
            Text('පෙනුම', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                secondary: const IconChip(
                  icon: Icons.dark_mode_outlined,
                  color: AppTheme.primaryBlue,
                ),
                title: const Text('අඳුරු ප්‍රකාරය'),
                subtitle: const Text('Dark mode'),
                value: widget.themeController.isDarkMode,
                onChanged: (value) => widget.themeController.setDarkMode(value),
              ),
            ),
            const SizedBox(height: 24),
            Text('ආචයනය', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const IconChip(
                  icon: Icons.storage_outlined,
                  color: AppTheme.accentTeal,
                ),
                title: const Text('භාවිත වූ ආචයනය'),
                subtitle: Text(
                  _loadingStorage
                      ? 'ගණනය කරමින්...'
                      : '$_storageText • පටිගත කිරීම් සහ ලේඛන',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'නැවත ගණනය කරන්න',
                  onPressed: () {
                    setState(() => _loadingStorage = true);
                    _load();
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('උදව්', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const IconChip(
                  icon: Icons.replay_circle_filled_outlined,
                  color: AppTheme.primaryBlue,
                ),
                title: const Text('හැඳින්වීම නැවත බලන්න'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _replayOnboarding,
              ),
            ),
            const SizedBox(height: 24),
            Text('පිළිබඳ', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const IconChip(
                  icon: Icons.info_outline_rounded,
                  color: AppTheme.textSecondary,
                ),
                title: const Text('E-ලේකම්'),
                subtitle: const Text('අනුවාදය $appVersion'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
