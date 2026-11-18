import 'speech_cadence.dart';

/// Pixel-registered full-body animation frames for one story character.
class CharacterFrames {
  const CharacterFrames({
    required this.closed,
    required this.talkHalf,
    required this.talkOpen,
    required this.blink,
  });

  final String closed;
  final String talkHalf;
  final String talkOpen;
  final String blink;

  /// All frame asset paths, in warm-up order so the resting pose decodes first.
  List<String> get all => [closed, talkHalf, talkOpen, blink];

  /// Body frame carrying the jaw shape only.
  ///
  /// Eyelids are drawn separately (a clipped band lifted from [blink]) so a
  /// blink can land *during* a word: the mouth keeps its vowel shape while the
  /// eyes close, which is what a real face does.
  String baseFor(MouthFrame mouth) {
    switch (mouth) {
      case MouthFrame.open:
        return talkOpen;
      case MouthFrame.half:
        return talkHalf;
      case MouthFrame.closed:
        return closed;
    }
  }

  /// Selects the frame for the current mouth shape and blink state.
  ///
  /// Open-mouth speech takes priority over a blink unless the mouth is closed
  /// between phrases, because our blink frame keeps a gentle closed smile.
  String resolve({required MouthFrame mouth, required bool blinking}) {
    if (mouth == MouthFrame.open) return talkOpen;
    if (mouth == MouthFrame.half) return talkHalf;
    return blinking ? blink : closed;
  }
}

/// Resolves content asset IDs to bundled file paths.
///
/// Every render path must tolerate a missing file — the UI widgets use
/// `Image.asset(..., errorBuilder: ...)` so the story still works while
/// illustration assets are being produced. See `assets/README.md` for the
/// asset inventory and what is still a placeholder.
class AssetLookup {
  const AssetLookup._();

  static const Map<String, String> characters = {
    'rahul': 'assets/characters/rahul.webp',
    'priya': 'assets/characters/priya.webp',
    'teacher': 'assets/characters/teacher.webp',
  };

  /// Full-body cut-outs (transparent PNG/WebP) used by the story stage, where
  /// the characters stand in the scene and speak in bubbles. The portrait
  /// files above stay for avatars.
  static const Map<String, String> fullBodyCharacters = {
    'rahul': 'assets/characters/rahul_full.webp',
    'priya': 'assets/characters/priya_full.webp',
    'teacher': 'assets/characters/teacher_full.webp',
  };

  /// Talking and blinking full-body frames aligned pixel-for-pixel to
  /// [fullBodyCharacters] so only the mouth and eyelids move during dialogue.
  static const Map<String, CharacterFrames> characterFrames = {
    'rahul': CharacterFrames(
      closed: 'assets/characters/rahul_full.webp',
      talkHalf: 'assets/characters/rahul_talk_half.webp',
      talkOpen: 'assets/characters/rahul_talk_open.webp',
      blink: 'assets/characters/rahul_blink.webp',
    ),
    'priya': CharacterFrames(
      closed: 'assets/characters/priya_full.webp',
      talkHalf: 'assets/characters/priya_talk_half.webp',
      talkOpen: 'assets/characters/priya_talk_open.webp',
      blink: 'assets/characters/priya_blink.webp',
    ),
    'teacher': CharacterFrames(
      closed: 'assets/characters/teacher_full.webp',
      talkHalf: 'assets/characters/teacher_talk_half.webp',
      talkOpen: 'assets/characters/teacher_talk_open.webp',
      blink: 'assets/characters/teacher_blink.webp',
    ),
  };

  static const Map<String, String> backgrounds = {
    'bg_school_gate': 'assets/backgrounds/bg_school_gate.webp',
    'bg_classroom': 'assets/backgrounds/bg_classroom.webp',
    'bg_school_garden': 'assets/backgrounds/bg_school_garden.webp',
    'bg_library': 'assets/backgrounds/bg_library.webp',
  };

  /// Per-chapter scene plates: a chapter draws its own version of a set
  /// (its classroom, its garden) instead of reusing the same four plates
  /// for fifteen different stories.
  static const Map<String, String> chapterScenes = {
    'ch01_classroom': 'assets/backgrounds/scene_ch01_classroom.webp',
    'ch02_classroom': 'assets/backgrounds/scene_ch02_classroom.webp',
    'ch03_garden': 'assets/backgrounds/scene_ch03_garden.webp',
    'ch04_classroom': 'assets/backgrounds/scene_ch04_classroom.webp',
    'ch04_garden': 'assets/backgrounds/scene_ch04_garden.webp',
    'ch05_classroom': 'assets/backgrounds/scene_ch05_classroom.webp',
    'ch06_classroom': 'assets/backgrounds/scene_ch06_classroom.webp',
    'ch07_classroom': 'assets/backgrounds/scene_ch07_classroom.webp',
    'ch08_classroom': 'assets/backgrounds/scene_ch08_classroom.webp',
    'ch09_classroom': 'assets/backgrounds/scene_ch09_classroom.webp',
  };

  static const Map<String, String> illustrations = {
    'ch01_thumb': 'assets/illustrations/ch01_thumb.webp',
    'ch02_thumb': 'assets/illustrations/ch02_thumb.webp',
    'ch03_thumb': 'assets/illustrations/ch03_thumb.webp',
    'ch04_thumb': 'assets/illustrations/ch04_thumb.webp',
    'ch05_thumb': 'assets/illustrations/ch05_thumb.webp',
    'ch06_thumb': 'assets/illustrations/ch06_thumb.webp',
    'ch07_thumb': 'assets/illustrations/ch07_thumb.webp',
    'ch08_thumb': 'assets/illustrations/ch08_thumb.webp',
    'ch09_thumb': 'assets/illustrations/ch09_thumb.webp',
    'ch10_thumb': 'assets/illustrations/ch10_thumb.webp',
    'ch11_thumb': 'assets/illustrations/ch11_thumb.webp',
    'ch12_thumb': 'assets/illustrations/ch12_thumb.webp',
    'ch13_thumb': 'assets/illustrations/ch13_thumb.webp',
    'ch14_thumb': 'assets/illustrations/ch14_thumb.webp',
    'ch15_thumb': 'assets/illustrations/ch15_thumb.webp',
    // Storyboard-matched screen hero illustrations (3D Pixar style).
    'splash_hero': 'assets/illustrations/splash_hero.webp',
    'onboarding_welcome': 'assets/illustrations/onboarding_welcome.webp',
    'onboarding_languages': 'assets/illustrations/onboarding_languages.webp',
    'onboarding_story_world':
        'assets/illustrations/onboarding_story_world.webp',
    'login_hero': 'assets/illustrations/login_hero.webp',
    'chapter_completed': 'assets/illustrations/chapter_completed.webp',
    'quiz_time': 'assets/illustrations/quiz_time.webp',
    'grammar_lesson': 'assets/illustrations/grammar_lesson.webp',
    'story_dialogue_bg': 'assets/illustrations/story_dialogue_bg.webp',
    'progress_avatar': 'assets/illustrations/progress_avatar.webp',
    'offline_download': 'assets/illustrations/offline_download.webp',
    'chapter_detail_hero': 'assets/illustrations/chapter_detail_hero.webp',
    'rewards_trophy': 'assets/illustrations/rewards_trophy.webp',
    'locked_chapter': 'assets/illustrations/locked_chapter.webp',
  };

  /// One grammar-topic badge per chapter, drawn for that chapter alone.
  /// The grammar-topic badge for [chapterId], or null when that chapter has no
  /// art yet (the chapter page then keeps its shared glyph).
  static String? topicIcon(String chapterId) => topicIcons[chapterId];

  /// The plate for [chapterId] in [backgroundId], or null when this chapter
  /// has no art of its own for that set — callers then keep the shared plate.
  static String? chapterScenePath(String chapterId, String? backgroundId) {
    if (backgroundId == null) return null;
    // A scene asks by set name (`bg_classroom`) or by its own plate id
    // (`ch04_classroom`); both resolve to "<chapter>_<set>".
    final set = backgroundId.startsWith('bg_')
        ? backgroundId.substring(3)
        : backgroundId.startsWith('${chapterId}_')
            ? backgroundId.substring(chapterId.length + 1)
            : backgroundId;
    return chapterScenes['${chapterId}_$set'];
  }

  static const Map<String, String> topicIcons = {
    'ch01': 'assets/icons/topic_ch01.webp',
    'ch02': 'assets/icons/topic_ch02.webp',
    'ch03': 'assets/icons/topic_ch03.webp',
    'ch04': 'assets/icons/topic_ch04.webp',
    'ch05': 'assets/icons/topic_ch05.webp',
    'ch06': 'assets/icons/topic_ch06.webp',
    'ch07': 'assets/icons/topic_ch07.webp',
    'ch08': 'assets/icons/topic_ch08.webp',
    'ch09': 'assets/icons/topic_ch09.webp',
    'ch10': 'assets/icons/topic_ch10.webp',
    'ch11': 'assets/icons/topic_ch11.webp',
    'ch12': 'assets/icons/topic_ch12.webp',
    'ch13': 'assets/icons/topic_ch13.webp',
    'ch14': 'assets/icons/topic_ch14.webp',
    'ch15': 'assets/icons/topic_ch15.webp',
  };

  static const Map<String, String> branding = {
    'logo_with_char': 'assets/branding/logo_with_char.webp',
  };

  static const Map<String, String> icons = {
    'flag_en': 'assets/icons/flag_en.webp',
    'flag_bn': 'assets/icons/flag_bn.webp',
    'flag_hi': 'assets/icons/flag_hi.webp',
  };

  /// Fractional height of the band that contains only hair, brow and eyelids,
  /// measured from each shipped sprite (the diff between `*_full` and `*_blink`
  /// stops before the mouth on every character, so a blink band never eats a
  /// vowel). Used to overlay a blink while the jaw keeps talking.
  static double eyeBandFraction(String characterId) {
    switch (characterId) {
      case 'rahul':
        return 0.173;
      case 'priya':
        return 0.135;
      case 'teacher':
        return 0.115;
      default:
        return 0.14;
    }
  }

  static String? characterPath(String characterId) => characters[characterId];

  static String? fullBodyPath(String characterId) =>
      fullBodyCharacters[characterId];

  static CharacterFrames? framesFor(String characterId) =>
      characterFrames[characterId];

  static String? backgroundPath(String backgroundId) =>
      backgrounds[backgroundId];

  /// Blurred props that belong *in front of* the cast, keyed by background.
  /// A doorway/pillar edge in the foreground is what stops two flat cut-outs
  /// from looking pasted onto a picture: the props cue depth, so the eye reads
  /// the characters as standing inside the room.
  static const Map<String, String> foregrounds = {
    'bg_school_gate': 'assets/foregrounds/fg_gate.webp',
    'bg_classroom': 'assets/foregrounds/fg_class.webp',
  };

  static String? foregroundPath(String backgroundId) =>
      foregrounds[backgroundId];

  static String? illustrationPath(String illustrationId) =>
      illustrations[illustrationId];

  static String? brandingPath(String brandingId) => branding[brandingId];

  static String? iconPath(String iconId) => icons[iconId];

  /// Friendly display name for a character id (used in dialogue captions
  /// and as the fallback when a portrait asset is missing).
  static String characterDisplayName(String characterId) {
    switch (characterId) {
      case 'rahul':
        return 'Rahul';
      case 'priya':
        return 'Priya';
      case 'teacher':
        return 'Mrs. Sen';
      default:
        final cleaned = characterId.replaceAll('_', ' ').trim();
        if (cleaned.isEmpty) return 'Narrator';
        return cleaned[0].toUpperCase() + cleaned.substring(1);
    }
  }
}
