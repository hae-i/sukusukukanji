import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../widgets/content_layout.dart';
import '../../widgets/plant_mark.dart';
import 'course_allocation_screen.dart';

class GradeListScreen extends StatelessWidget {
  const GradeListScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('한 학년씩, 무럭무럭')),
    body: SafeArea(
      child: ContentLayout(
        children: [
          const Text('초등학교 한자부터 중학교 상용한자까지,\n한 학년씩 연결하며 배워요.'),
          const SizedBox(height: 24),
          for (final grade in controller.catalog!.grades) ...[
            if (grade.grade == controller.catalog!.grades.first.grade ||
                grade.schoolLevel !=
                    controller
                        .catalog!
                        .grades[controller.catalog!.grades.indexOf(grade) - 1]
                        .schoolLevel) ...[
              Text(
                grade.schoolNameKo,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
            ],
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PlantMark(stage: grade.plantStage),
                  Text(
                    '${grade.nameKo} · ${grade.stageNameKo}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (controller.progress.completedGrades.contains(grade.grade))
                    const Text('✓ 졸업했어요!')
                  else if (!AppController.gradePolicy.isUnlocked(
                    grade,
                    controller.catalog!,
                    controller.progress,
                  ))
                    Text('잠김 · ${grade.requiredKanjiCount}자')
                  else if (grade.contentAsset == null)
                    const Text('해금됨 · 콘텐츠 준비 중')
                  else
                    Text(
                      '${AppController.gradePolicy.learnedCount(grade, controller.catalog!, controller.progress)} / ${grade.requiredKanjiCount}자 · 진행 중',
                    ),
                  if (grade.contentAsset != null &&
                      grade.requiredKanjiCount != null) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value:
                          (AppController.gradePolicy.learnedCount(
                                    grade,
                                    controller.catalog!,
                                    controller.progress,
                                  ) /
                                  grade.requiredKanjiCount!)
                              .clamp(0, 1),
                      semanticsLabel: '${grade.nameKo} 진행률',
                    ),
                  ],
                  if (controller.catalog!.allocations[grade.grade]
                      case final allocation?) ...[
                    const SizedBox(height: 12),
                    const Text('앱 자체 배정 · 학습 콘텐츠 준비 중'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CourseAllocationScreen(
                            grade: grade,
                            allocation: allocation,
                          ),
                        ),
                      ),
                      child: const Text('배정 한자 보기'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    ),
  );
}
