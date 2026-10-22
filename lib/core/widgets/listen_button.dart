import 'package:flutter/material.dart';

import '../../features/audio/audio_controller.dart';
import '../../app/theme/app_theme.dart';

/// Where the button is sitting — a white card or the dark board — so it reads
/// as part of the surface instead of a sticker on top of it.
enum ListenTone { onSurface, onBoard }

/// The little speaker next to a line of text.
///
/// Renders nothing at all when there is no audio for that line, when the
/// learner has switched narration off, or when the screen is being rendered
/// outside the app (tests, golden harnesses). That keeps every call site a
/// plain one-liner: ask for a clip, get a button only if the clip exists.
class ListenButton extends StatelessWidget {
  const ListenButton({
    super.key,
    required this.clipId,
    this.tone = ListenTone.onSurface,
    this.size = 30,
  });

  final String clipId;
  final ListenTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final audio = AudioScope.maybeOf(context);
    if (audio == null || !audio.canPlay(clipId)) return const SizedBox.shrink();

    final playing = audio.isPlaying(clipId);
    final onBoard = tone == ListenTone.onBoard;
    final foreground = onBoard ? Colors.white : AppColors.primary;
    final background = onBoard
        ? Colors.white.withValues(alpha: playing ? 0.30 : 0.16)
        : AppColors.primary.withValues(alpha: playing ? 0.18 : 0.09);
    final border = onBoard
        ? Colors.white.withValues(alpha: 0.32)
        : AppColors.primary.withValues(alpha: 0.22);

    return Semantics(
      button: true,
      label: playing ? 'Stop narration' : 'Play narration',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => audio.toggle(clipId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(color: border),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              playing ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
              key: ValueKey(playing),
              size: size * 0.56,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
