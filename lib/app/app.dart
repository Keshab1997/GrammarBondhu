import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  });

  final ContentController contentController;
  final SettingsController settingsController;
  final ProgressController progressController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
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
  }
}
