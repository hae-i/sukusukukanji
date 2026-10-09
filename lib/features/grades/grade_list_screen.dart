import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../widgets/content_layout.dart';
import '../../widgets/plant_mark.dart';

class GradeListScreen extends StatelessWidget {
  const GradeListScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('한 학년씩, 무럭무럭')),
    body: SafeArea(
      child: ContentLayout(
        children: [
          const Text('작은 새싹에서 한 그루의 나무까지.\n일본 초등학교 한자를 한 학년씩 만나요.'),
          const SizedBox(height: 24),
          for (final grade in controller.catalog!.grades) ...[
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
                    const Text('잠김 · 앞 학년을 먼저 완료해 주세요.')
                  else if (grade.contentAsset == null)
                    const Text('해금됨 · 콘텐츠 준비 중')
                  else
                    Text(
                      '${AppController.gradePolicy.learnedCount(grade, controller.catalog!, controller.progress)} / ${grade.requiredKanjiCount}자 · 진행 중',
                    ),
                  if (grade.requiredKanjiCount != null) ...[
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
