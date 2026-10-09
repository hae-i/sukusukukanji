import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../widgets/content_layout.dart';

class StudyHubScreen extends StatefulWidget {
  const StudyHubScreen({
    super.key,
    required this.controller,
    required this.onStart,
    required this.onReview,
    this.active = true,
  });
  final bool active;
  final AppController controller;
  final VoidCallback onStart;
  final void Function(int grade, int lesson) onReview;
  @override
  State<StudyHubScreen> createState() => _StudyHubScreenState();
}

class _StudyHubScreenState extends State<StudyHubScreen> {
  int? _selectedGrade;
  final _scroll = ScrollController();
  final _lessonKeys = <String, GlobalKey>{};
  String? _lastTarget;
  bool _wasActive = false;

  void _showNextLesson(int grade, int? next) {
    final target = next == null ? null : '$grade-$next';
    final shouldScroll =
        widget.active && (!_wasActive || target != _lastTarget);
    _wasActive = widget.active;
    _lastTarget = target;
    if (!shouldScroll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active || !_scroll.hasClients) return;
      final context = _lessonKeys[target]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.05,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

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
    _showNextLesson(grade.grade, next);
    return ContentLayout(
      controller: _scroll,
      children: [
        Text(
          grade.nameKo,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
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
        const SizedBox(height: 4),
        const Text('한자를 살펴보고 짧은 퀴즈로 연결을 확인해요.'),
        const SizedBox(height: 24),
        for (final lesson in lessons.entries) ...[
          SectionCard(
            key: _lessonKeys.putIfAbsent(
              '${grade.grade}-${lesson.key}',
              GlobalKey.new,
            ),
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
                  style: const TextStyle(
                    fontFamily: 'NotoSansJP',
                    fontSize: 32,
                  ),
                ),
                const SizedBox(height: 12),
                if (lesson.value.every(
                  (k) =>
                      controller.progress.kanji[k.id]?.firstStudiedAt != null,
                ))
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE3ECDD),
                      foregroundColor: const Color(0xFF355D43),
                    ),
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
