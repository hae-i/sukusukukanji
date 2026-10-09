import '../models/progress.dart';

abstract interface class ProgressRepository {
  Future<UserProgress> load();

  /// Read-transform-write atomically. A repeated sessionId is a no-op.
  Future<UserProgress> update(
    UserProgress Function(UserProgress) change, {
    String? sessionId,
  });
}

abstract interface class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}
