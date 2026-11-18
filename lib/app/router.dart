import 'package:material_ui/material_ui.dart';

import '../features/auth/login_screen.dart';
import '../features/chapters/chapter_detail_screen.dart';
import '../features/chapters/chapter_list_screen.dart';
import '../features/completion/chapter_completed_screen.dart';
import '../features/grammar/grammar_lesson_screen.dart';
import '../features/home/home_shell.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/quiz/review_practice_screen.dart';
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
        final chapterId = _chapterIdArg(settings.arguments);
        return _page(
          chapterId == null
              ? const ChapterListScreen()
              : ChapterDetailScreen(chapterId: chapterId),
          settings,
        );
      case StoryScreen.routeName:
        final args = settings.arguments;
        if (args is StoryArgs && args.chapterId.isNotEmpty) {
          return _page(StoryScreen(args: args), settings);
        }
        final chapterId = _chapterIdArg(args);
        return _page(
          chapterId == null
              ? const ChapterListScreen()
              : StoryScreen(args: StoryArgs(chapterId)),
          settings,
        );
      case GrammarLessonScreen.routeName:
        final chapterId = _chapterIdArg(settings.arguments);
        return _page(
          chapterId == null
              ? const ChapterListScreen()
              : GrammarLessonScreen(chapterId: chapterId),
          settings,
        );
      case QuizScreen.routeName:
        final chapterId = _chapterIdArg(settings.arguments);
        return _page(
          chapterId == null
              ? const ChapterListScreen()
              : QuizScreen(chapterId: chapterId),
          settings,
        );
      case ReviewPracticeScreen.routeName:
        return _page(const ReviewPracticeScreen(), settings);
      case ChapterCompletedScreen.routeName:
        final args = settings.arguments;
        return _page(
          args is CompletedArgs
              ? ChapterCompletedScreen(args: args)
              : const HomeShell(),
          settings,
        );
      case ProgressScreen.routeName:
        final tab = settings.arguments is int ? settings.arguments! as int : 0;
        return _page(ProgressScreen(initialTab: tab), settings);
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

  static String? _chapterIdArg(Object? raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static MaterialPageRoute<dynamic> _page(
      Widget child, RouteSettings settings) {
    return MaterialPageRoute<dynamic>(
      builder: (_) => child,
      settings: settings,
    );
  }
}
