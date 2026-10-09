import 'package:flutter/material.dart';

import '../../data/models/study_session.dart';
import '../../widgets/content_layout.dart';
import '../../widgets/kanji_source_button.dart';
import '../../app/app_controller.dart';
import 'study_cards_view.dart';
import '../quiz/quiz_view.dart';
import 'session_controller.dart';

class StudyFlowScreen extends StatefulWidget {
  const StudyFlowScreen({
    super.key,
    required this.session,
    required this.onSave,
    this.canReview,
    this.appController,
  });
  final StudySession session;
  final AppController? appController;
  final Future<void> Function(CompletedSession) onSave;
  final bool Function()? canReview;
  @override
  State<StudyFlowScreen> createState() => _StudyFlowScreenState();
}

class _StudyFlowScreenState extends State<StudyFlowScreen> {
  late final SessionController _controller;
  @override
  void initState() {
    super.initState();
    _controller = SessionController(widget.session, save: widget.onSave);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_controller.stage == SessionStage.saving) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('학습을 잠시 멈출까요?'),
        content: const Text('아직 완료하지 않은 이번 학습은 저장되지 않아요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속하기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final stage = _controller.stage;
      return PopScope(
        canPop: stage == SessionStage.result,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.session.isReview ? '한자 복습' : '오늘의 한자'),
            actions: [
              if (stage == SessionStage.cards)
                KanjiSourceButton(
                  kanji: widget.session.kanji[_controller.cardIndex],
                ),
            ],
          ),
          body: SafeArea(
            bottom: stage != SessionStage.quiz,
            child: stage == SessionStage.cards
                ? StudyCardsView(
                    controller: _controller,
                    appController: widget.appController,
                  )
                : stage == SessionStage.quiz
                ? QuizView(controller: _controller)
                : ContentLayout(
                    key: ValueKey(
                      '$stage:${_controller.cardIndex}:${_controller.questionIndex}',
                    ),
                    children: switch (stage) {
                      SessionStage.cards => [],
                      SessionStage.quiz => [],
                      SessionStage.saving => [
                        const Center(child: CircularProgressIndicator()),
                        const SizedBox(height: 20),
                        const Text('학습 기록을 저장하고 있어요.'),
                      ],
                      SessionStage.saveError => [
                        const Text('기록을 저장하지 못했어요. 답안은 그대로 있어요.'),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _controller.persist,
                          child: const Text('저장 다시 시도'),
                        ),
                      ],
                      SessionStage.result => [
                        Text(
                          '오늘 공부 끝!',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '${widget.session.isReview ? '복습한' : '오늘 배운'} 한자 ${widget.session.kanji.length}개',
                        ),
                        Text(
                          '정답 ${_controller.completed!.correctCount} / ${widget.session.questions.length}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.session.kanji
                              .map((k) => k.character)
                              .join(' '),
                          style: const TextStyle(
                            fontFamily: 'NotoSansJP',
                            fontSize: 36,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _controller.completed!.wrongKanjiIds.isEmpty
                              ? '모두 잘 기억했어요!'
                              : '헷갈리는 한자',
                        ),
                        if (_controller.completed!.wrongKanjiIds.isNotEmpty)
                          Text(
                            widget.session.kanji
                                .where(
                                  (k) => _controller.completed!.wrongKanjiIds
                                      .contains(k.id),
                                )
                                .map((k) => k.character)
                                .join(' '),
                            style: const TextStyle(
                              fontFamily: 'NotoSansJP',
                              fontSize: 32,
                            ),
                          ),
                        if (widget.session.isReview)
                          const Text('같은 한자의 복습을 2회 연속 모두 맞히면 복습 목록에서 빠져요.'),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('오늘은 여기까지'),
                        ),
                        if (widget.canReview?.call() ??
                            _controller.completed!.wrongKanjiIds.isNotEmpty)
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('한 번 더 복습하기'),
                          ),
                      ],
                    },
                  ),
          ),
        ),
      );
    },
  );
}
