import 'package:flutter/foundation.dart';

import '../../core/logic/quiz_eval.dart';
import '../../data/local/local_store.dart';
import '../../data/models/chapter.dart';
import '../../data/models/progress.dart';

/// Learner progress: XP, coins, streaks, chapter completion, resume points.
class ProgressController extends ChangeNotifier {
  ProgressController(this._store, UserProgress initial) : _progress = initial;

  final LocalStore _store;
  UserProgress _progress;

  UserProgress get progress => _progress;

  ChapterProgress chapterProgress(String chapterId) =>
      _progress.chapter(chapterId);

  bool isCompleted(String chapterId) => _progress.chapter(chapterId).completed;

  /// The chapter the learner should continue with.
  String recommendedChapterId(List<Chapter> chapters) {
    for (final chapter in chapters) {
      if (!isCompleted(chapter.id)) return chapter.id;
    }
    return chapters.isEmpty ? '' : chapters.last.id;
  }

  /// Marks the learner as having opened [chapterId] at [sceneIndex].
  Future<void> openChapter(String chapterId, int sceneIndex,
      {DateTime? now}) async {
    _progress.chapter(chapterId)
      ..resumeSceneIndex = sceneIndex
      ..lastOpenedAt = now ?? DateTime.now();
    _progress.registerStudyDay(now ?? DateTime.now());
    notifyListeners();
    await _persist();
  }

  /// Finishes a quiz run and applies rewards. [rewards] comes from the
  /// chapter content; [now] is injectable for tests.
  Future<QuizRunResult> recordQuizRun({
    required Chapter chapter,
    required int correct,
    required int total,
    DateTime? now,
  }) async {
    final moment = now ?? DateTime.now();
    final percent = QuizEval.scorePercent(correct, total);
    final stars = QuizEval.starsFor(percent);
    final xp = QuizEval.xpFor(chapter.rewards, percent);
    final coins = QuizEval.coinsFor(chapter.rewards, stars);

    final record = _progress.chapter(chapter.id)
      ..attempts += 1
      ..lastOpenedAt = moment;

    final isBest = QuizEval.isPersonalBest(percent, record.bestScorePercent);
    if (isBest) record.bestScorePercent = percent;

    final firstCompletion = !record.completed;
    if (firstCompletion) record.completed = true;
    if (stars > record.stars) record.stars = stars;

    // XP and coins are granted once per improvement path: full amount on
    // first completion, the difference when a better run beats the old best.
    var grantedXp = firstCompletion ? xp : 0;
    var grantedCoins = firstCompletion ? coins : 0;
    if (!firstCompletion && isBest) {
      final previousXp = record.xpEarned;
      final targetXp = xp;
      if (targetXp > previousXp) grantedXp = targetXp - previousXp;
    }
    record.xpEarned += grantedXp;

    _progress
      ..totalXp += grantedXp
      ..coins += grantedCoins
      ..registerQuestionAnswered(moment)
      ..registerStudyDay(moment);

    // Chapter finished → clear the resume point.
    record.resumeSceneIndex = null;

    notifyListeners();
    await _persist();
    return QuizRunResult(
      percent: percent,
      stars: stars,
      xpEarned: grantedXp,
      coinsEarned: grantedCoins,
      isPersonalBest: isBest,
      firstCompletion: firstCompletion,
    );
  }

  Future<void> resetAll() async {
    _progress = UserProgress();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() => _store.saveProgress(_progress);
}

/// Result of one completed quiz run (used by the reward screen).
class QuizRunResult {
  const QuizRunResult({
    required this.percent,
    required this.stars,
    required this.xpEarned,
    required this.coinsEarned,
    required this.isPersonalBest,
    required this.firstCompletion,
  });

  final int percent;
  final int stars;
  final int xpEarned;
  final int coinsEarned;
  final bool isPersonalBest;
  final bool firstCompletion;
}
