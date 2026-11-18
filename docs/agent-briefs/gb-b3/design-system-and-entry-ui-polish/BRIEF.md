# Worker C — `design-system-and-entry-ui-polish` (Batch `gb-b3`)

- **Target repo:** `Keshab1997/GrammarBondhu`
- **Reused Arena branch:** `arena/eead898e-grammarbondhu`
- **Pinned `base_sha`:** `2b5c9114705e7780d607556247227ab2684670c4` *(your verified `gb-b2` tip — do NOT rebase, reset, or merge `main`)*
- **Tracker issue:** https://github.com/Keshab1997/GrammarBondhu/issues/6
- **Gate:** `{"kind": "preflight"}` in worker sandbox (`storage.googleapis.com` is blocked in attached sandboxes); Captain runs full Flutter `3.50.0` `dart format`, `flutter analyze`, `flutter test`, and pixel screenshot checks before landing on `main`.

## Allowed files (exact — touch nothing else)

1. `lib/core/widgets/app_widgets.dart`
2. `lib/core/widgets/asset_images.dart`
3. `lib/features/splash/splash_screen.dart`
4. `lib/features/auth/login_screen.dart`

## Design directive (strict)

- **100% backward-compatible shared components:** Every existing public class, enum value, parameter name, type, and default in `app_widgets.dart` and `asset_images.dart` MUST keep full source compatibility with every caller in the app (new parameters may only be optional named parameters with sensible defaults!).
- **Zero ghostly / faded images:** Never wrap `Image.asset` in `Opacity < 1.0`. Use solid surfaces, warm subtle backplates behind portraits, crisp `1 dp` borders, and `FilterQuality.high` + `gaplessPlayback: true` so character portraits and chapter art look razor-sharp and never fade into backgrounds at any size.
- **Accessibility & small-phone safety:** Enforce `>= 48 dp` minimum interactive height on buttons, honour `MediaQuery.maybeDisableAnimationsOf(context)` for animations, avoid overflows at `320 × 640 dp` across `100%`, `130%`, and `200%` text scaling, and write strictly lint-clean Dart (no unused imports/locals, use only existing tokens in `lib/app/theme/app_theme.dart`).

## Requirements

### 1. Shared UI components elevation (`lib/core/widgets/app_widgets.dart`)
- **`AppButton`:**
  - Ensure minimum interactive height is at least `48.0` dp while allowing multi-line text growth cleanly (preserving `test/app_button_test.dart` behavior on long labels and `200%` text scale!).
  - Respect `MediaQuery.maybeDisableAnimationsOf(context) ?? false` on any shimmer/scale animations so reduced-motion users get crisp instant states without unnecessary motion.
  - Ensure disabled `AppButton` uses a solid readable muted surface and legible foreground text (never blurry low-opacity washout), and `outline` variant has a crisp `1.5 dp` border with subtle `AppColors.primarySoft` splash/highlight.
- **`AppCard`:**
  - Add an optional `this.border` (`BoxBorder?`) parameter; when `border == null` and `gradient == null`, paint a refined hairline `Border.all(color: AppColors.primary.withValues(alpha: 0.08))` so white cards sit cleanly and distinctly against `AppColors.background` (`#F1F5FB`) on every screen in the app!
  - Clip ink splashes cleanly to `BorderRadius.circular(radius)` with subtle `AppColors.primary.withValues(alpha: 0.06)` splash/highlight when `onTap != null`.
- **`AppProgressBar`:**
  - Ensure `clamped == 0` renders only the clean track without a stray zero-width glowing shadow artifact, and use a rich vibrant gradient (`[color, Color.lerp(color, Colors.white, 0.16)!]`) instead of fading out to `alpha: 0.7` (which washed the right tip into the track!).
- **`StarsDisplay`:**
  - Respect `MediaQuery.maybeDisableAnimationsOf(context) ?? false` (render at target scale immediately without tweening when reduced motion is enabled).
  - Give unearned stars a clearer crisp outline color (`AppColors.textMuted.withValues(alpha: 0.55)` instead of faint `0.3`) and natural size (`0.88` instead of tiny `0.6`) so `2 of 3 stars` reads instantly at a glance!
- **`LanguageChip`:**
  - Add crisp `1 dp` border polish and `FilterQuality.high` on flag icons while keeping its compact footprint overflow-safe at `320 dp`.

### 2. Solid, high-clarity character & chapter imagery (`lib/core/widgets/asset_images.dart`)
- **`CharacterAvatar`:**
  - Add optional `this.showBorder = true` (`bool`).
  - Give the circular portrait a solid warm `AppColors.primarySoft` backing color behind `Image.asset` (so even portraits with soft edges never bleed into dark or busy backgrounds!), `fit: BoxFit.cover`, `alignment: Alignment.topCenter` (keeps the character's face centered rather than cropping the forehead!), `gaplessPlayback: true`, `filterQuality: FilterQuality.high`, and when `showBorder` is true a subtle outer ring (`Border.all(color: Colors.white, width: size >= 44 ? 2.0 : 1.5)` + soft shadow when `size >= 40`) within the exact `size × size` box so layout dimensions never shift!
- **`SceneBackground`:**
  - Add `gaplessPlayback: true` and `filterQuality: FilterQuality.medium` on `Image.asset` for smooth scene transitions.
- **`ChapterThumbnail`:**
  - Remove `Opacity(opacity: 0.9, ...)` on `locked_chapter.webp`; render at full `1.0` opacity with `gaplessPlayback: true`, `filterQuality: FilterQuality.high`, and a subtle `1 dp` inner rim border (`Colors.black.withValues(alpha: 0.06)`) so thumbnails look crisp on light cards.

### 3. Splash screen polish (`lib/features/splash/splash_screen.dart`)
- **Critical test invariants (`test/splash_frames_test.dart` & `test/app_smoke_test.dart`):**
  - Keep exact visible strings `'Grammar'` (same widget count as before!), `'Bondhu'`, `'LEARN ENGLISH THROUGH STORIES'`, and `"Let's Begin"`.
  - Keep hero frame layout geometry stable when animation ticks (`splash_frames_test.dart` asserts that the `Rect` of `'Grammar'`, `'LEARN ENGLISH THROUGH STORIES'`, and `"Let's Begin"` does NOT jump or drift across frames!), and keep `"Let's Begin"` fully on screen on both short and tall phones and at `320 × 640 dp` across `100%`, `130%`, and `200%` text scaling!
- Polish visual richness inside those bounds: use `FilterQuality.high` and `gaplessPlayback: true` on hero art, refine the backdrop ambient glow and tagline pill legibility (high contrast, crisp letter spacing), and ensure `MediaQuery.maybeDisableAnimationsOf(context)` keeps the screen calm with zero layout shift.

### 4. Welcoming guest-first profile & backup screen (`lib/features/auth/login_screen.dart`)
- Give the top-left `'Back'` circle button a guaranteed `>= 48 × 48 dp` tap area with subtle shadow, add a gentle bottom-edge gradient blend on the `login_hero.webp` image (`FilterQuality.high`, 100% solid) into the rounded white sheet, and add a compact friendly reassurance chip row (`Offline-ready` · `Private on device` or localized equivalent if watching optional `SettingsController` safely via `context.watch<SettingsController?>()` — if `SettingsController` may be absent in isolated tests, use `Provider.of<SettingsController?>(context)` safely!).
- Polish the name `TextField` border states (clean rounded `14 dp` border, crisp `AppColors.primary` focused border, readable helper/hint contrast), refine the subtle `'or'` divider above `'Continue with Google'`, and ensure every CTA (`'Continue'`, `'Continue without a name'`, `'Continue with Google'`) has at least `48 dp` height and zero overflow at `320 × 640 dp` up to `200%` text scaling.
- **Exact strings/labels that MUST stay unchanged (`test/login_screen_test.dart`):**
  - `'Back'`, `'Make it yours'`, `'Your name (optional)'`, `'Continue'`, `'Continue without a name'`, `'Continue with Google'`, all existing snackbar messages — and NEVER introduce the words `'Password'`, `'Login'`, or `'Sign Up'`.

## Handoff

Follow `agent-bootstrap/captain/FASTLANE.md`: `start` → edit → `check` → `diff` → `publish`, then post or return the exact `AGENT C PUSHED` block for Issue `#6`. Do not open a PR, touch `main`, or dispatch CI.
