import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/asset_lookup.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/chapter.dart';
import '../grammar/grammar_lesson_screen.dart';

/// Navigation arguments for the story player.
class StoryArgs {
  const StoryArgs(this.chapterId, {this.startScene = 0});

  final String chapterId;
  final int startScene;
}

/// Screens 8 & 9 — the story scene, staged like a comic panel.
///
/// The scene background fills the screen, the chapter's characters stand in it
/// at full height (transparent cut-outs), and the speaker's line appears in a
/// bubble anchored just above *their* head — so it reads as someone talking in
/// the scene, not as captions pinned to the bottom of a photo. Characters who
/// are not speaking dim and shrink slightly, which is what makes the speaker
/// obvious at a glance.
///
/// English is always shown first; the toggle adds the Bengali or Hindi line
/// underneath. Tap anywhere to advance.
class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key, required this.args});

  static const routeName = '/story';

  final StoryArgs args;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  late int _sceneIndex = widget.args.startScene.clamp(0, 999);
  int _lineIndex = 0;
  StoryChoice? _chosenChoice;

  /// Local display language for translations: 'off', 'bn', 'hi'.
  String _translationLang = 'off';

  Chapter? get _chapter =>
      context.read<ContentController>().byId(widget.args.chapterId);

  void _advance() {
    final chapter = _chapter;
    if (chapter == null) return;
    final scene = chapter.scenes[_sceneIndex];
    setState(() => _chosenChoice = null);

    if (_lineIndex < scene.dialogue.length - 1) {
      setState(() => _lineIndex += 1);
      return;
    }
    // Scene finished → save resume point and move on.
    context.read<ProgressController>().openChapter(chapter.id, _sceneIndex);
    if (_sceneIndex < chapter.scenes.length - 1) {
      setState(() {
        _sceneIndex += 1;
        _lineIndex = 0;
      });
    } else {
      Navigator.of(context).pushReplacementNamed(
        GrammarLessonScreen.routeName,
        arguments: chapter.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _chapter;
    if (chapter == null) {
      return const Scaffold(body: Center(child: Text('Chapter not found')));
    }
    // Deliberately NOT seeded from the support language: opening a scene with
    // the translation already rendered means the learner reads the answer
    // before trying the English, which is the one thing this screen teaches.
    final scene =
        chapter.scenes[_sceneIndex.clamp(0, chapter.scenes.length - 1)];
    final line = scene.dialogue[_lineIndex.clamp(0, scene.dialogue.length - 1)];
    final text = Theme.of(context).textTheme;

    // The cast for this scene: whoever is listed, plus the current speaker if
    // the data forgot to list them (never leave the speaker off stage).
    final cast = <String>{
      ...scene.characterIds,
      line.characterId,
    }.toList();

    return Scaffold(
      body: GestureDetector(
        onTap: _advance,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _SceneBackdrop(backgroundId: scene.backgroundId),
            // Ground shading: the characters need something to stand on.
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0, 0.45),
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x4D0B1B3A)],
                  ),
                ),
              ),
            ),
            _Stage(
              cast: cast,
              speakerId: line.characterId,
              bubble: _DialogueBubble(
                characterId: line.characterId,
                line: line,
                translationLang: _translationLang,
              ),
            ),
            // Bottom interaction zone: choices, then the advance hint.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_chosenChoice != null)
                      _ChoiceResponseBubble(
                        choice: _chosenChoice!,
                        lang: _translationLang,
                      ),
                    if (scene.choices.isNotEmpty && _chosenChoice == null)
                      _ChoiceList(
                        choices: scene.choices,
                        lang: _translationLang,
                        onChosen: (choice) =>
                            setState(() => _chosenChoice = choice),
                      )
                    else
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.touch_app_rounded,
                                size: 15,
                                color: Colors.white.withValues(alpha: 0.95)),
                            const SizedBox(width: 6),
                            Text(
                              'Tap to continue',
                              style: text.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                shadows: const [
                                  Shadow(
                                      color: Color(0x99000000), blurRadius: 6),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Top bar: progress through the scene + the translation switch.
            // Positioned, not a bare Stack child: with `StackFit.expand` a
            // plain child fills the screen and its Row centres vertically,
            // which parked the back button in the middle of the scene.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xs, AppSpacing.sm, AppSpacing.sm, 0),
                  child: Row(
                    children: [
                      _GlassIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _SceneProgress(
                          scene: _sceneIndex + 1,
                          scenes: chapter.scenes.length,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _TranslationToggle(
                        lang: _translationLang,
                        onChanged: (value) =>
                            setState(() => _translationLang = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The stage
// ---------------------------------------------------------------------------

/// Lays the cast out along the bottom of the screen and floats the speaker's
/// bubble above their head.
///
/// Positions are computed once from the layout's own size, so the bubble can be
/// anchored to a head instead of to the screen edge: one character stands
/// centre, two stand left/right with the speaker a little forward and larger.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.cast,
    required this.speakerId,
    required this.bubble,
  });

  final List<String> cast;
  final String speakerId;
  final Widget bubble;

  /// Character height as a fraction of the stage, and where they stand.
  static const _baseHeightFactor = 0.52;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;

        // Speaker goes first so they always get the central slot.
        final ordered = <String>[
          speakerId,
          ...cast.where((c) => c != speakerId),
        ];

        final slots = _slotsFor(ordered.length, w, h);
        final placements = <_Placement>[];
        for (var i = 0; i < ordered.length; i++) {
          final id = ordered[i];
          placements.add(_Placement(
            id: id,
            dx: slots[i].dx,
            height: slots[i].height,
            isSpeaker: id == speakerId,
          ));
        }

        final speaker = placements.firstWhere(
          (p) => p.isSpeaker,
          orElse: () => placements.first,
        );

        // Bubble sits above the speaker's head, clamped to the screen so it can
        // never run off the top.
        final bubbleWidth = math.min(w * 0.78, 420.0);
        final headY = h - speaker.height - _stageBottomInset(context);

        return Stack(
          children: [
            for (final p in placements)
              Positioned(
                left: p.dx,
                // A floor strip so shoes are never cut by the screen edge and
                // the "Tap to continue" hint does not sit on their feet.
                bottom: _stageBottomInset(context),
                child: _Character(
                  id: p.id,
                  height: p.height,
                  isSpeaker: p.isSpeaker,
                ),
              ),
            // Anchored by its *bottom*, not its top: the bubble grows upward
            // from the speaker's head. Anchoring the top let a long line grow
            // down over the speaker's face.
            Positioned(
              bottom: math.max(
                h - headY + 4,
                MediaQuery.paddingOf(context).bottom + 120,
              ),
              left: (w - bubbleWidth) / 2,
              width: bubbleWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  bubble,
                  // Pointer down toward the head of whoever is talking.
                  _BubbleTail(
                    color: AppColors.surface,
                    align:
                        tailX(speaker.dx + speaker.width / 2, w, bubbleWidth),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static double _stageBottomInset(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + 46;

  /// 0..1 horizontal position of the tail inside the bubble, so the pointer
  /// lands on the head of whoever is talking.
  static double tailX(
      double headCentre, double stageWidth, double bubbleWidth) {
    final bubbleLeft = (stageWidth - bubbleWidth) / 2;
    return ((headCentre - bubbleLeft) / bubbleWidth).clamp(0.09, 0.91);
  }

  /// Where each cast member stands. The speaker takes the taller slot; the
  /// others step back and to the side. Slots never overlap: two full bodies
  /// drawn on top of each other read as one tangled shape, not a conversation.
  static List<_Slot> _slotsFor(int count, double w, double h) {
    // Height as a fraction of the stage, leaving a floor strip at the bottom.
    final base = h * _baseHeightFactor;
    switch (count) {
      case 1:
        final height = base * 0.96;
        return [_Slot(dx: (w - height * 0.36) / 2, height: height)];
      case 2:
        final speakerHeight = base * 1.0;
        final otherHeight = base * 0.88;
        // Speaker left of centre, other to the right, each inside its half.
        return [
          _Slot(dx: w * 0.03, height: speakerHeight),
          _Slot(dx: w * 0.55, height: otherHeight),
        ];
      default:
        final speakerHeight = base * 0.96;
        final otherHeight = base * 0.82;
        return [
          _Slot(dx: w * 0.02, height: speakerHeight),
          _Slot(dx: w * 0.36, height: otherHeight),
          _Slot(dx: w * 0.68, height: otherHeight),
        ];
    }
  }
}

class _Slot {
  const _Slot({required this.dx, required this.height});
  final double dx;
  final double height;
}

class _Placement {
  const _Placement({
    required this.id,
    required this.dx,
    required this.height,
    required this.isSpeaker,
  });

  final String id;
  final double dx;
  final double height;
  final bool isSpeaker;

  double get width => height * 0.36;
}

/// One full-body character. The cut-out keeps its own ratio; the speaker is at
/// full strength while the others dim, which is the whole "who is talking"
/// cue.
class _Character extends StatelessWidget {
  const _Character({
    required this.id,
    required this.height,
    required this.isSpeaker,
  });

  final String id;
  final double height;
  final bool isSpeaker;

  @override
  Widget build(BuildContext context) {
    final path = AssetLookup.fullBodyPath(id);
    final name = AssetLookup.characterDisplayName(id);

    final art = path == null
        ? _FallbackBody(name: name, height: height)
        : Image.asset(
            path,
            height: height,
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) =>
                _FallbackBody(name: name, height: height),
          );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: isSpeaker ? 1 : 0.82,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        scale: isSpeaker ? 1 : 0.97,
        alignment: Alignment.bottomCenter,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Contact shadow: without it the feet float over the scene.
            Container(
              width: height * 0.26,
              height: height * 0.035,
              margin: EdgeInsets.only(bottom: height * 0.004),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 14,
                  ),
                ],
              ),
            ),
            art,
          ],
        ),
      ),
    );
  }
}

class _FallbackBody extends StatelessWidget {
  const _FallbackBody({required this.name, required this.height});

  final String name;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: height * 0.36,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.skyTop],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(height * 0.18),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: height * 0.16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bubble
// ---------------------------------------------------------------------------

/// The speech bubble: the speaker's name, the English line, and — only when
/// asked for — the translation.
class _DialogueBubble extends StatelessWidget {
  const _DialogueBubble({
    required this.characterId,
    required this.line,
    required this.translationLang,
  });

  final String characterId;
  final DialogueLine line;
  final String translationLang;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = AssetLookup.characterDisplayName(characterId);
    final translation =
        translationLang == 'off' ? null : line.text.of(translationLang);

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm + 2, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: text.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            line.text.en,
            style: text.bodyLarge?.copyWith(height: 1.4),
          ),
          if (translation != null && translation != line.text.en) ...[
            const Divider(height: AppSpacing.md),
            Text(
              _translationLabel(translationLang),
              style: text.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Text(translation, style: text.bodyMedium?.copyWith(height: 1.4)),
          ],
        ],
      ),
    );
  }
}

/// The little pointer that makes a bubble belong to one character.
class _BubbleTail extends StatelessWidget {
  const _BubbleTail({required this.color, required this.align});

  final Color color;
  final double align;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const tailSize = 16.0;
        final left =
            (width * align - tailSize).clamp(10.0, width - tailSize * 2.3);
        return SizedBox(
          height: tailSize,
          width: width,
          child: Stack(
            children: [
              Positioned(
                left: left,
                child: ClipPath(
                  clipper: _TailClipper(),
                  child: Container(
                    width: tailSize * 1.6,
                    height: tailSize,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TailClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * 0.30, 0)
    ..lineTo(size.width * 0.70, 0)
    ..lineTo(size.width * 0.18, size.height)
    ..close();

  @override
  bool shouldReclip(_TailClipper oldClipper) => false;
}

// ---------------------------------------------------------------------------
// Chrome
// ---------------------------------------------------------------------------

class _SceneProgress extends StatelessWidget {
  const _SceneProgress({required this.scene, required this.scenes});

  final int scene;
  final int scenes;

  @override
  Widget build(BuildContext context) {
    final fraction = scenes == 0 ? 0.0 : (scene - 1) / scenes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scene $scene of $scenes',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: Color(0x99000000), blurRadius: 6)],
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.30),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// English · বাংলা · हिन्दी as a single segmented switch that cannot overflow.
class _TranslationToggle extends StatelessWidget {
  const _TranslationToggle({required this.lang, required this.onChanged});

  final String lang;
  final ValueChanged<String> onChanged;

  static const _options = <(String, String)>[
    ('off', 'EN'),
    ('bn', 'বাংলা'),
    ('hi', 'हिन्दी'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label) in _options)
            _Segment(
              label: label,
              selected: lang == value,
              onTap: () => onChanged(value),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Choices
// ---------------------------------------------------------------------------

class _ChoiceList extends StatelessWidget {
  const _ChoiceList({
    required this.choices,
    required this.lang,
    required this.onChosen,
  });

  final List<StoryChoice> choices;
  final String lang;
  final ValueChanged<StoryChoice> onChosen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final choice in choices)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppButton(
                label: choice.text.of(lang == 'off' ? 'en' : lang),
                variant: AppButtonVariant.blue,
                expand: false,
                onPressed: () => onChosen(choice),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChoiceResponseBubble extends StatelessWidget {
  const _ChoiceResponseBubble({required this.choice, required this.lang});

  final StoryChoice choice;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        choice.response.of(lang == 'off' ? 'en' : lang),
        style: text.bodyLarge
            ?.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _translationLabel(String lang) => lang == 'hi'
    ? 'HINDI'
    : lang == 'bn'
        ? 'BENGALI'
        : '';

/// The scene background.
///
/// A 1280 × 714 illustration on a portrait phone has to crop somewhere, and the
/// useful part of every scene is the middle band and the floor — so it covers
/// from the bottom. A soft top vignette hides the hard end of the crop and
/// gives the bubble some air.
class _SceneBackdrop extends StatelessWidget {
  const _SceneBackdrop({required this.backgroundId});

  final String? backgroundId;

  @override
  Widget build(BuildContext context) {
    final path =
        backgroundId == null ? null : AssetLookup.backgroundPath(backgroundId!);
    if (path == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.skyTop, AppColors.skyBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          path,
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: AppColors.skyTop),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xB313276B),
                Color(0x330F172A),
                Color(0x00000000),
                Color(0x4D0B1B3A),
              ],
              stops: [0.0, 0.22, 0.55, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
