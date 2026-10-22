# Narration clips

Every `.mp3` in `clips/` is generated, not hand-recorded:

    python3 tool/tts/make_clips.py          # edge-tts, free, no account
    python3 tool/tts/make_clips.py --force  # re-render everything

The script reads the same chapter JSON the UI renders, so the spoken text can
never drift from the written text, and it rewrites
`lib/features/audio/audio_catalog.g.dart` from whatever is really on disk —
a clip that does not exist simply gets no speaker button.

Clip ids:

| pattern | what it says | voice |
|---|---|---|
| `story_<chapter>_<scene>_<line>_en` | the English dialogue line | en-IN |
| `story_<chapter>_<scene>_<line>_bn` | its Bangla translation | bn-IN |
| `board_<chapter>_explain_<lang>` | the lesson explanation | bn-IN / en-IN |
| `board_<chapter>_examples_en` | the example sentences (always English) | en-IN |
| `teach_<page>_<lang>` | Mrs. Sen's line under the board | bn-IN / en-IN |

Voices: `bn-IN-TanishaaNeural` (Mrs. Sen, Priya), `bn-IN-BashkarNeural`
(Rahul), `en-IN-NeerjaNeural` / `en-IN-PrabhatNeural` (English lines). These are
the same neural voices Azure ships, reached through the free `edge-tts` route;
if you ever need the licensed endpoint, `--provider azure` with
`AZURE_SPEECH_KEY` and `AZURE_SPEECH_REGION` produces identical clips.

Total: 69 clips, ~3 MB — bundled in the APK, so narration works offline.
