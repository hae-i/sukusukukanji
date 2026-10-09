import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../data/models/kanji.dart';
import '../../data/models/progress.dart';
import '../../widgets/content_layout.dart';
import '../../widgets/favorite_button.dart';

String masteryLabel(KanjiProgress? progress) =>
    switch (progress?.status ?? KanjiMasteryStatus.newKanji) {
      KanjiMasteryStatus.newKanji => '처음 만나요',
      KanjiMasteryStatus.learning => '학습 중',
      KanjiMasteryStatus.familiar => '익숙해요',
      KanjiMasteryStatus.mastered => '잘 알아요',
    };

class KanjiListScreen extends StatefulWidget {
  const KanjiListScreen({
    super.key,
    required this.controller,
    required this.onSelect,
  });
  final AppController controller;
  final ValueChanged<Kanji> onSelect;
  @override
  State<KanjiListScreen> createState() => _KanjiListScreenState();
}

class _KanjiListScreenState extends State<KanjiListScreen> {
  int _filter = 0;
  @override
  Widget build(BuildContext context) {
    final items = widget.controller.catalog!.kanji.where((k) {
      final p = widget.controller.progress.kanji[k.id];
      return switch (_filter) {
        1 => p?.firstStudiedAt != null,
        2 => p?.needsReview ?? false,
        3 => widget.controller.progress.favoriteKanjiIds.contains(k.id),
        _ => true,
      };
    }).toList();
    return ContentLayout(
      children: [
        Text(
          '조금씩 익숙해지는 내 한자',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < 4; i++)
              ChoiceChip(
                label: Text(['전체', '배운 한자', '헷갈리는 한자', '즐겨찾기'][i]),
                selected: _filter == i,
                onSelected: (_) => setState(() => _filter = i),
              ),
          ],
        ),
        const SizedBox(height: 24),
        if (items.isEmpty)
          Text(
            _filter == 3
                ? '별을 눌러 즐겨찾는 한자를 모아 보세요.'
                : _filter == 2
                ? '복습할 한자가 없어요. 잘하고 있어요!'
                : '아직 배운 한자가 없어요. 첫 학습을 시작해 보세요.',
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final kanji in items)
              SizedBox(
                width: 116,
                child: Card(
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: FavoriteButton(
                          controller: widget.controller,
                          kanji: kanji,
                        ),
                      ),
                      Semantics(
                        button: true,
                        onTap: () => widget.onSelect(kanji),
                        excludeSemantics: true,
                        label:
                            '${kanji.character}, ${kanji.koreanMeanings.join(', ')}, ${kanji.koreanReading}, ${masteryLabel(widget.controller.progress.kanji[kanji.id])}, 상세 보기',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => widget.onSelect(kanji),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Column(
                              children: [
                                Text(
                                  kanji.character,
                                  locale: const Locale('ja'),
                                  style: const TextStyle(fontSize: 40),
                                ),
                                Text(kanji.koreanReading),
                                Text(
                                  widget
                                              .controller
                                              .progress
                                              .kanji[kanji.id]
                                              ?.needsReview ??
                                          false
                                      ? '복습 필요'
                                      : masteryLabel(
                                          widget.controller.progress.kanji[kanji
                                              .id],
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
