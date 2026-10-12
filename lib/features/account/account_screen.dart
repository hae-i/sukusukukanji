import 'package:flutter/material.dart';

import '../../widgets/content_layout.dart';
import 'backup_controller.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.controller});
  final BackupController controller;

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String description,
    String action,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(child: Text(description)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final cloud = controller;
      final saved = cloud.remote;
      return Scaffold(
        appBar: AppBar(title: const Text('계정과 진도 백업')),
        body: SafeArea(
          child: ContentLayout(
            children: [
              const Text(
                '기기를 바꿔도 이어서 배워요',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                '로그인 없이도 학습할 수 있어요. Google 계정을 연결하고 백업을 시작하면 학습 기록·복습 상태·즐겨찾기를 저장해요.',
              ),
              const SizedBox(height: 20),
              if (!cloud.service.configured)
                const SectionCard(
                  child: Text(
                    '계정 연결을 준비 중이에요. 현재 진도는 이 기기에 안전하게 저장돼요. 앱을 삭제하면 기기 기록이 사라질 수 있어요.',
                  ),
                )
              else if (cloud.userId == null) ...[
                FilledButton.icon(
                  onPressed: cloud.busy ? null : cloud.signIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Google 계정으로 연결'),
                ),
                const SizedBox(height: 8),
                const Text('브라우저에서 Google 로그인 후 앱으로 돌아와 주세요.'),
              ] else ...[
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cloud.service.email ?? 'Google 계정 연결됨',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(cloud.automatic ? '자동 백업 켜짐' : '사용할 기록을 선택해 주세요'),
                      if (saved != null) ...[
                        const SizedBox(height: 8),
                        Text('클라우드에서 배운 한자 ${cloud.remoteLearned}자'),
                        Text(
                          '마지막 백업: ${saved.updatedAt.toLocal().toString().substring(0, 16)}',
                        ),
                      ] else if (cloud.checked)
                        const Text('아직 클라우드 백업이 없어요.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: !cloud.canChoose
                      ? null
                      : () async {
                          if (!cloud.automatic &&
                              !await _confirm(
                                context,
                                '이 기기 기록을 백업할까요?',
                                '현재 기기의 기록을 이 Google 계정에 연결하고 이후 학습을 자동 백업해요. 기존 클라우드 기록이 있다면 이 기기 기록으로 교체해요.',
                                '백업 시작',
                              )) {
                            return;
                          }
                          await cloud.backupNow();
                        },
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('이 기기 기록 백업'),
                ),
                OutlinedButton.icon(
                  onPressed: !cloud.canChoose || saved == null
                      ? null
                      : () async {
                          if (await _confirm(
                            context,
                            '클라우드 진도를 복원할까요?',
                            '이 기기의 학습 기록·복습 상태·즐겨찾기를 클라우드 기록으로 교체해요. 교체한 기기 기록은 되돌릴 수 없어요. 광고 이용권과 구매 권한은 변경하지 않아요.',
                            '복원',
                          )) {
                            await cloud.restore();
                          }
                        },
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('클라우드 기록 복원'),
                ),
                TextButton(
                  onPressed: cloud.busy ? null : cloud.refresh,
                  child: const Text('백업 확인 / 다시 시도'),
                ),
                const SizedBox(height: 12),
                const Text(
                  '로그아웃해도 이 기기의 기록은 남아요. 다른 계정을 연결하면 기록을 연결할지 다시 선택해요.',
                ),
                TextButton(
                  onPressed: cloud.busy ? null : cloud.signOut,
                  child: const Text('로그아웃'),
                ),
                TextButton(
                  onPressed: cloud.busy
                      ? null
                      : () async {
                          if (await _confirm(
                            context,
                            '계정과 클라우드 기록을 삭제할까요?',
                            '스쿠스쿠칸지 계정과 백업을 영구 삭제해요. Google 계정 자체와 이 기기의 학습 기록은 삭제하지 않아요.',
                            '계정 삭제',
                          )) {
                            await cloud.deleteAccount();
                          }
                        },
                  child: const Text('계정 및 클라우드 기록 삭제'),
                ),
              ],
              if (cloud.busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: '계정 및 백업 처리 중',
                    ),
                  ),
                ),
              if (cloud.message != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(cloud.message!),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                '진도 백업에는 구매 내역, 광고 이용권, 앱 아이콘 선택은 포함하지 않아요. 구매 복원은 Google Play 계정으로 별도 처리해요.',
              ),
            ],
          ),
        ),
      );
    },
  );
}
