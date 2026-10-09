// The profile's clips by month in a lazy grid, picked with a tap or all at
// once, with the live count and Continue.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/pages/pick_clips_page.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/pick_clip_tile.dart';

import '../../../../shared/harness/settle.dart';
import '../../../../theme/support/load_osd_fonts.dart';
import '../../support/create_movie_world.dart';
import '../../support/pump_localized_osd.dart';

/// Days [first] to [last] of [month] 2026.
List<LocalDay> _days(int month, int first, int last) => <LocalDay>[
  for (int day = first; day <= last; day++) LocalDay(2026, month, day),
];

void main() {
  late CreateMovieWorld world;

  setUpAll(loadOsdFonts);
  setUp(() => world = CreateMovieWorld());
  tearDown(() => world.dispose());

  Future<CreateMovieCubit> pumpPage(WidgetTester tester) async {
    final CreateMovieCubit flow = world.cubit();
    await pumpLocalizedOsd(
      tester,
      world.wrap(flow, const PickClipsPage()),
      above: world.above,
    );
    return flow;
  }

  // A missing or corrupt file.
  testWidgets('a clip whose picture cannot be read is dimmed, says so and '
      'cannot be picked, not even by Select all', (WidgetTester tester) async {
    world.record(_days(9, 1, 3));
    final CreateMovieCubit flow = await pumpPage(tester);
    final ClipRef broken = world.indexOf().clipsOn(LocalDay(2026, 9, 2)).single;
    world.thumbnails.requests
        .firstWhere((request) => request.id.relPath == broken.relPath)
        .fail();
    await settle(tester);

    final Finder tile = find.byKey(PickClipTile.tileKey(broken));
    expect(
      tester.getSemantics(tile),
      isSemantics(
        label: Strings.clipUnavailableSemantics(date: 'September 2, 2026'),
        isEnabled: false,
        hasEnabledState: true,
      ),
    );
    expect(
      find.descendant(
        of: tile,
        matching: find.byWidgetPredicate(
          (Widget widget) => widget is Opacity && widget.opacity == .5,
        ),
      ),
      findsOneWidget,
      reason: 'dimmed',
    );

    await tester.tap(tile, warnIfMissed: false);
    await settle(tester);
    expect(flow.state.picks.contains(broken), isFalse);

    await tester.tap(find.byKey(PickClipsPage.selectAllKey));
    await settle(tester);
    expect(flow.state.picks.count, 2);
    expect(flow.state.picks.contains(broken), isFalse);
    expect(
      find.descendant(
        of: find.byKey(PickClipsPage.selectAllKey),
        matching: find.text(Strings.deselectAll),
      ),
      findsOneWidget,
      reason: 'every clip that can be picked is',
    );
  });
}
