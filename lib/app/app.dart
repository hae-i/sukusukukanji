import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/repositories/kanji_repository.dart';
import 'app_shell.dart';
import 'app_controller.dart';
import '../data/repositories/user_repositories.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'theme/app_theme.dart';
import '../data/services/app_icon_service.dart';

class SukuSukuApp extends StatefulWidget {
  const SukuSukuApp({
    super.key,
    required this.repository,
    required this.progressRepository,
    required this.settingsRepository,
    this.iconService,
  });
  final KanjiRepository repository;
  final ProgressRepository progressRepository;
  final SettingsRepository settingsRepository;
  final AppIconService? iconService;
  @override
  State<SukuSukuApp> createState() => _SukuSukuAppState();
}

class _SukuSukuAppState extends State<SukuSukuApp> {
  late final AppController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AppController(
      content: widget.repository,
      progress: widget.progressRepository,
      settings: widget.settingsRepository,
      iconService: widget.iconService,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '스쿠스쿠칸지',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko'), Locale('ja'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return switch (_controller.status) {
          AppStatus.loading => const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(semanticsLabel: '한자 불러오는 중'),
                  SizedBox(height: 20),
                  Text('작은 새싹을 준비하고 있어요'),
                ],
              ),
            ),
          ),
          AppStatus.error => Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 40),
                      const SizedBox(height: 16),
                      const Text(
                        '자료나 학습 기록을 불러오지 못했어요.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _controller.load,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AppStatus.ready =>
            _controller.settings.onboardingCompleted
                ? AppShell(controller: _controller)
                : OnboardingScreen(controller: _controller),
        };
      },
    ),
  );
}
