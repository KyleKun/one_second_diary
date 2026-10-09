// ClipPlayerView: a clip playing in its frame. The poster shows in the
// first frame and the pooled player fades in over it once ready.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/thumbnail_tier.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_playback.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_player_view.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

import '../../../shared/harness/clip_media_harness.dart';
import '../../../support/support.dart';

void main() {
  late ClipMediaHarness media;

  setUp(() {
    media = ClipMediaHarness()..index(<int>[4, 5, 6]);
    for (final int day in <int>[4, 5, 6]) {
      media.thumbnails.make(
        mediaClip(day),
        stamp: mediaStamp,
        tier: ThumbnailTier.poster,
        path: '/thumbs/$day.jpg',
      );
    }
  });
  tearDown(() => media.dispose());

  Widget player({required List<ClipRef> neighbours, required bool autoPlay}) =>
      ClipPlayerView(
        clip: mediaClip(5),
        neighbours: neighbours,
        autoPlay: autoPlay,
        loop: true,
        overlayBuilder:
            (
              BuildContext context,
              ClipPlayback playback,
              ClipPlayerControls given,
            ) => const SizedBox.shrink(),
      );

  /// Lets the pool open its players (their `initialize` completes).
  Future<void> ready(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(OsdMotion.fast);
  }

  // Phones have few hardware decoders, and a screen can be hidden or covered
  // (Today behind the Diary, the Diary under the viewer).
  testWidgets('a hidden screen keeps only its clip\'s player, paused; its '
      'neighbours warm again when it shows', (tester) async {
    final List<ClipRef> neighbours = <ClipRef>[mediaClip(4), mediaClip(6)];
    Widget inTab({required bool shown}) => TickerMode(
      enabled: shown,
      child: player(autoPlay: true, neighbours: neighbours),
    );
    await media.pump(tester, inTab(shown: true));
    await ready(tester);
    final FakePlayerHandle handle = media.playerOf(mediaClip(5));
    Iterable<String> alive() =>
        media.players.alive.map((FakePlayerHandle player) => player.path);

    await media.pump(tester, inTab(shown: false));
    await ready(tester);

    expect(alive(), <String>[media.pathOf(mediaClip(5))]);
    expect(handle.isDisposed, isFalse);
    expect(handle.value.value.playing, isFalse);

    await media.pump(tester, inTab(shown: true));
    await ready(tester);

    expect(
      alive(),
      unorderedEquals(<String>[
        media.pathOf(mediaClip(5)),
        media.pathOf(mediaClip(4)),
        media.pathOf(mediaClip(6)),
      ]),
    );
    expect(media.pool.shown.value?.handle, same(handle));
    expect(handle.value.value.playing, isTrue);
  });
}
