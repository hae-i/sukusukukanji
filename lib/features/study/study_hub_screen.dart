import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../widgets/content_layout.dart';

class StudyHubScreen extends StatelessWidget {
  const StudyHubScreen({
    super.key,
    required this.controller,
    required this.onStart,
  });
  final AppController controller;
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) {
    final lessons = controller.catalog!.lessonsForGrade(
      controller.currentGrade.grade,
    );
    final next = controller.nextLesson.firstOrNull?.lessonId;
    return ContentLayout(
      children: [
        Text(
          '${controller.currentGrade.nameKo} · 한 번에 5자',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text('한자를 살펴보고 짧은 퀴즈로 연결을 확인해요.'),
        const SizedBox(height: 24),
        if (lessons.isEmpty) const Text('이 학년의 콘텐츠는 준비 중이에요.'),
        for (final lesson in lessons.entries) ...[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Lesson ${lesson.key}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  lesson.value.map((k) => k.character).join(' '),
                  locale: const Locale('ja'),
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(height: 12),
                if (lesson.value.every(
                  (k) =>
                      controller.progress.kanji[k.id]?.firstStudiedAt != null,
                ))
                  const Text('✓ 학습 완료')
                else if (lesson.key == next)
                  FilledButton(onPressed: onStart, child: const Text('이어서 배우기'))
                else
                  const Text('앞 레슨부터 차근차근 배워요.'),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (controller.currentGrade.requiredKanjiCount != null)
          Text(
            '현재 ${controller.catalog!.forGrade(controller.currentGrade.grade).length}자가 준비되어 있어요. 전체 과정은 ${controller.currentGrade.requiredKanjiCount}자예요.',
          ),
      ],
    );
  }
}
