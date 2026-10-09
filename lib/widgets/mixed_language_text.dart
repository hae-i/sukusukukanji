import 'package:flutter/material.dart';

/// Korean uses the global theme; only CJK/kana runs override its font.
class MixedLanguageText extends StatelessWidget {
  const MixedLanguageText(this.data, {super.key, this.style, this.textAlign});
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;

  static final _japanese = RegExp(
    r'[\u3040-\u30ff\u3400-\u9fff\uf900-\ufaff\uff66-\uff9f々〆〇\u{20000}-\u{2fa1f}]+',
    unicode: true,
  );

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    var offset = 0;
    for (final match in _japanese.allMatches(data)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: data.substring(offset, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          locale: const Locale('ja'),
          style: const TextStyle(fontFamily: 'NotoSansJP'),
        ),
      );
      offset = match.end;
    }
    if (offset < data.length) spans.add(TextSpan(text: data.substring(offset)));
    return Text.rich(
      TextSpan(children: spans),
      style: style,
      textAlign: textAlign,
    );
  }
}
