# Worker C — `chapters-11-to-15` (Batch `gb-b2`)

- **Target repo:** `Keshab1997/GrammarBondhu`
- **Reused Arena branch:** `arena/eead898e-grammarbondhu`
- **Pinned `base_sha`:** `96d44e3a0930396c8991c2f67d1eb6c236c68051` *(your verified `gb-b1` tip — do NOT rebase, reset, or merge `main`)*
- **Tracker issue:** https://github.com/Keshab1997/GrammarBondhu/issues/6
- **Gate:** `{"kind": "preflight"}` in worker sandbox (`storage.googleapis.com` is blocked in attached sandboxes); Captain runs full Flutter `3.50.0` `dart format`, `flutter analyze`, and `flutter test` before landing on `main`.

## Allowed files (exact — touch nothing else)

1. `assets/data/manifest.json`
2. `assets/data/chapters/chapter_11.json` *(new)*
3. `assets/data/chapters/chapter_12.json` *(new)*
4. `assets/data/chapters/chapter_13.json` *(new)*
5. `assets/data/chapters/chapter_14.json` *(new)*
6. `assets/data/chapters/chapter_15.json` *(new)*
7. `README.md`
8. `test/content_repository_test.dart`

## Requirements

### 1. Intermediate curriculum arc (`ch11`–`ch15`)
Continue the warm, connected school story of Rahul (`rahul`), Priya (`priya`), and Mrs. Sen (`teacher`) right after Sports Day (`ch10`), introducing GrammarBondhu's **Intermediate** tier (`"difficulty": "intermediate"`):

| Order | ID | File | Grammar topic (`en`) | Story theme | Rewards |
|---|---|---|---|---|---|
| 11 | `ch11` | `chapters/chapter_11.json` | `Future Plans (will / going to)` | **Planning the Class Picnic** — planning ahead with `going to` and offering on-the-spot help with `will` | `100 XP`, `20 coins`, `3 max_stars` |
| 12 | `ch12` | `chapters/chapter_12.json` | `Quantity Words (some / any / many / much)` | **Packing the Picnic Basket** — counting sandwiches vs measuring water with `some`, `any`, `many`, and `much` | `100 XP`, `20 coins`, `3 max_stars` |
| 13 | `ch13` | `chapters/chapter_13.json` | `Adverbs (How & How Often)` | **In the School Garden** — describing *how* (`carefully`, `quietly`, `well`) and *how often* (`always`, `often`, `never`) actions happen | `110 XP`, `22 coins`, `3 max_stars` |
| 14 | `ch14` | `chapters/chapter_14.json` | `Joining Ideas (and / but / because / so)` | **The Rainy-Day Play** — connecting sentences cleanly with `and` (addition), `but` (contrast), `because` (reason), and `so` (result) | `110 XP`, `22 coins`, `3 max_stars` |
| 15 | `ch15` | `chapters/chapter_15.json` | `Present Perfect (have / has + done)` | **Our Class Scrapbook** — warm finale looking back at the weather notebook, plant chart, newspaper, Sports Day, and picnic using `have` / `has` + past participle (`made`, `written`, `learned`, `grown`) | `120 XP`, `24 coins`, `3 max_stars` |

Total curriculum XP becomes `760 + 540 = 1300 XP` (`15` chapters, `75` quiz questions, `260` coins).

### 2. Schema, asset & language quality rules
- Every chapter must pass `Chapter.validateJson(json)` with zero errors and have `"estimated_duration_minutes": 14` (or `12`–`15`), `"difficulty": "intermediate"`, **3 scenes** (`ch11_s1`..`ch15_s3`), at least **1 interactive choice** (`ch11_c1`..`ch15_c1`) with trilingual `text` and `response`, a `lesson` with trilingual `title` + `explanation` + **4 examples** (English `sentence` + trilingual `note`), and **5 quiz questions** (`ch11_q1`..`ch15_q5`) each with **4 distinct options**, valid `correct_index` covering **all 4 positions `{0, 1, 2, 3}`** within every chapter, and trilingual `explanation`.
- Make every quiz question **100% grammatically unambiguous** — only the option at `correct_index` should be defensible English in context (e.g. give explicit context when contrasting `will` vs `going to`, `because` vs `so`, or `present perfect` vs `simple past`).
- Use natural, idiomatic, child-friendly English, Bengali (বাংলা — standard spelling, e.g. `হিন্দি`, natural Kolkata/classroom register matching `ch06`–`ch10`), and Hindi (हिन्दी — accurate Devanagari and nuqta/matra usage matching `ch06`–`ch10`).
- Use **only** existing registered IDs and bundled assets:
  - `character_ids` / `character_id`: `"rahul"`, `"priya"`, `"teacher"`
  - `background_id`: `"bg_school_gate"`, `"bg_classroom"`, `"bg_library"`, `"bg_school_garden"`
  - `thumbnail_asset`: existing `assets/illustrations/ch0{1..5}_thumb.webp`
  - `background_asset`: existing `assets/backgrounds/bg_{school_gate,classroom,library,school_garden}.webp`
- Ensure every `scene_id`, `choice.id`, and `question_id` is globally unique across all 15 chapters (`ch01`–`ch15`).

### 3. Manifest, README & tests
- `assets/data/manifest.json`: append ordered entries `11`–`15` for `ch11`–`ch15`.
- `README.md`: update the chapter list to cover all 15 chapters (clearly noting Beginner chapters 1–10 and Intermediate chapters 11–15).
- `test/content_repository_test.dart`:
  - Import `package:grammar_bondhu/data/models/progress.dart` and verify:
    - All 15 chapters `ch01`–`ch15` load in order `1`–`15`.
    - `ch01`–`ch10` have `difficulty == 'beginner'` and `ch11`–`ch15` have `difficulty == 'intermediate'`.
    - Every chapter passes `Chapter.validateJson`, carries non-empty trilingual (`en`, `bn`, `hi`) text on all learner-facing fields, uses registered assets that exist on disk, has globally unique IDs, has 5 quiz questions with 4 distinct options covering `{0, 1, 2, 3}`, and handles `byId` / `nextAfter` / `recommendedNext` through `ch15`.
    - Total curriculum XP equals `1300`, and `UserProgress(totalXp: totalXp)` reaches `level >= 5` with `levelTitle == 'English Champion'`.
  - Keep Dart formatting clean (80-column lines, no unused imports). Run an independent Python check on all 15 JSON files before `worker_lane.py check`.

## Handoff
Follow `agent-bootstrap/captain/FASTLANE.md`: `start` → edit → `check` → `diff` → `publish`, then post or return the exact `AGENT C PUSHED` block for Issue `#6`. Do not open a PR, touch `main`, or dispatch CI.
