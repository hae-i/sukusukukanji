import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../data/models/kanji.dart';
import '../../widgets/content_layout.dart';
import '../../widgets/kanji_content.dart';
import 'kanji_list_screen.dart';

class KanjiDetailScreen extends StatefulWidget {
  const KanjiDetailScreen({super.key, required this.kanji, this.controller});
  final Kanji kanji;
  final AppController? controller;
  @override
  State<KanjiDetailScreen> createState() => _KanjiDetailScreenState();
}

class _KanjiDetailScreenState extends State<KanjiDetailScreen> {
  bool _saving = false;
  String? _error;
  Future<void> _add() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller!.addReview(widget.kanji);
    } catch (_) {
      if (mounted) setState(() => _error = '복습 목록을 저장하지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.controller?.progress.kanji[widget.kanji.id];
    return Scaffold(
      appBar: AppBar(title: const Text('한자 살펴보기')),
      body: SafeArea(
        child: ContentLayout(
          children: [
            KanjiContent(kanji: widget.kanji, controller: widget.controller),
            if (widget.controller != null) ...[
              const SizedBox(height: 24),
              Text('내 학습 상태 · ${masteryLabel(progress)}'),
              if (progress != null)
                Text(
                  '정답 ${progress.correctCount}회 · 오답 ${progress.wrongCount}회',
                ),
              const SizedBox(height: 12),
              if (_error != null) Text(_error!),
              FilledButton.tonal(
                onPressed: _saving || (progress?.needsReview ?? false)
                    ? null
                    : _add,
                child: Text(
                  _saving
                      ? '저장 중…'
                      : progress?.needsReview ?? false
                      ? '복습에 추가됨'
                      : '복습에 추가',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
