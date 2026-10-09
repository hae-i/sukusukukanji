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
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Pretendard',
      fontFamilyFallback: const ['NotoSansJP'],
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      textButtonTheme: const TextButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Pretendard',
              fontFamilyFallback: ['NotoSansJP'],
              fontWeight: FontWeight.w600,
            ),
          ),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      outlinedButtonTheme: const OutlinedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Pretendard',
              fontFamilyFallback: ['NotoSansJP'],
              fontWeight: FontWeight.w600,
            ),
          ),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      colorScheme: scheme,
      scaffoldBackgroundColor: cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: Color(0xFF263D2E),
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontFamilyFallback: ['NotoSansJP'],
          fontWeight: FontWeight.w700,
          fontSize: 22,
          color: Color(0xFF263D2E),
        ),
      ),
      dialogTheme: const DialogThemeData(
        titleTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontFamilyFallback: ['NotoSansJP'],
          fontWeight: FontWeight.w700,
          fontSize: 22,
          color: Color(0xFF263D2E),
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontFamilyFallback: ['NotoSansJP'],
          fontSize: 16,
          color: Color(0xFF263D2E),
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
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontFamilyFallback: ['NotoSansJP'],
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFE3ECDD),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Pretendard',
            fontFamilyFallback: ['NotoSansJP'],
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: green,
        linearTrackColor: Color(0xFFE0E7DB),
      ),
    );
  }
}
