import 'package:flutter/material.dart';

import '../../data/models/course_allocation.dart';
import '../../data/models/grade_theme.dart';

class CourseAllocationScreen extends StatelessWidget {
  const CourseAllocationScreen({
    super.key,
    required this.grade,
    required this.allocation,
  });
  final GradeTheme grade;
  final CourseAllocation allocation;

  void _showSources(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('중학교 과정 배정 기준'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(allocation.noteKo),
            const SizedBox(height: 16),
            Text(allocation.orderingKo),
            for (final reference in allocation.references) ...[
              const SizedBox(height: 16),
              Text(reference.label),
              SelectableText(reference.url),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(grade.nameKo),
      actions: [
        IconButton(
          tooltip: '배정 기준과 출처',
          onPressed: () => _showSources(context),
          icon: const Icon(Icons.info_outline),
        ),
      ],
    ),
    body: SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${allocation.characters.length}자 · ${allocation.characters.length ~/ 5}개 레슨',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(allocation.noteKo),
                  const SizedBox(height: 12),
                  const Text('배정 한자 목록이에요. 한국어 뜻과 대표 읽기 검수 후 학습이 열려요.'),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList.builder(
              itemCount: allocation.characters.length ~/ 5,
              itemBuilder: (context, index) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lesson ${index + 1}'),
                      const SizedBox(height: 8),
                      Text(
                        allocation.characters.skip(index * 5).take(5).join(' '),
                        locale: const Locale('ja'),
                        style: const TextStyle(
                          fontFamily: 'NotoSansJP',
                          fontSize: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
