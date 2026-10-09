// Where Today's stage puts the frame, the character and its bubble, on a
// 390 phone's stage (342 wide inside the page gutters, 480 tall).

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/today/domain/today_card_metrics.dart';
import 'package:one_second_diary/features/today/domain/today_stage_geometry.dart';

void main() {
  const Size room = Size(342, 480);
  const double bubbleRoom = 92;

  TodayStageLayout layout({
    required bool figure,
    required bool perched,
    double portraitness = 0,
    double dotsExtent = 0,
  }) => TodayStageGeometry.layout(
    room: room,
    portraitness: portraitness,
    isTablet: false,
    figure: figure,
    perched: perched,
    dotsExtent: dotsExtent,
    bubbleRoom: bubbleRoom,
  );

  test('waiting: no frame, the large character centred under the room '
      'kept for its bubble, which spans the stage', () {
    final TodayStageLayout waiting = layout(figure: true, perched: false);
    const double size = TodayStageGeometry.waitingSize;
    const double group = bubbleRoom + TodayStageGeometry.bubbleGap + size;
    final double top = (room.height - group) / 2;

    expect(waiting.framed, isFalse);
    expect(waiting.beside, isFalse);
    expect(waiting.character.size, const Size(size, size));
    expect(waiting.character.left, (room.width - size) / 2);
    expect(
      waiting.character.top,
      top + bubbleRoom + TodayStageGeometry.bubbleGap,
    );
    expect(waiting.bubbleLeft, TodayStageGeometry.bubbleInset);
    expect(waiting.bubbleRight, TodayStageGeometry.bubbleInset);
    expect(
      waiting.bubbleBottom,
      room.height - waiting.character.top + TodayStageGeometry.bubbleGap,
    );
  });

  test('perched on a landscape clip: the 16:9 frame inside the side insets, '
      'just under the small character on its left edge, the bubble beside', () {
    final TodayStageLayout perched = layout(figure: true, perched: true);
    const double size = TodayStageGeometry.perchedSize;
    final double frameWidth = room.width - 2 * TodayStageGeometry.sideInset;
    final double frameHeight = frameWidth * TodayCardMetrics.landscapeRatio;
    final double characterRoom = TodayStageGeometry.characterRoom(size);

    expect(perched.framed, isTrue);
    expect(perched.beside, isTrue);
    expect(perched.frame.size, Size(frameWidth, frameHeight));
    expect(perched.frame.left, TodayStageGeometry.sideInset);
    expect(perched.frame.top, (room.height - characterRoom - frameHeight) / 2);
    expect(perched.character.size, const Size(size, size));
    expect(perched.character.top, perched.frame.top - characterRoom);
    expect(
      perched.character.left,
      perched.frame.left + TodayStageGeometry.perchInset,
    );
    expect(perched.bubbleLeft, perched.character.left + size * .85);
    expect(
      perched.bubbleBottom,
      room.height - perched.character.top - size * .35 - 24,
    );
  });

  test('without a character the frame alone shows, at the top of the '
      'centred group', () {
    final TodayStageLayout bare = layout(figure: false, perched: false);
    final double frameHeight =
        (room.width - 2 * TodayStageGeometry.sideInset) *
        TodayCardMetrics.landscapeRatio;

    expect(bare.framed, isTrue);
    expect(bare.character.isEmpty, isTrue);
    expect(bare.frame.top, (room.height - frameHeight) / 2);
    expect(bare, layout(figure: false, perched: true));
  });

  test('a lerp runs from one placement to the other, the character midway '
      'between its two squares', () {
    final TodayStageLayout waiting = layout(figure: true, perched: false);
    final TodayStageLayout perched = layout(figure: true, perched: true);

    expect(TodayStageLayout.lerp(waiting, perched, 0), waiting);
    expect(TodayStageLayout.lerp(waiting, perched, 1), perched);
    expect(
      TodayStageLayout.lerp(waiting, perched, .5).character,
      Rect.lerp(waiting.character, perched.character, .5),
    );
  });

  test('the least height is the waiting character under its bubble room, '
      'or the perched one over the smallest frame, its dots and the breath '
      'to the controls', () {
    double minHeight({
      required bool figure,
      required bool perched,
      double portraitness = 0,
      double dotsExtent = 0,
    }) => TodayStageGeometry.minHeight(
      width: room.width,
      portraitness: portraitness,
      isTablet: false,
      figure: figure,
      perched: perched,
      dotsExtent: dotsExtent,
      bubbleRoom: bubbleRoom,
    );
    double smallestFrame(double portraitness) => TodayCardMetrics.minSlotHeight(
      innerWidth: room.width - 2 * TodayStageGeometry.sideInset,
      portraitness: portraitness,
      isTablet: false,
    );

    expect(
      minHeight(figure: true, perched: false),
      bubbleRoom +
          TodayStageGeometry.bubbleGap +
          TodayStageGeometry.waitingSize,
    );
    expect(
      minHeight(figure: true, perched: true, dotsExtent: 22),
      TodayStageGeometry.characterRoom(TodayStageGeometry.perchedSize) +
          smallestFrame(0) +
          22 +
          TodayStageGeometry.breath,
    );
    expect(
      minHeight(figure: false, perched: false, portraitness: 1),
      smallestFrame(1) + TodayStageGeometry.breath,
    );
  });
}
