import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/state/content_controller.dart';
import 'app/state/progress_controller.dart';
import 'app/state/settings_controller.dart';
import 'data/local/local_store.dart';
import 'data/repositories/content_repository.dart';
import 'features/audio/audio_controller.dart';
import 'features/audio/audio_port.dart';
import 'features/auth/google_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Offline-first: everything needed is loaded from the app bundle and
  // local storage before the first frame.
  final store = await LocalStore.open();
  final contentController = ContentController(ContentRepository());
  final settingsController = SettingsController(store, store.loadSettings());
  final progressController = ProgressController(store, store.loadProgress());
  // Narration plays from clips bundled in the APK, so it works with the phone
  // in aeroplane mode — the whole app is offline-first, audio included.
  final audioController = AudioController(
    port: JustAudioPort(),
    settings: settingsController,
  );

  runApp(GrammarBondhuApp(
    contentController: contentController,
    settingsController: settingsController,
    progressController: progressController,
    audioController: audioController,
  ));

  // Only a previously connected account reaches Firebase, and this runs after
  // the first frame so guests and first launches stay offline and responsive.
  if (settingsController.settings.cloudAccountId != null) {
    unawaited(_restoreCloudBackup(settingsController, progressController));
  }
}

Future<void> _restoreCloudBackup(
  SettingsController settings,
  ProgressController progress,
) async {
  final expectedUserId = settings.settings.cloudAccountId;
  if (expectedUserId == null) return;
  try {
    final user = await GoogleAuth.instance.restoreUser();
    // Re-check local account state after the async restore in case the learner
    // disconnected or switched accounts on Profile while startup was in flight.
    if (user == null ||
        user.uid != expectedUserId ||
        settings.settings.cloudAccountId != expectedUserId ||
        progress.cloudConnected) {
      return;
    }
    await progress.connectCloudBackup(userId: user.uid);
  } catch (error) {
    // Firebase may be temporarily unavailable or not configured in this build;
    // local learning continues and Profile can retry later.
    debugPrint('GrammarBondhu cloud restore unavailable: $error');
  }
}
