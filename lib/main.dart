import 'package:flutter/material.dart';

import 'app/app.dart';
import 'data/repositories/kanji_repository.dart';
import 'data/services/app_icon_service.dart';
import 'data/storage/sqlite_progress_repository.dart';
import 'data/storage/preferences_settings_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    SukuSukuApp(
      repository: AssetKanjiRepository(),
      progressRepository: SqliteProgressRepository(),
      settingsRepository: PreferencesSettingsRepository(),
      iconService: const PlatformAppIconService(),
    ),
  );
}
