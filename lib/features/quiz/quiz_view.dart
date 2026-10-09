import 'package:flutter/material.dart';

import '../study/session_controller.dart';
import '../../widgets/mixed_language_text.dart';
import '../../widgets/content_layout.dart';

class QuizView extends StatelessWidget {
  const QuizView({super.key, required this.controller});
  final SessionController controller;
  @override
  Widget build(BuildContext context) {
    final question = controller.question;
    final selected = controller.selectedAnswer;
    final answered = selected != null;
    final correct = answered && question.options[selected] == question.answer;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          ContentLayout(
            key: ValueKey(question.id),
            children: [
              Text(
                '퀴즈 ${controller.questionIndex + 1} / ${controller.session.questions.length}',
              ),
              const SizedBox(height: 20),
              Text(
                question.prompt,
                textAlign: TextAlign.center,
                locale: const Locale('ja'),
                style: const TextStyle(fontFamily: 'NotoSansJP', fontSize: 64),
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
                          child: MixedLanguageText(
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
            ],
          ),
          if (answered)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: TweenAnimationBuilder<double>(
                key: ValueKey('feedback-${question.id}'),
                tween: Tween(begin: 1, end: 0),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                builder: (context, value, child) => FractionalTranslation(
                  translation: Offset(0, value),
                  child: child,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * .65,
                  ),
                  child: _QuizFeedback(
                    controller: controller,
                    correct: correct,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuizFeedback extends StatelessWidget {
  const _QuizFeedback({required this.controller, required this.correct});
  final SessionController controller;
  final bool correct;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('quiz-feedback-panel'),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: correct ? const Color(0xFFDCEBDD) : const Color(0xFFFBE4DF),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      border: Border.all(
        color: correct ? const Color(0xFF90B79A) : const Color(0xFFD8A298),
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x20000000),
          blurRadius: 16,
          offset: Offset(0, -4),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            primary: false,
            child: Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    correct ? '✓ 정답이에요!' : '✕ 아쉬워요!',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  MixedLanguageText(controller.question.explanation),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: controller.nextQuestion,
          child: Text(
            controller.questionIndex == controller.session.questions.length - 1
                ? '결과 보기'
                : '다음 문제',
          ),
        ),
      ],
    ),
  );
}
