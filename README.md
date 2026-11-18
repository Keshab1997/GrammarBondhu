# GrammarBondhu 📚

**Learn English Through Stories** — a polished, offline-first Flutter app that
teaches English grammar through interactive stories featuring Rahul, a young
Indian student, and his friends.

English is the primary learning language; Bengali (বাংলা) and Hindi (हिन्दी)
provide translations and explanations.

## Features

- 📖 **Story-driven chapters** — 10 chapters follow Rahul, Priya and Mrs. Sen
  through school adventures, with dialogue and optional interactive choices:
  1. **The New Student** — am / is / are
  2. **A New Friend** — simple present
  3. **The Mystery of the Library** — articles and prepositions
  4. **The Lost Map** — past tense (was / were / -ed)
  5. **The School Adventure** — sentence formation
  6. **Rainy Day at School** — present continuous (am / is / are + -ing)
  7. **Whose Notebook Is This?** — pronouns and possessives
  8. **The Science Exhibition** — adjectives and comparisons
  9. **The School Newspaper** — asking questions (Do / Does / Did and Wh- words)
  10. **Ready for Sports Day** — helpful modals (can / should / must)
- 🌐 **Three languages** — English + Bengali + Hindi translations, in-story
  language toggle (EN / বাং / हि)
- 📝 **Grammar lessons** — rules, examples, character illustrations
- 🎯 **Quizzes** — 5 MCQs per chapter with kind, explanatory feedback
  (correct answer + why, in your language)
- 🏆 **Rewards** — XP, coins, stars, streaks, daily goal, achievements
- 💾 **Guest-first + offline** — bundled lessons and local progress work without
  an account; optional Google sign-in can sync progress through Firebase Firestore
- ☁️ **Optional progress backup** — a signed-in learner's local and cloud
  progress snapshots merge; disconnecting never deletes the on-device copy
- 🎨 **Storyboard-matched UI** — 18 screens, rounded cards, friendly colors

## Tech

- Flutter + Dart, Material 3, `provider` + `shared_preferences` (deliberately
  lightweight for low-RAM devices), with optional Firebase Auth/Firestore for
  account sign-in and progress backup
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

## Optional Google sign-in and cloud backup

Guest mode works without Firebase configuration. To enable account backup:

1. In Firebase Console, register the Android app with package ID
   `com.keshabstudios.grammarbondhu`, enable Google as a sign-in provider, and
   create a Cloud Firestore database.
2. Keep `android/app/google-services.json` local-only (it is git-ignored). For
   the manual Android build workflow, provide the base64 config through the
   `GOOGLE_SERVICES_JSON_BASE64` repository secret; never commit the JSON file.
3. Apply the account-scoped rules in `firestore.rules` before enabling learner
   backups. Each Firebase UID can access only its own progress document.

Learners opt in from Profile. On sign-in, local and cloud snapshots merge before
continuing; later progress changes sync in the background. If Firebase is
unavailable, the lesson continues and local progress remains saved for retry.

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
