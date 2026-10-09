// Performance guards of the clip picker over a diary of 1 200 clips: the
// first frame builds the tiles in view, a finished thumbnail rebuilds its
// own thumbnail, a tap rebuilds its own tile and the bar, and tiles flung
// past cancel their thumbnails.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_thumbnail_view.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/pages/pick_clips_page.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/pick_clip_tile.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/pick_clips_bar.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/pick_clips_grid.dart';
import 'package:one_second_diary/shared/widgets/controls/selection_badge.dart';

import '../../../../shared/fakes/fake_clip_caches.dart';
import '../../../../shared/harness/settle.dart';
import '../../../../theme/support/load_osd_fonts.dart';
import '../../support/create_movie_world.dart';
import '../../support/pump_localized_osd.dart';

/// The 1 200 days up to September 28, 2026, one clip each.
final List<LocalDay> _diary = <LocalDay>[
  for (int i = 1199; i >= 0; i--) LocalDay(2026, 9, 28).addDays(-i),
];

/// The widgets built while [body] runs, by type.
Future<Map<Type, int>> _buildsDuring(Future<void> Function() body) async {
  final Map<Type, int> builds = <Type, int>{};
  debugOnRebuildDirtyWidget = (Element element, bool builtOnce) => builds
      .update(element.widget.runtimeType, (int n) => n + 1, ifAbsent: () => 1);
  try {
    await body();
  } finally {
    debugOnRebuildDirtyWidget = null;
  }
  return builds;
}

void main() {
  late CreateMovieWorld world;

  setUpAll(loadOsdFonts);
  setUp(() => world = CreateMovieWorld()..record(_diary));
  tearDown(() => world.dispose());

  Future<void> pumpPage(WidgetTester tester) => pumpLocalizedOsd(
    tester,
    world.wrap(world.cubit(), const PickClipsPage()),
    above: world.above,
    settleAfter: false,
  );

  ClipRef clipOn(LocalDay day) => world.indexOf().clipsOn(day).single;

  testWidgets('the grid shows at once from the index, building only the '
      'tiles in view and asking only for their thumbnails; tiles flung past '
      'cancel theirs', (WidgetTester tester) async {
    await pumpPage(tester);

    final int tiles = find
        .byType(PickClipTile, skipOffstage: false)
        .evaluate()
        .length;
    expect(tiles, inInclusiveRange(1, 30));
    expect(
      find.byKey(PickClipTile.tileKey(clipOn(LocalDay(2026, 9, 1)))),
      findsOneWidget,
      reason: 'the newest month first',
    );
    expect(world.thumbnails.requests.length, lessThanOrEqualTo(tiles));

    final List<FakeThumbnailRequest> first = world.thumbnails.pending;
    await tester.fling(
      find.byKey(PickClipsGrid.scrollKey),
      const Offset(0, -6000),
      4000,
    );
    await settle(tester);

    expect(
      first.where((FakeThumbnailRequest request) => request.cancelled),
      isNotEmpty,
    );
    expect(
      find.byType(PickClipTile, skipOffstage: false).evaluate().length,
      inInclusiveRange(1, 30),
      reason: 'still only the tiles in view',
    );
  });

  // Select all over the whole diary stays a set operation: only the tiles in
  // view rebuild.
  testWidgets('a tap rebuilds the tapped tile and the bar, never the grid, '
      'the other tiles or any thumbnail; Select all over 1 200 clips '
      'rebuilds only the tiles in view', (WidgetTester tester) async {
    await pumpPage(tester);
    final int inView = find
        .byType(PickClipTile, skipOffstage: false)
        .evaluate()
        .length;

    final Map<Type, int> tap = await _buildsDuring(() async {
      await tester.tap(
        find.byKey(PickClipTile.tileKey(clipOn(LocalDay(2026, 9, 2)))),
      );
      await tester.pump();
    });
    expect(tap[SelectionBadge], 1, reason: 'the tapped tile only');
    expect(tap[PickClipsBar], 1);
    expect(tap[PickClipTile], isNull);
    expect(tap[ClipThumbnailView], isNull);
    expect(tap[PickClipsGrid], isNull);
    expect(tap[PickClipsPage], isNull);

    final Map<Type, int> all = await _buildsDuring(() async {
      await tester.tap(find.byKey(PickClipsPage.selectAllKey));
      await tester.pump();
    });
    expect(
      tester
          .element(find.byType(PickClipsPage))
          .read<CreateMovieCubit>()
          .state
          .picks
          .count,
      1200,
    );
    expect(all[SelectionBadge], lessThanOrEqualTo(inView));
    expect(all[PickClipTile], isNull);
  });
}
