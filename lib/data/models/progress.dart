/// Local learner progress — persisted as one JSON blob in SharedPreferences.
///
/// Deliberately lightweight: progress data is small key-value state
/// (chapters, XP, streaks). A database would only add build weight to a
/// device-friendly offline app.
class UserProgress {
  UserProgress({
    Map<String, ChapterProgress>? chapters,
    this.totalXp = 0,
    this.coins = 0,
    this.streakDays = 0,
    this.questionsAnsweredToday = 0,
    this.dailyGoalQuestions = 5,
    this.lastStudyDate,
    this.lastQuestionDate,
    DateTime? now,
  })  : chapters = chapters ?? {},
        _now = now;

  final DateTime? _now;
  final Map<String, ChapterProgress> chapters;
  int totalXp;
  int coins;
  int streakDays;
  int questionsAnsweredToday;
  int dailyGoalQuestions;
  DateTime? lastStudyDate;
  DateTime? lastQuestionDate;

  // ---- Level system: 100 XP per level, matching the design's Level 3 @ 300 XP.
  static const int xpPerLevel = 100;

  int get level => (totalXp ~/ xpPerLevel) + 1;

  int get xpIntoLevel => totalXp % xpPerLevel;

  int get xpToNextLevel => xpPerLevel - xpIntoLevel;

  String get levelTitle {
    switch (level) {
      case 1:
        return 'Story Starter';
      case 2:
        return 'Word Explorer';
      case 3:
        return 'Grammar Explorer';
      case 4:
        return 'Sentence Builder';
      default:
        return 'English Champion';
    }
  }

  ChapterProgress chapter(String chapterId) => chapters.putIfAbsent(
      chapterId, () => ChapterProgress(chapterId: chapterId));

  int get completedChapterCount =>
      chapters.values.where((c) => c.completed).length;

  int get totalQuizAnswered =>
      chapters.values.fold(0, (sum, c) => sum + c.attempts);

  int get missedQuestionCount =>
      chapters.values.fold(0, (sum, c) => sum + c.missedQuestionIds.length);

  /// Rolls the streak forward once per study day. Returns the new streak.
  int registerStudyDay(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final last = lastStudyDate;
    if (last == null) {
      streakDays = 1;
    } else {
      final lastDay = DateTime(last.year, last.month, last.day);
      final diff = today.difference(lastDay).inDays;
      if (diff == 1) {
        streakDays += 1;
      } else if (diff > 1) {
        streakDays = 1;
      }
      // diff == 0 → same day, streak unchanged.
    }
    lastStudyDate = today;
    return streakDays;
  }

  /// Reads the saved count only if it belongs to the local day of [now].
  int questionsAnsweredOn(DateTime now) {
    final last = lastQuestionDate;
    return last != null && _sameDay(last.toLocal(), now.toLocal())
        ? questionsAnsweredToday
        : 0;
  }

  /// Counts one answered quiz question toward the daily goal.
  void registerQuestionAnswered(DateTime now) {
    final local = now.toLocal();
    questionsAnsweredToday = questionsAnsweredOn(local) + 1;
    lastQuestionDate = DateTime(local.year, local.month, local.day);
  }

  bool get dailyGoalReached =>
      questionsAnsweredOn(_now ?? DateTime.now()) >= dailyGoalQuestions;

  /// The targets a learner can actually pick. A free-text goal invites "500",
  /// which is not a goal, it is a way to feel behind every day.
  static const List<int> dailyGoalChoices = [3, 5, 10, 15, 20];

  /// Sets the daily target, clamped to a range the goal card can draw.
  ///
  /// Returns false when the value was unusable and nothing changed, so a
  /// caller can ignore the write instead of persisting a no-op.
  bool setDailyGoal(int target) {
    if (target < 1 || target > 100) return false;
    if (dailyGoalQuestions == target) return false;
    dailyGoalQuestions = target;
    return true;
  }

  /// Merges two device snapshots without adding duplicate XP or quiz attempts.
  /// Per-chapter achievements use the strongest value, while missed questions
  /// are unioned so neither device loses its review list.
  static UserProgress mergeForCloud(UserProgress local, UserProgress remote) {
    final mergedChapters = <String, ChapterProgress>{};
    for (final id in {...local.chapters.keys, ...remote.chapters.keys}) {
      final a = local.chapters[id];
      final b = remote.chapters[id];
      if (a == null || b == null) {
        final source = a ?? b!;
        mergedChapters[id] = ChapterProgress.fromJson(source.toJson());
        continue;
      }

      final openedOnRemote = _isLater(b.lastOpenedAt, a.lastOpenedAt);
      mergedChapters[id] = ChapterProgress(
        chapterId: id,
        completed: a.completed || b.completed,
        stars: a.stars > b.stars ? a.stars : b.stars,
        bestScorePercent: a.bestScorePercent > b.bestScorePercent
            ? a.bestScorePercent
            : b.bestScorePercent,
        xpEarned: a.xpEarned > b.xpEarned ? a.xpEarned : b.xpEarned,
        coinsEarned:
            a.coinsEarned > b.coinsEarned ? a.coinsEarned : b.coinsEarned,
        attempts: a.attempts > b.attempts ? a.attempts : b.attempts,
        resumeSceneIndex:
            openedOnRemote ? b.resumeSceneIndex : a.resumeSceneIndex,
        lastOpenedAt: _laterDate(a.lastOpenedAt, b.lastOpenedAt),
        missedQuestionIds: {...a.missedQuestionIds, ...b.missedQuestionIds},
      );
    }

    final chapterXp = mergedChapters.values
        .fold<int>(0, (sum, chapter) => sum + chapter.xpEarned);
    final chapterCoins = mergedChapters.values
        .fold<int>(0, (sum, chapter) => sum + chapter.coinsEarned);
    final questionDate =
        _laterDate(local.lastQuestionDate, remote.lastQuestionDate);
    final sameQuestionDay = local.lastQuestionDate != null &&
        remote.lastQuestionDate != null &&
        _sameDay(local.lastQuestionDate!, remote.lastQuestionDate!);
    final questionsToday = sameQuestionDay || questionDate == null
        ? (local.questionsAnsweredToday > remote.questionsAnsweredToday
            ? local.questionsAnsweredToday
            : remote.questionsAnsweredToday)
        : questionDate == remote.lastQuestionDate
            ? remote.questionsAnsweredToday
            : local.questionsAnsweredToday;

    return UserProgress(
      chapters: mergedChapters,
      totalXp: [local.totalXp, remote.totalXp, chapterXp].reduce(
        (a, b) => a > b ? a : b,
      ),
      coins: [local.coins, remote.coins, chapterCoins].reduce(
        (a, b) => a > b ? a : b,
      ),
      streakDays: local.streakDays > remote.streakDays
          ? local.streakDays
          : remote.streakDays,
      questionsAnsweredToday: questionsToday,
      // Goal and UI preferences belong to the device doing the restore.
      dailyGoalQuestions: local.dailyGoalQuestions,
      lastStudyDate: _laterDate(local.lastStudyDate, remote.lastStudyDate),
      lastQuestionDate: questionDate,
    );
  }

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    final chapters = <String, ChapterProgress>{};
    final raw = json['chapters'] as Map<String, dynamic>? ?? {};
    for (final entry in raw.entries) {
      chapters[entry.key] = ChapterProgress.fromJson(
          (entry.value as Map).cast<String, dynamic>());
    }
    final questionDate = json['last_question_date'];
    return UserProgress(
      chapters: chapters,
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
      questionsAnsweredToday: (json['questions_today'] as num?)?.toInt() ?? 0,
      // A stored 0 (or a hand-edited 999) would divide by zero on the goal
      // card or leave the learner permanently behind, so it is clamped on the
      // way in, not trusted because it came from disk.
      dailyGoalQuestions:
          ((json['daily_goal_questions'] as num?)?.toInt() ?? 5).clamp(1, 100),
      lastStudyDate: json['last_study_date'] == null
          ? null
          : DateTime.tryParse(json['last_study_date'] as String),
      lastQuestionDate:
          questionDate is String ? DateTime.tryParse(questionDate) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'total_xp': totalXp,
        'coins': coins,
        'streak_days': streakDays,
        'questions_today': questionsAnsweredToday,
        'daily_goal_questions': dailyGoalQuestions,
        'last_study_date': lastStudyDate?.toIso8601String(),
        'last_question_date': lastQuestionDate?.toIso8601String(),
        'chapters': chapters.map((k, v) => MapEntry(k, v.toJson())),
      };
}

DateTime? _laterDate(DateTime? a, DateTime? b) => _isLater(b, a) ? b : a;

bool _isLater(DateTime? candidate, DateTime? reference) {
  if (candidate == null) return false;
  if (reference == null) return true;
  return candidate.isAfter(reference);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class ChapterProgress {
  ChapterProgress({
    required this.chapterId,
    this.completed = false,
    this.stars = 0,
    this.bestScorePercent = 0,
    this.xpEarned = 0,
    this.coinsEarned = 0,
    this.attempts = 0,
    this.resumeSceneIndex,
    this.lastOpenedAt,
    Set<String>? missedQuestionIds,
  }) : missedQuestionIds = missedQuestionIds ?? <String>{};

  final String chapterId;
  bool completed;

  /// 0–3 stars, best result so far.
  int stars;
  int bestScorePercent;
  int xpEarned;
  int coinsEarned;
  int attempts;

  /// Quiz questions the learner has answered incorrectly and can review later.
  final Set<String> missedQuestionIds;

  /// Scene index to resume an unfinished chapter; null when not started.
  int? resumeSceneIndex;
  DateTime? lastOpenedAt;

  bool get started => attempts > 0 || resumeSceneIndex != null || completed;

  factory ChapterProgress.fromJson(Map<String, dynamic> json) =>
      ChapterProgress(
        chapterId: json['chapter_id'] as String? ?? '',
        completed: json['completed'] as bool? ?? false,
        stars: (json['stars'] as num?)?.toInt() ?? 0,
        bestScorePercent: (json['best_score_percent'] as num?)?.toInt() ?? 0,
        xpEarned: (json['xp_earned'] as num?)?.toInt() ?? 0,
        coinsEarned: (json['coins_earned'] as num?)?.toInt() ?? 0,
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        missedQuestionIds: (json['missed_question_ids'] as List?)
                ?.whereType<String>()
                .toSet() ??
            <String>{},
        resumeSceneIndex: (json['resume_scene_index'] as num?)?.toInt(),
        lastOpenedAt: json['last_opened_at'] == null
            ? null
            : DateTime.tryParse(json['last_opened_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'chapter_id': chapterId,
        'completed': completed,
        'stars': stars,
        'best_score_percent': bestScorePercent,
        'xp_earned': xpEarned,
        'coins_earned': coinsEarned,
        'attempts': attempts,
        'missed_question_ids': missedQuestionIds.toList()..sort(),
        'resume_scene_index': resumeSceneIndex,
        'last_opened_at': lastOpenedAt?.toIso8601String(),
      };
}
