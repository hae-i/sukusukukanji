import 'package:flutter/foundation.dart';

import '../data/models/grade_theme.dart';
import '../data/models/kanji.dart';
import '../data/models/progress.dart';
import '../data/models/study_session.dart';
import '../data/repositories/kanji_repository.dart';
import '../data/repositories/user_repositories.dart';
import '../data/services/grade_policy.dart';
import '../data/services/icon_policy.dart';
import '../data/services/app_icon_service.dart';
import '../data/services/progress_policy.dart';
import '../data/services/session_planner.dart';

enum AppStatus { loading, ready, error }

class AppController extends ChangeNotifier {
  AppController({
    required KanjiRepository content,
    required ProgressRepository progress,
    required SettingsRepository settings,
    DateTime Function()? now,
    AppIconService? iconService,
  }) : _contentRepository = content,
       _progressRepository = progress,
       _settingsRepository = settings,
       now = now ?? DateTime.now,
       iconService = iconService ?? const UnsupportedAppIconService();
  final KanjiRepository _contentRepository;
  final ProgressRepository _progressRepository;
  final SettingsRepository _settingsRepository;
  final DateTime Function() now;
  final AppIconService iconService;
  bool changingIcon = false;
  String? iconError;
  AppStatus status = AppStatus.loading;
  KanjiCatalog? catalog;
  UserProgress progress = UserProgress();
  AppSettings settings = AppSettings();
  Object? error;
  bool _disposed = false;
  bool _loading = false;
  bool savingSettings = false;
  static const planner = SessionPlanner();
  static const gradePolicy = GradePolicy();
  static const iconPolicy = IconPolicy();
  List<GradeTheme> get pendingIconRewards => catalog!.iconThemes
      .skip(1)
      .where(
        (g) =>
            settings.icons.unlockedIcons.contains(g.iconKey) &&
            !settings.icons.seenUnlockModals.contains(g.iconKey),
      )
      .toList();
  GradeTheme get currentGrade => catalog!.grades.firstWhere(
    (g) => g.grade == progress.currentGrade,
    orElse: () => catalog!.grades.first,
  );
  List<Kanji> get nextLesson =>
      planner.nextLesson(catalog!, progress, currentGrade.grade);
  List<Kanji> get reviewItems => planner.review(catalog!, progress);
  int get reviewCount => catalog!.kanji
      .where((k) => progress.kanji[k.id]?.needsReview ?? false)
      .length;
  List<GradeTheme> get pendingGraduations => catalog!.grades
      .where(
        (g) =>
            progress.completedGrades.contains(g.grade) &&
            !progress.seenGradeCelebrations.contains(g.grade),
      )
      .toList();

  Future<void> load() async {
    if (_loading || _disposed) return;
    _loading = true;
    status = AppStatus.loading;
    error = null;
    notifyListeners();
    try {
      final content = await _contentRepository.load();
      final stored = await _progressRepository.load();
      final preferences = await _settingsRepository.load();
      if (_disposed) return;
      catalog = content;
      progress = stored;
      settings = preferences;
      await _reconcileIcons();
      if (_disposed) return;
      status = AppStatus.ready;
    } catch (exception) {
      if (_disposed) return;
      error = exception;
      status = AppStatus.error;
      if (kDebugMode) debugPrint('App loading failed: $exception');
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> completeOnboarding() async {
    if (savingSettings) return;
    savingSettings = true;
    notifyListeners();
    try {
      final next = AppSettings(
        onboardingCompleted: true,
        icons: settings.icons,
      );
      await _settingsRepository.save(next);
      if (!_disposed) settings = next;
    } finally {
      savingSettings = false;
      if (!_disposed) notifyListeners();
    }
  }

  StudySession? start({bool review = false}) {
    final items = review ? reviewItems : nextLesson;
    if (items.isEmpty) return null;
    if (!review && !gradePolicy.isUnlocked(currentGrade, catalog!, progress)) {
      return null;
    }
    return planner.create(items, catalog!, isReview: review);
  }

  Future<void> saveSession(CompletedSession session) async {
    final next = await _progressRepository.update(
      (old) => gradePolicy.reconcile(
        catalog!,
        const ProgressPolicy().apply(old, session),
      ),
      sessionId: session.session.id,
    );
    if (_disposed) return;
    progress = next;
    await _reconcileIcons();
    if (!_disposed) notifyListeners();
  }

  StudySession? startLessonReview(int grade, int lesson) {
    final theme = catalog!.grades.firstWhere((g) => g.grade == grade);
    if (!gradePolicy.isUnlocked(theme, catalog!, progress)) return null;
    final items = catalog!.lessonsForGrade(grade)[lesson];
    if (items == null ||
        !items.every((k) => progress.kanji[k.id]?.firstStudiedAt != null)) {
      return null;
    }
    return planner.create(items, catalog!, isReview: true);
  }

  Future<void> toggleFavorite(Kanji kanji) async {
    if (!catalog!.kanji.any((k) => k.id == kanji.id)) {
      throw ArgumentError('Unknown kanji');
    }
    final next = await _progressRepository.update((old) {
      final ids = {...old.favoriteKanjiIds};
      if (!ids.remove(kanji.id)) ids.add(kanji.id);
      return old.copyWith(favoriteKanjiIds: ids);
    });
    if (_disposed) return;
    progress = next;
    notifyListeners();
  }

  Future<void> addReview(Kanji kanji) async {
    final next = await _progressRepository.update((old) {
      final record = old.kanji[kanji.id] ?? KanjiProgress(kanjiId: kanji.id);
      if (record.needsReview) return old;
      return old.copyWith(kanji: {...old.kanji, kanji.id: record.forReview()});
    });
    if (_disposed) return;
    progress = next;
    notifyListeners();
  }

  Future<void> acknowledgeGraduation(int grade) async {
    final next = await _progressRepository.update((old) {
      if (!old.completedGrades.contains(grade)) {
        throw StateError('Grade not complete');
      }
      return old.copyWith(
        seenGradeCelebrations: {...old.seenGradeCelebrations, grade},
      );
    });
    if (_disposed) return;
    progress = next;
    notifyListeners();
  }

  Future<void> _reconcileIcons() async {
    if (catalog!.grades.isEmpty) return;
    final icons = iconPolicy.reconcile(catalog!, progress, settings.icons);
    final changed =
        !setEquals(icons.unlockedIcons, settings.icons.unlockedIcons) ||
        !setEquals(icons.seenUnlockModals, settings.icons.seenUnlockModals) ||
        icons.selectedIcon != settings.icons.selectedIcon;
    settings = AppSettings(
      onboardingCompleted: settings.onboardingCompleted,
      icons: icons,
    );
    if (changed) {
      try {
        await _settingsRepository.save(settings);
        iconError = null;
      } catch (_) {
        iconError = '아이콘 보상 저장을 다시 시도해 주세요.';
      }
    }
  }

  Future<void> acknowledgeIcon(String key) async {
    if (!settings.icons.unlockedIcons.contains(key)) {
      throw StateError('Icon is locked');
    }
    final next = AppSettings(
      onboardingCompleted: settings.onboardingCompleted,
      icons: AppIconPreferences(
        unlockedIcons: settings.icons.unlockedIcons,
        selectedIcon: settings.icons.selectedIcon,
        seenUnlockModals: {...settings.icons.seenUnlockModals, key},
      ),
    );
    await _settingsRepository.save(next);
    if (_disposed) return;
    settings = next;
    iconError = null;
    notifyListeners();
  }

  /// Returns whether the actual launcher was changed. A selection is still
  /// saved on platforms without alternate-icon support and reported as such.
  Future<bool> selectIcon(String key) async {
    if (!settings.icons.unlockedIcons.contains(key)) {
      throw StateError('Icon is locked');
    }
    if (changingIcon || savingSettings) {
      throw StateError('Settings are being saved');
    }
    changingIcon = true;
    iconError = null;
    notifyListeners();
    var applied = false;
    String? previousNative;
    try {
      if (await iconService.isSupported()) {
        previousNative = await iconService.current();
        await iconService.apply(key);
        applied = true;
      }
      final next = AppSettings(
        onboardingCompleted: settings.onboardingCompleted,
        icons: AppIconPreferences(
          unlockedIcons: settings.icons.unlockedIcons,
          selectedIcon: key,
          seenUnlockModals: settings.icons.seenUnlockModals,
        ),
      );
      await _settingsRepository.save(next);
      if (!_disposed) settings = next;
      return applied;
    } catch (_) {
      if (applied && previousNative != null) {
        try {
          await iconService.apply(previousNative);
        } catch (_) {
          iconError = '기기 아이콘을 복원하지 못했어요. 다시 선택해 주세요.';
        }
      }
      iconError ??= '아이콘을 바꾸지 못했어요. 다시 시도해 주세요.';
      rethrow;
    } finally {
      changingIcon = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
