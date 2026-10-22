import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/audio/audio_controller.dart';
import '../features/splash/splash_screen.dart';
import 'router.dart';
import 'state/content_controller.dart';
import 'state/progress_controller.dart';
import 'state/settings_controller.dart';
import 'theme/app_theme.dart';

/// Root widget — dependency wiring and theming.
class GrammarBondhuApp extends StatelessWidget {
  const GrammarBondhuApp({
    super.key,
    required this.contentController,
    required this.settingsController,
    required this.progressController,
    this.audioController,
  });

  final ContentController contentController;
  final SettingsController settingsController;
  final ProgressController progressController;

  /// Null in tests that do not care about sound: every speaker button then
  /// renders as nothing, and nothing tries to open an audio device.
  final AudioController? audioController;

  @override
  Widget build(BuildContext context) {
    final app = MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: contentController),
        ChangeNotifierProvider.value(value: settingsController),
        ChangeNotifierProvider.value(value: progressController),
      ],
      child: MaterialApp(
        title: 'GrammarBondhu',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        initialRoute: SplashScreen.routeName,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );

    // No controller, no scope: a test that only checks layout gets a UI with
    // no speakers rather than a widget that tries to open an audio device.
    final audio = audioController;
    if (audio == null) return app;
    return AudioScope(controller: audio, child: app);
  }
}
