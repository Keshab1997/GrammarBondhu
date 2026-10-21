/// Resolves content asset IDs to bundled file paths.
///
/// Every render path must tolerate a missing file — the UI widgets use
/// `Image.asset(..., errorBuilder: ...)` so the story still works while
/// illustration assets are being produced. See `assets/README.md` for the
/// asset inventory and what is still a placeholder.
class AssetLookup {
  const AssetLookup._();

  static const Map<String, String> characters = {
    'rahul': 'assets/characters/rahul.png',
    'priya': 'assets/characters/priya.png',
    'teacher': 'assets/characters/teacher.png',
  };

  static const Map<String, String> backgrounds = {
    'bg_school_gate': 'assets/backgrounds/bg_school_gate.png',
    'bg_classroom': 'assets/backgrounds/bg_classroom.png',
    'bg_school_garden': 'assets/backgrounds/bg_school_garden.png',
    'bg_library': 'assets/backgrounds/bg_library.png',
  };

  static const Map<String, String> illustrations = {
    'ch01_thumb': 'assets/illustrations/ch01_thumb.png',
    'ch02_thumb': 'assets/illustrations/ch02_thumb.png',
    'ch03_thumb': 'assets/illustrations/ch03_thumb.png',
    'ch04_thumb': 'assets/illustrations/ch04_thumb.png',
    'ch05_thumb': 'assets/illustrations/ch05_thumb.png',
  };

  static String? characterPath(String characterId) => characters[characterId];

  static String? backgroundPath(String backgroundId) => backgrounds[backgroundId];

  static String? illustrationPath(String illustrationId) => illustrations[illustrationId];

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
