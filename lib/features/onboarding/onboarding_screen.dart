import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../widgets/plant_mark.dart';
import '../../widgets/page_dots.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;
  final _pages = PageController();
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) => _pages.animateToPage(
    page,
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
  );
  String? _error;
  Future<void> _finish() async {
    setState(() => _error = null);
    try {
      await widget.controller.completeOnboarding();
    } catch (_) {
      if (mounted) setState(() => _error = '시작 설정을 저장하지 못했어요. 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.controller.catalog!;
    final first = catalog.kanji.first;
    final connected = catalog.kanji.firstWhere(
      (k) => k.koreanConnections.isNotEmpty,
      orElse: () => first,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('すくすく漢字')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: 3,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, page) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          Text(switch (page) {
                            0 => '한자를 외우지 말고\n연결해서 배워보세요.',
                            1 => '이미 알고 있는 한국어와\n일본어 한자를 연결해요.',
                            _ => '일본 초등학교 1학년부터\n한 학년씩 자라보세요.',
                          }, style: Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 32),
                          if (page == 0) ...[
                            Text(
                              first.character,
                              locale: const Locale('ja'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 112),
                            ),
                            Text(
                              [
                                first.koreanReading,
                                ...first.onyomi.take(1),
                                ...first.kunyomi.take(1),
                              ].join(' / '),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ] else if (page == 1) ...[
                            Text(
                              connected.character,
                              locale: const Locale('ja'),
                              style: const TextStyle(fontSize: 88),
                            ),
                            if (connected.koreanConnections.isNotEmpty) ...[
                              Text(
                                '${connected.koreanConnections.first.wordKo}(${connected.koreanConnections.first.hanja})',
                                style: const TextStyle(fontSize: 28),
                              ),
                              Text(
                                connected.koreanConnections.first.note ??
                                    '익숙한 한국어와 연결해 보세요.',
                              ),
                            ],
                          ] else ...[
                            for (final grade in catalog.grades.take(3))
                              ListTile(
                                leading: PlantMark(
                                  stage: grade.plantStage,
                                  size: 48,
                                ),
                                title: Text(grade.nameKo),
                                subtitle: Text(grade.stageNameKo),
                                trailing: grade == catalog.grades.first
                                    ? null
                                    : const Icon(Icons.lock_outline),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            PageDots(index: _page, count: 3),
            const SizedBox(height: 20),
            if (_error != null) ...[Text(_error!), const SizedBox(height: 12)],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: widget.controller.savingSettings
                      ? null
                      : _page == 2
                      ? _finish
                      : () => _go(_page + 1),
                  child: Text(
                    widget.controller.savingSettings
                        ? '저장 중…'
                        : _page == 2
                        ? '1학년 시작하기'
                        : '다음',
                  ),
                ),
              ),
            ),
            Visibility(
              visible: _page > 0,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: TextButton(
                onPressed: widget.controller.savingSettings
                    ? null
                    : () => _go(_page - 1),
                child: const Text('이전'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
