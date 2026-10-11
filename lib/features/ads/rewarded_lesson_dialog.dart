import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import 'ad_service.dart';

class RewardedLessonDialog extends StatefulWidget {
  const RewardedLessonDialog({super.key, required this.controller});
  final AppController controller;
  @override
  State<RewardedLessonDialog> createState() => _RewardedLessonDialogState();
}

class _RewardedLessonDialogState extends State<RewardedLessonDialog> {
  bool _busy = false;
  String? _message;
  Future<void> _watch() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (widget.controller.hasPendingReward) {
        await widget.controller.retryPendingRewards();
        if (mounted) Navigator.pop(context, true);
        return;
      }
      final outcome = await widget.controller.ads.showRewarded(
        widget.controller.grantAdReward,
      );
      if (!mounted) return;
      if (outcome == RewardedOutcome.earned) {
        Navigator.pop(context, true);
      } else {
        setState(
          () => _message = outcome == RewardedOutcome.dismissed
              ? '시청 완료 보상을 받지 못했어요. 이용권은 차감되지 않았어요.'
              : '지금 광고를 불러올 수 없어요. 연결을 확인하고 다시 시도해 주세요.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = widget.controller.hasPendingReward
              ? '광고 시청은 완료됐어요. 이용권 저장을 다시 시도해 주세요.'
              : '광고를 표시하지 못했어요. 잠시 후 다시 시도해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('한 레슨 더 배워볼까요?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '오늘 무료 레슨 2개를 모두 열었어요. 광고를 끝까지 시청하고 보상을 받으면 추가 레슨 이용권 1개가 생겨요.',
            ),
            const SizedBox(height: 12),
            const Text('복습은 언제든 무료예요. 내일은 새 레슨 2개를 다시 무료로 열 수 있어요.'),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('나중에'),
        ),
        FilledButton(
          onPressed: _busy ? null : _watch,
          child: Text(
            _busy
                ? '처리 중…'
                : widget.controller.hasPendingReward
                ? '보상 저장 다시 시도'
                : '광고 보고 레슨 1개 열기',
          ),
        ),
      ],
    ),
  );
}
