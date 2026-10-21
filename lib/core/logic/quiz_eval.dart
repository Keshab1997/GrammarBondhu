import '../../data/models/chapter.dart';

/// Pure quiz-evaluation logic, kept free of UI so it is easy to test.
class QuizEval {
  const QuizEval._();

  /// Percentage score, rounded to the nearest int (0–100).
  static int scorePercent(int correct, int total) {
    if (total <= 0) return 0;
    return ((correct / total) * 100).round().clamp(0, 100);
  }

  /// Stars for a finished chapter: generous but meaningful.
  /// 3 stars ≈ near perfect, 2 stars solid, 1 star = finished.
  static int starsFor(int percent) {
    if (percent >= 90) return 3;
    if (percent >= 70) return 2;
    return 1;
  }

  /// XP earned for one quiz run — scales with score, never a punishment.
  static int xpFor(ChapterRewards rewards, int percent) {
    final scaled = (rewards.xp * percent / 100).round();
    return scaled < 10 && percent > 0 ? 10 : scaled;
  }

  /// Coins are small and steady: full coins at 3 stars, half otherwise.
  static int coinsFor(ChapterRewards rewards, int stars) =>
      stars >= 3 ? rewards.coins : (rewards.coins / 2).round();

  /// Whether this run beats the stored best score.
  static bool isPersonalBest(int percent, int previousBest) => percent > previousBest;
}
