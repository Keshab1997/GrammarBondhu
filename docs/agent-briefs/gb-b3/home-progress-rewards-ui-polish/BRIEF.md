# Worker A — `home-progress-rewards-ui-polish` (Batch `gb-b3`)

- **Target repo:** `Keshab1997/GrammarBondhu`
- **Reused Arena branch:** `arena/f3a73e45-grammarbondhu`
- **Pinned `base_sha`:** `0d829f00f6b40a6bb3589f049ce7f1df76dd6703` *(your verified `gb-b2` tip — do NOT rebase, reset, or merge `main`)*
- **Tracker issue:** https://github.com/Keshab1997/GrammarBondhu/issues/6
- **Gate:** `{"kind": "preflight"}` in worker sandbox (`storage.googleapis.com` is blocked in attached sandboxes); Captain runs full Flutter `3.50.0` `dart format`, `flutter analyze`, `flutter test`, and pixel screenshot checks before landing on `main`.

## Allowed files (exact — touch nothing else)

1. `lib/features/home/home_screen.dart`
2. `lib/features/progress/progress_screen.dart`
3. `lib/features/rewards/rewards_screen.dart`

## Design directive (strict)

- **Zero washed-out / ghostly visuals:** Never wrap character portraits, thumbnails, icons, or locked/disabled cards in `Opacity` / `AnimatedOpacity` below `1.0`. Use solid surfaces, subtle `1 dp` borders (`AppColors.primary.withValues(alpha: 0.12)`), clean muted slate colors, and `FilterQuality.high` on downscaled character/scene art so every illustration looks crisp and grounded.
- **Strict accessibility & small-phone safety:** Every interactive button/card tap target must be at least `48 × 48 dp` (`AccessibleLayout.minTouchTarget`), use `Wrap` / `Flexible` / `Expanded` so zero `RenderFlex` overflow occurs on a `320 × 640 dp` phone at `100%`, `130%`, and `200%` text scaling, and write 100% lint-clean Dart (no unused imports/locals, no unnecessary braces in strings, `const` constructors where possible, stay strictly on tokens already defined in `app_theme.dart`: `AppColors.primary`, `primaryDark`, `primaryDeeper`, `primarySoft`, `primaryGlow`, `accent`, `accentDark`, `accentDeep`, `accentSoft`, `success`, `successDark`, `successSoft`, `error`, `errorSoft`, `warning`, `info`, `background`, `backgroundAlt`, `surface`, `textPrimary`, `textSecondary`, `textMuted`, `textOnDark`).

## Requirements

### 1. Home dashboard UI/UX polish (`lib/features/home/home_screen.dart`)
- Watch `SettingsController` (`supportLanguage`) safely where chapter metadata is displayed:
  - In the active hero journey card (when not course-complete), show the current chapter's `grammarTopic.en` as a crisp translucent topic pill (and when `supportLanguage != 'en'` and `chapter.grammarTopic.of(supportLanguage) != chapter.grammarTopic.en`, show the localized grammar topic subtly underneath without crowding or overflowing at `320 dp` / `200%`).
  - Strengthen readable text contrast on the hero banner (bump secondary white text from `0.78` to at least `0.90`, keep any character/illustration artwork 100% solid with `FilterQuality.high` and a subtle contact/drop shadow so art separates cleanly from gradients).
- Polish the `_ReviewMistakesCard` visual hierarchy:
  - Give it a warm accented card frame (soft `AppColors.accentSoft` / white gradient or subtle `1.5 dp` `AppColors.warning.withValues(alpha: 0.30)` border, crisp rounded icon badge with `Icons.replay_rounded`, and clear right-chevron cue) so learners immediately notice pending mistake practice without harsh red error styling.
  - Keep `Navigator.of(context).pushNamed(ReviewPracticeScreen.routeName)` (or use `ReviewPracticeScreen.routeName` if defined on your branch; if `routeName` is already defined on `ReviewPracticeScreen`, prefer `pushNamed`, otherwise keep your existing `MaterialPageRoute` cleanly — Captain verifies route navigation on merge).
- Polish the `Daily Goal` card and `Your Course` card:
  - Give `Daily Goal` a warm celebratory border & check badge when the daily goal is met (`Goal complete — nicely done!`), and crisp numeric pill styling on `$count/$target`.
  - Give quick-action tiles and the `Your Course` card crisp `1 dp` subtle borders (`color.withValues(alpha: 0.16)`) and clear visual hierarchy between label and caption, ensuring disabled states use solid muted colors rather than washed-out faint text.
- **Exact strings/labels that MUST stay unchanged for tests:**
  - `'Hello, $name!'` (e.g. `'Hello, Rahul!'`), `'Start Your Journey'`, `'Continue Your Journey'`, `'Course complete!'`, `'Review chapters'`, `'Step X of Y'`, `'Your Course'`, `'$completed/${chapters.length}'`, `'Current chapter · Step X of Y'`, `'Daily Goal'`, `'Complete $target quiz questions today'`, `'$count/$target'`, `'Goal complete — nicely done!'`, `'Review Mistakes'`, `'$reviewCount ${reviewCount == 1 ? 'question' : 'questions'} waiting for another try'`, `'Chapter 1'`.

### 2. Learning Progress & Review screen polish (`lib/features/progress/progress_screen.dart`)
- Give the segmented tab switcher (`Stats` / `Review` or existing tab control) a crisp pill container with `>= 48 dp` tap targets, clear selected elevation/border, and `Semantics(button: true, selected: ...)` on each tab.
- On the **Stats** view:
  - Elevate the course-completion overview card with a crisp visual summary bar, clean stat rows with soft circular icon badges (`AppColors.primarySoft` / `AppColors.accentSoft` / `AppColors.successSoft`), subtle row dividers, and clear visual emphasis on streak & best-streak rows (`4 days` etc.).
  - Ensure any avatar/illustration (`progress_avatar.webp`) renders at 100% solid opacity with `FilterQuality.high` and clean framing.
- On the **Review** view:
  - Frame the top practise callout card with a warm `AppColors.primarySoft` background and subtle `AppColors.primary.withValues(alpha: 0.18)` border so `'Practise Mistakes'` stands out above individual missed-question cards.
  - Polish each missed-question review card: subtle chapter pill header, bold readable question prompt, green tinted answer strip (`AppColors.successSoft` with crisp `AppColors.successDark` text for `'Answer: ${question.correctAnswer}'`), clean explanation block in the learner's support language, and a `>= 48 dp` `'Mark reviewed'` action.
  - Polish the `'Nothing to review'` empty state with a cheerful `AppColors.successSoft` circle check icon and warm encouraging subtitle.
- **Exact strings/labels that MUST stay unchanged for tests:**
  - `'Stats'`, `'Review'`, `'Questions today'`, `'Practise Mistakes'`, `'$n ${n == 1 ? 'question' : 'questions'} ready to practise'`, `'Answer: ${question.correctAnswer}'`, `'Mark reviewed'`, `'Nothing to review'`, `'Open practice'`, best-streak `'X days'` text inside its row.

### 3. Rewards & Achievements showcase polish (`lib/features/rewards/rewards_screen.dart`)
- Upgrade the top stats card (`Coins`, `Day Streak`, `Total XP`):
  - Give each `_BigStat` a warm circular tinted icon medallion (`accentSoft` for Coins, soft orange `warning.withValues(alpha: 0.14)` for Day Streak, `primarySoft` for Total XP) and tabular-feeling bold numbers, wrapping gracefully at `320 dp` × `200%` text (stacking vertically when `AccessibleLayout.needsReflow(context)` or width `< 340` so 3 columns never collide at `200%` text!).
- Upgrade the `'Level progress'` card:
  - Frame it with a subtle `AppColors.primarySoft` header badge showing `'Level progress'`, crisp `'Level ${p.level} · ${p.levelTitle}'` title, rounded 10 dp progress bar with `semanticsLabel: 'Level progress'`, and clear `'$xpIntoLevel / $xpForNextLevel XP to next level'` caption.
- Upgrade every achievement card in `'Achievements'`:
  - **Earned badges:** warm sunlit card tint (`Color.lerp(AppColors.surface, AppColors.accentSoft, 0.35)!`), crisp `1.5 dp` `AppColors.accent.withValues(alpha: 0.55)` border, golden icon medallion (`AppColors.accentSoft` with `AppColors.accentDeep` icon), and emerald `Icons.check_circle_rounded` (`semanticLabel: 'Unlocked'`).
  - **Locked badges:** 100% solid clean white `AppColors.surface` card with subtle `1 dp` slate border (`AppColors.textMuted.withValues(alpha: 0.25)`), solid crisp `AppColors.background` icon circle with `AppColors.textSecondary` icon, `Icons.lock_outline_rounded` (`semanticLabel: 'Locked'`), AND when progress toward that achievement can be computed cleanly from `p` (e.g. completed chapters count, 3-star count, streak, total XP, total coins), show a compact 5 dp progress bar below `a.detail` so the learner sees how close they are to unlocking it!
  - Support `standalone` / back button cleanly at `>= 48 × 48 dp` when pushed outside `HomeShell`.
- **Exact strings/labels that MUST stay unchanged for tests:**
  - `'Coins'`, `'Day Streak'`, `'Total XP'`, `'Level progress'`, `'Level ${p.level} · ${p.levelTitle}'`, `'$xpIntoLevel / $xpForNextLevel XP to next level'`, `'Achievements'`, `'$earnedCount of ${achievements.length} unlocked'`, every existing achievement title (including `'Story Finisher'`), and `'Unlocked'` / `'Locked'` icon semantic labels.

## Handoff

Follow `agent-bootstrap/captain/FASTLANE.md`: `start` → edit → `check` → `diff` → `publish`, then post or return the exact `AGENT A PUSHED` block for Issue `#6`. Do not open a PR, touch `main`, or dispatch CI.
