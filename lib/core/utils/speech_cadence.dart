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

/// Turns a dialogue line (English, Bengali or Hindi) into a rhythmic mouth
/// animation timeline.
///
/// Exact phoneme timestamps would require shipping sidecar alignment files for
/// every audio clip. For warm 3D cartoon dialogue, pacing syllables from vowel
/// nuclei and holding brief closures on commas and sentence breaks gives the
/// eye a natural talking rhythm at zero bundle cost — both while a neural voice
/// clip is playing and when voice narration is switched off.
class SpeechCadence {
  SpeechCadence._(this._spans, this.totalMs);

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
    var syllableCounter = 0;

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final syllables = _estimateSyllables(token);
      final openHeavy = _hasOpenVowel(token);

      for (var s = 0; s < syllables; s++) {
        // Vary peak openness across syllables so a long word reads as lively
        // speech rather than a mechanical metronome.
        final wide = (openHeavy && s == 0) ||
            (syllableCounter % 3 != 1 && syllables > 1) ||
            (syllables == 1 && syllableCounter.isEven);
        if (wide) {
          push(52, MouthFrame.half);
          push(92, MouthFrame.open);
          push(48, MouthFrame.half);
        } else {
          push(118, MouthFrame.half);
          push(36, MouthFrame.closed);
        }
        syllableCounter += 1;
      }

      final pause = _trailingPauseMs(token, isLast: i == tokens.length - 1);
      push(pause, MouthFrame.closed);
    }

    if (spans.isEmpty) {
      return SpeechCadence._(const [_Span(400, MouthFrame.closed)], 400);
    }
    return SpeechCadence._(List<_Span>.unmodifiable(spans), cursor);
  }

  final List<_Span> _spans;

  /// Unclamped timeline length in milliseconds.
  final int totalMs;

  /// Comfortable speaking window when playing silently (no audio clip).
  Duration get silentDuration =>
      Duration(milliseconds: totalMs.clamp(1200, 5600));

  /// Mouth shape at [elapsed] into the utterance.
  ///
  /// When [loop] is true (live audio is still playing), the timeline wraps so
  /// a slightly slower neural voice read keeps moving naturally until the exact
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
    final stripped = token.replaceAll(RegExp('["\'”’)\\]]+\$'), '');
    if (stripped.isEmpty) return isLast ? 220 : 45;
    final last = stripped[stripped.length - 1];
    if (last == '.' ||
        last == '!' ||
        last == '?' ||
        last == '।' ||
        last == '॥') {
      return isLast ? 240 : 280;
    }
    if (last == ',' ||
        last == ';' ||
        last == ':' ||
        last == '—' ||
        last == '–') {
      return 190;
    }
    return isLast ? 200 : 44;
  }
}
