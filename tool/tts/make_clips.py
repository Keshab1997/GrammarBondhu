#!/usr/bin/env python3
"""Generate the narration clips that the app plays, from the app's own content.

One source of truth: every mp3 is built from the same chapter JSON the UI
renders, so a rewritten story line can never drift away from what is spoken.
The script also rewrites `lib/features/audio/audio_catalog.g.dart`, so the app
only ever offers a speaker button for a clip that actually exists in the bundle.

Free by default: `edge-tts` speaks through the same neural voices as Azure
(the ones the Edge browser "Read aloud" uses) with no account and no key.
If you do have an Azure key, pass `--provider azure` with
AZURE_SPEECH_KEY and AZURE_SPEECH_REGION set and you get the identical voice
through the licensed endpoint — the clips and the catalog come out the same.

    python3 tool/tts/make_clips.py                 # everything, English + Bangla
    python3 tool/tts/make_clips.py --langs en      # English only
    python3 tool/tts/make_clips.py --only ch01     # one chapter
    python3 tool/tts/make_clips.py --force         # re-render existing clips
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import pathlib
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
DATA = ROOT / "assets" / "data"
CLIPS = ROOT / "assets" / "audio" / "clips"
CATALOG = ROOT / "lib" / "features" / "audio" / "audio_catalog.g.dart"

# A voice per job, not one voice for the whole app: two students talking in the
# teacher's voice sounds like a narrator reading a script, not a conversation.
VOICE = {
    "narrator_f_bn": "bn-IN-TanishaaNeural",
    "narrator_f_en": "en-IN-NeerjaNeural",
    "narrator_m_bn": "bn-IN-BashkarNeural",
    "narrator_m_en": "en-IN-PrabhatNeural",
}

# Story speakers, by who they are. Anything unlisted is treated as female: the
# cast is Rahul (m), Priya (f) and Mrs. Sen (f).
MALE_SPEAKERS = {"rahul"}

# Deliberately NOT in the lesson/progress JSON: these are the three lines the
# teacher says under the board. Keep in step with _teacherLine() in
# lib/features/grammar/grammar_lesson_screen.dart — they are quoted here so the
# audio and the bubble say the same words.
TEACHER_LINES = {
    "en": [
        "The rule is on the board — read it carefully.",
        "Read each example out loud; I am listening.",
        "Your turn now. Try it in the quiz.",
    ],
    "bn": [
        "নিয়মটা বোর্ডে লিখেছি। ভালো করে দেখো।",
        "উদাহরণগুলো জোরে পড়ো — আমি শুনছি।",
        "এখন তোমার পালা। কুইজে চেষ্টা করো।",
    ],
    "hi": [
        "यह नियम बोर्ड पर है। ध्यान से देखो।",
        "उदाहरण ज़ोर से पढ़ो — मैं सुन रही हूँ।",
        "अब अपनी बारी। क्विज़ में आज़माओ।",
    ],
}

# Slower than the story on purpose: this is the text being taught, and the
# learner is reading it at the same time.
LESSON_RATE = "-8%"


def chapters():
    manifest = json.loads((DATA / "manifest.json").read_text(encoding="utf-8"))
    for entry in manifest["chapters"]:
        path = DATA / entry["file"]
        yield json.loads(path.read_text(encoding="utf-8"))


def jobs(langs: set[str], only: str | None):
    """(clip_id, text, voice_key, rate) for every speakable line."""
    out = []
    for ch in chapters():
        cid = ch["chapter_id"]
        if only and cid != only:
            continue

        # Story dialogue: the English line the learner is being taught, and the
        # translation they can reveal underneath it.
        for si, scene in enumerate(ch["scenes"]):
            for li, line in enumerate(scene["dialogue"]):
                who = line["character_id"]
                gender = "m" if who in MALE_SPEAKERS else "f"
                text = line["text"]
                if "en" in langs and text.get("en"):
                    out.append((
                        f"story_{cid}_{si}_{li}_en", text["en"],
                        f"narrator_{gender}_en", "+0%"))
                for lang in ("bn", "hi"):
                    if lang in langs and text.get(lang):
                        out.append((
                            f"story_{cid}_{si}_{li}_{lang}", text[lang],
                            f"narrator_{gender}_{lang}", "+0%"))

        # Lesson board: the explanation, per language the board can show.
        lesson = ch.get("lesson") or {}
        for lang in ("en", "bn", "hi"):
            if lang in langs and (lesson.get("explanation") or {}).get(lang):
                out.append((
                    f"board_{cid}_explain_{lang}", lesson["explanation"][lang],
                    f"narrator_f_{lang}", LESSON_RATE))

        # The example sentences are always English, whatever the board shows —
        # a teacher does not translate the sentence she is teaching.
        examples = [e["sentence"] for e in (lesson.get("examples") or [])]
        if "en" in langs and examples:
            out.append((
                f"board_{cid}_examples_en", " ".join(examples),
                "narrator_m_en", LESSON_RATE))

    # The three lines under the board, per page and per language.
    for lang in ("en", "bn", "hi"):
        if lang not in langs:
            continue
        for page, text in enumerate(TEACHER_LINES[lang], start=1):
            out.append((
                f"teach_{page}_{lang}", text,
                f"narrator_f_{lang}", LESSON_RATE))
    return out


async def render_edge(items, force):
    import edge_tts

    for clip_id, text, voice_key, rate in items:
        target = CLIPS / f"{clip_id}.mp3"
        if target.exists() and not force:
            print(f"  skip  {clip_id}")
            continue
        await edge_tts.Communicate(text, VOICE[voice_key], rate=rate).save(str(target))
        print(f"  edge  {clip_id}  ({target.stat().st_size // 1024} KB)")


def render_azure(items, force):
    key = os.environ.get("AZURE_SPEECH_KEY")
    region = os.environ.get("AZURE_SPEECH_REGION")
    if not key or not region:
        sys.exit("azure: set AZURE_SPEECH_KEY and AZURE_SPEECH_REGION")
    endpoint = f"https://{region}.tts.speech.microsoft.com/cognitiveservices/v1"
    for clip_id, text, voice_key, rate in items:
        target = CLIPS / f"{clip_id}.mp3"
        if target.exists() and not force:
            print(f"  skip  {clip_id}")
            continue
        ssml = (
            f'<speak version="1.0" xml:lang="en-IN"><voice name="{VOICE[voice_key]}">'
            f'<prosody rate="{rate}">{text}</prosody></voice></speak>'
        ).encode("utf-8")
        req = urllib.request.Request(endpoint, data=ssml, method="POST", headers={
            "Ocp-Apim-Subscription-Key": key,
            "Content-Type": "application/ssml+xml",
            "X-Microsoft-OutputFormat": "audio-24khz-48kbitrate-mono-mp3",
            "User-Agent": "GrammarBondhu",
        })
        with urllib.request.urlopen(req) as response:
            target.write_bytes(response.read())
        print(f"  azure {clip_id}  ({target.stat().st_size // 1024} KB)")


def write_catalog(ids):
    """The generated half of the audio API. Checked in so the app compiles
    without Python, and regenerated by this script so it cannot go stale."""
    lines = [
        "// GENERATED by tool/tts/make_clips.py — do not edit by hand.",
        "",
        "/// The narration bundled with the app.",
        "///",
        "/// Generated from the asset folder, so it lists what really shipped: the",
        "/// UI asks [has] before offering a speaker, and a missing clip hides the",
        "/// button instead of failing at playback time.",
        "abstract final class AudioCatalog {",
        "  /// Every narration clip in the bundle.",
        "  static const Set<String> ids = <String>{",
        *[f"    '{i}'," for i in sorted(ids)],
        "  };",
        "",
        "  static bool has(String clipId) => ids.contains(clipId);",
        "",
        "  /// Asset path for a clip id.",
        "  static String assetFor(String clipId) => 'assets/audio/clips/$clipId.mp3';",
        "}",
        "",
    ]
    CATALOG.parent.mkdir(parents=True, exist_ok=True)
    CATALOG.write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--langs", default="en,bn", help="comma list: en,bn,hi")
    parser.add_argument("--only", default=None, help="single chapter id, e.g. ch01")
    parser.add_argument("--provider", default="edge", choices=["edge", "azure"])
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    langs = {x.strip() for x in args.langs.split(",") if x.strip()}
    items = jobs(langs, args.only)
    CLIPS.mkdir(parents=True, exist_ok=True)
    print(f"{len(items)} clip(s), provider={args.provider}, langs={sorted(langs)}")
    if args.provider == "azure":
        render_azure(items, args.force)
    else:
        asyncio.run(render_edge(items, args.force))

    # Only advertise what is really on disk: a half-finished run must not leave
    # the app pointing at clips that were never written.
    on_disk = [p.stem for p in sorted(CLIPS.glob("*.mp3"))]
    write_catalog(on_disk)
    total = sum(p.stat().st_size for p in CLIPS.glob("*.mp3"))
    print(f"catalog: {len(on_disk)} clip(s), {total / 1024 / 1024:.2f} MB -> {CATALOG.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
