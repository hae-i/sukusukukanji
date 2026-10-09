import 'package:flutter/foundation.dart';

import '../../data/models/study_session.dart';

enum SessionStage { cards, quiz, saving, saveError, result }

class SessionController extends ChangeNotifier {
  SessionController(
    this.session, {
    required this.save,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final StudySession session;
  final Future<void> Function(CompletedSession) save;
  final DateTime Function() _now;
  SessionStage stage = SessionStage.cards;
  int cardIndex = 0;
  int questionIndex = 0;
  final List<int> _answers = [];
  CompletedSession? completed;
  bool _disposed = false;
  int? get selectedAnswer =>
      _answers.length > questionIndex ? _answers[questionIndex] : null;
  QuizQuestion get question => session.questions[questionIndex];

  void showCard(int index) {
    if (stage != SessionStage.cards ||
        index < 0 ||
        index >= session.kanji.length ||
        index == cardIndex) {
      return;
    }
    cardIndex = index;
    notifyListeners();
  }

  void nextCard() {
    if (stage != SessionStage.cards) return;
    if (cardIndex < session.kanji.length - 1) {
      cardIndex++;
    } else {
      stage = SessionStage.quiz;
    }
    notifyListeners();
  }

  void answer(int index) {
    if (stage != SessionStage.quiz ||
        selectedAnswer != null ||
        index < 0 ||
        index >= question.options.length) {
      return;
    }
    _answers.add(index);
    notifyListeners();
  }

  Future<void> nextQuestion() async {
    if (stage != SessionStage.quiz || selectedAnswer == null) return;
    if (questionIndex < session.questions.length - 1) {
      questionIndex++;
      notifyListeners();
    } else {
      completed = CompletedSession(
        session: session,
        answers: _answers,
        completedAt: _now(),
      );
      await persist();
    }
  }

  Future<void> persist() async {
    if (completed == null ||
        stage == SessionStage.saving ||
        stage == SessionStage.result) {
      return;
    }
    stage = SessionStage.saving;
    notifyListeners();
    try {
      await save(completed!);
      if (_disposed) return;
      stage = SessionStage.result;
    } catch (_) {
      if (_disposed) return;
      stage = SessionStage.saveError;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
