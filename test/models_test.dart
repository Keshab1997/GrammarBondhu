import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/data/models/chapter.dart';
import 'package:grammar_bondhu/data/models/localized_text.dart';
import 'package:grammar_bondhu/data/models/progress.dart';
import 'package:grammar_bondhu/data/models/settings.dart';

void main() {
  group('LocalizedText', () {
    test('falls back to English when translation missing', () {
      const text = LocalizedText(en: 'Hello');
      expect(text.of('bn'), 'Hello');
      expect(text.of('hi'), 'Hello');
      expect(text.of('en'), 'Hello');
    });

    test('returns matching translation', () {
      const text = LocalizedText(en: 'Hello', bn: 'হ্যালো', hi: 'नमस्ते');
      expect(text.of('bn'), 'হ্যালো');
      expect(text.of('hi'), 'नमस्ते');
    });

    test('throws when English text missing', () {
      expect(() => LocalizedText.fromJson({'bn': 'x'}), throwsFormatException);
      expect(() => LocalizedText.fromJson('nope'), throwsFormatException);
    });

    test('round-trips through JSON', () {
      const text = LocalizedText(en: 'Hi', bn: 'হাই');
      expect(LocalizedText.fromJson(text.toJson()), text);
    });
  });

  group('Chapter parsing', () {
    Map<String, dynamic> validChapter() => {
          'chapter_id': 'ch01',
          'title': {'en': 'The New Student'},
          'description': {'en': 'First day'},
          'grammar_topic': {'en': 'am / is / are'},
          'difficulty': 'beginner',
          'estimated_duration_minutes': 10,
          'rewards': {'xp': 50, 'coins': 10, 'max_stars': 3},
          'scenes': [
            {
              'scene_id': 'ch01_s1',
              'dialogue': [
                {
                  'character_id': 'rahul',
                  'text': {'en': 'Hi! I am Rahul.'},
                }
              ],
            }
          ],
          'lesson': {
            'title': {'en': 'am / is / are'},
            'explanation': {'en': 'Use am with I.'},
            'examples': [
              {
                'sentence': 'I am a student.',
                'note': {'en': 'I + am'}
              }
            ],
          },
          'quiz': [
            {
              'question_id': 'ch01_q1',
              'question': 'I ___ a student.',
              'options': ['am', 'is', 'are', 'was'],
              'correct_index': 0,
              'explanation': {'en': 'Use am with I.'},
            }
          ],
        };

    test('parses a complete chapter', () {
      final chapter = Chapter.fromJson(validChapter());
      expect(chapter.id, 'ch01');
      expect(chapter.scenes.length, 1);
      expect(chapter.quiz.single.correctAnswer, 'am');
      expect(chapter.lesson.examples.single.sentence, 'I am a student.');
    });

    test('rejects missing required fields', () {
      final json = validChapter()..remove('quiz');
      expect(() => Chapter.fromJson(json), throwsFormatException);
    });

    test('rejects out-of-range correct_index', () {
      final json = validChapter();
      (json['quiz'] as List).first['correct_index'] = 9;
      expect(() => Chapter.fromJson(json), throwsFormatException);
    });

    test('rejects empty scenes', () {
      final json = validChapter();
      json['scenes'] = [];
      expect(Chapter.validateJson(json), isNotEmpty);
    });

    test('validateJson accepts a good chapter', () {
      expect(Chapter.validateJson(validChapter()), isEmpty);
    });
  });

  group('UserProgress', () {
    test('level and XP math', () {
      final p = UserProgress(totalXp: 250);
      expect(p.level, 3);
      expect(p.xpIntoLevel, 50);
      expect(p.xpToNextLevel, 50);
    });

    test('streak increments across days and resets after a gap', () {
      final p = UserProgress();
      p.registerStudyDay(DateTime(2026, 10, 20));
      expect(p.streakDays, 1);
      p.registerStudyDay(DateTime(2026, 10, 21));
      expect(p.streakDays, 2);
      p.registerStudyDay(DateTime(2026, 10, 21));
      expect(p.streakDays, 2);
      p.registerStudyDay(DateTime(2026, 10, 24));
      expect(p.streakDays, 1);
    });

    test('daily question counter resets on a new day', () {
      final p = UserProgress();
      p.registerQuestionAnswered(DateTime(2026, 10, 20));
      p.registerQuestionAnswered(DateTime(2026, 10, 20));
      expect(p.questionsAnsweredToday, 2);
      p.registerQuestionAnswered(DateTime(2026, 10, 21));
      expect(p.questionsAnsweredToday, 1);
    });

    test('JSON round trip', () {
      final p = UserProgress(totalXp: 120, coins: 30, streakDays: 2)
        ..chapter('ch01').completed = true
        ..chapter('ch01').stars = 3;
      final copy = UserProgress.fromJson(p.toJson());
      expect(copy.totalXp, 120);
      expect(copy.coins, 30);
      expect(copy.chapter('ch01').completed, true);
      expect(copy.chapter('ch01').stars, 3);
    });
  });

  group('AppSettings', () {
    test('falls back to bn for unsupported language', () {
      final s = AppSettings.fromJson({'support_language': 'fr'});
      expect(s.supportLanguage, 'bn');
    });

    test('round-trips through JSON', () {
      final s = AppSettings(supportLanguage: 'hi', audioEnabled: false);
      final copy = AppSettings.fromJson(s.toJson());
      expect(copy.supportLanguage, 'hi');
      expect(copy.audioEnabled, false);
    });
  });
}
