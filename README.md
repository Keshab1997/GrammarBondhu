# GrammarBondhu 📚

**Learn English Through Stories** — a polished, offline-first Flutter app that
teaches English grammar through interactive stories featuring Rahul, a young
Indian student, and his friends.

English is the primary learning language; Bengali (বাংলা) and Hindi (हिन्दী)
provide translations and explanations.

## Features

- 📖 **Story-driven chapters** — 5 chapters (am/is/are, simple present, articles
  & prepositions, past tense, sentence formation) with scenes, dialogue and
  optional interactive choices
- 🌐 **Three languages** — English + Bengali + Hindi translations, in-story
  language toggle (EN / বাং / हि)
- 📝 **Grammar lessons** — rules, examples, character illustrations
- 🎯 **Quizzes** — 5 MCQs per chapter with kind, explanatory feedback
  (correct answer + why, in your language)
- 🏆 **Rewards** — XP, coins, stars, streaks, daily goal, achievements
- 💾 **Offline-first** — all content bundled as JSON, progress saved locally
  (SharedPreferences), no backend, no accounts required (guest mode)
- 🎨 **Storyboard-matched UI** — 18 screens, rounded cards, friendly colors

## Tech

- Flutter + Dart, Material 3, `provider` + `shared_preferences` (deliberately
  lightweight for low-RAM devices)
- **JSON-driven content**: `assets/data/manifest.json` +
  `assets/data/chapters/chapter_NN.json` — add a chapter by adding one JSON
  file and one manifest entry; no code changes
- Feature-based structure under `lib/features/`, models under `lib/data/`

## Getting started

```bash
flutter pub get
flutter run            # Android device/emulator
flutter test           # automated tests
```

## Build an APK

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

## Content authoring

1. Create `assets/data/chapters/chapter_NN.json` (see any existing chapter for
   the schema: scenes, dialogue en/bn/hi, lesson, quiz with 4 options,
   explanations in all three languages, rewards).
2. Register it in `assets/data/manifest.json`.
3. `flutter test` validates every bundled chapter.

## Asset inventory

See `assets/README.md` — which art is finished and which is still a placeholder.
The app never depends on an asset: every image has a designed fallback.

## Package

`com.keshabstudios.grammarbondhu` — Play Store title suggestion:
**"GrammarBondhu: Learn English"**.
