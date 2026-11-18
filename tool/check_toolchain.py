#!/usr/bin/env python3
"""check_toolchain.py — catch a Flutter/Android toolchain split before CI does.

The build failed once with "your AGP 9.1.0 is lower than Flutter's minimum
9.1.1" because `.fvmrc` pinned Flutter 3.50.0 while `android/` still carried an
older template's Gradle numbers. Nothing in the repo said the two had to move
together, and the mistake only surfaced after a slow, expensive Gradle run.

This script holds the three numbers in one place and checks that they agree:

    Flutter (pinned in .fvmrc)
      -> minimum / warn AGP      (android/settings.gradle.kts)
      -> minimum / warn Gradle   (android/gradle/wrapper/gradle-wrapper.properties)
      -> minimum Kotlin          (android/settings.gradle.kts)

Where the numbers come from: the pinned Flutter SDK itself, when one is on
PATH (`packages/flutter_tools/gradle/src/main/kotlin/DependencyVersionChecker.kt`
and `lib/src/android/gradle_utils.dart`). Without an SDK it falls back to the
table in KNOWN_FLUTTER below, so the check still runs in a bare sandbox.

    python3 tool/check_toolchain.py            # check this repo
    python3 tool/check_toolchain.py --root ../my_app
    python3 tool/check_toolchain.py --json     # machine-readable
    python3 tool/check_toolchain.py --help

Exit status: 0 = consistent, 1 = at least one problem (or unknown versions).
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys

# The project being checked. Defaults to the repo this script sits in, but
# `--root` (or FLUTTER_BUILDER_ROOT) points it at any checkout — that is how a
# reusable CI job runs it against the caller's tree instead of its own.
ROOT = pathlib.Path(
    os.environ.get("FLUTTER_BUILDER_ROOT", "")
    or pathlib.Path(__file__).resolve().parent.parent)

# Flutter version -> the floor it enforces (error) and the level it warns at.
# Measured from flutter/flutter at each release; extend when bumping .fvmrc.
KNOWN_FLUTTER: dict[str, dict[str, str]] = {
    "3.50.0": {
        "agp_min": "9.1.1",
        "agp_warn": "9.3.1",
        "gradle_min": "9.3.1",
        "gradle_warn": "9.5.0",
        "kotlin_min": "2.4.10",
    },
}


class V(tuple):
    """A dotted version that compares numerically, not as a string."""

    def __new__(cls, text: str):
        parts = [int(p) for p in re.findall(r"\d+", text)[:3]]
        while len(parts) < 3:
            parts.append(0)
        return super().__new__(cls, parts)

    def __str__(self) -> str:  # pragma: no cover - display only
        return ".".join(str(p) for p in self)


def read_text(path: pathlib.Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return ""


def flutter_pin() -> tuple[str | None, str]:
    """(version, where it came from)."""
    fvmrc = read_text(ROOT / ".fvmrc")
    if fvmrc:
        match = re.search(r'"flutter"\s*:\s*"([^"]+)"', fvmrc)
        if match:
            return match.group(1), ".fvmrc"

    flutter = shutil.which("flutter")
    if flutter:
        try:
            out = subprocess.run([flutter, "--version"], capture_output=True,
                                 text=True, timeout=120).stdout
            match = re.search(r"Flutter (\d+\.\d+\.\d+)", out)
            if match:
                return match.group(1), "flutter --version"
        except (OSError, subprocess.SubprocessError):
            pass
    return None, "not found"


def agp_version() -> str | None:
    text = read_text(ROOT / "android/settings.gradle.kts")
    if not text:
        text = read_text(ROOT / "android/settings.gradle")
    match = re.search(
        r'com\.android\.application"?\)?\s*version\s*"?([\d.]+)"?', text)
    return match.group(1) if match else None


def kotlin_version() -> str | None:
    text = read_text(ROOT / "android/settings.gradle.kts")
    match = re.search(
        r'org\.jetbrains\.kotlin\.android"?\)?\s*version\s*"?([\d.]+)"?', text)
    return match.group(1) if match else None


def gradle_version() -> str | None:
    text = read_text(ROOT / "android/gradle/wrapper/gradle-wrapper.properties")
    match = re.search(r"gradle-([\d.]+)-(?:all|bin)\.zip", text)
    return match.group(1) if match else None


def sdk_root() -> pathlib.Path | None:
    """Where the Flutter SDK lives: $FLUTTER_ROOT first (what CI sets), then
    whatever `flutter` resolves to on PATH."""
    root = os.environ.get("FLUTTER_ROOT", "").strip()
    if root and (pathlib.Path(root) / "bin/flutter").exists():
        return pathlib.Path(root)
    flutter = shutil.which("flutter")
    if flutter:
        return pathlib.Path(flutter).resolve().parent.parent
    return None


def sdk_floor(version: str) -> dict[str, str] | None:
    """Query the pinned Flutter SDK for its own constraints, if present."""
    sdk = sdk_root()
    if sdk is None:
        return None
    checker = sdk / ("packages/flutter_tools/gradle/src/main/kotlin/"
                     "DependencyVersionChecker.kt")
    text = read_text(checker)
    if not text:
        return None

    def grab(pattern: str) -> str | None:
        match = re.search(pattern, text)
        return match.group(1) if match else None

    agp_min = grab(r"errorAGPVersion[^=]*=\s*AndroidPluginVersion\(([\d, ]+)\)")
    agp_warn = grab(r"warnAGPVersion[^=]*=\s*AndroidPluginVersion\(([\d, ]+)\)")
    gradle_min = grab(r"errorGradleVersion[^=]*=\s*Version\(([\d, ]+)\)")
    gradle_warn = grab(r"warnGradleVersion[^=]*=\s*Version\(([\d, ]+)\)")
    kotlin_min = grab(r"errorKGPVersion[^=]*=\s*Version\(([\d, ]+)\)")
    if not all((agp_min, agp_warn, gradle_min, gradle_warn, kotlin_min)):
        return None
    dots = lambda s: ".".join(p.strip() for p in s.split(","))  # noqa: E731
    return {
        "agp_min": dots(agp_min),
        "agp_warn": dots(agp_warn),
        "gradle_min": dots(gradle_min),
        "gradle_warn": dots(gradle_warn),
        "kotlin_min": dots(kotlin_min),
        "source": f"Flutter SDK at {sdk}",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="print JSON")
    parser.add_argument("--root", default=None,
                        help="project to check (default: this repo, or "
                             "$FLUTTER_BUILDER_ROOT)")
    args = parser.parse_args()

    global ROOT
    if args.root:
        ROOT = pathlib.Path(args.root).expanduser().resolve()
        if not (ROOT / "android").is_dir():
            print(f"toolchain: {ROOT} has no android/ directory", file=sys.stderr)
            return 1

    flutter, flutter_src = flutter_pin()
    agp, kotlin, gradle = agp_version(), kotlin_version(), gradle_version()

    floor = (sdk_floor(flutter) if flutter else None) or (
        dict(KNOWN_FLUTTER[flutter], source="built-in table")
        if flutter in KNOWN_FLUTTER else None)

    problems: list[str] = []
    notes: list[str] = []

    if flutter is None:
        problems.append("no Flutter version: .fvmrc has no \"flutter\" key and "
                        "no flutter on PATH")
    if agp is None:
        problems.append("cannot read the AGP version from android/settings.gradle.kts")
    if gradle is None:
        problems.append("cannot read Gradle from the wrapper properties")
    if flutter and floor is None:
        problems.append(
            f"no constraint table for Flutter {flutter} — add it to "
            "KNOWN_FLUTTER in tool/check_toolchain.py")

    if floor and agp and gradle:
        if V(agp) < V(floor["agp_min"]):
            problems.append(
                f"AGP {agp} is below Flutter {flutter}'s minimum {floor['agp_min']}"
                " — the build stops before compiling any Dart")
        elif V(agp) < V(floor["agp_warn"]):
            notes.append(f"AGP {agp} works but is below the warn version "
                         f"{floor['agp_warn']}")
        if V(gradle) < V(floor["gradle_min"]):
            problems.append(
                f"Gradle {gradle} is below Flutter {flutter}'s minimum "
                f"{floor['gradle_min']}")
        elif V(gradle) < V(floor["gradle_warn"]):
            notes.append(f"Gradle {gradle} works but is below the warn version "
                         f"{floor['gradle_warn']}")
        if kotlin and V(kotlin) < V(floor["kotlin_min"]):
            problems.append(
                f"Kotlin plugin {kotlin} is below Flutter {flutter}'s minimum "
                f"{floor['kotlin_min']}")

    result = {
        "flutter": flutter,
        "flutter_source": flutter_src,
        "agp": agp,
        "gradle": gradle,
        "kotlin": kotlin,
        "constraints": floor,
        "problems": problems,
        "notes": notes,
        "ok": not problems,
    }

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"flutter {flutter or '?'} ({flutter_src})")
        print(f"  AGP     {agp or '?'}")
        print(f"  Gradle  {gradle or '?'}")
        print(f"  Kotlin  {kotlin or '?'}")
        if floor:
            print(f"  floors from {floor.get('source', '?')}: "
                  f"AGP >= {floor['agp_min']}, Gradle >= {floor['gradle_min']}, "
                  f"Kotlin >= {floor['kotlin_min']}")
        for note in notes:
            print(f"  note: {note}")
        for problem in problems:
            print(f"  FAIL {problem}")
        print("toolchain: " + ("consistent" if not problems
                               else f"{len(problems)} problem(s)"))
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
