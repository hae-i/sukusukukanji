import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import '../features/kanji/kanji_list_screen.dart';
import '../features/study/study_hub_screen.dart';
import '../features/study/study_flow_screen.dart';
import '../features/grades/graduation_dialog.dart';
import '../features/app_icon/icon_unlock_dialog.dart';
import 'app_controller.dart';
import 'router.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final AppController controller;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _selectedTab = 0;
  bool _studying = false;
  bool _showingGraduation = false;
  final Set<String> _announcedIcons = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showGraduations();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  Future<void> _showGraduations() async {
    if (_showingGraduation ||
        _studying ||
        !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    _showingGraduation = true;
    var shown = false;
    while (mounted && widget.controller.pendingGraduations.isNotEmpty) {
      shown = true;
      final grade = widget.controller.pendingGraduations.first;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            GraduationDialog(controller: widget.controller, grade: grade),
      );
    }
    for (final grade in widget.controller.pendingIconRewards.toList()) {
      if (!mounted || !_announcedIcons.add(grade.iconKey)) continue;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            IconUnlockDialog(controller: widget.controller, grade: grade),
      );
    }
    _showingGraduation = false;
    if (shown && mounted) await AppRouter.grades(context, widget.controller);
  }

  Future<void> _study({bool review = false, int? grade, int? lesson}) async {
    if (_studying) return;
    _studying = true;
    try {
      var repeat = review;
      do {
        final session = lesson != null && !repeat
            ? widget.controller.startLessonReview(grade!, lesson)
            : widget.controller.start(review: repeat);
        if (session == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  repeat ? '지금은 복습할 한자가 없어요.' : '새 한자 콘텐츠를 준비 중이에요.',
                ),
              ),
            );
          }
          break;
        }
        final again = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            settings: RouteSettings(
              name: session.isReview ? '/review' : '/study',
            ),
            builder: (_) => StudyFlowScreen(
              session: session,
              appController: widget.controller,
              onSave: widget.controller.saveSession,
              canReview: () => widget.controller.reviewCount > 0,
            ),
          ),
        );
        if (!mounted) return;
        setState(() => _selectedTab = 0);
        if (again != true) break;
        repeat = true;
      } while (mounted);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('학습을 준비하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      _studying = false;
    }
    if (mounted) await _showGraduations();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        ['すくすく漢字', '학습', '내 한자'][_selectedTab],
        style: _selectedTab == 0
            ? const TextStyle(fontFamily: 'NotoSansJP')
            : null,
      ),
      actions: [
        IconButton(
          tooltip: '앱 안내',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => AppRouter.settings(context, widget.controller),
        ),
      ],
    ),
    body: SafeArea(
      child: IndexedStack(
        index: _selectedTab,
        children: [
          HomeScreen(
            controller: widget.controller,
            onStudy: () => _study(),
            onReview: () => _study(review: true),
            onGrades: () => AppRouter.grades(context, widget.controller),
          ),
          StudyHubScreen(
            controller: widget.controller,
            onStart: () => _study(),
            onReview: (grade, lesson) => _study(grade: grade, lesson: lesson),
          ),
          KanjiListScreen(
            controller: widget.controller,
            onSelect: (kanji) =>
                AppRouter.detail(context, kanji, widget.controller),
          ),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedTab,
      onDestinationSelected: (index) => setState(() => _selectedTab = index),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          label: '학습',
        ),
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          label: '내 한자',
        ),
      ],
    ),
  );
}
