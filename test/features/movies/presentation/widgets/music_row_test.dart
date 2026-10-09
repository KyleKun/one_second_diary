// The confirmation's "Music" row: None by default; its sheet adds
// files through the system picker, lists them with Remove, and shows the
// keep-sound switch and the volume once there is a track.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/audio_picker_gateway.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/music_row.dart';
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

  testWidgets('the row says None; the sheet has Add music files and no '
      'switch yet; a pick lists the track and the row sums it up; the switch '
      'toggles; Remove on the last track clears the music', (
    WidgetTester tester,
  ) async {
    world.record(<LocalDay>[
      for (int day = 1; day <= 3; day++) LocalDay(2026, 9, day),
    ]);
    world.audioPicker.answers.add(const <PickedAudio>[
      PickedAudio(path: '/scratch/music-1/0-song.mp3', name: 'song.mp3'),
    ]);
    final CreateMovieCubit flow = world.cubit(
      source: const MovieSource.month(year: 2026, month: 9),
    );
    await pumpLocalizedOsd(
      tester,
      world.wrap(
        flow,
        const Scaffold(body: SingleChildScrollView(child: MusicRow())),
      ),
      above: world.above,
    );

    String subtitleOf(Key key) =>
        tester.widget<OsdListRow>(find.byKey(key)).subtitle!;
    expect(subtitleOf(MusicRow.rowKey), 'None');

    await tester.tap(find.byKey(MusicRow.rowKey));
    await settle(tester);
    expect(find.byKey(OsdSheet.surfaceKey), findsOneWidget);
    expect(find.text('Music for the movie'), findsOneWidget);
    expect(find.byKey(MusicRow.addKey), findsOneWidget);
    expect(find.byKey(MusicRow.keepSoundKey), findsNothing);

    // A cancelled pick: "No file was added" in the sheet's note.
    world.audioPicker.answers.insert(0, const <PickedAudio>[]);
    await tester.tap(find.byKey(MusicRow.addKey));
    await settle(tester);
    expect(find.byKey(MusicSheet.noneAddedKey), findsOneWidget);
    expect(flow.state.music, isNull);

    await tester.tap(find.byKey(MusicRow.addKey));
    await settle(tester);
    expect(world.audioPicker.opened, 2);
    expect(find.byKey(MusicSheet.noneAddedKey), findsNothing);
    expect(find.byKey(MusicRow.trackKey(0)), findsOneWidget);
    expect(find.text('song.mp3'), findsOneWidget);
    expect(find.byKey(MusicRow.keepSoundKey), findsOneWidget);
    expect(find.byKey(MusicRow.volumeKey), findsOneWidget);
    expect(flow.state.music?.tracks, <String>['/scratch/music-1/0-song.mp3']);

    await tester.tap(find.byKey(MusicRow.keepSoundKey));
    await settle(tester);
    expect(flow.state.music?.keepClipSound, isFalse);
    expect(subtitleOf(MusicRow.keepSoundKey), 'Only the music plays');

    await tester.tap(find.byKey(MusicRow.removeKey(0)));
    await settle(tester);
    expect(flow.state.music, isNull);
    expect(find.byKey(MusicRow.trackKey(0)), findsNothing);
    expect(find.byKey(MusicRow.keepSoundKey), findsNothing);

    // Close the sheet: the row follows what the sheet did.
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);
    expect(find.byKey(OsdSheet.surfaceKey), findsNothing);
    expect(subtitleOf(MusicRow.rowKey), 'None');
  });
}
