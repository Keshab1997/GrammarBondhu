# Worker B — `trilingual-ux-and-accessibility` (Batch `gb-b2`)

- **Target repo:** `Keshab1997/GrammarBondhu`
- **Reused Arena branch:** `arena/77b265ce-grammarbondhu`
- **Pinned `base_sha`:** `f7067045d6efd3ff5a9e2c3ebadcaa54ed852119` *(your verified `gb-b1` tip — do NOT rebase, reset, or merge `main`)*
- **Tracker issue:** https://github.com/Keshab1997/GrammarBondhu/issues/6
- **Gate:** `{"kind": "preflight"}` in worker sandbox (`storage.googleapis.com` is blocked in attached sandboxes); Captain runs full Flutter `3.50.0` `dart format`, `flutter analyze`, and `flutter test` before landing on `main`.

## Allowed files (exact — touch nothing else)

1. `lib/features/onboarding/onboarding_screen.dart`
2. `lib/features/settings/language_selection_screen.dart`
3. `lib/features/grammar/grammar_lesson_screen.dart`
4. `lib/features/quiz/quiz_screen.dart`
5. `lib/features/chapters/chapter_list_screen.dart`
6. `lib/features/chapters/chapter_detail_screen.dart`
7. `test/onboarding_guest_flow_test.dart`
8. `test/quiz_completion_test.dart`
9. `test/accessibility_text_scaling_test.dart`

## Requirements

### 1. Interactive onboarding language picker & lifecycle cleanup (`lib/features/onboarding/onboarding_screen.dart`)
- Dispose `_controller` in `dispose()`.
- Add a `_finishing` guard on `_next()` and `_skip()` so rapid double-taps on `'Get Started'` or `'Skip'` cannot persist/navigate twice. Keep onboarding 100% guest-first (no sign-in gate, `'Skip'` and `'Next'` → `'Get Started'` labels unchanged so existing smoke tests pass!).
- On page 2 (`'3 Languages,\n1 Goal'`):
  - Replace the static non-interactive `Row` of `LanguageChip`s with an interactive centered `Wrap(alignment: WrapAlignment.center, spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, ...)` offering `'en'` (`'English'`), `'bn'` (`'বাংলা'`), and `'hi'` (`'हिन्दी'`).
  - Watch `SettingsController.supportLanguage`, style the active chip distinctly (filled primary with white text vs soft surface with primary border/text), enforce `minHeight: 48` touch target on each chip, wrap each in `Semantics(button: true, selected: selected, label: ...)` (`excludeSemantics` where appropriate so the label isn't read twice), and call `context.read<SettingsController>().setSupportLanguage(code)` on tap.
  - Fix the Bengali spelling on page 2 from `'হিন্দী'` to standard `'হিন্দি'` (`'আপনি বাংলা বা হিন্দি ভাষায় অনুবাদ দেখতে পারবেন।'`).
  - Ensure no layout overflow at `320 dp` width across `100%`, `130%`, and `200%` text scaling.

### 2. Explanation language selection polish (`lib/features/settings/language_selection_screen.dart`)
- Expose `Semantics(button: true, selected: isSelected)` on each language option card so assistive tech announces the active selection, with at least `48 dp` height.
- Add a concise **Preview** `AppCard` below the 3 options showing a sample sentence (`'I am holding my umbrella.'`) plus how its grammar note reads in `_selected`:
  - `'en'`: `'Use am with I.'`
  - `'bn'`: `'I-এর সঙ্গে am বসে।'`
  - `'hi'`: `'I के साथ am लगता है।'`
- Ensure zero overflow at `320 dp` width up to `200%` text scaling.

### 3. Accessible 48 dp lesson controls (`lib/features/grammar/grammar_lesson_screen.dart`)
- Give `_GlassButton` (the top-left close button) a `>= 48 × 48 dp` hit box (`ConstrainedBox(constraints: const BoxConstraints(minWidth: 48, minHeight: 48))` + `Tooltip(message: 'Close lesson')` so screen readers announce its purpose).
- Give the board language toggle pill (`_LangPill`) a `>= 48 dp` tap target height (you can keep the painted pill sleek while giving the `InkWell`/`Semantics` wrapper a `48 dp` minimum height) and clear button semantics, without causing any overflow at `320 dp` or `200%` text scale.

### 4. On-the-spot trilingual quiz explanation switcher (`lib/features/quiz/quiz_screen.dart`)
- Add `tooltip: 'Close quiz'` on the top-left close/back `IconButton` if not already set.
- Add nullable `String? _explanationLang;` state (reset to `null` inside `_next` when advancing and inside `_tryAgain`). Define `final activeLang = _explanationLang ?? settings.supportLanguage;` and render `question.explanation.resolve(activeLang)` inside the submitted feedback card — so default behavior is 100% unchanged when untouched!
- When `question.explanation.bn != null || question.explanation.hi != null`, include a compact accessible `Wrap` inside the submitted feedback card with pills for `'en'` (`'EN'`), and when available `'bn'` (`'বাংলা'`) and `'hi'` (`'हिन्दी'`), each with `minWidth: 48, minHeight: 48` interactive area and `Semantics(button: true, selected: activeLang == code, label: ...)` (e.g. `'English explanation'`, `'Bengali explanation'`, `'Hindi explanation'`) so learners can compare the explanation across languages without mutating their global `SettingsController.supportLanguage`. Must not overflow at `320 dp` with `200%` text scaling or disturb the feedback card's initial spoken verdict test.

### 5. Localized chapter cues & difficulty badge (`lib/features/chapters/chapter_list_screen.dart`, `lib/features/chapters/chapter_detail_screen.dart`)
- In `ChapterListScreen`:
  - Watch `SettingsController.supportLanguage` (defaulting safely if read from `SettingsController`).
  - Clamp `_ChapterCard`'s step label: `'Step ${(resumeStep ?? 0).clamp(0, sceneCount) + 1} of ${sceneCount + 1}'`.
  - When `supportLanguage != 'en'` and `chapter.grammarTopic.resolve(supportLanguage) != chapter.grammarTopic.en`, show the localized grammar topic beneath/after the English topic (clean secondary style, wrapping without overflow at `320 dp` / `200%` text).
  - When `chapter.difficulty.trim().toLowerCase() != 'beginner'` and `chapter.difficulty.trim().isNotEmpty`, display a small level chip (e.g. `'Intermediate'` for `'intermediate'`, title-cased cleanly) so intermediate chapters (`ch11`–`ch15`) stand out automatically while beginner cards remain clean.
- In `ChapterDetailScreen`:
  - Watch `SettingsController.supportLanguage`. When `supportLanguage != 'en'`, display `chapter.title.resolve(lang)` softly under the English title (when different from `chapter.title.en`) and `chapter.description.resolve(lang)` softly under the English description (when different from `chapter.description.en`) so Bengali and Hindi learners understand the story setup before tapping Start.
  - Include a clean difficulty indicator (e.g. `'Beginner'` / `'Intermediate'`) in the chapter overview metadata using overflow-safe layout (`Wrap`) so `320 dp` at `200%` text never clips or overflows.

### 6. Tests (`test/onboarding_guest_flow_test.dart`, `test/quiz_completion_test.dart`, `test/accessibility_text_scaling_test.dart`)
- Write strictly lint-clean Dart (no unused imports/locals, no unnecessary string interpolation braces).
- `test/onboarding_guest_flow_test.dart`: verify tapping `'हिन्दी'` on onboarding page 2 updates and persists `supportLanguage == 'hi'` while finishing onboarding directly into `HomeShell` as a guest, and double-tapping `'Skip'` stays safe.
- `test/quiz_completion_test.dart`: verify switching the in-quiz explanation language shows English, Bengali, and Hindi explanations for the current question, keeps `SettingsController.supportLanguage` unchanged, and resets back to `SettingsController.supportLanguage` on `'Next Question'`; also verify localized chapter detail/list copy and intermediate difficulty label.
- `test/accessibility_text_scaling_test.dart`: add `320 dp` × `{1.0, 1.3, 2.0}` text-scale overflow checks for `OnboardingScreen` (page 2 with language chips) and `LanguageSelectionScreen`, and verify `GrammarLessonScreen`'s `'Close lesson'` control is at least `48 × 48 dp`. Keep all existing accessibility tests passing.

## Handoff
Follow `agent-bootstrap/captain/FASTLANE.md`: `start` → edit → `check` → `diff` → `publish`, then post or return the exact `AGENT B PUSHED` block for Issue `#6`. Do not open a PR, touch `main`, or dispatch CI.
