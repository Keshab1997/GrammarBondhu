#!/usr/bin/env python3
"""Generate real waveform-synced lip-sync envelopes for bundled voice clips.

Reads every clip listed in `lib/features/audio/audio_catalog.g.dart`, runs
zero-phase speech-band (180-3500 Hz), open-vowel F1 (420-1150 Hz), and
sibilant (3800-7800 Hz) analysis on the 24 kHz audio, applies human jaw
smoothing + syllable-peak gating, and writes `lib/features/audio/audio_lipsync.g.dart`.

Encoding per clip (50 ms / 20 Hz step):
  '0' -> MouthFrame.closed  (silence, breath, comma/period pause, labial stop)
  '1' -> MouthFrame.half    (conversational vowels, transitions, soft consonants)
  '2' -> MouthFrame.open    (stressed open-vowel syllable peaks only)
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, find_peaks, sosfiltfilt

ROOT = Path(__file__).resolve().parent.parent
CATALOG_PATH = ROOT / "lib/features/audio/audio_catalog.g.dart"
OUT_PATH = ROOT / "lib/features/audio/audio_lipsync.g.dart"

STEP_MS = 50  # 20 Hz animation grid


def _bandpass(signal: np.ndarray, sr: int, low: float, high: float) -> np.ndarray:
    nyq = 0.5 * sr
    hi = min(high, nyq * 0.94)
    lo = max(low, 20.0)
    if lo >= hi or len(signal) < 64:
        return np.zeros_like(signal)
    sos = butter(3, [lo / nyq, hi / nyq], btype="bandpass", output="sos")
    return sosfiltfilt(sos, signal)


def _frame_rms(x: np.ndarray, hop: int, win: int) -> np.ndarray:
    n_frames = max(1, int(np.ceil(len(x) / hop)))
    out = np.zeros(n_frames, dtype=np.float64)
    half = win // 2
    sq = x * x
    csum = np.concatenate(([0.0], np.cumsum(sq)))
    n = len(x)
    for i in range(n_frames):
        center = i * hop + hop // 2
        a = max(0, center - half)
        b = min(n, center + half)
        if b > a:
            out[i] = np.sqrt((csum[b] - csum[a]) / (b - a))
    return out


def analyze_clip(path: Path) -> tuple[str, int]:
    samples, sr = sf.read(path, dtype="float64", always_2d=False)
    if samples.ndim > 1:
        samples = samples.mean(axis=1)
    duration_ms = int(round(len(samples) * 1000.0 / sr))
    if len(samples) < sr // 20:
        return "0", max(duration_ms, STEP_MS)

    peak = float(np.max(np.abs(samples)))
    if peak < 1e-4:
        n = max(1, duration_ms // STEP_MS)
        return "0" * n, duration_ms

    # Zero-phase acoustic bands so mouth timing has zero filter lag.
    vocal = _bandpass(samples, sr, 180.0, 3500.0)
    f1_open = _bandpass(samples, sr, 420.0, 1180.0)
    sibilant = _bandpass(samples, sr, 3800.0, 7800.0)

    hop = max(1, int(round(sr * STEP_MS / 1000.0)))
    win = max(hop, int(round(sr * 0.065)))  # 65 ms Hann-like integration window

    rms_vocal = _frame_rms(vocal, hop, win)
    rms_f1 = _frame_rms(f1_open, hop, win)
    rms_sib = _frame_rms(sibilant, hop, win)
    n = len(rms_vocal)

    # Adaptive per-clip normalization.
    noise = float(np.percentile(rms_vocal, 8))
    max_v = float(np.max(rms_vocal))
    gate = max(noise * 2.4, max_v * 0.085)
    active = rms_vocal[rms_vocal > gate]
    if len(active) == 0:
        return "0" * n, duration_ms

    ref = float(np.percentile(active, 86))
    denom = max(ref - gate, 1e-6)
    loud = np.clip((rms_vocal - gate) / denom, 0.0, 1.30)

    # First-formant ratio distinguishes open vowels (/a, o, e/) from closed
    # vowels (/i, u/) and nasals (/m, n/) so the jaw opens widest on real
    # open vowels instead of every loud phoneme.
    f1_ratio = rms_f1 / (rms_vocal + 1e-6)
    f1_gain = np.clip(0.52 + 0.72 * ((f1_ratio - 0.25) / 0.55), 0.48, 1.18)

    # Fricatives/sibilants (/s, sh, f, t/) are spoken with nearly closed lips.
    sib_ratio = rms_sib / (rms_vocal + 1e-6)
    sib_gain = np.where(sib_ratio > 0.90, 0.42, np.where(sib_ratio > 0.60, 0.72, 1.0))

    # Detect crisp voiceless/bilabial consonant dips (/p, b, m, t, k/) and real
    # speech silences directly on the unsmoothed vocal loudness.
    voiced = rms_vocal > max(noise * 2.6, max_v * 0.095)

    jaw_target = np.where(voiced, np.clip(loud * f1_gain * sib_gain, 0.0, 1.25), 0.0)

    # Biomechanical jaw follower: responsive vowel attack, gentle natural close.
    jaw = np.zeros(n, dtype=np.float64)
    cur = 0.0
    for i in range(n):
        tgt = jaw_target[i]
        if tgt >= cur:
            cur += 0.62 * (tgt - cur)
        else:
            # Close promptly in true silence, gently across connected syllables.
            alpha = 0.56 if not voiced[i] else 0.38
            cur += alpha * (tgt - cur)
        jaw[i] = cur

    # Base voiced/silence state with hysteresis: '0' closed, '1' half-open.
    states = [0] * n
    speaking = False
    for i in range(n):
        if not speaking:
            if voiced[i] and jaw[i] >= 0.16:
                speaking = True
        else:
            # Close on real pauses OR distinct intra-phrase labial/stop closures.
            if (not voiced[i] and jaw[i] < 0.14) or jaw[i] < 0.10:
                speaking = False
        states[i] = 1 if speaking else 0

    # Suppress isolated 1-frame (50 ms) micro-blips so the mouth never twitches.
    for i in range(1, n - 1):
        if states[i - 1] == states[i + 1] and states[i] != states[i - 1]:
            states[i] = states[i - 1]

    # Add calm natural labial closures inside long uninterrupted voiced runs
    # (> 550 ms = 11 frames) at genuine local energy valleys so a fast phrase
    # articulates naturally instead of holding a frozen half-open mouth.
    valleys, _ = find_peaks(-jaw, distance=6, prominence=0.14)
    valley_set = {int(v) for v in valleys if jaw[v] < 0.34}
    for v in sorted(valley_set):
        if 1 <= v < n - 1 and states[v] == 1:
            # Check if surrounded by a long run of non-zero frames.
            left = v
            while left > 0 and states[left - 1] > 0:
                left -= 1
            right = v
            while right < n - 1 and states[right + 1] > 0:
                right += 1
            if (right - left) >= 10:
                states[v] = 0
                if v + 1 < n - 1 and jaw[v + 1] < 0.36:
                    states[v + 1] = 0

    # Promote ONLY genuine stressed open-vowel syllable peaks to '2' (open).
    # Minimum distance of 6 frames (300 ms) caps wide openings at ~2-2.6/sec —
    # matching natural human speech rhythm instead of rapid cartoon chatter.
    peaks, _ = find_peaks(jaw, distance=6, height=0.52, prominence=0.11)
    for p in peaks:
        p = int(p)
        if states[p] == 0:
            continue
        # Hold open across the syllable nucleus (150-200 ms = 3-4 frames).
        span = [p]
        if p - 1 >= 0 and states[p - 1] == 1 and jaw[p - 1] >= max(0.44, jaw[p] * 0.76):
            span.insert(0, p - 1)
        if p + 1 < n and states[p + 1] == 1 and jaw[p + 1] >= max(0.42, jaw[p] * 0.72):
            span.append(p + 1)
        if len(span) < 3:
            # Ensure at least 150 ms hold when voiced neighbours support it so
            # an open vowel reads warmly instead of flashing for 50-100 ms.
            if span[-1] + 1 < n and states[span[-1] + 1] == 1 and jaw[span[-1] + 1] >= 0.34:
                span.append(span[-1] + 1)
            elif span[0] - 1 >= 0 and states[span[0] - 1] == 1 and jaw[span[0] - 1] >= 0.34:
                span.insert(0, span[0] - 1)
        if len(span) >= 2:
            for idx in span[:4]:
                states[idx] = 2

    # If a long voiced clause (>= 450 ms = 9 frames) had soft prosody and never
    # hit a loud '2' peak, lift its single strongest vowel nucleus (2-3 frames)
    # so softer phrases still show gentle jaw articulation instead of holding a
    # static half-open frame for half a second.
    i = 0
    while i < n:
        if states[i] > 0:
            j = i
            has_open = False
            while j < n and states[j] > 0:
                if states[j] == 2:
                    has_open = True
                j += 1
            if not has_open and (j - i) >= 9:
                seg = jaw[i + 1 : j - 1]
                best = i + 1 + int(np.argmax(seg))
                if jaw[best] >= 0.32:
                    states[best] = 2
                    if best + 1 < j - 1 and jaw[best + 1] >= 0.28:
                        states[best + 1] = 2
            i = j
        else:
            i += 1

    # Break up a long frozen half-open hold (> 250 ms = 5 frames) with one
    # gentle jaw emphasis at its strongest point, so a run of connected
    # syllables keeps breathing instead of parking on a single shape.
    i = 0
    while i < n:
        if states[i] == 1:
            j = i
            while j < n and states[j] == 1:
                j += 1
            if (j - i) >= 5:
                seg = jaw[i:j]
                best = i + int(np.argmax(seg))
                if jaw[best] >= 0.45 and jaw[best] <= 0.72:
                    states[best] = 2
                    if best + 1 < j and jaw[best + 1] >= 0.42:
                        states[best + 1] = 2
            i = j
        else:
            i += 1

    # Ensure there is always at least 100 ms (2 frames) of half/closed rest
    # between consecutive open peaks so back-to-back opens never chatter.
    i = 0
    while i < n:
        if states[i] == 2:
            j = i
            while j < n and states[j] == 2:
                j += 1
            if j + 1 < n and states[j] == 1 and states[j + 1] == 2:
                states[j + 1] = 1
            i = j
        else:
            i += 1

    # Biomechanical jaw rule: never jump 0 -> 2 or 2 -> 0 without passing
    # through '1' (half-open), and always rest on '0' at the final frame.
    states[-1] = 0
    for i in range(n - 1):
        if states[i] == 0 and states[i + 1] == 2:
            states[i + 1] = 1
        elif states[i] == 2 and states[i + 1] == 0:
            states[i] = 1

    # Clean up any leftover 1-frame open flicker created by boundary clamping.
    for i in range(1, n - 1):
        if states[i] == 2 and states[i - 1] != 2 and states[i + 1] != 2:
            states[i] = 1

    return "".join(str(s) for s in states), duration_ms


def parse_catalog(text: str) -> list[tuple[str, str]]:
    ids = re.findall(r"^\s*'([a-z0-9_]+)',\s*$", text, flags=re.MULTILINE)
    return [(cid, f"assets/audio/clips/{cid}.mp3") for cid in ids]


def main() -> int:
    if not CATALOG_PATH.exists():
        print(f"Missing {CATALOG_PATH}", file=sys.stderr)
        return 1
    entries = parse_catalog(CATALOG_PATH.read_text(encoding="utf-8"))
    if not entries:
        print("No clips found in audio_catalog.g.dart", file=sys.stderr)
        return 1

    envelopes: list[tuple[str, int, str]] = []
    total_sec = 0.0
    total_transitions = 0
    total_open_runs = 0
    counts = {0: 0, 1: 0, 2: 0}

    for clip_id, rel_path in entries:
        audio_path = ROOT / rel_path
        if not audio_path.exists():
            print(f"Missing audio file: {audio_path}", file=sys.stderr)
            return 1
        env, dur_ms = analyze_clip(audio_path)
        envelopes.append((clip_id, dur_ms, env))

        total_sec += dur_ms / 1000.0
        for ch in env:
            counts[int(ch)] += 1
        for a, b in zip(env, env[1:]):
            if a != b:
                total_transitions += 1
            if a != "2" and b == "2":
                total_open_runs += 1

    lines = [
        "// GENERATED CODE - DO NOT MODIFY BY HAND.",
        "// Regenerate with: python3 tool/build_audio_lipsync.py",
        "",
        "import '../../core/utils/speech_cadence.dart';",
        "",
        "/// Precomputed 20 Hz (50 ms) acoustic lip-sync timelines for every",
        "/// bundled narration clip, extracted directly from each MP3 waveform's",
        "/// vocal energy, open-vowel F1 formant band, and natural speech pauses.",
        "class AudioLipSync {",
        "  const AudioLipSync._();",
        "",
        f"  /// Milliseconds per encoded viseme character in [_envelopes].",
        f"  static const int stepMs = {STEP_MS};",
        "",
        "  /// Slight visual lead (ITU-R BT.1359) so jaw opening feels locked to",
        "  /// consonant/vowel onset rather than trailing behind the ear.",
        "  static const int visualLeadMs = 25;",
        "",
        "  static bool has(String clipId) => _envelopes.containsKey(clipId);",
        "",
        "  /// Exact duration of [clipId] in milliseconds, or null when uncatalogued.",
        "  static int? durationMsOf(String clipId) {",
        "    final env = _envelopes[clipId];",
        "    return env == null ? null : env.length * stepMs;",
        "  }",
        "",
        "  /// Mouth shape at [position] inside [clipId]'s real audio playback.",
        "  static MouthFrame frameAt(String clipId, Duration position) {",
        "    final env = _envelopes[clipId];",
        "    if (env == null || env.isEmpty) return MouthFrame.closed;",
        "    final ms = position.inMilliseconds;",
        "    if (ms <= 0) return MouthFrame.closed;",
        "    final idx = (ms + visualLeadMs) ~/ stepMs;",
        "    if (idx < 0 || idx >= env.length) return MouthFrame.closed;",
        "    switch (env.codeUnitAt(idx)) {",
        "      case 0x32: // '2'",
        "        return MouthFrame.open;",
        "      case 0x31: // '1'",
        "        return MouthFrame.half;",
        "      default:",
        "        return MouthFrame.closed;",
        "    }",
        "  }",
        "",
        "  /// Smoothed vocal energy in [0.0, 1.0] around [position], used for",
        "  /// gentle phrase-level breathing and head emphasis without rapid jitter.",
        "  static double energyAt(String clipId, Duration position) {",
        "    final env = _envelopes[clipId];",
        "    if (env == null || env.isEmpty) return 0.0;",
        "    final ms = position.inMilliseconds;",
        "    if (ms <= 0) return 0.0;",
        "    final center = (ms + visualLeadMs) ~/ stepMs;",
        "    if (center < 0 || center >= env.length) return 0.0;",
        "    var sum = 0.0;",
        "    var weight = 0.0;",
        "    for (var offset = -4; offset <= 4; offset++) {",
        "      final i = center + offset;",
        "      if (i < 0 || i >= env.length) continue;",
        "      final w = 1.0 + 0.6 * (4 - offset.abs());",
        "      final code = env.codeUnitAt(i);",
        "      final v = code == 0x32 ? 1.0 : (code == 0x31 ? 0.52 : 0.0);",
        "      sum += v * w;",
        "      weight += w;",
        "    }",
        "    return weight == 0 ? 0.0 : (sum / weight).clamp(0.0, 1.0);",
        "  }",
        "",
        "  static const Map<String, String> _envelopes = <String, String>{",
    ]
    for clip_id, _dur_ms, env in envelopes:
        if len(env) <= 64:
            lines.append(f"    '{clip_id}': '{env}',")
        else:
            lines.append(f"    '{clip_id}':")
            for start in range(0, len(env), 68):
                chunk = env[start : start + 68]
                suffix = "," if start + 68 >= len(env) else ""
                lines.append(f"        '{chunk}'{suffix}")
    lines.extend(["  };", "}", ""])

    OUT_PATH.write_text("\n".join(lines), encoding="utf-8")

    # The checked-in file must already be in `dart format` shape: CI runs
    # `dart format --set-exit-if-changed .` and generated code is not exempt.
    dart = shutil.which("dart")
    if dart:
        subprocess.run([dart, "format", str(OUT_PATH)], check=False)
    else:
        print("  ! dart not on PATH -- run `dart format` before committing")

    total_frames = sum(counts.values())
    print(
        f"Generated {OUT_PATH.relative_to(ROOT)}: {len(envelopes)} clips, "
        f"{total_sec:.1f}s audio, {OUT_PATH.stat().st_size / 1024:.1f} KB"
    )
    print(
        f"  Distribution: closed={100*counts[0]/total_frames:.1f}% | "
        f"half={100*counts[1]/total_frames:.1f}% | "
        f"open={100*counts[2]/total_frames:.1f}%"
    )
    print(
        f"  Cadence: {total_transitions / total_sec:.2f} frame changes/sec | "
        f"{total_open_runs / total_sec:.2f} open-vowel peaks/sec"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
