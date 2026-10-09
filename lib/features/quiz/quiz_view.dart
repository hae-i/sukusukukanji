import 'package:flutter/material.dart';

import '../study/session_controller.dart';

class QuizView extends StatelessWidget {
  const QuizView({super.key, required this.controller});
  final SessionController controller;
  @override
  Widget build(BuildContext context) {
    final question = controller.question;
    final selected = controller.selectedAnswer;
    final answered = selected != null;
    final correct = answered && question.options[selected] == question.answer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '퀴즈 ${controller.questionIndex + 1} / ${controller.session.questions.length}',
        ),
        const SizedBox(height: 20),
        Text(
          question.prompt,
          textAlign: TextAlign.center,
          locale: const Locale('ja'),
          style: const TextStyle(fontSize: 64),
        ),
        const SizedBox(height: 16),
        Text(
          question.instruction,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < question.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton(
              key: ValueKey('option-$i'),
              onPressed: answered ? null : () => controller.answer(i),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 56),
                alignment: Alignment.centerLeft,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${i + 1}. ${question.options[i]}${selected == i && question.options[i] != question.answer ? ' · 선택한 답' : ''}',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  if (answered && question.options[i] == question.answer)
                    const Icon(
                      Icons.check,
                      color: Colors.red,
                      semanticLabel: '정답 보기',
                    ),
                ],
              ),
            ),
          ),
        if (answered) ...[
          TweenAnimationBuilder<double>(
            key: ValueKey('feedback-${question.id}'),
            tween: Tween(begin: 1, end: 0),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            builder: (context, value, child) => Transform.translate(
              offset: Offset(0, 28 * value),
              child: child,
            ),
            child: Semantics(
              liveRegion: true,
              child: Text(
                correct ? '✓ 정답이에요!' : '✕ 아쉬워요!',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(question.explanation),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: controller.nextQuestion,
            child: Text(
              controller.questionIndex ==
                      controller.session.questions.length - 1
                  ? '결과 보기'
                  : '다음 문제',
            ),
          ),
        ],
      ],
    );
  }
}
