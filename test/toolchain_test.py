"""Guards the Flutter <-> Android toolchain split that broke the APK build once.

Runs the real checker against throwaway copies of the repo with one number
knocked out of line. No Flutter SDK needed: the checker falls back to its
built-in table, which is exactly what a bare sandbox has.
"""

from __future__ import annotations

import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
CHECKER = ROOT / "tool" / "check_toolchain.py"


def _copy(tmp: pathlib.Path) -> pathlib.Path:
    """A minimal repo: the pins the checker reads, nothing else."""
    for rel in (".fvmrc", "android/settings.gradle.kts",
                "android/gradle/wrapper/gradle-wrapper.properties"):
        dest = tmp / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(ROOT / rel, dest)
    return tmp


def _run(tmp: pathlib.Path) -> tuple[int, str]:
    out = subprocess.run([sys.executable, str(CHECKER), "--root", str(tmp)],
                         cwd=tmp, capture_output=True, text=True)
    return out.returncode, out.stdout + out.stderr


def _edit(path: pathlib.Path, old: str, new: str) -> None:
    text = path.read_text()
    assert old in text, f"{old} not in {path}"
    path.write_text(text.replace(old, new))


def main() -> int:
    failures = []

    with tempfile.TemporaryDirectory() as bad:
        tmp = _copy(pathlib.Path(bad))
        # The exact number that failed the real build.
        _edit(tmp / "android/settings.gradle.kts", 'version "9.3.1"', 'version "9.1.0"')
        code, log = _run(tmp)
        if code == 0 or "below Flutter" not in log:
            failures.append("AGP below the floor was not reported")
        elif "9.1.1" not in log:
            failures.append("AGP failure does not name the minimum version")

    with tempfile.TemporaryDirectory() as bad:
        tmp = _copy(pathlib.Path(bad))
        _edit(tmp / "android/gradle/wrapper/gradle-wrapper.properties",
              "gradle-9.5.0-all.zip", "gradle-8.9-all.zip")
        code, log = _run(tmp)
        if code == 0 or "Gradle 8.9" not in log:
            failures.append("Gradle below the floor was not reported")

    with tempfile.TemporaryDirectory() as bad:
        tmp = _copy(pathlib.Path(bad))
        (tmp / ".fvmrc").write_text('{\n  "flutter": "9.99.99"\n}\n')
        code, log = _run(tmp)
        if code == 0 or "no constraint table" not in log:
            failures.append("an unknown Flutter version passed silently")

    with tempfile.TemporaryDirectory() as good:
        code, log = _run(_copy(pathlib.Path(good)))
        if code != 0 or "consistent" not in log:
            failures.append(f"the real tree is not consistent:\n{log}")

    for failure in failures:
        print(f"toolchain: {failure}")
    print(f"toolchain checks: {4 - len(failures)}/4 passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
