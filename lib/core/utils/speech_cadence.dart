/// Discrete mouth shapes backed by bundled full-body character frames.
enum MouthFrame {
  /// Resting closed smile (between clauses, on pauses, and once speech ends).
  closed,

  /// Gently parted lips — short syllables and transitions into/out of vowels.
  half,

  /// Clearly open mouth — stressed and open vowel syllables.
  open,
}

class _Span {
  const _Span(this.endMs, this.frame);

  final int endMs;
  final MouthFrame frame;
}

/// Turns a dialogue line (English, Bengali or Hindi) into a calm, human-paced
/// mouth animation timeline.
///
/// Real narration is lip-synced from the actual waveform (see `AudioLipSync`).
/// This class is the fallback for the two cases where no waveform exists: the
/// learner has narration switched off, and Hindi lines that ship no clip. Both
/// must still read as natural speech, so the pacing here is deliberately
/// *slow* — one comfortable syllable beat at a time with real punctuation
/// pauses — instead of a rapid, television-cartoon flapping.
class SpeechCadence {
  SpeechCadence._(this._spans, this.totalMs);

  /// Comfortable adult narration beat: roughly 3.7 syllables per second, the
  /// measured rate of the bundled neural voices (they read 45 narration lines in
  /// 5.6 s of audio per 20 words). Fast enough to feel
  /// alive, slow enough that a human eye can follow each shape.
  static const int syllableMs = 270;

  factory SpeechCadence.fromText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return SpeechCadence._(const [_Span(400, MouthFrame.closed)], 400);
    }

    final spans = <_Span>[];
    var cursor = 0;

    void push(int durationMs, MouthFrame frame) {
      if (durationMs <= 0) return;
      cursor += durationMs;
      if (spans.isNotEmpty && spans.last.frame == frame) {
        spans[spans.length - 1] = _Span(cursor, frame);
      } else {
        spans.add(_Span(cursor, frame));
      }
    }

    final tokens = trimmed.split(RegExp(r'\s+'));
    var syllableIndex = 0;

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final syllables = _estimateSyllables(token);
      if (syllables == 0) {
        // Punctuation-only token ("—", "…"): just let the pause stand.
        push(_trailingPauseMs(token, isLast: i == tokens.length - 1),
            MouthFrame.closed);
        continue;
      }

      final openHeavy = _hasOpenVowel(token);
      for (var s = 0; s < syllables; s++) {
        // One wide, clearly open vowel every third beat (and always on the
        // stressed first syllable of an open-vowel word). A steady every-third
        // rhythm would look mechanical, so the pattern is offset per word.
        final wide = (openHeavy && s == 0) ||
            (syllables > 1 && (syllableIndex + syllableIndex ~/ 5) % 3 == 0);
        if (wide) {
          // Split the beat so the openness lands centred on the vowel nucleus
          // rather than at the very start of the syllable.
          final openMs = (syllableMs * 0.46).round();
          final halfMs = syllableMs - openMs;
          push(halfMs ~/ 2, MouthFrame.half);
          push(openMs, MouthFrame.open);
          push(halfMs - halfMs ~/ 2, MouthFrame.half);
        } else {
          push((syllableMs * 0.60).round(), MouthFrame.half);
          push((syllableMs * 0.24).round(), MouthFrame.closed);
          push(
              syllableMs -
                  (syllableMs * 0.60).round() -
                  (syllableMs * 0.24).round(),
              MouthFrame.half);
        }
        syllableIndex += 1;
      }

      push(_trailingPauseMs(token, isLast: i == tokens.length - 1),
          MouthFrame.closed);
    }

    if (spans.isEmpty) {
      return SpeechCadence._(const [_Span(400, MouthFrame.closed)], 400);
    }
    return SpeechCadence._(List<_Span>.unmodifiable(spans), cursor);
  }

  final List<_Span> _spans;

  /// Unclamped timeline length in milliseconds.
  final int totalMs;

  /// How long silent narration lingers before handing the scene back.
  ///
  /// Matches the real clip lengths instead of a fixed short window, so a
  /// silently delivered sentence occupies the screen for as long as it would
  /// take to say out loud.
  Duration get silentDuration => Duration(milliseconds: totalMs);

  /// Mouth shape at [elapsed] into the utterance.
  ///
  /// When [loop] is true (live audio is still playing) the timeline wraps so a
  /// slightly slower neural voice read keeps moving naturally until the exact
  /// moment playback finishes. When false, the speaker settles into a closed
  /// smile once the timeline ends.
  MouthFrame frameAt(Duration elapsed, {bool loop = false}) {
    final ms = elapsed.inMilliseconds;
    if (ms < 0 || totalMs <= 0) return MouthFrame.closed;
    if (!loop && ms >= totalMs) return MouthFrame.closed;
    final target = loop ? (ms % totalMs) : ms;

    var low = 0;
    var high = _spans.length - 1;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (target < _spans[mid].endMs) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return _spans[low].frame;
  }

  static final RegExp _latinVowelGroup =
      RegExp(r'[aeiouy]+', caseSensitive: false);
  static final RegExp _indicLetter = RegExp(r'[\u0905-\u0939\u0985-\u09B9]');
  static final RegExp _virama = RegExp(r'[\u094D\u09CD]');
  static final RegExp _openVowel = RegExp(
    r'[aAoO\u0906\u0913\u0914\u093E\u094B\u094C\u0986\u0993\u0994\u09BE\u09CB\u09CC]',
  );

  static int _estimateSyllables(String token) {
    final indic = _indicLetter.allMatches(token).length;
    if (indic > 0) {
      // Conjuncts joined by hasanta/halant merge two consonants into one beat.
      final joins = _virama.allMatches(token).length;
      return (indic - joins).clamp(1, 5);
    }

    final letters = token.replaceAll(RegExp(r'[^A-Za-z]'), '').toLowerCase();
    if (letters.isEmpty) return 0;
    var groups = _latinVowelGroup.allMatches(letters).length;
    // Silent trailing "e" in English words like "make", "smile", "inside".
    if (letters.length > 3 &&
        letters.endsWith('e') &&
        !letters.endsWith('le') &&
        groups > 1) {
      groups -= 1;
    }
    return groups.clamp(1, 5);
  }

  static bool _hasOpenVowel(String token) => _openVowel.hasMatch(token);

  static int _trailingPauseMs(String token, {required bool isLast}) {
    var stripped = token;
    const closers = '"”’)]';
    while (stripped.isNotEmpty &&
        closers.contains(stripped[stripped.length - 1])) {
      stripped = stripped.substring(0, stripped.length - 1);
    }
    if (stripped.isEmpty) return isLast ? 260 : 90;
    final last = stripped[stripped.length - 1];
    // A full stop is the one place a narrator really breathes.
    if (last == '.' ||
        last == '!' ||
        last == '?' ||
        last == '।' ||
        last == '॥') {
      return isLast ? 300 : 340;
    }
    if (last == ',' ||
        last == ';' ||
        last == ':' ||
        last == '—' ||
        last == '–') {
      return 230;
    }
    return isLast ? 200 : 70;
  }
}
