import 'package:flutter/foundation.dart';

class CloudBackup {
  const CloudBackup({
    required this.revision,
    required this.updatedAt,
    required this.payload,
  });
  final int revision;
  final DateTime updatedAt;
  final Map<String, dynamic> payload;
}

class BackupConflict implements Exception {}

/// SDK boundary. The default keeps the app fully usable without cloud config.
class BackupService extends ChangeNotifier {
  bool get configured => false;
  String? get userId => null;
  String? get email => null;
  String? get authenticationError => null;
  Future<void> initialize() async {}
  Future<void> signIn() async => throw StateError('Cloud is not configured');
  Future<void> signOut() async {}
  Future<CloudBackup?> read(String userId) async => null;
  Future<CloudBackup> write(
    String userId,
    Map<String, dynamic> payload,
    int expectedRevision,
  ) async => throw StateError('Cloud is not configured');
  Future<void> deleteAccount() async =>
      throw StateError('Cloud is not configured');
}
