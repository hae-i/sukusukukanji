import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sukusukukanji/data/cloud/backup_service.dart';
import 'package:sukusukukanji/data/cloud/supabase_backup_service.dart';

void main() {
  late SupabaseClient client;
  late SupabaseBackupService service;
  final requests = <http.Request>[];
  int status = 200;
  Map<String, dynamic> response = {};
  setUp(() async {
    requests.clear();
    status = 200;
    response = {
      'revision': 1,
      'updated_at': '2026-10-12T12:00:00Z',
      'payload': {'version': 1},
    };
    client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(response),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    // SDK recovery with a test token; no Google authentication or network traffic.
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': 'test-token',
        'token_type': 'bearer',
        'user': {
          'id': 'alice',
          'aud': 'authenticated',
          'created_at': '2026-10-12T00:00:00Z',
          'app_metadata': {},
          'user_metadata': {},
        },
      }),
    );
    service = SupabaseBackupService.withClient(client);
  });
  tearDown(() async {
    service.dispose();
    await client.dispose();
  });

  test(
    'RPC carries the captured account ID and revision for atomic authorization',
    () async {
      final saved = await service.write('alice', {'version': 1}, 0);
      expect(saved.revision, 1);
      final request = requests.single;
      expect(request.url.path, '/rest/v1/rpc/save_kanji_progress_backup');
      expect(jsonDecode(request.body), {
        'snapshot': {'version': 1},
        'expected_revision': 0,
        'expected_user_id': 'alice',
      });
      expect(request.headers['authorization'], 'Bearer test-token');
    },
  );
  test(
    'a stale revision is surfaced as a recoverable backup conflict',
    () async {
      status = 409;
      response = {'code': '40001', 'message': 'Backup revision conflict'};
      await expectLater(
        service.write('alice', {'version': 1}, 0),
        throwsA(isA<BackupConflict>()),
      );
    },
  );
  test(
    'wrong account requests are rejected before sending learning data',
    () async {
      await expectLater(
        service.write('bob', {'version': 1}, 0),
        throwsStateError,
      );
      await expectLater(service.read('bob'), throwsStateError);
      expect(requests, isEmpty);
    },
  );
  test('read filters explicitly by the signed-in account in addition to server RLS', () async {
    final saved = await service.read('alice');
    expect(saved!.revision, 1);
    expect(requests.single.url.queryParameters['user_id'], 'eq.alice');
  });
}
