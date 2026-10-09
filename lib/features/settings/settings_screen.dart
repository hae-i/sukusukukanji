import 'package:flutter/material.dart';

import '../../widgets/content_layout.dart';
import '../../app/app_controller.dart';
import '../../app/router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('앱 안내')),
    body: SafeArea(
      child: ContentLayout(
        children: [
          ListTile(
            leading: const Icon(Icons.eco_outlined),
            title: const Text('앱 아이콘'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => AppRouter.icons(context, controller),
          ),
          ListTile(
            title: const Text('폰트·오픈소스 라이선스'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'SukuSuku Kanji',
            ),
          ),
          const SizedBox(height: 16),
          const SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'すくすく漢字',
                  style: TextStyle(
                    fontFamily: 'NotoSansJP',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text('스쿠스쿠칸지 · SukuSuku Kanji'),
                SizedBox(height: 16),
                Text('하루 5분, 무럭무럭 자라는 한자'),
                SizedBox(height: 24),
                Text('1학년 한자 80자를 5자씩 연결하며 배워요.'),
                SizedBox(height: 12),
                Text(
                  '학습과 복습, 기록 저장은 인터넷 없이 동작해요. 기록은 이 기기에 저장되며 앱 삭제 시 사라질 수 있어요.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('콘텐츠 출처와 이용 조건', style: TextStyle(fontSize: 20)),
                SizedBox(height: 16),
                SelectableText(
                  '음독·훈독·학년: KANJIDIC2  / kanjiapi.dev\n'
                  '© James William BREEN and The Electronic Dictionary Research and Development Group\n'
                  'https://www.edrdg.org/wiki/index.php/KANJIDIC_Project\n'
                  'https://www.edrdg.org/edrdg/licence.html',
                ),
                SizedBox(height: 16),
                SelectableText(
                  '한국 한자음·뜻·단어 확인: 위키낱말사전 기여자, Wikipedia 기여자\n'
                  '항목별 출처는 한자 상세 화면에서 볼 수 있어요.',
                ),
                SizedBox(height: 16),
                SelectableText(
                  '한자 데이터: CC BY-SA 4.0\n'
                  'https://creativecommons.org/licenses/by-sa/4.0/\n'
                  '대표 읽기를 선별하고, 훈독 표기의 구분점을 제거했으며 한국어 설명과 학습 순서를 덧붙였어요.',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
