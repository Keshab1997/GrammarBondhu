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
    """One plate per (chapter, room the chapter actually uses)."""
    missing = []
    for c in chapters():
        cid = c["chapter_id"]
        sets = set()
        for scene in c["scenes"]:
            bg = scene.get("background_id") or ""
            if not bg:
                continue
            room = bg[3:] if bg.startswith("bg_") else bg.split("_", 1)[-1]
            if room.startswith("school_"):
                room = room[len("school_"):]
            sets.add(room)
        for room in sorted(sets):
            per_chapter = ROOT / f"assets/backgrounds/scene_{cid}_{room}.webp"
            if not per_chapter.exists():
                missing.append(f"{cid}: scene art for {room}")
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
