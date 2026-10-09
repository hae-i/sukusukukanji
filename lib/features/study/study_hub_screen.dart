import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../widgets/content_layout.dart';

class StudyHubScreen extends StatefulWidget {
  const StudyHubScreen({
    super.key,
    required this.controller,
    required this.onStart,
    required this.onReview,
  });
  final AppController controller;
  final VoidCallback onStart;
  final void Function(int grade, int lesson) onReview;
  @override
  State<StudyHubScreen> createState() => _StudyHubScreenState();
}

class _StudyHubScreenState extends State<StudyHubScreen> {
  int? _selectedGrade;
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final available = controller.catalog!.grades
        .where(
          (g) =>
              controller.catalog!.forGrade(g.grade).isNotEmpty &&
              AppController.gradePolicy.isUnlocked(
                g,
                controller.catalog!,
                controller.progress,
              ),
        )
        .toList();
    if (available.isEmpty) {
      return const ContentLayout(children: [Text('이 학년의 콘텐츠는 준비 중이에요.')]);
    }
    final grade = available.firstWhere(
      (g) => g.grade == (_selectedGrade ?? controller.currentGrade.grade),
      orElse: () => available.first,
    );
    final lessons = controller.catalog!.lessonsForGrade(grade.grade);
    final next = AppController.planner
        .nextLesson(controller.catalog!, controller.progress, grade.grade)
        .firstOrNull
        ?.lessonId;
    return ContentLayout(
      children: [
        Text(
          '${grade.nameKo} · 한 번에 5자',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (available.length > 1)
          DropdownButton<int>(
            value: grade.grade,
            items: [
              for (final g in available)
                DropdownMenuItem(value: g.grade, child: Text(g.nameKo)),
            ],
            onChanged: (value) => setState(() => _selectedGrade = value),
          ),
        const SizedBox(height: 12),
        const Text('한자를 살펴보고 짧은 퀴즈로 연결을 확인해요.'),
        const SizedBox(height: 24),
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
                  FilledButton(
                    onPressed: () => widget.onReview(grade.grade, lesson.key),
                    child: const Text('복습하기'),
                  )
                else if (lesson.key == next)
                  FilledButton(
                    onPressed: widget.onStart,
                    child: const Text('이어서 배우기'),
                  )
                else
                  FilledButton(
                    onPressed: null,
                    child: Text('Lesson ${lesson.key - 1} 학습 필요'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
