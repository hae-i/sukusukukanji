import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../data/models/kanji.dart';

class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.controller,
    required this.kanji,
  });
  final AppController controller;
  final Kanji kanji;
  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool _saving = false;
  Future<void> _toggle() async {
    setState(() => _saving = true);
    try {
      await widget.controller.toggleFavorite(widget.kanji);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('즐겨찾기를 저장하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final selected = widget.controller.progress.favoriteKanjiIds.contains(
        widget.kanji.id,
      );
      return IconButton(
        tooltip: '${widget.kanji.character} 즐겨찾기 ${selected ? '해제' : '추가'}',
        isSelected: selected,
        onPressed: _saving ? null : _toggle,
        icon: const Icon(Icons.star_outline),
        selectedIcon: const Icon(Icons.star, color: Color(0xFFAA7819)),
      );
    },
  );
}
