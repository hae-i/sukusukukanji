import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../data/services/progress_policy.dart';
import '../../widgets/content_layout.dart';
import '../../widgets/plant_mark.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onStudy,
    required this.onReview,
    required this.onGrades,
  });
  final AppController controller;
  final VoidCallback onStudy, onReview, onGrades;
  @override
  Widget build(BuildContext context) {
    final grade = controller.currentGrade;
    final learned = AppController.gradePolicy.learnedCount(
      grade,
      controller.catalog!,
      controller.progress,
    );
    final required = grade.requiredKanjiCount;
    final text = Theme.of(context).textTheme;
    final last = controller.progress.lastStudyDate;
    final todayDone =
        last != null &&
        ProgressPolicy.calendarDay(last) ==
            ProgressPolicy.calendarDay(controller.now());
    return ContentLayout(
      children: [
        Text(
          '연속 ${ProgressPolicy.visibleStreak(controller.progress, controller.now())}일',
          style: text.labelLarge,
        ),
        const SizedBox(height: 12),
        Text(
          todayDone ? '오늘도 한 뼘 자랐어요!' : '오늘도 한자 5분만!',
          style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 28),
        SectionCard(
          color: const Color(0xFFEAF0E3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('일본 초등학교 한자'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PlantMark(stage: grade.plantStage, size: 104),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(grade.nameKo, style: text.headlineLarge),
                      Text(grade.stageNameKo),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(required == null ? '다음 과정 준비 중' : '$learned / $required자'),
              if (required != null) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (learned / required).clamp(0, 1),
                  minHeight: 8,
                  semanticsLabel: '${grade.nameKo} 학습 진행률',
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('오늘의 학습', style: text.titleLarge),
              const SizedBox(height: 12),
              if (controller.nextLesson.isNotEmpty) ...[
                Text('새 한자 ${controller.nextLesson.length}개 · 내 속도로 차근차근'),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onStudy,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(todayDone ? '다음 한자 배우기' : '오늘의 한자 배우기'),
                ),
              ] else
                const Text('준비된 한자를 모두 배웠어요.\n다음 콘텐츠를 기다리는 동안 배운 한자를 복습해 보세요.'),
            ],
          ),
        ),
        if (controller.reviewCount > 0) ...[
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '헷갈리는 한자 ${controller.reviewCount}개',
                  style: text.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text('한 번에 최대 5자씩 다시 연결해요.'),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: onReview,
                  child: const Text('복습하기'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onGrades,
          icon: const Icon(Icons.eco_outlined),
          label: const Text('학년별 성장 과정'),
        ),
        const SizedBox(height: 24),
        const Text('하루 5분, 무럭무럭 자라는 한자', textAlign: TextAlign.center),
      ],
    );
  }
}
