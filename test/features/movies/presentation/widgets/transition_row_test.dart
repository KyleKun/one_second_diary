// The confirmation's "Transition" row: None by default, a sheet of
// the styles, and the older-clips switch only with a style and older clips.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/stamped_clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/transition_row.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';

import '../../../../shared/harness/settle.dart';
import '../../../../theme/support/load_osd_fonts.dart';
import '../../support/create_movie_world.dart';
import '../../support/pump_localized_osd.dart';

void main() {
  late CreateMovieWorld world;

  setUpAll(loadOsdFonts);
  setUp(() => world = CreateMovieWorld());
  tearDown(() => world.dispose());

  testWidgets('the row says None, the sheet lists the styles and the choice '
      'shows; the older-clips switch appears with a style and older clips, '
      'and toggles; a dismissed sheet leaves the choice', (
    WidgetTester tester,
  ) async {
    final List<LocalDay> days = <LocalDay>[
      for (int day = 1; day <= 3; day++) LocalDay(2026, 9, day),
    ];
    world.record(days);
    for (final (int at, LocalDay day) in days.indexed) {
      final ClipRef clip = world.indexOf().clipsOn(day).single;
      world.metadata.entries[clip.relPath] = StampedClipMeta(
        stamp: world.indexOf().stampOf(clip)!,
        meta: ClipMeta(
          keyframes: ClipKeyframes(
            frameCount: 45,
            indices: at == 0 ? const <int>[0] : const <int>[0, 10, 35],
          ),
        ),
      );
    }
    final CreateMovieCubit flow = world.cubit(
      source: const MovieSource.month(year: 2026, month: 9),
    );
    await pumpLocalizedOsd(
      tester,
      world.wrap(
        flow,
        const Scaffold(body: SingleChildScrollView(child: TransitionRow())),
      ),
      above: world.above,
    );

    String subtitleOf(Key key) =>
        tester.widget<OsdListRow>(find.byKey(key)).subtitle!;
    expect(subtitleOf(TransitionRow.rowKey), 'None');
    expect(find.byKey(TransitionRow.upgradeKey), findsNothing);

    await tester.tap(find.byKey(TransitionRow.rowKey));
    await settle(tester);
    expect(find.byKey(OsdSheet.surfaceKey), findsOneWidget);
    expect(find.text('Transition between clips'), findsOneWidget);
    for (final MovieTransition? choice in <MovieTransition?>[
      null,
      ...MovieTransition.values,
    ]) {
      expect(find.byKey(TransitionRow.choiceKey(choice)), findsOneWidget);
    }

    await tester.tap(
      find.byKey(TransitionRow.choiceKey(MovieTransition.fadeBlack)),
    );
    await settle(tester);
    expect(find.byKey(OsdSheet.surfaceKey), findsNothing);
    expect(flow.state.transition, MovieTransition.fadeBlack);
    expect(subtitleOf(TransitionRow.rowKey), 'Fade through black');
    expect(find.byKey(TransitionRow.upgradeKey), findsOneWidget);
    expect(
      subtitleOf(TransitionRow.upgradeKey),
      '1 older clip will cut without a transition',
    );

    await tester.tap(find.byKey(TransitionRow.upgradeKey));
    await settle(tester);
    expect(flow.state.upgradeOlderClips, isTrue);
    expect(
      subtitleOf(TransitionRow.upgradeKey),
      '1 older clip will be re-encoded first (slower)',
    );

    await tester.tap(find.byKey(TransitionRow.rowKey));
    await settle(tester);
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);
    expect(flow.state.transition, MovieTransition.fadeBlack);

    await tester.tap(find.byKey(TransitionRow.rowKey));
    await settle(tester);
    await tester.tap(find.byKey(TransitionRow.choiceKey(null)));
    await settle(tester);
    expect(flow.state.transition, isNull);
    expect(find.byKey(TransitionRow.upgradeKey), findsNothing);
  });
}
