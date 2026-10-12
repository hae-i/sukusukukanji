import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BackupBinding {
  const BackupBinding(this.userId, this.revision);
  final String userId;
  final int revision;
}

abstract interface class BackupPreferences {
  Future<BackupBinding?> load();
  Future<void> save(BackupBinding binding);
}

class PlatformBackupPreferences implements BackupPreferences {
  final _preferences = SharedPreferencesAsync();
  static const _key = 'sukusukukanji.backup_binding.v1';
  @override
  Future<BackupBinding?> load() async {
    final value = await _preferences.getString(_key);
    if (value == null) return null;
    final json = jsonDecode(value) as Map<String, dynamic>;
    if (json['version'] != 1 ||
        json['userId'] is! String ||
        json['revision'] is! int ||
        (json['revision'] as int) < 0) {
      throw const FormatException('Invalid backup binding');
    }
    return BackupBinding(json['userId'] as String, json['revision'] as int);
  }

  @override
  Future<void> save(BackupBinding binding) => _preferences.setString(
    _key,
    jsonEncode({
      'version': 1,
      'userId': binding.userId,
      'revision': binding.revision,
    }),
  );
}
