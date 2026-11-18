# quiz-finish-once — Worker B

**Repository:** `Keshab1997/GrammarBondhu` — attach this repo in Arena Agent Mode. This is a first task from the exact `main` baseline in `task.json`; if your linked checkout is not at that base, report `BLOCKED` without switching or resetting branches.

**Goal and acceptance:** Rapid repeated taps on **Finish Quiz** must record one attempt and make one completion navigation, including while saving is still in progress. Add a widget regression that holds the save pending and taps again. A normal one-tap finish must still work.

**Interface / exclusions:** Keep the existing score, XP/coins, review-list, daily goal, retry behaviour, and completion route/arguments. Do not change `ProgressController`, shared widgets, cloud code, CI, lockfiles, or tool/pack files.

**Scope and gate:** [task.json](task.json) freezes the exact file list and Flutter 3.50.0 test. Use the existing lockfile. If the exact SDK, lockfile check, or targeted test is unavailable, report `BLOCKED`; do not substitute a different SDK/gate or claim success.

**Report:** After the Fast Lane verifies `PUSHED`, post one `@Keshab1997` checkpoint comment in [tracker #6](https://github.com/Keshab1997/GrammarBondhu/issues/6) with the pinned brief, full checkpoint block, commit link, and one-line result. Return the comment link in Arena. If issue comment access is unavailable, report the block and commit link in Arena with `MENTION PENDING` and the reason; do not pair again.

Use the current [Captain Fast Lane](https://github.com/Keshab1997/agent-bootstrap/blob/main/captain/FASTLANE.md), not the old app `AGENTS.md` direct-to-`main` shortcut. Stay on the real `arena/*` branch. Do not run `tool/agent_loop.py`, dispatch CI, or open/merge/close a PR. If no checkpoint was pushed, report `AGENT B BLOCKED` and the reason.
