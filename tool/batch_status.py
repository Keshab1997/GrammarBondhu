#!/usr/bin/env python3
"""Show which big-batch assets are still missing, grouped so the work can be
handed to parallel agents (one lane per job, no two lanes touching a file)."""
from __future__ import annotations

import glob
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ILL = ROOT / "assets/illustrations"


def chapters() -> list[dict]:
    return [json.loads(pathlib.Path(p).read_text())
            for p in sorted(glob.glob(str(ROOT / "assets/data/chapters/chapter_*.json")))]


def lane_covers() -> list[str]:
    return [f"{c['chapter_id']}: cover {c['thumbnail_asset']}"
            for c in chapters()
            if not (ROOT / c["thumbnail_asset"]).exists()]


def lane_icons() -> list[str]:
    return [f"{c['chapter_id']}: icon assets/icons/topic_{c['chapter_id']}.webp"
            for c in chapters()
            if not (ROOT / f"assets/icons/topic_{c['chapter_id']}.webp").exists()]


def lane_scenes() -> list[str]:
    missing = []
    for c in chapters():
        for bg in sorted({s["background_id"] for s in c["scenes"]}):
            if bg == c.get("background_asset", "").rsplit("/", 1)[-1].removesuffix(".webp"):
                continue
            per_chapter = ROOT / f"assets/backgrounds/{bg}_{c['chapter_id']}.webp"
            if not per_chapter.exists():
                missing.append(f"{c['chapter_id']}: scene art for {bg}")
    return missing


LANES = {
    "covers": (lane_covers, "tool/check_covers.py"),
    "topic icons": (lane_icons, None),
    "per-chapter scenes": (lane_scenes, None),
}

def main() -> int:
    total = 0
    for name, (fn, guard) in LANES.items():
        items = fn()
        total += len(items)
        print(f"\n== {name}: {len(items)} open")
        for item in items:
            print("   -", item)
        if guard:
            print(f"   guard: python3 {guard}")
    print(f"\nbatch: {total} asset(s) still open")
    return 0 if total == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
