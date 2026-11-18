# cloud-progress-safety — Worker A

**Repository:** `Keshab1997/GrammarBondhu` — attach this repo in Arena Agent Mode. This is a first task from the exact `main` baseline in `task.json`; if your linked checkout is not at that base, report `BLOCKED` without switching or resetting branches.

**Goal and acceptance:** A stale cloud copy must not undo review completion or a device-only reset.

- A question marked reviewed or answered correctly stays out after merging an older missed copy; a newer wrong answer can put it back. Preserve unrelated missed questions and load legacy snapshots without losing their review entries.
- Keep **Reset Progress** device-only. While there is an active **or saved** Google backup connection, ask the learner to disconnect in Profile first; do not clear local progress, delete or replace the cloud backup, or report a successful reset yet. After disconnect, the existing local reset must work. An explicit later reconnect may restore backed-up progress.
- Coordinate manual and background sync so that edits made while a sync is in flight survive. A queued or completed sync from a disconnected or superseded session must not change current local progress or sync status.
- Add delayed fake-backup regressions for review removal and re-add, a local edit made during sync, and an old sync completing after disconnect/reset. Do not use a real Firebase backend or Google account in tests.

**Interface / exclusions:** Preserve the guest/offline flow and the existing progress API and Firebase backup document format for older snapshots; use backward-compatible fields if needed. No changes to quiz UI, `lib/main.dart`, auth, Firestore rules, Firebase/CI settings, or tool/pack files. If a shared entry-point change is needed, report it to the Captain instead of editing it.

**Scope and gate:** [task.json](task.json) freezes the exact file list and Flutter 3.50.0 test. Use the existing lockfile. If the exact SDK, lockfile check, or targeted test is unavailable, report `BLOCKED`; do not substitute a different SDK/gate or claim success.

**Report:** After the Fast Lane verifies `PUSHED`, post one `@Keshab1997` checkpoint comment in [tracker #6](https://github.com/Keshab1997/GrammarBondhu/issues/6) with the pinned brief, full checkpoint block, commit link, and one-line result. Return the comment link in Arena. If issue comment access is unavailable, report the block and commit link in Arena with `MENTION PENDING` and the reason; do not pair again.

Use the current [Captain Fast Lane](https://github.com/Keshab1997/agent-bootstrap/blob/main/captain/FASTLANE.md), not the old app `AGENTS.md` direct-to-`main` shortcut. Stay on the real `arena/*` branch. Do not run `tool/agent_loop.py`, dispatch CI, or open/merge/close a PR. If no checkpoint was pushed, report `AGENT A BLOCKED` and the reason.
