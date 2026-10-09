import 'package:sukusukukanji/data/models/progress.dart';
import 'package:sukusukukanji/data/repositories/user_repositories.dart';

/// Test doubles only. Production always uses SQLite and platform preferences.
class MemoryProgressRepository implements ProgressRepository {
  MemoryProgressRepository([UserProgress? value])
    : value = value ?? UserProgress();
  UserProgress value;
  final Set<String> sessions = {};
  bool failWrites = false;
  @override
  Future<UserProgress> load() async => value;
  @override
  Future<UserProgress> update(
    UserProgress Function(UserProgress) change, {
    String? sessionId,
  }) async {
    if (failWrites) throw StateError('simulated disk failure');
    if (sessionId != null && sessions.contains(sessionId)) return value;
    value = change(value);
    if (sessionId != null) sessions.add(sessionId);
    return value;
  }
}

class MemorySettingsRepository implements SettingsRepository {
  MemorySettingsRepository({bool onboardingCompleted = true})
    : value = AppSettings(onboardingCompleted: onboardingCompleted);
  AppSettings value;
  bool failWrites = false;
  @override
  Future<AppSettings> load() async => value;
  @override
  Future<void> save(AppSettings settings) async {
    if (failWrites) throw StateError('simulated preferences failure');
    value = settings;
  }
}
