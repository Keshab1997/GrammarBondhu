# chapters-06-to-10 — Worker C

**Repository:** `Keshab1997/GrammarBondhu` — attach in a fresh Arena Agent Mode chat (baseline `e648e6a2dcd3b7de04352659ccadb091b9e2db2e`).
**Goal and acceptance:** Expand GrammarBondhu's bundled story curriculum from 5 chapters (320 XP — where Level 5 `English Champion` at 400 XP was unreachable) to **10 cohesive, warm, trilingual (English + Bengali + Hindi) chapters** starring Rahul, Priya, and Mrs. Sen:
1. **Author `assets/data/chapters/chapter_06.json` .. `chapter_10.json` and register them in `assets/data/manifest.json` (`order` 6..10):**
   - `ch06` — **Rainy Day at School** · Grammar: *Present Continuous (`am / is / are + -ing`)* · `xp: 80, coins: 16, max_stars: 3`
   - `ch07` — **Whose Notebook Is This?** · Grammar: *Pronouns & Possessives (`I/me/my/mine`, `he/him/his`, `they/their`)* · `xp: 80, coins: 16, max_stars: 3`
   - `ch08` — **The Science Exhibition** · Grammar: *Adjectives & Comparisons (`tall / taller / tallest`, `more ... than`)* · `xp: 90, coins: 18, max_stars: 3`
   - `ch09` — **The School Newspaper** · Grammar: *Asking Questions (`Do / Does / Did` & `Wh-` words)* · `xp: 90, coins: 18, max_stars: 3`
   - `ch10` — **Ready for Sports Day** · Grammar: *Helpful Modals (`can / should / must`)* · `xp: 100, coins: 20, max_stars: 3`
2. **Exact schema & asset discipline (match `chapter_01.json`..`chapter_05.json` and `Chapter.validateJson`):**
   - Every chapter has `chapter_id`, trilingual `title`, `description`, `grammar_topic` (`en`, `bn`, `hi` — natural, idiomatic Bengali in বাংলা script and natural Hindi in देवनागरी script), `difficulty` (respect `Chapter.validateJson`), `estimated_duration_minutes`, existing bundled `thumbnail_asset` (reuse `assets/illustrations/ch01_thumb.webp`..`ch05_thumb.webp` so every file exists on disk) and `background_asset` (`assets/backgrounds/bg_*.webp`), and `rewards`.
   - 3 scenes per chapter (`chNN_s1`..`chNN_s3`) using only registered `background_id`s (`bg_school_gate`, `bg_classroom`, `bg_school_garden`, `bg_library`) and `character_ids` (`rahul`, `priya`, `teacher`), warm age-appropriate dialogue lines that naturally model the chapter's grammar point, and at least one interactive `choices` entry (`id`, trilingual `text`, trilingual `response`).
   - `lesson` with trilingual `title`, clear trilingual `explanation`, and 4 concrete English `examples` each with a trilingual `note`.
   - `quiz` of exactly **5 MCQs** (`chNN_q1`..`chNN_q5`), each with 4 distinct options, **strictly one unambiguously correct option** (double-check every distractor so none forms a valid alternative sentence!), **all four `correct_index` values `(0, 1, 2, 3)` used in every chapter**, and kind, specific trilingual `explanation`s (`en`, `bn`, `hi`).
3. **Update `README.md` & `test/content_repository_test.dart`:**
   - Update `README.md` feature summary to describe all 10 chapters and topics (and fix the mixed Bengali/Devanagari typo `हिन्दী` -> `हिन्दी` on line 7!).
   - Expand `test/content_repository_test.dart` for `ch01`..`ch10`: assert `Chapter.validateJson` is empty for every bundled chapter JSON, non-empty trilingual strings across titles/descriptions/topics/dialogues/choices/lessons/example-notes/quiz-explanations, globally unique scene/choice/question IDs, registered `AssetLookup` character & background IDs, existing on-disk `thumbnail_asset` & `background_asset` files, 4 unique options per question, all 4 `correct_index` positions per chapter, `nextAfter('ch05')!.id == 'ch06'`, `nextAfter('ch10') == null`, `recommendedNext((_) => true).id == 'ch10'`, and total curriculum XP >= 700 (unlocking Level 5 `English Champion`).

**Interface / exclusions:** Only edit files in `allowed`. Do not touch `lib/**`, audio files, workflows, `pubspec.yaml`, `pubspec.lock`, or `tool/*`.
**Scope and gate:** See [task.json](task.json) at this same commit. Do not edit it.
**Report:** Post on https://github.com/Keshab1997/GrammarBondhu/issues/6 mentioning `@Keshab1997` (or report in worker chat with `MENTION PENDING` if commenting is unavailable).

Use the current agent-bootstrap `captain/FASTLANE.md` (not `tool/agent_loop.py` direct-to-`main`). Keep the real `arena/*` branch. After a verified `PUSHED`, include the brief link, checkpoint block, and commit link. If blocked, report `AGENT C BLOCKED` with the reason; do not switch branches, re-pair, run CI, or open/merge/close a PR.
