import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/logic/quiz_eval.dart';
import '../../data/local/local_store.dart';
import '../../data/models/chapter.dart';
import '../../data/models/progress.dart';
import '../../data/remote/progress_cloud_backup.dart';

/// Learner progress: XP, coins, streaks, chapter completion, resume points.
class ProgressController extends ChangeNotifier {
  ProgressController(this._store, UserProgress initial) : _progress = initial;

  final LocalStore _store;
  UserProgress _progress;

  UserProgress get progress => _progress;

  ProgressCloudBackup? _cloudBackup;
  String? _cloudUserId;
  Future<void> _cloudQueue = Future<void>.value();
  bool _cloudSyncing = false;
  Object? _lastCloudSyncError;

  bool get cloudConnected => _cloudBackup != null && _cloudUserId != null;
  bool get cloudSyncing => _cloudSyncing;
  Object? get lastCloudSyncError => _lastCloudSyncError;

  /// Connects this controller to the signed-in learner's private backup.
  /// Local and cloud progress are merged before either copy is replaced.
  Future<void> connectCloudBackup({
    required String userId,
    ProgressCloudBackup? backup,
  }) async {
    _cloudBackup = backup ?? ProgressCloudBackup();
    _cloudUserId = userId;
    await syncCloudNow();
  }

  /// Retries synchronization explicitly, e.g. from the Profile screen.
  Future<void> syncCloudNow() async {
    final backup = _cloudBackup;
    final userId = _cloudUserId;
    if (backup == null || userId == null) {
      throw StateError('No cloud account is connected.');
    }
    await _cloudQueue;
    _cloudSyncing = true;
    _lastCloudSyncError = null;
    notifyListeners();
    try {
      final merged = await backup.synchronize(userId, _progress);
      _progress = merged;
      await _store.saveProgress(_progress);
    } catch (error) {
      _lastCloudSyncError = error;
      rethrow;
    } finally {
      _cloudSyncing = false;
      notifyListeners();
    }
  }

  void disconnectCloudBackup() {
    _cloudBackup = null;
    _cloudUserId = null;
    _lastCloudSyncError = null;
    notifyListeners();
  }

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
    // Finishing is never worth 0 XP — a completion floor keeps the
    // experience encouraging even after a rough first run.
    final completionXp = xp < 10 ? 10 : xp;
    var grantedXp = firstCompletion ? completionXp : 0;
    var grantedCoins = firstCompletion ? coins : 0;
    if (!firstCompletion && isBest) {
      final previousXp = record.xpEarned;
      final targetXp = xp;
      if (targetXp > previousXp) grantedXp = targetXp - previousXp;
    }
    record
      ..xpEarned += grantedXp
      ..coinsEarned += grantedCoins;

    // No registerQuestionAnswered here: the daily counter is advanced once per
    // submitted answer by the quiz screen. Counting the run here as a single
    // question is what made a five-question quiz look like one.
    _progress
      ..totalXp += grantedXp
      ..coins += grantedCoins
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

  /// The daily question target the learner chose in Settings.
  ///
  /// Stored in the progress snapshot rather than in [AppSettings] because the
  /// cloud merge already treats `dailyGoalQuestions` as this device's own
  /// preference - moving it to a second store would let the two disagree.
  int get dailyGoalQuestions => _progress.dailyGoalQuestions;

  /// Saves a new daily target. False when the value was unusable or unchanged.
  Future<bool> setDailyGoal(int target) async {
    final changed = _progress.setDailyGoal(target);
    if (!changed) return false;
    notifyListeners();
    await _persist();
    return true;
  }

  /// Counts one *submitted* quiz answer toward today's goal.
  ///
  /// Called per answer, not per quiz: a learner who answers three questions
  /// and stops has made progress, and a quiz that is abandoned half way must
  /// still count what was actually answered. Deliberately does not register a
  /// study day - a streak is about showing up, which only a finished quiz
  /// proves.
  Future<void> registerQuestionAnswered({DateTime? now}) async {
    _progress.registerQuestionAnswered(now ?? DateTime.now());
    notifyListeners();
    await _persist();
  }

  /// Adds an incorrect quiz answer to the learner's local review list.
  Future<void> markQuestionForReview(
      String chapterId, String questionId) async {
    final changed =
        _progress.chapter(chapterId).missedQuestionIds.add(questionId);
    if (!changed) return;
    notifyListeners();
    await _persist();
  }

  /// Removes a question after the learner marks it reviewed or answers it
  /// correctly on a later attempt.
  Future<void> clearQuestionForReview(
      String chapterId, String questionId) async {
    final chapter = _progress.chapters[chapterId];
    if (chapter == null) return;
    final changed = chapter.missedQuestionIds.remove(questionId);
    if (!changed) return;
    notifyListeners();
    await _persist();
  }

  Future<void> resetAll() async {
    _progress = UserProgress();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    await _store.saveProgress(_progress);
    if (!cloudConnected) return;
    _cloudQueue = _cloudQueue.then((_) => _syncLatestCloudSnapshot());
    unawaited(_cloudQueue);
  }

  /// Background sync stays off the learner's critical path: local progress is
  /// saved first and a network failure never interrupts the lesson.
  Future<void> _syncLatestCloudSnapshot() async {
    final backup = _cloudBackup;
    final userId = _cloudUserId;
    if (backup == null || userId == null) return;
    _cloudSyncing = true;
    notifyListeners();
    try {
      final merged = await backup.synchronize(userId, _progress);
      _progress = UserProgress.mergeForCloud(_progress, merged);
      await _store.saveProgress(_progress);
      _lastCloudSyncError = null;
    } catch (error) {
      _lastCloudSyncError = error;
    } finally {
      _cloudSyncing = false;
      notifyListeners();
    }
  }
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
