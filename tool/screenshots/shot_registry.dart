// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:grammar_bondhu/app/router.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/app/theme/app_theme.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/models/progress.dart';
import 'package:grammar_bondhu/data/models/settings.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/features/chapters/chapter_detail_screen.dart';
import 'package:grammar_bondhu/features/chapters/chapter_list_screen.dart';
import 'package:grammar_bondhu/features/grammar/grammar_lesson_screen.dart';
import 'package:grammar_bondhu/features/home/home_screen.dart';
import 'package:grammar_bondhu/features/home/home_shell.dart';
import 'package:grammar_bondhu/features/onboarding/onboarding_screen.dart';
import 'package:grammar_bondhu/features/progress/progress_screen.dart';
import 'package:grammar_bondhu/features/quiz/quiz_screen.dart';
import 'package:grammar_bondhu/features/quiz/review_practice_screen.dart';
import 'package:grammar_bondhu/features/rewards/rewards_screen.dart';
import 'package:grammar_bondhu/features/settings/language_selection_screen.dart';
import 'package:grammar_bondhu/features/story/story_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shot_framework.dart';

late ContentController _content;
late LocalStore _store;
final DateTime _shotDate = DateTime(2026, 11, 18, 9, 30);

Map<String, Object> _learnerState({
  String language = 'bn',
  UserProgress? progress,
}) =>
    <String, Object>{
      'app_settings_v1': jsonEncode(
        AppSettings(
          supportLanguage: language,
          onboardingComplete: true,
          isGuest: true,
        ).toJson(),
      ),
      if (progress != null) 'user_progress_v1': jsonEncode(progress.toJson()),
    };

UserProgress _midCourseWithMistakes() => UserProgress(
      totalXp: 760,
      coins: 152,
      streakDays: 5,
      bestStreakDays: 7,
      lastStudyDate: _shotDate,
      questionsAnsweredToday: 3,
      dailyGoalQuestions: 5,
      lastQuestionDate: _shotDate,
      chapters: <String, ChapterProgress>{
        for (var i = 1; i <= 10; i++)
          'ch${i.toString().padLeft(2, '0')}': ChapterProgress(
            chapterId: 'ch${i.toString().padLeft(2, '0')}',
            completed: true,
            bestScorePercent: i == 1 ? 100 : 80,
            stars: i == 1 ? 3 : 2,
            attempts: 1,
            missedQuestionIds: i == 10 ? <String>{'ch10_q2'} : <String>{},
          ),
        'ch11': ChapterProgress(
          chapterId: 'ch11',
          resumeSceneIndex: 1,
          missedQuestionIds: <String>{'ch11_q1'},
        ),
      },
    );

final ShotEnv env = ShotEnv(
  fontAssets: const <String, String>{
    'Baloo2': 'assets/fonts/Baloo2-700.ttf',
    'Roboto': 'assets/fonts/Baloo2-600.ttf',
    'NotoSansBengali': 'assets/fonts/NotoSansBengali-Regular.ttf',
    'NotoSansDevanagari': 'assets/fonts/NotoSansDevanagari-Regular.ttf',
  },
  setUpAll: () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    _store = await LocalStore.open();
    _content = ContentController(ContentRepository());
    await _content.load();
  },
  seedPreferences: (values) async {
    SharedPreferences.setMockInitialValues(values);
    _store = await LocalStore.open();
  },
  wrap: (child) => MultiProvider(
    providers: [
      ChangeNotifierProvider<ContentController>.value(value: _content),
      ChangeNotifierProvider<SettingsController>(
        create: (_) => SettingsController(_store, _store.loadSettings()),
      ),
      ChangeNotifierProvider<ProgressController>(
        create: (_) => ProgressController(_store, _store.loadProgress()),
      ),
    ],
    child: child,
  ),
  app: (shot, home) => MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: home,
    ),
  ),
);

final List<Shot> shots = <Shot>[
  Shot(
    name: 'onboarding',
    dark: false,
    build: () => const OnboardingScreen(),
  ),
  Shot(
    name: 'home',
    dark: false,
    build: () => const HomeShell(),
  ),
  Shot(
    name: 'home-review',
    dark: false,
    preferences: _learnerState(progress: _midCourseWithMistakes()),
    logicalSize: const Size(390, 1100),
    build: () => Scaffold(body: HomeScreen(now: _shotDate)),
  ),
  Shot(
    name: 'chapters-intermediate',
    dark: false,
    preferences: _learnerState(progress: _midCourseWithMistakes()),
    logicalSize: const Size(390, 1500),
    build: () => const ChapterListScreen(),
  ),
  Shot(
    name: 'chapter-11-detail',
    dark: false,
    preferences: _learnerState(progress: _midCourseWithMistakes()),
    build: () => const ChapterDetailScreen(chapterId: 'ch11'),
  ),
  Shot(
    name: 'story-ch11',
    dark: false,
    preferences: _learnerState(),
    build: () => const StoryScreen(args: StoryArgs('ch11')),
  ),
  Shot(
    name: 'grammar-lesson-ch11',
    dark: false,
    preferences: _learnerState(),
    build: () => const GrammarLessonScreen(chapterId: 'ch11'),
  ),
  Shot(
    name: 'quiz-ch11',
    dark: false,
    preferences: _learnerState(),
    build: () => const QuizScreen(chapterId: 'ch11'),
  ),
  Shot(
    name: 'review-practice',
    dark: false,
    preferences: _learnerState(progress: _midCourseWithMistakes()),
    build: () => const ReviewPracticeScreen(),
  ),
  Shot(
    name: 'progress-review',
    dark: false,
    preferences: _learnerState(progress: _midCourseWithMistakes()),
    build: () => ProgressScreen(now: _shotDate, initialTab: 3),
  ),
  Shot(
    name: 'rewards',
    dark: false,
    preferences: _learnerState(progress: _midCourseWithMistakes()),
    logicalSize: const Size(390, 1200),
    build: () => const Scaffold(body: RewardsScreen()),
  ),
  Shot(
    name: 'language',
    dark: false,
    preferences: _learnerState(language: 'bn'),
    build: () => const LanguageSelectionScreen(),
  ),
];
