# Worker A — `mistake-practice-and-rewards` (Batch `gb-b2`)

- **Target repo:** `Keshab1997/GrammarBondhu`
- **Reused Arena branch:** `arena/f3a73e45-grammarbondhu`
- **Pinned `base_sha`:** `01e6bb8677f29603301087e21ba278482fdf9cf0` *(your verified `gb-b1` tip — do NOT rebase, reset, or merge `main`)*
- **Tracker issue:** https://github.com/Keshab1997/GrammarBondhu/issues/6
- **Gate:** `{"kind": "preflight"}` in worker sandbox (`storage.googleapis.com` is blocked in attached sandboxes); Captain runs full Flutter `3.50.0` `dart format`, `flutter analyze`, and `flutter test` before landing on `main`.

## Allowed files (exact — touch nothing else)

1. `lib/features/quiz/review_practice_screen.dart` *(new)*
2. `lib/features/progress/progress_screen.dart`
3. `lib/features/home/home_screen.dart`
4. `lib/features/rewards/rewards_screen.dart`
5. `test/review_practice_test.dart` *(new)*
6. `test/home_layout_test.dart`

Do **not** edit `lib/app/router.dart` (reserved — Captain wires `ReviewPracticeScreen.routeName` after review).

## Requirements

### 1. Focused Mistake Practice session (`lib/features/quiz/review_practice_screen.dart`)
- Create `ReviewPracticeScreen extends StatefulWidget` with `const ReviewPracticeScreen({super.key})` and `static const routeName = '/review-practice'`.
- Snapshot the ordered list of queued items `(Chapter chapter, QuizQuestion question)` across `ContentController.chapters` where `progress.chapterProgress(chapter.id).missedQuestionIds.contains(question.id)` once when the session initializes (or when explicitly restarted from the summary screen), so clearing an item mid-session never shifts question indices underneath the learner.
- **Empty state** (no queued missed questions): render a friendly `AppCard` (`'Nothing to review'`, concise encouragement) and an `AppButton` (`'Back'`) calling `Navigator.of(context).maybePop()`.
- **Active question view**:
  - `AppBar` with close/back `IconButton(tooltip: 'Close', ...)` and title `'Mistake Practice'`.
  - Scrollable `SafeArea` body showing `Question i of N`, the source chapter's `chapter.title.en`, a progress bar, the `question.question` text, and 4 option tiles (each at least `48 dp` tall, wrapped in clear `Semantics` with option letter A–D, text, `button: true`, `enabled`, `selected`, and post-submit `'correct answer'` / `'your answer, incorrect'` verdict).
  - Lock option selection while `_submitting || _submitted`.
  - On first `Submit`:
    - If `_selected == question.correctIndex`: `await progress.clearQuestionForReview(chapter.id, question.id)`, increment `_clearedCount`.
    - Otherwise: `await progress.markQuestionForReview(chapter.id, question.id)`.
    - Always `await progress.registerQuestionAnswered()` so review practice counts fairly toward the learner's daily question goal (never call `recordQuizRun` — no duplicate chapter XP/coins).
    - Guard `mounted` after every `await`; clear `_submitting` in `finally`.
  - After submit: show the feedback card with `question.explanation.resolve(settings.supportLanguage)` and a `'Next Question'` / `'Finish Practice'` `AppButton`.
- **Session summary view**:
  - Show `'Cleared $_clearedCount of $total'` and an encouraging subtitle (`'Every mistake cleared!'` when remaining is 0, else `'$remaining left for next time'`).
  - If queued mistakes still remain in `ProgressController`, offer a `'Practise Remaining'` `AppButton` that starts a fresh deck from the remaining missed questions, plus a `'Done'` button calling `Navigator.of(context).maybePop()`.
- Must not overflow at `320 dp` width with `100%`, `130%`, or `200%` text scaling.

### 2. Progress screen polish (`lib/features/progress/progress_screen.dart`)
- Add optional `this.initialTab = 0` on `ProgressScreen` and initialize `_tab = widget.initialTab.clamp(0, 3)`.
- In the **Review** tab (`_tab == 3`), when `reviewCount > 0`, show a summary `AppCard` above the per-chapter review cards with `'$reviewCount ${reviewCount == 1 ? 'question' : 'questions'} ready to practise'` and an `AppButton(label: 'Practise Mistakes', ...)` that opens `ReviewPracticeScreen` via `Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReviewPracticeScreen()))`.
- In the **Stats** tab, add `_StatRow(label: 'Best streak', value: '${p.bestStreakDays} ${p.bestStreakDays == 1 ? 'day' : 'days'}')` right after `'Current streak'`, and avoid unnecessary braces in string interpolations (use `'$activeStreak ...'`, never `'${activeStreak} ...'`, so `flutter analyze --fatal-infos` stays clean).
- Give the scrolling `ListView` bottom padding `108` (`EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 108)`).

### 3. Home review nudge & safe clamps (`lib/features/home/home_screen.dart`)
- Compute `completedChapters = chapters.where((chapter) => progress.chapterProgress(chapter.id).completed).length` and use it for `allChaptersComplete` and `_ProgressCard.completedChapters`.
- Clamp `(record.resumeSceneIndex ?? 0).clamp(0, chapter.scenes.length)` in both `_ProgressCard` and `_ContinueCard`.
- Count queued missed questions that belong to loaded `chapters`. When `reviewCount > 0`, show a clean, accessible `_ReviewMistakesCard` below `_DailyGoalCard` (`'Review Mistakes'`, `'$reviewCount ${reviewCount == 1 ? 'question' : 'questions'} waiting for another try'`) that pushes `MaterialPageRoute<void>(builder: (_) => const ReviewPracticeScreen())` on tap. Hide it completely when `reviewCount == 0` so fresh-run Home stays uncluttered and existing tests stay intact. Must lay out cleanly at `320 dp` and `200%` text scale.

### 4. Expanded Rewards & Level progress (`lib/features/rewards/rewards_screen.dart`)
- Watch `ContentController` via `Provider.of<ContentController?>(context)` (nullable so standalone tests that only provide `ProgressController` still work without changing setup!).
- Add a clean **Level progress** `AppCard` between the stats banner and `'Achievements'` showing `'Level ${p.level} · ${p.levelTitle}'`, a rounded `LinearProgressIndicator(value: p.xpForNextLevel > 0 ? (p.xpIntoLevel / p.xpForNextLevel).clamp(0.0, 1.0) : 0.0)`, and `'${p.xpIntoLevel} / ${p.xpForNextLevel} XP to next level'`.
- Expand `achievements` to 7 strictly achievable milestones (keeping all 4 original titles intact):
  1. `'First Chapter'` — `'Complete your first chapter'` (`p.completedChapterCount >= 1`)
  2. `'Perfect Quiz'` — `'Score 100% on any chapter quiz'` (`p.chapters.values.any((c) => c.completed && c.bestScorePercent >= 100)`)
  3. `'3-Day Streak'` — `'Study three days in a row'` (`p.bestStreakDays >= 3`)
  4. `'Star Collector'` — `'Earn 6 stars in total'` (`totalStars >= 6`)
  5. `'Grammar Explorer'` — `'Reach level 3'` (`p.level >= 3`)
  6. `'English Champion'` — `'Reach level 5'` (`p.level >= 5`)
  7. `'Story Finisher'` — `'Complete every chapter in the course'` (`chapters.isNotEmpty ? chapters.every((c) => p.chapters[c.id]?.completed ?? false) : false`)
- Show `'$earnedCount of ${achievements.length} unlocked'` beside/under `'Achievements'` using a `Wrap` so `320 dp` at `200%` text never overflows.

### 5. Tests (`test/review_practice_test.dart`, `test/home_layout_test.dart`)
- Keep all unused imports/variables/parameters out so `tool/preflight.py` and `flutter analyze --fatal-infos` pass cleanly (avoid unnecessary string interpolation braces, avoid deprecated `SemanticsData.hasFlag` — if checking semantics flags use `Matchers` like `matchesSemantics` or standard widget expectations).
- In `test/review_practice_test.dart`: test clearing a missed question and keeping a still-missed question in `ReviewPracticeScreen`, daily-goal increment without awarding duplicate chapter XP/coins, `'Practise Remaining'` flow, empty state, `ProgressScreen(initialTab: 3)` `'Practise Mistakes'` launch + `'Best streak'` row in Stats, `RewardsScreen` 7 badges + `'English Champion'` + `'Story Finisher'` + level bar + `320 dp` at `200%` text scaling, and `ReviewPracticeScreen` at `320 dp` with `200%` text scaling.
- In `test/home_layout_test.dart`: verify the Home `'Review Mistakes'` card is absent with 0 mistakes, appears when a question is missed, opens `ReviewPracticeScreen`, and does not overflow at `320 dp` with `200%` text scaling.

## Handoff
Follow `agent-bootstrap/captain/FASTLANE.md`: `start` → edit → `check` → `diff` → `publish`, then post or return the exact `AGENT A PUSHED` block for Issue `#6`. Do not open a PR, touch `main`, or dispatch CI.
