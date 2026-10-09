import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'data/repositories/kanji_repository.dart';
import 'data/services/app_icon_service.dart';
import 'data/storage/sqlite_progress_repository.dart';
import 'data/storage/preferences_settings_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Noto Sans JP',
    ], await rootBundle.loadString('assets/fonts/NotoSansJP-OFL.txt'));
    yield LicenseEntryWithLineBreaks([
      'Pretendard',
    ], await rootBundle.loadString('assets/fonts/Pretendard-OFL.txt'));
  });
  runApp(
    SukuSukuApp(
      repository: AssetKanjiRepository(),
      progressRepository: SqliteProgressRepository(),
      settingsRepository: PreferencesSettingsRepository(),
      iconService: const PlatformAppIconService(),
    ),
  );
}
