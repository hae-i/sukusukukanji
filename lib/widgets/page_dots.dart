import 'package:flutter/material.dart';

class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.index, required this.count});
  final int index;
  final int count;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${index + 1} / $count 페이지',
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: i == index ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i == index
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    ),
  );
}
