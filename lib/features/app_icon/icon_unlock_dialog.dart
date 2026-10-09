import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../data/models/grade_theme.dart';
import '../../widgets/plant_mark.dart';

class IconUnlockDialog extends StatefulWidget {
  const IconUnlockDialog({
    super.key,
    required this.controller,
    required this.grade,
  });
  final AppController controller;
  final GradeTheme grade;
  @override
  State<IconUnlockDialog> createState() => _IconUnlockDialogState();
}

class _IconUnlockDialogState extends State<IconUnlockDialog> {
  bool _busy = false;
  String? _error;
  Future<void> _finish(bool change) async {
    setState(() => _busy = true);
    try {
      if (change) {
        final applied = await widget.controller.selectIcon(
          widget.grade.iconKey,
        );
        if (mounted && !applied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('선택을 저장했어요. 이 환경에서는 기기 아이콘 변경을 지원하지 않아요.'),
            ),
          );
        }
      }
      await widget.controller.acknowledgeIcon(widget.grade.iconKey);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '아이콘 설정을 저장하지 못했어요. 다시 시도해 주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('새로운 아이콘이 열렸어요!'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlantMark(stage: widget.grade.plantStage, size: 100),
            Text('${widget.grade.nameKo} ${widget.grade.stageNameKo}'),
            const SizedBox(height: 12),
            const Text('원하는 때 설정에서 바꿀 수 있어요.'),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => _finish(false),
          child: const Text('나중에'),
        ),
        FilledButton(
          onPressed: _busy ? null : () => _finish(true),
          child: Text(_busy ? '저장 중…' : '지금 바꾸기'),
        ),
        if (_error != null)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('계속 공부하기'),
          ),
      ],
    ),
  );
}
