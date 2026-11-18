# Worker B — `learning-flow-ui-polish` (Batch `gb-b3`)

- **Target repo:** `Keshab1997/GrammarBondhu`
- **Reused Arena branch:** `arena/77b265ce-grammarbondhu`
- **Pinned `base_sha`:** `a48530cc7041b7a45f61b41790ae6d8bece0f0e7` *(your verified `gb-b2` tip — do NOT rebase, reset, or merge `main`)*
- **Tracker issue:** https://github.com/Keshab1997/GrammarBondhu/issues/6
- **Gate:** `{"kind": "preflight"}` in worker sandbox (`storage.googleapis.com` is blocked in attached sandboxes); Captain runs full Flutter `3.50.0` `dart format`, `flutter analyze`, `flutter test`, and pixel screenshot checks before landing on `main`.

## Allowed files (exact — touch nothing else)

1. `lib/features/grammar/grammar_lesson_screen.dart`
2. `lib/features/chapters/chapter_detail_screen.dart`
3. `lib/features/chapters/chapter_list_screen.dart`
4. `lib/features/quiz/quiz_screen.dart`
5. `lib/features/completion/chapter_completed_screen.dart`

## Design directive (strict)

- **Highest priority focus — Grammar Lesson & Chapter/Quiz learning UX!**
- **Zero ghostly / faded artwork or washed-out text:** Never wrap character standees, portraits, or thumbnails in `Opacity < 1.0`. Separate characters from backgrounds with `FilterQuality.high` and true contour drop shadows (`ImageFilter.blur` + `ColorFilter.mode(..., BlendMode.srcIn)`), and raise low-alpha chalk/caption styles so text is effortlessly readable on real phones.
- **Strict accessibility & small-phone safety:** Every interactive control must have at least a `48 × 48 dp` (`AccessibleLayout.minTouchTarget`) hit box, zero overflow at `320 × 640 dp` across `100%`, `130%`, and `200%` text scales, and 100% lint-clean Dart (`dart:ui show ImageFilter` if used; no unused imports/variables; use only existing `AppColors` tokens from `lib/app/theme/app_theme.dart`).

## Requirements

### 1. Grammar Lesson chalkboard fix & cinema polish (`lib/features/grammar/grammar_lesson_screen.dart`)
- **Critical chapter-content fix on `_BoardPage`:** Right now `_BoardPage` hardcodes Chapter 1's `am / is / are` conjugation `_table` on page 0 and Chapter 1's `I ___ a student. / He ___ my friend. / They ___ classmates.` (`_gaps` + `_answers`) on page 2 for ALL 15 chapters! Pass `Chapter chapter` into `_Board` and `_BoardPage`:
  - When `chapter.id == 'ch01'`, keep the exact `_table` (`am`, `is`, `are`) on page 0 and the exact 3 `ch01` gap sentences + `'Answers: am · is · are'` / `'উত্তর: am · is · are'` / `'जवाब: am · is · are'` on page 2.
  - For every other chapter (`chapter.id != 'ch01'`):
    - On **page 0 (`TODAY’S RULE`)**: beneath `lesson.explanation.of(lang)`, if `lesson.examples.isNotEmpty`, render a crisp chalk callout box (subtle `Colors.white.withValues(alpha: 0.08)` fill, `1 dp` `AppColors.accent.withValues(alpha: 0.45)` left/outer border, rounded corners) showcasing `lesson.examples.first.sentence` in warm gold-tinted chalk plus its `note.of(lang)` underneath when non-empty.
    - On **page 2 (`Say it yourself`)**: derive up to 3 real practice lines from `chapter.quiz.questions.take(3)` (displaying `q.question` for each numbered line, and building the answer key from each question's `q.correctAnswer` joined with `' · '`, prefixed by `'Answers: '` / `'উত্তর: '` / `'जवाब: '`; fall back gracefully to `lesson.examples.take(3)` if a chapter has no quiz questions).
- **Interactive tap-to-reveal chalk answers on page 2:**
  - Add `bool _revealAnswers = false;` in `_GrammarLessonScreenState` (reset to `false` inside `_turn` whenever the page changes) and pass `revealAnswers` + `onToggleAnswers` to `_Board` / `_BoardPage`.
  - Below the 3 practice prompts on page 2, render an accessible `>= 48 dp` chalk pill button (`Show answers` / `উত্তর দেখো` / `जवाब देखो` when hidden; `Hide answers` / `উত্তর লুকাও` / `जवाब छुपाओ` when shown, with visibility icon) that reveals the answer string in bright readable warm-gold chalk (`AppColors.accent`) inside a subtle slate pill container.
- **Chalkboard readability & layout polish:**
  - Put `_pageLabel` and the 3 page-progress dots cleanly in a top header row *above* the scrollable `_BoardPage` content inside `_Board` (instead of `Positioned` floating over the top-right where long titles or 200% text can collide with them!). Make active dot warm `AppColors.accent` and inactive dots crisp `Colors.white.withValues(alpha: 0.32)`.
  - Improve chalk legibility: raise kicker alpha from `0.55` → `0.76`, explanation alpha from `0.88` → `0.95`, example note alpha from `0.55` → `0.80` (with warm soft cream tint `const Color(0xFFE2F1E8)`), and example check icon to `AppColors.accent.withValues(alpha: 0.90)`.
  - Give `_BoardListenChip` a `>= 48 dp` minimum touch target (`ConstrainedBox(minWidth: 48, minHeight: 48)`), `Semantics(button: true, label: label)`, and a warm `AppColors.accent` border + soft glow when `playing` is true.
  - Upgrade `_Teacher` standee: use `FilterQuality.high`, `gaplessPlayback: true`, 100% solid opacity, and wrap with a subtle contour drop shadow behind the standee (`Transform.translate(offset: const Offset(-2, 4))` + `ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7, tileMode: TileMode.decal))` + `ColorFiltered(colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.32), BlendMode.srcIn))`) inside a `Stack(alignment: Alignment.bottomRight)` so Mrs. Sen stands sharply in 3D relief in front of the slate without blurring or blending into the green board!
  - Polish `_TeacherSays` bubble with a subtle `1 dp` `AppColors.primary.withValues(alpha: 0.14)` border and crisp `>= 48 dp` back button on `_CtaBar` (`tooltip: 'Previous page'`).
- **Exact strings/labels that MUST stay unchanged:** `'Grammar lesson'`, `'Close lesson'`, `'Show lesson in $language'`, `'TODAY’S RULE'`, `'Say it yourself'`, `'Next'`, `'Start the quiz'`, `'Hear it'`, `'শুনে নাও'`, `'सुनकर देखो'`, `'Could not play this audio'`, `'Mrs. Sen'`.

### 2. Chapter Detail screen UI/UX polish (`lib/features/chapters/chapter_detail_screen.dart`)
- **Brighter, chapter-aware `_Hero`:**
  - Pass `backgroundId: chapter.scenes.isNotEmpty ? chapter.scenes.first.backgroundId : null` into `_Hero`; load `AssetLookup.backgroundPath(backgroundId)` when available (falling back to `'assets/illustrations/chapter_detail_hero.webp'`) with `FilterQuality.high`.
  - Replace the overly dark `0xCC000000` bottom black curtain (left over from an older layout) with a balanced top-and-bottom cinema vignette (`[Color(0x520B1B3A), Color(0x00000000), Color(0x470B1B3A)]`, `stops: [0.0, 0.45, 1.0]`) so the scene artwork shines vividly while keeping top controls legible.
  - Give `_CircleButton` a guaranteed `>= 48 × 48 dp` hit area (`ConstrainedBox(minWidth: AccessibleLayout.minTouchTarget, minHeight: AccessibleLayout.minTouchTarget)`).
  - When `completed && stars > 0`, wrap `StarsDisplay(count: stars, size: 18)` in a frosted dark capsule pill (`Colors.black.withValues(alpha: 0.38)`, stadium border) so gold stars pop cleanly against bright skies.
- **Richer `_SheetBody` without crowding the sticky CTA:**
  - Collect distinct character IDs appearing in `chapter.scenes` (via `s.characterIds` and `d.characterId`); when non-empty, display a compact overflow-safe `Wrap` of solid character chips (`CharacterAvatar(characterId: id, size: 24)` + `AssetLookup.characterDisplayName(id)` inside a rounded `AppColors.primarySoft` pill with `1 dp` `AppColors.primary.withValues(alpha: 0.14)` border).
  - Polish the reward metadata & `_StepRow` roadmap cards with clear visual step status (emerald check for finished steps, highlighted royal-blue ring for the active next step, clean slate circle for upcoming steps) and crisp borders, keeping the sticky bottom `_CtaBar` (`Start` / `Resume` / `Replay` etc.) always visible on screen.
- **Exact strings/labels that MUST stay unchanged:** `'Back'`, `'CHAPTER $number'`, `chapter.difficultyLabel` (e.g. `'Intermediate'`), `'COMPLETED'`, `chapter.title.en`, `chapter.description.en`, localized title/description when `supportLanguage != 'en'`, `chapter.grammarTopic.en`, `'Resume'` (and existing Start/Replay CTA labels), and never showing `'Scene ${scenes.length + 1}'`.

### 3. Chapter List curriculum UX polish (`lib/features/chapters/chapter_list_screen.dart`)
- **Remove thumbnail ghosting:** Replace `Opacity(opacity: locked ? 0.62 : 1, child: ChapterThumbnail(...))` with a 100% solid `ChapterThumbnail` plus (when `locked`) an opaque-preserving `ColorFiltered(colorFilter: ColorFilter.mode(const Color(0x4D1E293B), BlendMode.srcATop), ...)` and a crisp small lock badge in the bottom-right corner — so locked cards look intentionally locked without transparent washout.
- **Visual state distinction on `_ChapterCard`:**
  - Give `inProgress` cards a crisp `1.5 dp` `AppColors.primary.withValues(alpha: 0.35)` border and a compact 5 dp rounded progress bar showing `((resumeStep ?? 0).clamp(0, sceneCount) + 1) / (sceneCount + 1)` beside/under `'Step X of Y'`.
  - Give `completed` cards a subtle `1 dp` `AppColors.success.withValues(alpha: 0.30)` border and crisp emerald completion accent.
  - Ensure filter chips (`'All'`, `'Started'`, `'Done'`, `'Locked'`) each meet `minHeight: 48` with `Semantics(button: true, selected: ...)` and clear active contrast.
- **Exact test invariants to preserve:**
  - Do NOT display the word `'Beginner'` on `ChapterListScreen` (`quiz_completion_test.dart` asserts `expect(find.text('Beginner'), findsNothing)` on beginner cards, while `'Intermediate'` MUST still appear for intermediate chapters!).
  - Keep exact filter labels `'All'`, `'Started'`, `'Done'`, `'Locked'`, exact `'Step X of Y'` copy, exact `'... to unlock'` wording, and exact empty-state messages (`'No chapters in progress...'`, `'No completed chapters...'`, `'Every chapter is unlocked...'`).

### 4. Quiz screen tactile learning polish (`lib/features/quiz/quiz_screen.dart`)
- Add a clean segmented question progress strip (one slim rounded capsule per question: answered = `AppColors.primary`, current = `AppColors.accentDark`, upcoming = `AppColors.primarySoft`) right under the question counter header, plus a subtle `chapter.grammarTopic.en` pill so the learner keeps the target rule in mind.
- Polish the question prompt card with a soft `AppColors.surface` elevation + `1 dp` `AppColors.primary.withValues(alpha: 0.12)` border and comfortable line-height (`1.4`).
- Polish `_OptionTile` visual states (selected = crisp `2 dp` `AppColors.primary` border + `AppColors.primarySoft` fill + filled primary letter badge; submitted correct = `2 dp` `AppColors.success` border + `AppColors.successSoft` fill + check icon; submitted wrong selection = `2 dp` `AppColors.error` border + `AppColors.errorSoft` fill + close icon; unselected after submit = solid clean `AppColors.surface` with muted border — zero low-opacity transparency!).
- Polish `_FeedbackCard` with clear separation between the verdict row (`'Correct!'` / `'Incorrect'`), the explanation text, and the compact trilingual pill switcher (`'EN'`, `'বাংলা'`, `'हिन्दी'`), preserving every single accessibility semantics label, `isSelected` flag, live-region verdict announcement, disabled Submit hint, and `>= 48 dp` target tested by `accessibility_text_scaling_test.dart`, `quiz_completion_test.dart`, `progress_review_test.dart`, and `daily_goal_test.dart`.

### 5. Chapter Completed celebration polish (`lib/features/completion/chapter_completed_screen.dart`)
- Watch `SettingsController` safely (`Provider.of<SettingsController?>(context)?.supportLanguage ?? 'en'`); when `supportLanguage == 'bn'` or `'hi'`, display a warm localized congratulatory subtitle beneath the English praise heading (e.g. `'দারুণ কাজ! আরও এগিয়ে চলো।'` / `'शानदार काम! ऐसे ही आगे बढ़ते रहो।'`).
- Give the celebration artwork `FilterQuality.high` and solid framing, display a crisp score/accuracy summary pill (`'${args.correct}/${args.total} correct'` when `args.total > 0`), give `_RewardChip`s (`'+${xp} XP'`, `'+${coins} Coins'`) warm tinted surfaces with crisp `1 dp` borders, and ensure `'Close'` tooltip (`>= 48 × 48 dp`) and `'Finish for now'` / next-chapter CTAs stay cleanly accessible at `320 dp` × `200%` text.

## Handoff

Follow `agent-bootstrap/captain/FASTLANE.md`: `start` → edit → `check` → `diff` → `publish`, then post or return the exact `AGENT B PUSHED` block for Issue `#6`. Do not open a PR, touch `main`, or dispatch CI.
