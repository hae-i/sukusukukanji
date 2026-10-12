import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/cloud/backup_preferences.dart';
import '../../data/cloud/backup_service.dart';
import '../../data/cloud/progress_snapshot.dart';
import '../../data/repositories/kanji_repository.dart';
import '../../data/repositories/user_repositories.dart';

/// Optional snapshot backup. Offline writes always commit to SQLite first.
/// A different account/device must explicitly choose which snapshot to keep.
class BackupController extends ChangeNotifier {
  BackupController({
    required this.service,
    required this.preferences,
    required this.progress,
    required this.catalog,
    required this.onRestored,
  }) {
    service.addListener(_accountChanged);
  }
  final BackupService service;
  final BackupPreferences preferences;
  final ProgressRepository progress;
  final KanjiCatalog catalog;
  final Future<void> Function() onRestored;
  CloudBackup? remote;
  String? message;
  bool busy = false, automatic = false, checked = false;
  bool _disposed = false, _refreshPending = false, _dirty = false;
  String? _loadedUser;
  int _localGeneration = 0;
  Timer? _timer;
  String? get userId => service.userId;
  bool get canChoose =>
      checked && _loadedUser == userId && userId != null && !busy;
  int? get remoteLearned => remote == null
      ? null
      : ProgressSnapshot.decode(remote!.payload, catalog).totalLearned;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    await _run(() async {
      await service.initialize();
    });
    if (!_disposed && service.configured) await refresh();
  }

  void _accountChanged() {
    if (_disposed) return;
    if (service.authenticationError != null) {
      message = service.authenticationError;
      _notify();
    }
    if (_loadedUser == userId) {
      return; // Token refresh is not an account switch.
    }
    automatic = false;
    checked = false;
    remote = null;
    _timer?.cancel();
    if (busy) {
      _refreshPending = true;
    } else {
      unawaited(refresh());
    }
    _notify();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    message = null;
    _notify();
    try {
      await action();
    } on BackupConflict {
      automatic = false;
      checked = false;
      message = '다른 기기에서 백업이 바뀌었어요. 백업 확인 후 사용할 기록을 선택해 주세요.';
    } catch (_) {
      message = '연결 또는 저장을 완료하지 못했어요. 기기의 학습 기록은 유지돼요. 다시 시도해 주세요.';
    } finally {
      busy = false;
      _notify();
      if (!_disposed && _refreshPending) {
        _refreshPending = false;
        unawaited(refresh());
      }
    }
  }

  void _check(String id) {
    if (_disposed || userId != id) throw StateError('Account changed');
  }

  Future<void> refresh() async {
    await _run(() async {
      await service.initialize();
      final id = userId;
      automatic = false;
      checked = false;
      if (id == null) {
        _loadedUser = null;
        remote = null;
        return;
      }
      final binding = await preferences.load();
      final saved = await service.read(id).timeout(const Duration(seconds: 20));
      _check(id);
      if (saved != null) ProgressSnapshot.decode(saved.payload, catalog);
      remote = saved;
      _loadedUser = id;
      checked = true;
      automatic =
          binding?.userId == id && binding!.revision == (saved?.revision ?? 0);
      if (binding?.userId == id && !automatic) {
        message = '클라우드 기록이 바뀌었어요. 복원하거나 이 기기 기록으로 백업해 주세요.';
      }
    });
    if (automatic && !_disposed) await backupNow();
  }

  Future<void> signIn() => _run(service.signIn);
  Future<void> signOut() async {
    automatic = false;
    _timer?.cancel();
    await _run(service.signOut);
  }

  Future<void> deleteAccount() async {
    automatic = false;
    _timer?.cancel();
    await _run(service.deleteAccount);
  }

  void localChanged() {
    _localGeneration++;
    _dirty = true;
    if (!automatic && !checked && userId != null && !busy) {
      unawaited(refresh());
    } else {
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (!automatic || _disposed) return;
    _timer = Timer(const Duration(seconds: 1), () async {
      if (busy) {
        _schedule();
        return;
      }
      await backupNow();
    });
  }

  /// Explicit first upload also binds existing guest data to this account.
  Future<void> backupNow() async {
    if (!canChoose) return;
    _timer?.cancel();
    await _run(() async {
      final id = userId!;
      final generation = _localGeneration;
      final snapshot = ProgressSnapshot.encode(await progress.load());
      _check(id);
      CloudBackup saved;
      if (remote != null &&
          jsonEncode(remote!.payload) == jsonEncode(snapshot)) {
        final latest = await service
            .read(id)
            .timeout(const Duration(seconds: 20));
        if (latest == null || latest.revision != remote!.revision) {
          throw BackupConflict();
        }
        saved = latest;
      } else {
        saved = await service
            .write(id, snapshot, remote?.revision ?? 0)
            .timeout(const Duration(seconds: 20));
      }
      _check(id);
      // Persist the binding only after a successful cloud write.
      await preferences.save(BackupBinding(id, saved.revision));
      _check(id);
      remote = saved;
      automatic = true;
      _dirty = generation != _localGeneration;
      message = '진도를 백업했어요.';
    });
    if (message == '진도를 백업했어요.' && _dirty) _schedule();
  }

  /// UI must confirm replacement; quota and purchases are never restored.
  Future<void> restore() async {
    if (!canChoose || remote == null) return;
    await _run(() async {
      final id = userId!;
      final generation = _localGeneration;
      final saved = await service.read(id).timeout(const Duration(seconds: 20));
      _check(id);
      if (saved == null || saved.revision != remote!.revision) {
        throw BackupConflict();
      }
      final snapshot = ProgressSnapshot.decode(saved.payload, catalog);
      await progress.update((local) {
        _check(id);
        if (generation != _localGeneration) throw BackupConflict();
        return snapshot.copyWith(learningAccess: local.learningAccess);
      });
      _check(id);
      // Always refresh UI after the local transaction, even if preferences fail.
      await onRestored();
      await preferences.save(BackupBinding(id, saved.revision));
      _check(id);
      remote = saved;
      automatic = true;
      _dirty = false;
      message = '클라우드 진도를 복원했어요.';
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    service.removeListener(_accountChanged);
    service.dispose();
    super.dispose();
  }
}
