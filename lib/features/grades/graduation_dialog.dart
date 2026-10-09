import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../data/models/grade_theme.dart';
import '../../widgets/plant_mark.dart';

class GraduationDialog extends StatefulWidget {
  const GraduationDialog({
    super.key,
    required this.controller,
    required this.grade,
  });
  final AppController controller;
  final GradeTheme grade;
  @override
  State<GraduationDialog> createState() => _GraduationDialogState();
}

class _GraduationDialogState extends State<GraduationDialog> {
  bool _saving = false;
  String? _error;
  Future<void> _continue() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.acknowledgeGraduation(widget.grade.grade);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '확인을 저장하지 못했어요. 다시 시도해 주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grades = widget.controller.catalog!.grades;
    final index = grades.indexOf(widget.grade);
    final next = index + 1 < grades.length ? grades[index + 1] : null;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text('${widget.grade.nameKo}을 졸업했어요!'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlantMark(stage: (next ?? widget.grade).plantStage, size: 120),
              Text('${widget.grade.requiredKanjiCount}개의 한자를 만났어요.'),
              if (next != null) ...[
                const SizedBox(height: 12),
                Text('${next.stageNameKo}으로 자랐어요.\n${next.nameKo} 과정이 열렸어요.'),
                if (next.contentAsset == null)
                  const Text('다음 학년 콘텐츠는 준비 중이에요.'),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: _saving ? null : _continue,
            child: Text(_saving ? '저장 중…' : '성장 과정 보기'),
          ),
        ],
      ),
    );
  }
}
