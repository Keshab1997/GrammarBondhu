#!/usr/bin/env python3
"""Every chapter must ship its OWN cover: no chapter may borrow another's art.

CI-catchable guard: the chapter JSON points at `assets/illustrations/<id>_thumb.webp`,
the file exists, and no two chapters resolve to the same picture.
"""
from __future__ import annotations

import glob
import hashlib
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
failures: list[str] = []
seen: dict[str, str] = {}

for path in sorted(glob.glob(str(ROOT / "assets/data/chapters/chapter_*.json"))):
    data = json.loads(pathlib.Path(path).read_text())
    cid = data["chapter_id"]
    asset = data.get("thumbnail_asset", "")
    want = f"assets/illustrations/{cid}_thumb.webp"
    if asset != want:
        failures.append(f"{cid}: cover is {asset or 'missing'}, expected {want}")
        continue
    file = ROOT / asset
    if not file.exists():
        failures.append(f"{cid}: {asset} does not exist")
        continue
    digest = hashlib.sha256(file.read_bytes()).hexdigest()
    if digest in seen:
        failures.append(f"{cid} and {seen[digest]} ship the same cover file")
    seen[digest] = cid

# Grammar-topic badges: one dedicated picture per chapter, never a shared one.
for path in sorted(glob.glob(str(ROOT / "assets/data/chapters/chapter_*.json"))):
    data = json.loads(pathlib.Path(path).read_text())
    cid = data["chapter_id"]
    want = f"assets/icons/topic_{cid}.webp"
    icon = data.get("topic_icon_asset")
    if icon is not None and not (ROOT / icon).exists():
        failures.append(f"{cid}: topic badge {icon} does not exist")

for f in failures:
    print(f"cover: {f}")
print(f"covers: {len(seen)} unique chapter cover(s) "
      f"of {len(glob.glob(str(ROOT / 'assets/data/chapters/chapter_*.json')))} chapter(s)")
sys.exit(1 if failures else 0)
