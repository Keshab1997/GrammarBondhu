# Asset Inventory — GrammarBondhu

All assets are local and bundled. The app **never requires an asset to run**:
every image has a designed fallback (initial avatar / gradient scene card),
so the learning flow works even while illustrations are still being produced.

## Naming conventions

| Kind | Location | Pattern | Example |
|---|---|---|---|
| Character portrait | `assets/characters/` | `<character_id>.webp` | `rahul.webp` |
| Scene background | `assets/backgrounds/` | `<background_id>.webp` | `bg_classroom.webp` |
| Illustration / thumbnail | `assets/illustrations/` | `<key>.webp` | `ch01_thumb.webp` |
| Content data | `assets/data/` | `manifest.json`, `chapters/chapter_NN.json` | `chapter_01.json` |
| Audio (future) | `assets/audio/` | `<chapter_id>_<key>.mp3` | `ch01_intro.mp3` |

Character IDs in content JSON: `rahul`, `priya`, `teacher` (see
`lib/core/utils/asset_lookup.dart`, which is the single source of truth).

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
| Audio | `audio/` | ⬜ not used in v1 (audio toggle reserved) |

## Guidelines for new art

- Prefer WebP or optimized PNG; keep each file under ~200 KB.
- Characters: transparent background, full body, consistent outfit for Rahul
  (blue school uniform, backpack).
- Backgrounds: 16:9-ish (e.g. 1280×720), no baked-in text.
- Register new IDs in `lib/core/utils/asset_lookup.dart` **before** referencing
  them from chapter JSON.
