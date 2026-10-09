// Music in the Create movie flow: a choice for this movie, none by
// default; files from the system picker, in order; a volume and whether the
// videos' sound stays; the request carries it; another movie starts without.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/movie_music.dart';
import 'package:one_second_diary/core/platform/audio_picker_gateway.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../../shared/fakes/clip_index_fixture.dart';
import '../../../../shared/fakes/fake_audio_picker_gateway.dart';
import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../shared/fakes/fake_free_space_gateway.dart';
import '../../../../shared/fakes/fake_profiles_repository.dart';
import '../../../../support/support.dart';
import '../../support/pausable_backfill.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

const PickedAudio _a = PickedAudio(
  path: '/scratch/music-1/0-a.mp3',
  name: 'a.mp3',
);
const PickedAudio _b = PickedAudio(
  path: '/scratch/music-1/1-b.m4a',
  name: 'b.m4a',
);
const PickedAudio _c = PickedAudio(
  path: '/scratch/music-2/0-c.mp3',
  name: 'c.mp3',
);

void main() {
  late FakeClipRepository clips;
  late FakeAudioPickerGateway picker;

  /// September 1–5.
  final ClipIndex september = clipIndexOf(_default, <LocalDay>[
    for (int day = 1; day <= 5; day++) LocalDay(2026, 9, day),
  ]);

  setUp(() {
    clips = FakeClipRepository()..publish(september);
    picker = FakeAudioPickerGateway();
  });

  tearDown(() => clips.close());

  CreateMovieCubit build() {
    final CreateMovieCubit cubit = CreateMovieCubit(
      profiles: FakeProfilesRepository(),
      clips: clips,
      clock: FakeClock(DateTime(2026, 9, 28, 10)),
      freeSpace: FakeFreeSpaceGateway(),
      backfill: PausableBackfill(),
      audioPicker: picker,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('none by default; a cancelled pick adds nothing; picks append in '
      'order at the default volume with the videos\' sound kept; the volume '
      'and the switch change; a track removed goes, the last one clears the '
      'music; the request carries it; another movie starts without', () async {
    final CreateMovieCubit cubit = build()..confirmPreset();
    expect(cubit.state.music, isNull);

    expect(await cubit.addMusic(), isFalse);
    expect(cubit.state.music, isNull);
    expect(picker.opened, 1);

    picker.answers.addAll(<List<PickedAudio>>[
      <PickedAudio>[_a, _b],
      <PickedAudio>[_c],
    ]);
    expect(await cubit.addMusic(), isTrue);
    expect(
      cubit.state.music,
      const MovieMusic(
        tracks: <String>[
          '/scratch/music-1/0-a.mp3',
          '/scratch/music-1/1-b.m4a',
        ],
      ),
    );
    expect(cubit.state.musicNames, <String, String>{
      '/scratch/music-1/0-a.mp3': 'a.mp3',
      '/scratch/music-1/1-b.m4a': 'b.m4a',
    });
    expect(cubit.state.music!.volume, MovieMusic.defaultVolume);
    expect(cubit.state.music!.keepClipSound, isTrue);
    expect(await cubit.addMusic(), isTrue);
    expect(cubit.state.music!.tracks.last, '/scratch/music-2/0-c.mp3');

    cubit
      ..setMusicVolume(1.4)
      ..setKeepClipSound(keep: false);
    expect(cubit.state.music!.volume, 1);
    expect(cubit.state.music!.keepClipSound, isFalse);

    cubit.removeMusicTrack(1);
    expect(cubit.state.music!.tracks, <String>[
      '/scratch/music-1/0-a.mp3',
      '/scratch/music-2/0-c.mp3',
    ]);
    await cubit.startMovie(title: 'September 2026');
    expect(cubit.state.request?.music, cubit.state.music);

    expect(
      cubit.state.musicNames.keys,
      isNot(contains('/scratch/music-1/1-b.m4a')),
    );
    cubit
      ..removeMusicTrack(0)
      ..removeMusicTrack(0);
    expect(cubit.state.music, isNull);
    expect(cubit.state.musicNames, isEmpty);

    // Another movie (a new range, a new profile) starts without music.
    picker.answers.add(<PickedAudio>[_a]);
    await cubit.addMusic();
    cubit
      ..choosePreset(MoviePreset.allTime)
      ..confirmPreset();
    expect(cubit.state.music, isNull);
    picker.answers.add(<PickedAudio>[_a]);
    await cubit.addMusic();
    cubit.chooseProfile(const ProfileKey('Kids'));
    expect(cubit.state.music, isNull);
  });
}
