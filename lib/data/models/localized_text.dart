/// A piece of learner-facing text in the three supported languages.
///
/// English is always required — it is the primary learning language.
/// Bengali and Hindi are supporting translations and fall back to English
/// when missing. All learner-facing content flows through this type so the
/// UI never hardcodes translated strings.
class LocalizedText {
  const LocalizedText({required this.en, this.bn, this.hi});

  final String en;
  final String? bn;
  final String? hi;

  factory LocalizedText.fromJson(Object? json, {String field = 'text'}) {
    if (json is! Map) {
      throw FormatException(
          'LocalizedText.$field: expected an object, got ${json.runtimeType}');
    }
    final map = json.cast<String, dynamic>();
    final en = map['en'] as String?;
    if (en == null || en.trim().isEmpty) {
      throw FormatException('LocalizedText.$field: missing or empty "en" text');
    }
    return LocalizedText(
      en: en,
      bn: _optionalString(map['bn']),
      hi: _optionalString(map['hi']),
    );
  }

  static String? _optionalString(Object? value) {
    if (value == null) return null;
    if (value is! String) return value.toString();
    return value.trim().isEmpty ? null : value;
  }

  Map<String, dynamic> toJson() => {
        'en': en,
        if (bn != null) 'bn': bn,
        if (hi != null) 'hi': hi,
      };

  /// Returns the text in [languageCode] ('en', 'bn' or 'hi'),
  /// falling back to English for unsupported or missing languages.
  String of(String languageCode) {
    switch (languageCode) {
      case 'bn':
        return bn ?? en;
      case 'hi':
        return hi ?? en;
      default:
        return en;
    }
  }

  /// Whether a translation exists for [languageCode] (English always does).
  bool has(String languageCode) =>
      languageCode == 'en' ||
      of(languageCode) != en ||
      (languageCode == 'bn' && bn != null) ||
      (languageCode == 'hi' && hi != null);

  @override
  bool operator ==(Object other) =>
      other is LocalizedText &&
      other.en == en &&
      other.bn == bn &&
      other.hi == hi;

  @override
  int get hashCode => Object.hash(en, bn, hi);

  @override
  String toString() => 'LocalizedText(en: $en)';
}
