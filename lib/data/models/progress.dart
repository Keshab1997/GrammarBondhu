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
    DateTime? now,
  }) : chapters = chapters ?? {};

  final Map<String, ChapterProgress> chapters;
  int totalXp;
  int coins;
  int streakDays;
  int questionsAnsweredToday;
  int dailyGoalQuestions;
  DateTime? lastStudyDate;

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

  /// Counts one answered quiz question toward the daily goal.
  void registerQuestionAnswered(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final last = lastStudyDate;
    if (last == null || DateTime(last.year, last.month, last.day) != today) {
      questionsAnsweredToday = 0;
    }
    questionsAnsweredToday += 1;
  }

  bool get dailyGoalReached => questionsAnsweredToday >= dailyGoalQuestions;

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    final chapters = <String, ChapterProgress>{};
    final raw = json['chapters'] as Map<String, dynamic>? ?? {};
    for (final entry in raw.entries) {
      chapters[entry.key] = ChapterProgress.fromJson(
          (entry.value as Map).cast<String, dynamic>());
    }
    return UserProgress(
      chapters: chapters,
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
      questionsAnsweredToday: (json['questions_today'] as num?)?.toInt() ?? 0,
      dailyGoalQuestions: (json['daily_goal_questions'] as num?)?.toInt() ?? 5,
      lastStudyDate: json['last_study_date'] == null
          ? null
          : DateTime.tryParse(json['last_study_date'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'total_xp': totalXp,
        'coins': coins,
        'streak_days': streakDays,
        'questions_today': questionsAnsweredToday,
        'daily_goal_questions': dailyGoalQuestions,
        'last_study_date': lastStudyDate?.toIso8601String(),
        'chapters': chapters.map((k, v) => MapEntry(k, v.toJson())),
      };
}

class ChapterProgress {
  ChapterProgress({
    required this.chapterId,
    this.completed = false,
    this.stars = 0,
    this.bestScorePercent = 0,
    this.xpEarned = 0,
    this.attempts = 0,
    this.resumeSceneIndex,
    this.lastOpenedAt,
  });

  final String chapterId;
  bool completed;

  /// 0–3 stars, best result so far.
  int stars;
  int bestScorePercent;
  int xpEarned;
  int attempts;

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
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
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
        'attempts': attempts,
        'resume_scene_index': resumeSceneIndex,
        'last_opened_at': lastOpenedAt?.toIso8601String(),
      };
}
