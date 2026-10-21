import 'localized_text.dart';

/// Everything the app needs to run one story chapter.
///
/// Chapters are loaded from `assets/data/chapters/*.json` and registered in
/// `assets/data/manifest.json`. Adding a chapter means adding one JSON file —
/// no screen or logic change is required.
class Chapter {
  const Chapter({
    required this.id,
    required this.title,
    required this.description,
    required this.grammarTopic,
    required this.difficulty,
    required this.estimatedDurationMinutes,
    required this.rewards,
    required this.scenes,
    required this.lesson,
    required this.quiz,
    this.thumbnailAsset,
    this.backgroundAsset,
  });

  final String id;
  final LocalizedText title;
  final LocalizedText description;
  final LocalizedText grammarTopic;

  /// 'beginner' | 'intermediate' | 'advanced'
  final String difficulty;
  final int estimatedDurationMinutes;
  final ChapterRewards rewards;
  final List<StoryScene> scenes;
  final GrammarLesson lesson;
  final List<QuizQuestion> quiz;

  /// Asset reference, e.g. `assets/illustrations/ch01_thumb.webp`.
  /// Renderers must show a friendly fallback when the file is missing.
  final String? thumbnailAsset;
  final String? backgroundAsset;

  factory Chapter.fromJson(Map<String, dynamic> json) {
    final id = _reqString(json, 'chapter_id');
    final scenes = _reqList(json, 'scenes')
        .map((e) => StoryScene.fromJson(_asMap(e, 'scenes[]')))
        .toList();
    final quiz = _reqList(json, 'quiz')
        .map((e) => QuizQuestion.fromJson(_asMap(e, 'quiz[]')))
        .toList();
    if (scenes.isEmpty) {
      throw FormatException('Chapter.$id: "scenes" must not be empty');
    }
    if (quiz.isEmpty) {
      throw FormatException('Chapter.$id: "quiz" must not be empty');
    }
    return Chapter(
      id: id,
      title: LocalizedText.fromJson(json['title'], field: 'title'),
      description:
          LocalizedText.fromJson(json['description'], field: 'description'),
      grammarTopic:
          LocalizedText.fromJson(json['grammar_topic'], field: 'grammar_topic'),
      difficulty: _reqString(json, 'difficulty'),
      estimatedDurationMinutes: _reqInt(json, 'estimated_duration_minutes'),
      rewards: ChapterRewards.fromJson(_asMap(json['rewards'], 'rewards')),
      scenes: scenes,
      lesson: GrammarLesson.fromJson(_asMap(json['lesson'], 'lesson')),
      quiz: quiz,
      thumbnailAsset: json['thumbnail_asset'] as String?,
      backgroundAsset: json['background_asset'] as String?,
    );
  }

  /// Human-readable validation issues (used by tests and the content check).
  static List<String> validateJson(Map<String, dynamic> json) {
    final issues = <String>[];
    try {
      final chapter = Chapter.fromJson(json);
      for (final q in chapter.quiz) {
        if (q.options.length < 2) {
          issues.add('${q.id}: needs at least 2 options');
        }
        if (q.options.length > 4) {
          issues.add('${q.id}: more than 4 options is not supported by the UI');
        }
      }
    } on FormatException catch (e) {
      issues.add(e.message);
    }
    return issues;
  }
}

class ChapterRewards {
  const ChapterRewards(
      {required this.xp, required this.coins, required this.maxStars});

  final int xp;
  final int coins;
  final int maxStars;

  factory ChapterRewards.fromJson(Map<String, dynamic> json) => ChapterRewards(
        xp: _reqInt(json, 'xp'),
        coins: _reqInt(json, 'coins'),
        maxStars: _reqInt(json, 'max_stars'),
      );
}

class StoryScene {
  const StoryScene({
    required this.sceneId,
    required this.dialogue,
    this.backgroundId,
    this.characterIds = const [],
    this.choices = const [],
  });

  final String sceneId;

  /// Asset/scene key such as `bg_school_gate`; resolved via the asset lookup.
  final String? backgroundId;
  final List<String> characterIds;
  final List<DialogueLine> dialogue;
  final List<StoryChoice> choices;

  factory StoryScene.fromJson(Map<String, dynamic> json) {
    final dialogue = _reqList(json, 'dialogue')
        .map((e) => DialogueLine.fromJson(_asMap(e, 'dialogue[]')))
        .toList();
    if (dialogue.isEmpty) {
      throw FormatException(
          'StoryScene ${json['scene_id']}: "dialogue" must not be empty');
    }
    return StoryScene(
      sceneId: _reqString(json, 'scene_id'),
      backgroundId: json['background_id'] as String?,
      characterIds:
          (json['character_ids'] as List?)?.cast<String>() ?? const [],
      dialogue: dialogue,
      choices: (json['choices'] as List? ?? const [])
          .map((e) => StoryChoice.fromJson(_asMap(e, 'choices[]')))
          .toList(),
    );
  }
}

class DialogueLine {
  const DialogueLine({required this.characterId, required this.text});

  final String characterId;
  final LocalizedText text;

  factory DialogueLine.fromJson(Map<String, dynamic> json) => DialogueLine(
        characterId: _reqString(json, 'character_id'),
        text: LocalizedText.fromJson(json['text'], field: 'text'),
      );
}

/// An optional interactive choice inside a story scene.
///
/// Choices never block progress — they add a friendly response line and
/// keep the narrative moving.
class StoryChoice {
  const StoryChoice(
      {required this.id, required this.text, required this.response});

  final String id;
  final LocalizedText text;
  final LocalizedText response;

  factory StoryChoice.fromJson(Map<String, dynamic> json) => StoryChoice(
        id: _reqString(json, 'id'),
        text: LocalizedText.fromJson(json['text'], field: 'text'),
        response: LocalizedText.fromJson(json['response'], field: 'response'),
      );
}

class GrammarLesson {
  const GrammarLesson(
      {required this.title, required this.explanation, required this.examples});

  final LocalizedText title;
  final LocalizedText explanation;
  final List<LessonExample> examples;

  factory GrammarLesson.fromJson(Map<String, dynamic> json) {
    final examples = _reqList(json, 'examples')
        .map((e) => LessonExample.fromJson(_asMap(e, 'examples[]')))
        .toList();
    if (examples.isEmpty) {
      throw FormatException('GrammarLesson: "examples" must not be empty');
    }
    return GrammarLesson(
      title: LocalizedText.fromJson(json['title'], field: 'title'),
      explanation:
          LocalizedText.fromJson(json['explanation'], field: 'explanation'),
      examples: examples,
    );
  }
}

class LessonExample {
  const LessonExample({required this.sentence, required this.note});

  /// The English example sentence. It is shown exactly as authored —
  /// translations must never alter the grammar being taught.
  final String sentence;
  final LocalizedText note;

  factory LessonExample.fromJson(Map<String, dynamic> json) {
    final sentence = _reqString(json, 'sentence');
    return LessonExample(
      sentence: sentence,
      note: LocalizedText.fromJson(json['note'] ?? {'en': ''}, field: 'note'),
    );
  }
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String id;

  /// Question text in English — grammar questions stay in English.
  final String question;
  final List<String> options;
  final int correctIndex;
  final LocalizedText explanation;

  bool isCorrect(int index) => index == correctIndex;

  String get correctAnswer => options[correctIndex];

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final id = _reqString(json, 'question_id');
    final options =
        (json['options'] as List?)?.map((e) => e.toString()).toList();
    if (options == null || options.length < 2) {
      throw FormatException(
          'QuizQuestion.$id: "options" needs at least 2 entries');
    }
    final correct = json['correct_index'];
    if (correct is! int || correct < 0 || correct >= options.length) {
      throw FormatException('QuizQuestion.$id: "correct_index" out of range');
    }
    return QuizQuestion(
      id: id,
      question: _reqString(json, 'question'),
      options: options,
      correctIndex: correct,
      explanation:
          LocalizedText.fromJson(json['explanation'], field: 'explanation'),
    );
  }
}

// ---------------------------------------------------------------------------
// JSON helpers — strict about structure, forgiving about optional strings.
// ---------------------------------------------------------------------------

String _reqString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or empty required string "$key"');
  }
  return value;
}

int _reqInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Missing or non-int required field "$key"');
  }
  return value;
}

List<dynamic> _reqList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Missing or non-list required field "$key"');
  }
  return value;
}

Map<String, dynamic> _asMap(Object? value, String field) {
  if (value is! Map) {
    throw FormatException(
        '$field: expected an object, got ${value.runtimeType}');
  }
  return value.cast<String, dynamic>();
}
