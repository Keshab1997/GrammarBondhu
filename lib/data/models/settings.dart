/// App preferences, persisted locally.
///
/// [supportLanguage] is the language used for translations, explanations and
/// story text. English (the learning language) always stays visible.
class AppSettings {
  AppSettings({
    this.supportLanguage = 'bn',
    this.audioEnabled = true,
    this.notificationsEnabled = true,
    this.onboardingComplete = false,
    this.displayName,
    this.isGuest = true,
  });

  /// 'en' | 'bn' | 'hi' — 'en' means "show English only".
  String supportLanguage;
  bool audioEnabled;
  bool notificationsEnabled;
  bool onboardingComplete;

  /// Display name for the local profile; null while in guest mode.
  String? displayName;
  bool isGuest;

  static const supportedLanguages = ['en', 'bn', 'hi'];

  static bool isSupportedLanguage(String code) => supportedLanguages.contains(code);

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final language = json['support_language'] as String? ?? 'bn';
    return AppSettings(
      supportLanguage: isSupportedLanguage(language) ? language : 'bn',
      audioEnabled: json['audio_enabled'] as bool? ?? true,
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      onboardingComplete: json['onboarding_complete'] as bool? ?? false,
      displayName: json['display_name'] as String?,
      isGuest: json['is_guest'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'support_language': supportLanguage,
        'audio_enabled': audioEnabled,
        'notifications_enabled': notificationsEnabled,
        'onboarding_complete': onboardingComplete,
        'display_name': displayName,
        'is_guest': isGuest,
      };
}
