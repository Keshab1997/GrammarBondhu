import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/state/content_controller.dart';
import 'app/state/progress_controller.dart';
import 'app/state/settings_controller.dart';
import 'data/local/local_store.dart';
import 'data/repositories/content_repository.dart';
import 'features/audio/audio_controller.dart';
import 'features/audio/audio_port.dart';

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
}
