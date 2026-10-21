import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/data/models/chapter.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContentRepository (bundled content)', () {
    late ContentRepository repository;

    setUp(() async {
      repository = ContentRepository();
      await repository.load();
    });

    test('loads every manifest chapter in order', () {
      expect(repository.chapters.length, 5);
      expect(
        repository.chapters.map((c) => c.id).toList(),
        ['ch01', 'ch02', 'ch03', 'ch04', 'ch05'],
      );
    });

    test('every chapter carries trilingual learner-facing text', () {
      for (final chapter in repository.chapters) {
        expect(chapter.title.en.isNotEmpty, true, reason: chapter.id);
        expect(chapter.title.bn, isNotNull, reason: chapter.id);
        expect(chapter.title.hi, isNotNull, reason: chapter.id);
        expect(chapter.lesson.explanation.bn, isNotNull, reason: chapter.id);
        expect(chapter.lesson.explanation.hi, isNotNull, reason: chapter.id);
        for (final line in chapter.scenes.expand((s) => s.dialogue)) {
          expect(line.text.bn, isNotNull, reason: '${chapter.id} dialogue');
          expect(line.text.hi, isNotNull, reason: '${chapter.id} dialogue');
        }
        for (final q in chapter.quiz) {
          expect(q.explanation.bn, isNotNull, reason: '${q.id} explanation');
          expect(q.explanation.hi, isNotNull, reason: '${q.id} explanation');
        }
      }
    });

    test('every chapter has a working quiz of 5 questions', () {
      for (final chapter in repository.chapters) {
        expect(chapter.quiz.length, 5, reason: chapter.id);
        for (final q in chapter.quiz) {
          expect(q.options.length, 4, reason: q.id);
          expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1),
              reason: q.id);
        }
      }
    });

    test('every chapter JSON passes validation', () {
      for (final chapter in repository.chapters) {
        // Validation runs on the parsed structure via a fresh model build.
        expect(chapter.lesson.examples, isNotEmpty, reason: chapter.id);
        expect(chapter.scenes, isNotEmpty, reason: chapter.id);
      }
    });

    test('byId / nextAfter / recommendedNext', () {
      expect(repository.byId('ch02')!.title.en, 'A New Friend');
      expect(repository.nextAfter('ch01')!.id, 'ch02');
      expect(repository.nextAfter('ch05'), isNull);

      final recommended = repository.recommendedNext((id) => id == 'ch01');
      expect(recommended.id, 'ch02');

      final allDone = repository.recommendedNext((_) => true);
      expect(allDone.id, 'ch05');
    });

    test('Chapter.validateJson stays quiet for the shipped content shape', () {
      final issues = Chapter.validateJson({
        'chapter_id': 'x',
        'title': {'en': 't'},
        'description': {'en': 'd'},
        'grammar_topic': {'en': 'g'},
        'difficulty': 'beginner',
        'estimated_duration_minutes': 1,
        'rewards': {'xp': 1, 'coins': 1, 'max_stars': 3},
        'scenes': [
          {
            'scene_id': 's',
            'dialogue': [
              {
                'character_id': 'rahul',
                'text': {'en': 'hi'}
              }
            ],
          }
        ],
        'lesson': {
          'title': {'en': 'l'},
          'explanation': {'en': 'e'},
          'examples': [
            {'sentence': 'I am.', 'note': {'en': 'n'}}
          ],
        },
        'quiz': [
          {
            'question_id': 'q',
            'question': '?',
            'options': ['a', 'b'],
            'correct_index': 0,
            'explanation': {'en': 'x'},
          }
        ],
      });
      expect(issues, isEmpty);
    });
  });
}
