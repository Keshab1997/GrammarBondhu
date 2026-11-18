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
  int _cloudSession = 0;
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
    _resetCloudSync();
    await syncCloudNow();
  }

  /// Retries synchronization explicitly, e.g. from the Profile screen.
  Future<void> syncCloudNow() async {
    if (!cloudConnected) {
      throw StateError('No cloud account is connected.');
    }
    await _enqueueCloudSync(_cloudSession, reportError: true);
  }

  void disconnectCloudBackup() {
    _cloudBackup = null;
    _cloudUserId = null;
    _resetCloudSync();
    notifyListeners();
  }

  void _resetCloudSync() {
    // An old account's network request must not hold up the next connection.
    _cloudSession++;
    _cloudQueue = Future<void>.value();
    _cloudSyncing = false;
    _lastCloudSyncError = null;
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
    final moment = now ?? DateTime.now();
    _progress.chapter(chapterId)
      ..resumeSceneIndex = sceneIndex
      ..lastOpenedAt = moment;
    _progress.registerStudyDay(moment);
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

    // The first completion grants full rewards. Replays grant only the
    // difference beyond what the learner has already earned.
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
    if (!firstCompletion && coins > record.coinsEarned) {
      grantedCoins = coins - record.coinsEarned;
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
    String chapterId,
    String questionId, {
    DateTime? now,
  }) =>
      _updateReview(chapterId, questionId, missed: true, now: now);

  /// Removes a question after the learner marks it reviewed or answers it
  /// correctly on a later attempt.
  Future<void> clearQuestionForReview(
    String chapterId,
    String questionId, {
    DateTime? now,
  }) =>
      _updateReview(chapterId, questionId, missed: false, now: now);

  Future<void> _updateReview(
    String chapterId,
    String questionId, {
    required bool missed,
    DateTime? now,
  }) async {
    final chapter = _progress.chapter(chapterId);
    if (missed) {
      chapter.missedQuestionIds.add(questionId);
    } else {
      chapter.missedQuestionIds.remove(questionId);
    }
    // Record even an unchanged local status: another device may have made an
    // opposite change before this answer, and not synced it here yet.
    chapter.reviewUpdatedAt[questionId] = (now ?? DateTime.now()).toUtc();
    notifyListeners();
    await _persist();
  }

  /// Resets device progress without modifying the backup or daily goal.
  Future<void> resetAll() async {
    if (cloudConnected) return;
    _progress = UserProgress(dailyGoalQuestions: _progress.dailyGoalQuestions);
    notifyListeners();
    await _store.saveProgress(_progress);
  }

  Future<void> _persist() async {
    final session = _cloudSession;
    await _store.saveProgress(_progress);
    if (session != _cloudSession || !cloudConnected) return;
    unawaited(_enqueueCloudSync(session, reportError: false));
  }

  Future<void> _enqueueCloudSync(int session, {required bool reportError}) {
    final task = _cloudQueue.then(
      (_) => _syncLatestCloudSnapshot(session, reportError: reportError),
    );
    // Explicit callers see failures, but a failed retry does not poison the
    // queue for subsequent requests. Background callers never need to wait.
    _cloudQueue = task.then<void>((_) {}, onError: (Object _) {});
    return task;
  }

  Future<void> _syncLatestCloudSnapshot(
    int session, {
    required bool reportError,
  }) async {
    final backup = _cloudBackup;
    final userId = _cloudUserId;
    if (session != _cloudSession || backup == null || userId == null) return;
    _cloudSyncing = true;
    if (reportError) _lastCloudSyncError = null;
    try {
      notifyListeners();
      if (session != _cloudSession) return;
      // Freeze the upload so that an old request cannot observe edits made
      // after it started. Merge its result with the live local state instead.
      final snapshot = UserProgress.fromJson(_progress.toJson());
      final merged = await backup.synchronize(userId, snapshot);
      if (session != _cloudSession) return;
      _progress = UserProgress.mergeForCloud(_progress, merged);
      await _store.saveProgress(_progress);
      if (session == _cloudSession) _lastCloudSyncError = null;
    } catch (error) {
      if (session == _cloudSession) {
        _lastCloudSyncError = error;
        if (reportError) rethrow;
      }
    } finally {
      if (session == _cloudSession) {
        _cloudSyncing = false;
        notifyListeners();
      }
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
