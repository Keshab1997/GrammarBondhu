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

  static const Map<String, String> backgrounds = {
    'bg_school_gate': 'assets/backgrounds/bg_school_gate.webp',
    'bg_classroom': 'assets/backgrounds/bg_classroom.webp',
    'bg_school_garden': 'assets/backgrounds/bg_school_garden.webp',
    'bg_library': 'assets/backgrounds/bg_library.webp',
  };

  static const Map<String, String> illustrations = {
    'ch01_thumb': 'assets/illustrations/ch01_thumb.webp',
    'ch02_thumb': 'assets/illustrations/ch02_thumb.webp',
    'ch03_thumb': 'assets/illustrations/ch03_thumb.webp',
    'ch04_thumb': 'assets/illustrations/ch04_thumb.webp',
    'ch05_thumb': 'assets/illustrations/ch05_thumb.webp',
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

  static const Map<String, String> branding = {
    'logo_with_char': 'assets/branding/logo_with_char.webp',
  };

  static const Map<String, String> icons = {
    'flag_en': 'assets/icons/flag_en.webp',
    'flag_bn': 'assets/icons/flag_bn.webp',
    'flag_hi': 'assets/icons/flag_hi.webp',
  };

  static String? characterPath(String characterId) => characters[characterId];

  static String? fullBodyPath(String characterId) =>
      fullBodyCharacters[characterId];

  static String? backgroundPath(String backgroundId) =>
      backgrounds[backgroundId];

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
