// ClipThumbnailView: a clip's poster from the thumbnail cache, for every
// screen that shows clips. A poster the cache knows shows in the same
// frame; the rest never blocks one.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_thumbnail_view.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';

import '../../../shared/fakes/fake_clip_caches.dart';
import '../../../shared/harness/clip_media_harness.dart';

void main() {
  late ClipMediaHarness media;

  setUp(() => media = ClipMediaHarness());
  tearDown(() => media.dispose());

  Widget view({
    int day = 5,
    ClipThumbnailSlot slot = ClipThumbnailSlot.player,
  }) => ClipThumbnailView(clip: mediaClip(day), slot: slot);

  testWidgets('a tile that goes away cancels what it asked for', (
    tester,
  ) async {
    media.index(<int>[5]);
    await media.pump(tester, view());
    final FakeThumbnailRequest asked = media.thumbnails.pending.single;

    await media.pump(tester, const SizedBox.shrink());

    expect(asked.cancelled, isTrue);
  });
}
