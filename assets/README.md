# Asset Inventory — GrammarBondhu

All assets are local and bundled. The app **never requires an asset to run**:
every image has a designed fallback (initial avatar / gradient scene card),
so the learning flow works even while illustrations are still being produced.

## Naming conventions

| Kind | Location | Pattern | Example |
|---|---|---|---|
| Character portrait | `assets/characters/` | `<character_id>.webp` | `rahul.webp` |
| Scene background | `assets/backgrounds/` | `<background_id>.webp` | `bg_classroom.webp` |
| Illustration / thumbnail | `assets/illustrations/` | `<key>.webp` / `.png` | `ch01_thumb.webp` |
| Branding / logo | `assets/branding/` | `<key>.png` | `logo_with_char.png` |
| Content data | `assets/data/` | `manifest.json`, `chapters/chapter_NN.json` | `chapter_01.json` |
| Audio (future) | `assets/audio/` | `<chapter_id>_<key>.mp3` | `ch01_intro.mp3` |

Character IDs in content JSON: `rahul`, `priya`, `teacher` (see
`lib/core/utils/asset_lookup.dart`, which is the single source of truth).

## Art style

All character / background / hero art is rendered in a consistent
**3D Pixar-style cartoon** look:
- Warm Indian skin tones, big expressive eyes, soft shading
- Bright saturated colors (friendly kid-app palette)
- Rahul: light-blue polo with dark-blue collar, red backpack, black hair,
  wristwatch, colorful beaded bracelet
- Priya: light-blue dress, white collar, red ribbon in ponytail, yellow book
- Mrs. Sen (teacher): teal sari with gold border, glasses, bindi, bunned hair
- Backgrounds: sunlit Indian school scenes (red-brick clock tower, banyan
  garden, bright classroom, magical library)

## Status

| Asset | File | Status |
|---|---|---|
| Chapters 1–5 content | `assets/data/chapters/*.json` | ✅ finished (EN/BN/HI) |
| Manifest | `assets/data/manifest.json` | ✅ finished |
| Rahul portrait | `characters/rahul.webp` | ✅ finished (3D-style) |
| Priya portrait | `characters/priya.webp` | ✅ finished (3D-style) |
| Mrs. Sen portrait | `characters/teacher.webp` | ✅ finished (3D-style) |
| Backgrounds (4 scene keys) | `backgrounds/bg_*.webp` | ✅ finished (3D-style) |
| Chapter thumbnails (5) | `illustrations/ch01..05_thumb.webp` | ✅ finished (3D-style) |
| Splash hero (frame 1) | `illustrations/splash_hero.png` | ✅ 3D-style |
| Onboarding welcome (frame 2) | `illustrations/onboarding_welcome.png` | ✅ 3D-style |
| Onboarding languages (frame 3) | `illustrations/onboarding_languages.png` | ✅ 3D-style |
| Onboarding story world (frame 4) | `illustrations/onboarding_story_world.png` | ✅ 3D-style |
| Login hero (frame 5) | `illustrations/login_hero.png` | ✅ 3D-style |
| Grammar lesson (frame 10) | `illustrations/grammar_lesson.png` | ✅ 3D-style |
| Quiz time (frame 11) | `illustrations/quiz_time.png` | ✅ 3D-style |
| Chapter completed reward (frame 13) | `illustrations/chapter_completed.png` | ✅ 3D-style |
| Branded logo with character | `branding/logo_with_char.png` | ✅ 3D-style |
| Progress avatar (frame 6 & 14) | `illustrations/progress_avatar.png` | ✅ 3D-style |
| Offline download hero (frame 16) | `illustrations/offline_download.png` | ✅ 3D-style |
| Chapter detail hero (frame 17) | `illustrations/chapter_detail_hero.png` | ✅ 3D-style |
| Rewards trophy (rewards tab) | `illustrations/rewards_trophy.png` | ✅ 3D-style |
| Locked chapter thumbnail | `illustrations/locked_chapter.png` | ✅ 3D-style |
| Flag icons EN/BN/HI (frame 18) | `icons/flag_{en,bn,hi}.png` | ✅ 3D circular flag buttons |
| Audio | `audio/` | ⬜ not used in v1 (audio toggle reserved) |

## Guidelines for new art

- Prefer WebP or optimized PNG; keep each file under ~300 KB.
- Characters: transparent background, full body, consistent outfit for Rahul
  (blue school uniform, backpack).
- Backgrounds: 16:9-ish (e.g. 1280×720), no baked-in text.
- Screen hero illustrations: match the frames in the project storyboard
  (`GrammarBondhu Language Learning App Storyboard.png`) — same composition,
  same palette, same characters.
- Register new IDs in `lib/core/utils/asset_lookup.dart` **before** referencing
  them from chapter JSON or screen code.
