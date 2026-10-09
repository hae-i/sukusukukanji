import 'package:flutter/material.dart';

import '../data/models/kanji.dart';
import 'app_controller.dart';
import '../features/app_icon/icon_selection_screen.dart';
import '../features/grades/grade_list_screen.dart';
import '../features/kanji/kanji_detail_screen.dart';
import '../features/settings/settings_screen.dart';

/// Typed route arguments; no duplicate routing package or nested navigator.
abstract final class AppRouter {
  static Future<void> detail(
    BuildContext context,
    Kanji kanji,
    AppController controller,
  ) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: RouteSettings(name: '/kanji/${kanji.id}'),
      builder: (_) => KanjiDetailScreen(kanji: kanji, controller: controller),
    ),
  );
  static Future<void> grades(BuildContext context, AppController controller) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/grades'),
          builder: (_) => GradeListScreen(controller: controller),
        ),
      );
  static Future<void> icons(BuildContext context, AppController controller) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/icons'),
          builder: (_) => IconSelectionScreen(controller: controller),
        ),
      );
  static Future<void> settings(
    BuildContext context,
    AppController controller,
  ) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/settings'),
      builder: (_) => SettingsScreen(controller: controller),
    ),
  );
}
