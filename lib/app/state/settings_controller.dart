import 'package:flutter/foundation.dart';

import '../../data/local/local_store.dart';
import '../../data/models/settings.dart';

/// App-wide preferences (support language, audio, notifications, profile).
class SettingsController extends ChangeNotifier {
  SettingsController(this._store, AppSettings initial) : _settings = initial;

  final LocalStore _store;
  final AppSettings _settings;

  AppSettings get settings => _settings;

  /// Language used for translations and explanations ('en' | 'bn' | 'hi').
  String get supportLanguage => _settings.supportLanguage;

  /// True when translations should be shown at all (support language != en).
  bool get showTranslations => _settings.supportLanguage != 'en';

  /// Narration on/off — the master switch behind every speaker in the app.
  bool get audioEnabled => _settings.audioEnabled;

  /// Whether story scenes speak and advance automatically between lines.
  bool get autoPlayStory => _settings.autoPlayStory;

  /// Every chapter open, regardless of what came before it.
  bool get unlockAllChapters => _settings.unlockAllChapters;

  bool get cloudConnected =>
      !_settings.isGuest && (_settings.cloudAccountId?.isNotEmpty ?? false);

  Future<void> setSupportLanguage(String code) async {
    if (!AppSettings.isSupportedLanguage(code)) return;
    _settings.supportLanguage = code;
    notifyListeners();
    await _store.saveSettings(_settings);
  }

  Future<void> setAudioEnabled(bool value) async {
    _settings.audioEnabled = value;
    notifyListeners();
    await _store.saveSettings(_settings);
  }

  Future<void> setAutoPlayStory(bool value) async {
    if (_settings.autoPlayStory == value) return;
    _settings.autoPlayStory = value;
    notifyListeners();
    await _store.saveSettings(_settings);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _settings.notificationsEnabled = value;
    notifyListeners();
    await _store.saveSettings(_settings);
  }

  Future<void> setUnlockAllChapters(bool value) async {
    if (_settings.unlockAllChapters == value) return;
    _settings.unlockAllChapters = value;
    notifyListeners();
    await _store.saveSettings(_settings);
  }

  Future<void> completeOnboarding() async {
    _settings.onboardingComplete = true;
    notifyListeners();
    await _store.saveSettings(_settings);
  }

  /// Local-only profile: no backend, no real auth in v1.
  Future<void> signInLocally(String displayName) async {
    _settings
      ..displayName = displayName.trim()
      ..cloudAccountId = null
      ..isGuest = false;
    notifyListeners();
    await _store.saveSettings(_settings);
  }

  /// Account-backed profile. The UID is an identifier only; auth credentials
  /// remain owned by Firebase and are never copied into local preferences.
  Future<void> signInWithGoogle({
    required String displayName,
    required String userId,
  }) async {
    _settings
      ..displayName = displayName.trim()
      ..cloudAccountId = userId
      ..isGuest = false;
    notifyListeners();
    await _store.saveSettings(_settings);
  }

  Future<void> signOutToGuest() async {
    _settings
      ..displayName = null
      ..cloudAccountId = null
      ..isGuest = true;
    notifyListeners();
    await _store.saveSettings(_settings);
  }

  Future<void> continueAsGuest() async {
    _settings
      ..displayName = null
      ..cloudAccountId = null
      ..isGuest = true;
    notifyListeners();
    await _store.saveSettings(_settings);
  }

  String get greetingName => (_settings.displayName?.isNotEmpty ?? false)
      ? _settings.displayName!
      : 'Rahul';
}
