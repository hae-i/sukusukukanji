import 'kanji.dart';

enum QuizKind { meaning, reading, wordReading }

class QuizQuestion {
  QuizQuestion({
    required this.id,
    required this.kanjiId,
    required this.kind,
    required this.prompt,
    required this.instruction,
    required this.answer,
    required List<String> options,
    required this.explanation,
  }) : options = List.unmodifiable(options) {
    if (options.toSet().length != options.length ||
        !options.contains(answer) ||
        options.length < 2) {
      throw ArgumentError(
        'A quiz needs distinct options and one correct answer',
      );
    }
  }
  final String id;
  final String kanjiId;
  final QuizKind kind;
  final String prompt;
  final String instruction;
  final String answer;
  final List<String> options;
  final String explanation;
}

class StudySession {
  StudySession({
    required this.id,
    required List<Kanji> kanji,
    required List<QuizQuestion> questions,
    this.isReview = false,
  }) : kanji = List.unmodifiable(kanji),
       questions = List.unmodifiable(questions) {
    final ids = kanji.map((k) => k.id).toSet();
    if (id.isEmpty ||
        kanji.isEmpty ||
        ids.length != kanji.length ||
        questions.isEmpty ||
        questions.map((q) => q.id).toSet().length != questions.length ||
        questions.any((q) => !ids.contains(q.kanjiId)) ||
        ids.any((id) => !questions.any((q) => q.kanjiId == id))) {
      throw ArgumentError('A session must cover every distinct kanji');
    }
  }
  final String id;
  final List<Kanji> kanji;
  final List<QuizQuestion> questions;
  final bool isReview;
}

class CompletedSession {
  CompletedSession({
    required this.session,
    required List<int> answers,
    required this.completedAt,
  }) : answers = List.unmodifiable(answers) {
    if (answers.length != session.questions.length) {
      throw ArgumentError('All questions must be answered before saving');
    }
    for (var i = 0; i < answers.length; i++) {
      if (answers[i] < 0 || answers[i] >= session.questions[i].options.length) {
        throw ArgumentError('Invalid answer index');
      }
    }
  }
  final StudySession session;
  final List<int> answers;
  final DateTime completedAt;
  bool isCorrect(int index) =>
      session.questions[index].options[answers[index]] ==
      session.questions[index].answer;
  int get correctCount =>
      List.generate(answers.length, (i) => i).where(isCorrect).length;
  Set<String> get wrongKanjiIds => {
    for (var i = 0; i < answers.length; i++)
      if (!isCorrect(i)) session.questions[i].kanjiId,
  };
}
