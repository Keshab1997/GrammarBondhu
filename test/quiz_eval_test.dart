import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/core/logic/quiz_eval.dart';
import 'package:grammar_bondhu/data/models/chapter.dart';

void main() {
  const rewards = ChapterRewards(xp: 50, coins: 10, maxStars: 3);

  group('QuizEval', () {
    test('scorePercent rounds and clamps', () {
      expect(QuizEval.scorePercent(4, 5), 80);
      expect(QuizEval.scorePercent(5, 5), 100);
      expect(QuizEval.scorePercent(0, 5), 0);
      expect(QuizEval.scorePercent(1, 3), 33);
      expect(QuizEval.scorePercent(0, 0), 0);
    });

    test('starsFor is generous but meaningful', () {
      expect(QuizEval.starsFor(100), 3);
      expect(QuizEval.starsFor(90), 3);
      expect(QuizEval.starsFor(89), 2);
      expect(QuizEval.starsFor(70), 2);
      expect(QuizEval.starsFor(69), 1);
      expect(QuizEval.starsFor(0), 1);
    });

    test('xpFor scales with score and never starves', () {
      expect(QuizEval.xpFor(rewards, 100), 50);
      expect(QuizEval.xpFor(rewards, 80), 40);
      expect(QuizEval.xpFor(rewards, 0), 0);
      // Tiny positive scores still get a little XP.
      expect(QuizEval.xpFor(rewards, 10), 10);
    });

    test('coinsFor rewards full coins only at 3 stars', () {
      expect(QuizEval.coinsFor(rewards, 3), 10);
      expect(QuizEval.coinsFor(rewards, 2), 5);
      expect(QuizEval.coinsFor(rewards, 1), 5);
    });

    test('isPersonalBest compares against previous best', () {
      expect(QuizEval.isPersonalBest(80, 70), true);
      expect(QuizEval.isPersonalBest(70, 70), false);
      expect(QuizEval.isPersonalBest(60, 70), false);
    });
  });
}
