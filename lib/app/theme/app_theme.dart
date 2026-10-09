import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const green = Color(0xFF355D43);
  static const cream = Color(0xFFF8F7F2);
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: green,
      brightness: Brightness.light,
      surface: cream,
    );
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Pretendard',
      fontFamilyFallback: const ['NotoSansJP'],
      colorScheme: scheme,
    );
    final titleStyle = base.textTheme.titleLarge!.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 22,
      color: const Color(0xFF263D2E),
    );
    final buttonStyle = base.textTheme.labelLarge!.copyWith(
      fontWeight: FontWeight.w600,
    );
    return base.copyWith(
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(buttonStyle),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(buttonStyle),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      scaffoldBackgroundColor: cream,
      appBarTheme: AppBarTheme(
        backgroundColor: cream,
        foregroundColor: const Color(0xFF263D2E),
        centerTitle: false,
        titleTextStyle: titleStyle,
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: titleStyle,
        contentTextStyle: base.textTheme.bodyLarge!.copyWith(
          color: const Color(0xFF263D2E),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
          minimumSize: const Size(48, 52),
          textStyle: buttonStyle.copyWith(fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFE3ECDD),
        labelTextStyle: WidgetStatePropertyAll(
          buttonStyle.copyWith(fontSize: 14),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: green,
        linearTrackColor: Color(0xFFE0E7DB),
      ),
    );
  }
}
