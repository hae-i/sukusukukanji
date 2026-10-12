import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backup_service.dart';

class SupabaseBackupService extends BackupService {
  SupabaseBackupService({required this.url, required this.publishableKey});
  @visibleForTesting
  SupabaseBackupService.withClient(SupabaseClient client)
    : url = '',
      publishableKey = '',
      _client = client;
  factory SupabaseBackupService.fromEnvironment() => SupabaseBackupService(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );
  final String url, publishableKey;
  static const redirectUrl = 'app.sukusukukanji://login-callback';
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _subscription;
  bool _disposed = false;
  String? _authenticationError;
  @override
  String? get authenticationError => _authenticationError;
  @override
  bool get configured =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      url.isNotEmpty &&
      publishableKey.isNotEmpty;
  @override
  String? get userId => _client?.auth.currentUser?.id;
  @override
  String? get email => _client?.auth.currentUser?.email;
  @override
  Future<void> initialize() async {
    if (!configured || _client != null) return;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        !publishableKey.startsWith('sb_publishable_')) {
      throw const FormatException(
        'Use an HTTPS URL and a Supabase publishable key',
      );
    }
    final supabase = await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    if (_disposed) return;
    _client = supabase.client;
    _subscription = _client!.auth.onAuthStateChange.listen(
      (_) {
        _authenticationError = null;
        if (!_disposed) notifyListeners();
      },
      onError: (Object _) {
        _authenticationError = 'Google 계정 연결을 완료하지 못했어요. 다시 연결해 주세요.';
        if (!_disposed) notifyListeners();
      },
    );
  }

  @override
  Future<void> signIn() async {
    _authenticationError = null;
    await initialize();
    if (_client == null ||
        !await _client!.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectUrl,
          queryParams: const {'prompt': 'select_account'},
        )) {
      throw StateError('Cannot open Google sign-in');
    }
  }

  @override
  Future<void> signOut() async =>
      _client?.auth.signOut(scope: SignOutScope.local);
  void _checkUser(String expected) {
    if (userId != expected) throw StateError('Account changed');
  }

  CloudBackup _parse(Map<String, dynamic> row) => CloudBackup(
    revision: row['revision'] as int,
    updatedAt: DateTime.parse(row['updated_at'] as String),
    payload: Map<String, dynamic>.from(row['payload'] as Map),
  );
  @override
  Future<CloudBackup?> read(String userId) async {
    _checkUser(userId);
    final row = await _client!
        .from('kanji_progress_backups')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    _checkUser(userId);
    return row == null ? null : _parse(row);
  }

  @override
  Future<CloudBackup> write(
    String userId,
    Map<String, dynamic> payload,
    int expectedRevision,
  ) async {
    _checkUser(userId);
    try {
      final row = await _client!.rpc(
        'save_kanji_progress_backup',
        params: {
          'snapshot': payload,
          'expected_revision': expectedRevision,
          'expected_user_id': userId,
        },
      );
      _checkUser(userId);
      return _parse(Map<String, dynamic>.from(row as Map));
    } on PostgrestException catch (error) {
      if (error.code == '40001') throw BackupConflict();
      rethrow;
    }
  }

  @override
  Future<void> deleteAccount() async {
    if (userId == null) throw StateError('Sign in first');
    final response = await _client!.functions.invoke(
      'delete-account',
      body: {'expectedUserId': userId},
    );
    if (response.status != 200) throw StateError('Account deletion failed');
    await signOut();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
