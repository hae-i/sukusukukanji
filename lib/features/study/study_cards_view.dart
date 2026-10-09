import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../widgets/content_layout.dart';
import '../../widgets/kanji_content.dart';
import '../../widgets/page_dots.dart';
import 'session_controller.dart';

class StudyCardsView extends StatefulWidget {
  const StudyCardsView({
    super.key,
    required this.controller,
    this.appController,
  });
  final SessionController controller;
  final AppController? appController;
  @override
  State<StudyCardsView> createState() => _StudyCardsViewState();
}

class _StudyCardsViewState extends State<StudyCardsView> {
  late final PageController _pages;
  @override
  void initState() {
    super.initState();
    _pages = PageController(initialPage: widget.controller.cardIndex);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (widget.controller.cardIndex ==
        widget.controller.session.kanji.length - 1) {
      widget.controller.nextCard();
      return;
    }
    _pages.animateToPage(
      widget.controller.cardIndex + 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          '한자 ${widget.controller.cardIndex + 1} / ${widget.controller.session.kanji.length}',
        ),
      ),
      Expanded(
        child: PageView.builder(
          key: const ValueKey('study-pages'),
          controller: _pages,
          itemCount: widget.controller.session.kanji.length,
          onPageChanged: widget.controller.showCard,
          itemBuilder: (context, index) => ContentLayout(
            children: [
              KanjiContent(
                kanji: widget.controller.session.kanji[index],
                controller: widget.appController,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _next,
                child: Text(
                  index == widget.controller.session.kanji.length - 1
                      ? '퀴즈 시작하기'
                      : '알겠어요 →',
                ),
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 8),
        child: PageDots(
          index: widget.controller.cardIndex,
          count: widget.controller.session.kanji.length,
        ),
      ),
    ],
  );
}
