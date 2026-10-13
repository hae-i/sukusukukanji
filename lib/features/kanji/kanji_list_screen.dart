import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../data/models/kanji.dart';
import '../../data/models/grade_theme.dart';
import 'kanji_browser.dart';
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
  final _search = TextEditingController();
  KanjiFilter _filter = KanjiFilter.all;
  KanjiSort _sort = KanjiSort.lesson;
  int? _grade;

  bool get _hasFilters =>
      _search.text.isNotEmpty ||
      _grade != null ||
      _filter != KanjiFilter.all ||
      _sort != KanjiSort.lesson;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reset() {
    FocusScope.of(context).unfocus();
    setState(() {
      _search.clear();
      _filter = KanjiFilter.all;
      _sort = KanjiSort.lesson;
      _grade = null;
    });
  }

  Widget _gradePicker() => InputDecorator(
    decoration: const InputDecoration(labelText: '학년'),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        key: const ValueKey('kanji-grade'),
        isExpanded: true,
        isDense: true,
        itemHeight: null,
        value: _grade ?? 0,
        items: [
          const DropdownMenuItem(value: 0, child: Text('모든 학년')),
          for (final grade in widget.controller.catalog!.grades)
            DropdownMenuItem(
              value: grade.grade,
              child: Text(
                '${grade.schoolLevel == SchoolLevel.elementary ? '초등학교 ' : ''}${grade.nameKo}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (value) =>
            setState(() => _grade = value == 0 ? null : value),
      ),
    ),
  );

  Widget _sortPicker() => InputDecorator(
    decoration: const InputDecoration(labelText: '정렬'),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<KanjiSort>(
        key: const ValueKey('kanji-sort'),
        isExpanded: true,
        isDense: true,
        itemHeight: null,
        value: _sort,
        items: [
          for (final sort in KanjiSort.values)
            DropdownMenuItem(
              value: sort,
              child: Text(
                sort.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _sort = value);
        },
      ),
    ),
  );

  String _emptyMessage() {
    if (_grade != null &&
        widget.controller.catalog!.forGrade(_grade!).isEmpty) {
      return '이 학년의 학습 콘텐츠는 준비 중이에요.';
    }
    if (_search.text.trim().isNotEmpty) return '검색 조건에 맞는 한자가 없어요.';
    return switch (_filter) {
      KanjiFilter.favorites => '별을 눌러 즐겨찾는 한자를 모아 보세요.',
      KanjiFilter.review => '복습할 한자가 없어요. 잘하고 있어요!',
      KanjiFilter.learned => '아직 배운 한자가 없어요. 첫 학습을 시작해 보세요.',
      KanjiFilter.all => '표시할 한자가 없어요.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final items = KanjiBrowser.select(
      widget.controller.catalog!.kanji,
      widget.controller.progress,
      query: _search.text,
      grade: _grade,
      filter: _filter,
      sort: _sort,
    );
    return ContentLayout(
      children: [
        TextField(
          key: const ValueKey('kanji-search'),
          controller: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: '한자 검색',
            hintText: '한자 · 뜻 · 읽기 · 단어',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: '검색어 지우기',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(_search.clear),
                  ),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in KanjiFilter.values)
              ChoiceChip(
                label: Text(filter.label),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
              ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 480 &&
                MediaQuery.textScalerOf(context).scale(16) < 24) {
              return Row(
                children: [
                  Expanded(child: _gradePicker()),
                  const SizedBox(width: 12),
                  Expanded(child: _sortPicker()),
                ],
              );
            }
            return Column(
              children: [
                _gradePicker(),
                const SizedBox(height: 16),
                _sortPicker(),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                '${items.length}자',
                key: const ValueKey('kanji-result-count'),
              ),
            ),
            if (_hasFilters)
              TextButton(onPressed: _reset, child: const Text('필터 초기화')),
          ],
        ),
        const SizedBox(height: 16),
        if (items.isEmpty) Text(_emptyMessage()),
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
            final columns = scale > 1.5 ? 2 : 3;
            final cellWidth =
                (constraints.maxWidth - 12 * (columns - 1)) / columns;
            return GridView.builder(
              shrinkWrap: true,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final kanji = items[index];
                final p = widget.controller.progress.kanji[kanji.id];
                final needsReview = p?.needsReview ?? false;
                return Card(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Semantics(
                        button: true,
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          widget.onSelect(kanji);
                        },
                        excludeSemantics: true,
                        label:
                            '${kanji.character}, ${kanji.koreanMeanings.join(', ')}, ${kanji.koreanReading}, ${needsReview ? '복습 필요' : masteryLabel(p)}, 상세 보기',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            widget.onSelect(kanji);
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        kanji.character,
                                        locale: const Locale('ja'),
                                        style: TextStyle(
                                          fontFamily: 'NotoSansJP',
                                          fontSize: (cellWidth * .34).clamp(
                                            26,
                                            40,
                                          ),
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    kanji.koreanReading,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (needsReview || p?.firstStudiedAt != null)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: ExcludeSemantics(
                            child: Icon(
                              needsReview
                                  ? Icons.close_rounded
                                  : Icons.check_rounded,
                              color: needsReview
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                          ),
                        ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: FavoriteButton(
                          controller: widget.controller,
                          kanji: kanji,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
