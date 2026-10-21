import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/progress.dart';
import '../models/settings.dart';

/// Local persistence for progress and settings.
///
/// SharedPreferences is a deliberate choice: the state is a few small
/// key-value records, it works fully offline, and it adds no native build
/// weight — important for the target hardware.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _progressKey = 'user_progress_v1';
  static const _settingsKey = 'app_settings_v1';

  /// Opens the local store. Uses mock values in tests.
  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  UserProgress loadProgress() {
    final raw = _prefs.getString(_progressKey);
    if (raw == null) return UserProgress();
    try {
      return UserProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt record: start fresh rather than crash the learner out.
      return UserProgress();
    }
  }

  Future<void> saveProgress(UserProgress progress) async {
    await _prefs.setString(_progressKey, jsonEncode(progress.toJson()));
  }

  AppSettings loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null) return AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<void> clearAll() async {
    await _prefs.remove(_progressKey);
    await _prefs.remove(_settingsKey);
  }
}
