import 'package:flutter/material.dart';

import '../features/auth/login_screen.dart';
import '../features/chapters/chapter_detail_screen.dart';
import '../features/chapters/chapter_list_screen.dart';
import '../features/completion/chapter_completed_screen.dart';
import '../features/grammar/grammar_lesson_screen.dart';
import '../features/home/home_shell.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/settings/language_selection_screen.dart';
import '../features/settings/offline_download_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/story/story_screen.dart';

/// Central route table — one place to see the whole navigation graph.
class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case SplashScreen.routeName:
        return _page(const SplashScreen(), settings);
      case OnboardingScreen.routeName:
        return _page(const OnboardingScreen(), settings);
      case LoginScreen.routeName:
        return _page(const LoginScreen(), settings);
      case HomeShell.routeName:
        final tab = settings.arguments is int ? settings.arguments! as int : 0;
        return _page(HomeShell(initialTab: tab), settings);
      case ChapterListScreen.routeName:
        return _page(const ChapterListScreen(), settings);
      case ChapterDetailScreen.routeName:
        return _page(ChapterDetailScreen(chapterId: settings.arguments! as String), settings);
      case StoryScreen.routeName:
        return _page(StoryScreen(args: settings.arguments! as StoryArgs), settings);
      case GrammarLessonScreen.routeName:
        return _page(GrammarLessonScreen(chapterId: settings.arguments! as String), settings);
      case QuizScreen.routeName:
        return _page(QuizScreen(chapterId: settings.arguments! as String), settings);
      case ChapterCompletedScreen.routeName:
        return _page(ChapterCompletedScreen(args: settings.arguments! as CompletedArgs), settings);
      case ProgressScreen.routeName:
        return _page(const ProgressScreen(), settings);
      case SettingsScreen.routeName:
        return _page(const SettingsScreen(), settings);
      case LanguageSelectionScreen.routeName:
        return _page(const LanguageSelectionScreen(), settings);
      case OfflineDownloadScreen.routeName:
        return _page(const OfflineDownloadScreen(), settings);
      default:
        return _page(const SplashScreen(), settings);
    }
  }

  static MaterialPageRoute<dynamic> _page(Widget child, RouteSettings settings) {
    return MaterialPageRoute<dynamic>(
      builder: (_) => child,
      settings: settings,
    );
  }
}
