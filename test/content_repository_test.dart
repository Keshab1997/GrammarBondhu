import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/core/utils/asset_lookup.dart';
import 'package:grammar_bondhu/data/models/chapter.dart';
import 'package:grammar_bondhu/data/models/localized_text.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';

void _expectTrilingual(LocalizedText text, String field) {
  final translations = text.toJson();
  for (final language in ['en', 'bn', 'hi']) {
    expect((translations[language] ?? '').trim(), isNotEmpty,
        reason: '$field ($language)');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContentRepository (bundled content)', () {
    late ContentRepository repository;

    setUp(() async {
      repository = ContentRepository();
      await repository.load();
    });

    test('loads every manifest chapter in order', () {
      expect(repository.chapters.map((chapter) => chapter.id), [
        'ch01',
        'ch02',
        'ch03',
        'ch04',
        'ch05',
        'ch06',
        'ch07',
        'ch08',
        'ch09',
        'ch10',
      ]);
      expect(repository.manifest.entries.map((entry) => entry.order),
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    });

    test('every bundled chapter JSON passes validation', () async {
      for (final entry in repository.manifest.entries) {
        final asset = 'assets/data/${entry.file}';
        final json = jsonDecode(await rootBundle.loadString(asset))
            as Map<String, dynamic>;
        expect(Chapter.validateJson(json), isEmpty, reason: asset);
      }
    });

    test('every chapter carries trilingual learner-facing text', () {
      for (final chapter in repository.chapters) {
        final id = chapter.id;
        _expectTrilingual(chapter.title, '$id title');
        _expectTrilingual(chapter.description, '$id description');
        _expectTrilingual(chapter.grammarTopic, '$id grammar topic');
        _expectTrilingual(chapter.lesson.title, '$id lesson title');
        _expectTrilingual(chapter.lesson.explanation, '$id lesson explanation');
        for (final example in chapter.lesson.examples) {
          _expectTrilingual(example.note, '$id example: ${example.sentence}');
        }
        for (final scene in chapter.scenes) {
          for (final line in scene.dialogue) {
            _expectTrilingual(
                line.text, '${scene.sceneId} dialogue: ${line.characterId}');
          }
          for (final choice in scene.choices) {
            _expectTrilingual(choice.text, '${choice.id} text');
            _expectTrilingual(choice.response, '${choice.id} response');
          }
        }
        for (final question in chapter.quiz) {
          _expectTrilingual(question.explanation, '${question.id} explanation');
        }
      }
    });

    test('story and quiz IDs are unique across the curriculum', () {
      final ids = <String>{};
      for (final chapter in repository.chapters) {
        final chapterIds = [
          for (final scene in chapter.scenes) ...[
            scene.sceneId,
            for (final choice in scene.choices) choice.id,
          ],
          for (final question in chapter.quiz) question.id,
        ];
        for (final id in chapterIds) {
          expect(id.trim(), isNotEmpty, reason: chapter.id);
          expect(ids.add(id), isTrue, reason: 'Duplicate content ID: $id');
        }
      }
    });

    test('each story uses registered assets and has an interactive choice', () {
      for (final chapter in repository.chapters) {
        expect(chapter.scenes, hasLength(3), reason: chapter.id);
        expect(chapter.lesson.examples, hasLength(4), reason: chapter.id);
        expect(chapter.scenes.expand((scene) => scene.choices), isNotEmpty,
            reason: chapter.id);
        for (final asset in [chapter.thumbnailAsset, chapter.backgroundAsset]) {
          expect(asset, isNotNull, reason: chapter.id);
          expect(File(asset!).existsSync(), isTrue,
              reason: '${chapter.id}: $asset');
        }
        for (final scene in chapter.scenes) {
          expect(AssetLookup.backgrounds.containsKey(scene.backgroundId), isTrue,
              reason: scene.sceneId);
          expect(scene.characterIds, isNotEmpty, reason: scene.sceneId);
          for (final character in scene.characterIds) {
            expect(AssetLookup.characters.containsKey(character), isTrue,
                reason: scene.sceneId);
          }
          for (final line in scene.dialogue) {
            expect(scene.characterIds, contains(line.characterId),
                reason: scene.sceneId);
          }
        }
      }
    });

    test('every quiz has 5 questions and uses all four answer positions', () {
      for (final chapter in repository.chapters) {
        expect(chapter.quiz, hasLength(5), reason: chapter.id);
        for (final question in chapter.quiz) {
          final options = question.options.map((option) => option.trim());
          expect(options, hasLength(4), reason: question.id);
          expect(options, everyElement(isNotEmpty), reason: question.id);
          expect(options.toSet(), hasLength(4), reason: question.id);
          expect(question.correctIndex, inInclusiveRange(0, 3),
              reason: question.id);
        }
        final positions = chapter.quiz.map((q) => q.correctIndex).toSet();
        expect(positions, {0, 1, 2, 3}, reason: chapter.id);
      }
    });

    test('byId / nextAfter / recommendedNext', () {
      expect(repository.byId('ch02')!.title.en, 'A New Friend');
      expect(repository.nextAfter('ch01')!.id, 'ch02');
      expect(repository.nextAfter('ch05')!.id, 'ch06');
      expect(repository.nextAfter('ch10'), isNull);
      expect(repository.recommendedNext((id) => id == 'ch01').id, 'ch02');
      expect(repository.recommendedNext((_) => true).id, 'ch10');
    });

    test('curriculum provides enough XP for English Champion', () {
      final totalXp = repository.chapters.fold<int>(
        0,
        (total, chapter) => total + chapter.rewards.xp,
      );
      expect(totalXp, greaterThanOrEqualTo(700));
    });
  });
}
