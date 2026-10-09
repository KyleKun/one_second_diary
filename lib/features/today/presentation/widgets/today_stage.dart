import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/character/domain/character_look.dart';
import 'package:one_second_diary/features/character/presentation/widgets/character_figure.dart';
import 'package:one_second_diary/features/character/presentation/widgets/speech_bubble.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/user_name_cubit.dart';
import 'package:one_second_diary/features/today/domain/today_stage_geometry.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_character_cubit.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_cubit.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_state.dart';
import 'package:one_second_diary/features/today/presentation/today_line_text.dart';
import 'package:one_second_diary/features/today/presentation/today_motion.dart';
import 'package:one_second_diary/features/today/presentation/widgets/held_while_hidden.dart';
import 'package:one_second_diary/features/today/presentation/widgets/today_clip_carousel.dart';
import 'package:one_second_diary/features/today/presentation/widgets/today_frame.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';

/// Today between its header and its controls: the character and the day's
/// clip frame, placed by [TodayStageGeometry].
///
/// - Without a clip the character stands in the middle, large, its bubble
///   above it; the dashed frame is not shown. Once the day is kept it
///   shrinks onto the top-left edge of its clip, in the profile's shape,
///   and talks to the side. The two placements tween into each other, as
///   does the frame's shape when the profile switches and the room its
///   page dots take.
/// - While the diary loads the frame shows its loading state with the
///   character out of sight, perched, so it fades in where it will sit.
/// - Without a character (the look's `hidden`) the frame alone shows,
///   dashed with the date stamp until a clip, as the frame always did.
/// - A tap on the character pokes it (a squish, the light haptic and a
///   line); a long press opens its sheet ([onCustomize]). The bubble's
///   typing moves its mouth.
/// - A change made while Today is hidden plays once Today shows
///   ([HeldWhileHidden]).
///
/// Its least height is the stage's ([TodayStageGeometry.minHeight]), so
/// the page scrolls only when even that does not fit.
class TodayStage extends StatefulWidget {
  const TodayStage({
    super.key,
    required this.onOpen,
    required this.onCustomize,
  });

  /// Opens a clip in the viewer (a long press on the clip in view).
  final ValueChanged<ClipRef> onOpen;

  /// Opens the character's sheet (a long press on the character).
  final VoidCallback onCustomize;

  static const Key characterKey = Key('todayStage.character');

  @override
  State<TodayStage> createState() => _TodayStageState();
}

class _TodayStageState extends State<TodayStage> {
  final GlobalKey<CharacterFigureState> _figure =
      GlobalKey<CharacterFigureState>();

  /// The bubble is typing: the mouth moves.
  bool _talking = false;

  void _poke() {
    unawaited(OsdHaptic.light.play());
    _figure.currentState?.poke();
    context.read<TodayCharacterCubit>().poke();
  }

  @override
  Widget build(BuildContext context) {
    final _Scene scene = context.select(
      (TodayCubit cubit) => _sceneOf(cubit.state),
    );
    final CharacterLook look = context.select(
      (TodayCharacterCubit cubit) => cubit.state.look,
    );
    final bool isTablet =
        MediaQuery.sizeOf(context).shortestSide >= OsdSizes.tabletShortestSide;
    final double dotsExtent = TodayClipCarousel.dotsExtent(
      scene.clipCount,
      MediaQuery.textScalerOf(context),
    );
    return HeldWhileHidden<_Scene>(
      value: scene,
      builder: (BuildContext context, _Scene shown) {
        final bool figure = !look.hidden;
        final bool perched = shown.kept || shown.loading;
        return _StageBox(
          portraitness: shown.portrait ? 1 : 0,
          isTablet: isTablet,
          figure: figure,
          perched: perched,
          dotsExtent: dotsExtent,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) =>
                _Tweened(
                  portraitness: shown.portrait ? 1 : 0,
                  perchedness: perched ? 1 : 0,
                  dotsExtent: dotsExtent,
                  builder:
                      (
                        BuildContext context,
                        double portraitness,
                        double perchedness,
                        double dots,
                      ) => _buildStage(
                        context,
                        room: constraints.biggest,
                        scene: shown,
                        look: look,
                        isTablet: isTablet,
                        portraitness: portraitness,
                        perchedness: perchedness,
                        dotsExtent: dots,
                      ),
                ),
          ),
        );
      },
    );
  }

  Widget _buildStage(
    BuildContext context, {
    required Size room,
    required _Scene scene,
    required CharacterLook look,
    required bool isTablet,
    required double portraitness,
    required double perchedness,
    required double dotsExtent,
  }) {
    final bool figure = !look.hidden;
    TodayStageLayout at({required bool perched}) => TodayStageGeometry.layout(
      room: room,
      portraitness: portraitness,
      isTablet: isTablet,
      figure: figure,
      perched: perched,
      dotsExtent: dotsExtent,
      bubbleRoom: SpeechBubble.room,
    );
    final TodayStageLayout layout = TodayStageLayout.lerp(
      at(perched: false),
      at(perched: true),
      perchedness,
    );
    // The frame fades and settles in as the character perches; without a
    // character it is always there.
    final double frameIn = figure ? perchedness : 1;
    final Duration duration = OsdMotion.d(context, OsdMotion.standard);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: 0,
          right: 0,
          top: layout.frame.top,
          child: IgnorePointer(
            ignoring: !layout.framed,
            child: Opacity(
              opacity: frameIn,
              child: Transform.scale(
                scale: .94 + .06 * frameIn,
                alignment: Alignment.topCenter,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: layout.frame.width,
                      maxWidth: room.width,
                      minHeight: layout.frame.height,
                    ),
                    child: TodayFrame(onOpen: widget.onOpen),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (figure)
          Positioned.fromRect(
            rect: layout.character,
            child: Semantics(
              button: true,
              label: Strings.characterA11y,
              onTapHint: Strings.characterPokeHint,
              onLongPressHint: Strings.characterCustomizeA11y,
              child: GestureDetector(
                key: TodayStage.characterKey,
                behavior: HitTestBehavior.opaque,
                onTap: _poke,
                onLongPress: () {
                  unawaited(OsdHaptic.medium.play());
                  widget.onCustomize();
                },
                child: AnimatedOpacity(
                  duration: duration,
                  opacity: scene.loading ? 0 : 1,
                  child: _TalkingFigure(
                    figureKey: _figure,
                    look: look,
                    happy: scene.kept,
                    talking: _talking,
                    size: layout.character.width,
                  ),
                ),
              ),
            ),
          ),
        if (figure)
          Positioned(
            left: layout.bubbleLeft,
            right: layout.bubbleRight,
            bottom: layout.bubbleBottom,
            child: Align(
              alignment: layout.beside
                  ? Alignment.bottomLeft
                  : Alignment.bottomCenter,
              child: _Bubble(
                beside: layout.beside,
                onTyping: (bool typing) {
                  if (typing != _talking) setState(() => _talking = typing);
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// The character with what the cubit says about its eyes.
class _TalkingFigure extends StatelessWidget {
  const _TalkingFigure({
    required this.figureKey,
    required this.look,
    required this.happy,
    required this.talking,
    required this.size,
  });

  final GlobalKey<CharacterFigureState> figureKey;
  final CharacterLook look;
  final bool happy;
  final bool talking;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool lookingDown = context.select(
      (TodayCharacterCubit cubit) => cubit.state.lookingDown,
    );
    return CharacterFigure(
      key: figureKey,
      look: look,
      happy: happy,
      talking: talking,
      lookingDown: lookingDown,
      size: size,
    );
  }
}

/// The bubble, with the cubit's line in the app's language.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.beside, required this.onTyping});

  final bool beside;
  final ValueChanged<bool> onTyping;

  @override
  Widget build(BuildContext context) {
    final TodayCharacterState character = context
        .watch<TodayCharacterCubit>()
        .state;
    final String name = context.select(
      (UserNameCubit cubit) => cubit.state.name,
    );
    return SpeechBubble(
      line: character.line == null
          ? null
          : TodayLineText.of(character.line!, name: name),
      id: character.lineId,
      beside: beside,
      onTyping: onTyping,
      onDone: context.read<TodayCharacterCubit>().lineDone,
    );
  }
}

/// Three tweens the stage's layout follows: the frame's shape, the
/// character perching, the page dots' room.
class _Tweened extends StatelessWidget {
  const _Tweened({
    required this.portraitness,
    required this.perchedness,
    required this.dotsExtent,
    required this.builder,
  });

  final double portraitness;
  final double perchedness;
  final double dotsExtent;
  final Widget Function(
    BuildContext context,
    double portraitness,
    double perchedness,
    double dotsExtent,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    final bool reduced = OsdMotion.reduced(context);
    final Duration standard = OsdMotion.d(context, OsdMotion.standard);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: portraitness),
      duration: reduced ? Duration.zero : TodayMotion.orientationMorph,
      curve: TodayMotion.orientationMorphCurve,
      builder: (BuildContext context, double portraitness, _) =>
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: perchedness),
            duration: standard,
            curve: OsdMotion.standardCurve,
            builder: (BuildContext context, double perchedness, _) =>
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: dotsExtent),
                  duration: standard,
                  curve: OsdMotion.standardCurve,
                  builder: (BuildContext context, double dots, _) =>
                      builder(context, portraitness, perchedness, dots),
                ),
          ),
    );
  }
}

/// What the stage's placement depends on, compared by value.
final class _Scene extends Equatable {
  const _Scene({
    required this.portrait,
    required this.clipCount,
    required this.loading,
  });

  final bool portrait;
  final int clipCount;
  final bool loading;

  bool get kept => clipCount > 0;

  @override
  List<Object?> get props => <Object?>[portrait, clipCount, loading];
}

_Scene _sceneOf(TodayState state) => _Scene(
  portrait: state.profile.orientation == VideoOrientation.portrait,
  clipCount: state.clips.length,
  loading: state.status == TodayStatus.loading,
);

/// Sizes the stage: as tall as the room it is given, and never less than
/// the layout's least height, which is its intrinsic height (the page
/// scrolls below it). The stage under it lays itself out by its size.
class _StageBox extends SingleChildRenderObjectWidget {
  const _StageBox({
    required this.portraitness,
    required this.isTablet,
    required this.figure,
    required this.perched,
    required this.dotsExtent,
    required Widget super.child,
  });

  final double portraitness;
  final bool isTablet;
  final bool figure;
  final bool perched;
  final double dotsExtent;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStageBox(
    portraitness: portraitness,
    isTablet: isTablet,
    figure: figure,
    perched: perched,
    dotsExtent: dotsExtent,
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderStageBox)
        ..portraitness = portraitness
        ..isTablet = isTablet
        ..figure = figure
        ..perched = perched
        ..dotsExtent = dotsExtent;
}

class _RenderStageBox extends RenderProxyBox {
  _RenderStageBox({
    required this._portraitness,
    required this._isTablet,
    required this._figure,
    required this._perched,
    required this._dotsExtent,
  });

  double _portraitness;
  set portraitness(double value) {
    if (value == _portraitness) return;
    _portraitness = value;
    markNeedsLayout();
  }

  bool _isTablet;
  set isTablet(bool value) {
    if (value == _isTablet) return;
    _isTablet = value;
    markNeedsLayout();
  }

  bool _figure;
  set figure(bool value) {
    if (value == _figure) return;
    _figure = value;
    markNeedsLayout();
  }

  bool _perched;
  set perched(bool value) {
    if (value == _perched) return;
    _perched = value;
    markNeedsLayout();
  }

  double _dotsExtent;
  set dotsExtent(double value) {
    if (value == _dotsExtent) return;
    _dotsExtent = value;
    markNeedsLayout();
  }

  double _minHeight(double width) => width.isFinite
      ? TodayStageGeometry.minHeight(
          width: width,
          portraitness: _portraitness,
          isTablet: _isTablet,
          figure: _figure,
          perched: _perched,
          dotsExtent: _dotsExtent,
          bubbleRoom: SpeechBubble.room,
        )
      : 0;

  @override
  double computeMinIntrinsicHeight(double width) => _minHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _minHeight(width);

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  Size _sizeIn(BoxConstraints constraints) => Size(
    constraints.maxWidth,
    constraints.hasBoundedHeight
        ? constraints.maxHeight
        : constraints.constrainHeight(_minHeight(constraints.maxWidth)),
  );

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeIn(constraints);

  @override
  void performLayout() {
    size = _sizeIn(constraints);
    child?.layout(BoxConstraints.tight(size));
  }
}
