import 'dart:math' as math;
import 'dart:ui' show Rect, Size, lerpDouble;

import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/today/domain/today_card_metrics.dart';

/// Where Today's stage puts the clip frame, the character and its bubble.
///
/// All of it in the stage's own coordinates. [frame] is the clip frame (the
/// dashed frame, or the day's clip) without its page dots, which hang
/// below it; [character] is the square the character is drawn in, empty
/// when there is none. The bubble is placed by insets, as a `Positioned`
/// takes them: [bubbleBottom] is how far its bottom edge sits above the
/// stage's bottom.
final class TodayStageLayout extends Equatable {
  const TodayStageLayout({
    required this.frame,
    required this.character,
    required this.framed,
    required this.beside,
    required this.bubbleLeft,
    required this.bubbleRight,
    required this.bubbleBottom,
  });

  final Rect frame;
  final Rect character;

  /// The frame shows (a kept day, a loading diary, or no character).
  final bool framed;

  /// The bubble sits beside the character, tail on its left; else above
  /// it, tail under its centre.
  final bool beside;

  final double bubbleLeft;
  final double bubbleRight;
  final double bubbleBottom;

  static TodayStageLayout lerp(
    TodayStageLayout a,
    TodayStageLayout b,
    double t,
  ) => TodayStageLayout(
    frame: Rect.lerp(a.frame, b.frame, t)!,
    character: Rect.lerp(a.character, b.character, t)!,
    framed: t < .5 ? a.framed : b.framed,
    beside: t < .5 ? a.beside : b.beside,
    bubbleLeft: lerpDouble(a.bubbleLeft, b.bubbleLeft, t)!,
    bubbleRight: lerpDouble(a.bubbleRight, b.bubbleRight, t)!,
    bubbleBottom: lerpDouble(a.bubbleBottom, b.bubbleBottom, t)!,
  );

  @override
  List<Object?> get props => <Object?>[
    frame,
    character,
    framed,
    beside,
    bubbleLeft,
    bubbleRight,
    bubbleBottom,
  ];
}

/// The stage's layout. Without a clip the character has the stage to
/// itself, [waitingSize] tall, the bubble above it in its kept room. Once
/// the day is kept (or while the diary loads) it shrinks to [perchedSize]
/// and sits on the top-left edge of its clip, talking to the side, so the
/// clip takes the middle and most of the height. Without a character the
/// frame alone shows.
abstract final class TodayStageGeometry {
  /// The character waiting in the middle, and perched on its clip.
  static const double waitingSize = 160;
  static const double perchedSize = 84;

  /// The body's base sits this far above its box's bottom: the clip starts
  /// just below it, so the character rests on the edge without covering
  /// the clip.
  static const double perchFraction = .07;

  /// The frame's inset from the stage's sides.
  static const double sideInset = 24;

  /// The bubble's inset from the stage's sides.
  static const double bubbleInset = 16;

  /// Between the bubble and the character under it.
  static const double bubbleGap = 6;

  /// How far in from the clip's left edge the perched character sits.
  static const double perchInset = 12;

  /// Room a frame keeps to the controls below, so a tall frame never
  /// touches them.
  static const double breath = 24;

  /// The character's room above the frame, for a character [size] tall.
  static double characterRoom(double size) => size * (1 - perchFraction);

  /// The character's size for a stage: none without a [figure], small when
  /// [perched] (a kept day, a loading diary), else large.
  static double characterSize({required bool figure, required bool perched}) =>
      !figure
      ? 0
      : perched
      ? perchedSize
      : waitingSize;

  /// The layout of a stage [room] big.
  static TodayStageLayout layout({
    required Size room,
    required double portraitness,
    required bool isTablet,
    required bool figure,
    required bool perched,
    required double dotsExtent,
    required double bubbleRoom,
  }) {
    final double width = room.width;
    final double height = room.height;
    final bool framed = perched || !figure;
    final double size = characterSize(figure: figure, perched: perched);
    final double characterRoom = TodayStageGeometry.characterRoom(size);
    final Size frame = TodayCardMetrics.frame(
      innerWidth: width - 2 * sideInset,
      slotHeight: height - characterRoom - dotsExtent - breath,
      portraitness: portraitness,
      isTablet: isTablet,
    );
    final double group = framed
        ? characterRoom + frame.height + dotsExtent
        : bubbleRoom + bubbleGap + size;
    final double top = math.max(0, (height - group) / 2);
    final double frameLeft = (width - frame.width) / 2;
    final double characterLeft = framed
        ? frameLeft + perchInset
        : (width - size) / 2;
    final double characterTop = framed ? top : top + bubbleRoom + bubbleGap;
    return TodayStageLayout(
      frame: Rect.fromLTWH(
        frameLeft,
        top + characterRoom,
        frame.width,
        frame.height,
      ),
      character: Rect.fromLTWH(characterLeft, characterTop, size, size),
      framed: framed,
      beside: framed,
      // Beside the character its tail aims at the upper body; the tail
      // sits 24 above the bubble's bottom (centred on one line).
      bubbleLeft: framed ? characterLeft + size * .85 : bubbleInset,
      bubbleRight: bubbleInset,
      bubbleBottom: framed
          ? height - characterTop - size * .35 - 24
          : height - characterTop + bubbleGap,
    );
  }

  /// The least height a stage [width] wide needs: the frame at its
  /// smallest under the perched character, or the waiting character under
  /// its bubble's room. Below it the page scrolls instead.
  static double minHeight({
    required double width,
    required double portraitness,
    required bool isTablet,
    required bool figure,
    required bool perched,
    required double dotsExtent,
    required double bubbleRoom,
  }) {
    final double size = characterSize(figure: figure, perched: perched);
    if (!(perched || !figure)) return bubbleRoom + bubbleGap + size;
    return characterRoom(size) +
        TodayCardMetrics.minSlotHeight(
          innerWidth: width - 2 * sideInset,
          portraitness: portraitness,
          isTablet: isTablet,
        ) +
        dotsExtent +
        breath;
  }
}
