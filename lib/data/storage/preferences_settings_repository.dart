import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/progress.dart';
import '../repositories/user_repositories.dart';

class PreferencesSettingsRepository implements SettingsRepository {
  PreferencesSettingsRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _preferences;
  static const key = 'sukusukukanji.settings.v1';
  @override
  Future<AppSettings> load() async {
    final value = await _preferences.getString(key);
    if (value == null) return AppSettings();
    final data = jsonDecode(value) as Map<String, dynamic>;
    if (data['version'] != 1 || data['onboardingCompleted'] is! bool) {
      throw const FormatException(
        'Invalid settings; refusing to reset user state',
      );
    }
    final icons = data['icons'] as Map<String, dynamic>;
    return AppSettings(
      onboardingCompleted: data['onboardingCompleted'] as bool,
      icons: AppIconPreferences(
        unlockedIcons: (icons['unlocked'] as List).cast<String>().toSet(),
        selectedIcon: icons['selected'] as String,
        seenUnlockModals: (icons['seen'] as List).cast<String>().toSet(),
      ),
    );
  }

  @override
  Future<void> save(AppSettings settings) => _preferences.setString(
    key,
    jsonEncode({
      'version': 1,
      'onboardingCompleted': settings.onboardingCompleted,
      'icons': {
        'unlocked': settings.icons.unlockedIcons.toList(),
        'selected': settings.icons.selectedIcon,
        'seen': settings.icons.seenUnlockModals.toList(),
      },
    }),
  );
}
