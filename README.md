# GrammarBondhu 📚

**Learn English Through Stories** — a polished, offline-first Flutter app that
teaches English grammar through interactive stories featuring Rahul, a young
Indian student, and his friends.

English is the primary learning language; Bengali (বাংলা) and Hindi (हिन्दी)
provide translations and explanations.

## Features

- 📖 **Story-driven chapters** — 15 chapters follow Rahul, Priya and Mrs. Sen
  through school adventures, with dialogue and optional interactive choices.

  **Beginner · Chapters 1–10**

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

  **Intermediate · Chapters 11–15**

  11. **Planning the Class Picnic** — future plans (will / going to)
  12. **Packing the Picnic Basket** — quantity words (some / any / many / much)
  13. **In the School Garden** — adverbs of manner and frequency
  14. **The Rainy-Day Play** — joining ideas (and / but / because / so)
  15. **Our Class Scrapbook** — present perfect (have / has + past participle)

- 🎬 **Animated auto-play stories** — Rahul, Priya and Mrs. Sen speak their
  lines out loud in Indian English and Bengali across all 15 chapters, with
  mouth shapes measured from each recording's own waveform (pauses, breaths and
  syllable peaks included), natural eye blinks that never cut a word short, and
  automatic line-by-line playback that pauses at interactive choices (with an
  on-stage `Auto` switch)
- 🌐 **Three languages** — English + Bengali + Hindi translations, interactive
  onboarding language picker, live explanation preview in Settings, and
  in-story / in-lesson / in-quiz language toggles (EN / বাংলা / हिन्दी)
- 📝 **Grammar lessons** — rules, examples, character illustrations
- 🎯 **Quizzes & Mistake Practice** — 5 MCQs per chapter with kind, trilingual
  feedback, plus a focused Mistake Practice deck to clear missed questions
  without farming duplicate XP
- 🏆 **Rewards** — XP, coins, stars, current & best streaks, daily goal, level
  progress bar and 7 unlockable achievements
- 💾 **Guest-first + offline** — bundled lessons and local progress work without
  an account; optional Google sign-in can sync progress through Firebase Firestore
- ☁️ **Optional progress backup** — a signed-in learner's local and cloud
  progress snapshots merge; disconnecting never deletes the on-device copy
- 🎨 **Storyboard-matched UI** — 18 screens, rounded cards, friendly colors

## Tech

- Flutter + Dart, Material 3 via `package:material_ui/material_ui.dart`,
  `provider` + `shared_preferences` (deliberately lightweight for low-RAM
  devices), with optional Firebase Auth/Firestore for account sign-in and
  progress backup
- Toolchain pinned in `.fvmrc` (Flutter 3.50.0) and picked up by CI, so a
  drifting `stable` channel cannot change the analyzer rules under us.
  `python3 tool/check_toolchain.py` proves the pin still matches the Android
  side (AGP in `android/settings.gradle.kts`, Gradle in the wrapper, Kotlin
  plugin) — the split that once failed the APK build before any Dart ran
- **JSON-driven content**: `assets/data/manifest.json` +
  `assets/data/chapters/chapter_NN.json` — add a chapter by adding one JSON
  file and one manifest entry; no code changes
- Feature-based structure under `lib/features/`, models under `lib/data/`
- **Lesson standee frames**: `tool/build_teacher_pose_frames.py` authors talking
  and blink frames for Mrs. Sen's three lesson poses (`teacher_pointer`,
  `teacher_book`, `teacher_invite`) with a local, feathered jaw deformation plus
  eyelid bands, so she keeps teaching the board instead of standing frozen
- **Measured lip-sync**: `tool/build_audio_lipsync.py` reads every narration MP3,
  extracts a 20 Hz mouth timeline (vocal energy, open-vowel formant, sibilants,
  real pauses) and writes `lib/features/audio/audio_lipsync.g.dart`. Characters
  then follow the *actual playhead* of the clip that is sounding; re-run
  `python3 tool/build_audio_lipsync.py` whenever narration is regenerated

## Getting started

```bash
flutter pub get
flutter run            # Android device/emulator
flutter test           # automated tests
flutter analyze --no-pub --fatal-infos   # what CI gates on
python3 tool/check_toolchain.py          # Flutter pin vs AGP/Gradle/Kotlin
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
