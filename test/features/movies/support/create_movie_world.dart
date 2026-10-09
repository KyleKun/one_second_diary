import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';

import '../../../shared/fakes/clip_index_fixture.dart';
import '../../../shared/fakes/fake_audio_picker_gateway.dart';
import '../../../shared/fakes/fake_clip_caches.dart';
import '../../../shared/fakes/fake_clip_repository.dart';
import '../../../shared/fakes/fake_free_space_gateway.dart';
import '../../../shared/fakes/fake_movie_builder.dart';
import '../../../shared/fakes/fake_profiles_repository.dart';
import '../../../support/support.dart';
import 'pausable_backfill.dart';

/// A second profile, portrait.
const ProfileKey kidsProfile = ProfileKey('Kids');

/// Everything the Create movie screens read, faked, on September 28, 2026
/// at 10:00: Default (landscape, active) and Kids (portrait), whose clips
/// the test [record]s.
final class CreateMovieWorld {
  CreateMovieWorld()
    : clock = FakeClock(DateTime(2026, 9, 28, 10)),
      profiles = FakeProfilesRepository(
        profiles: <Profile>[
          testProfile(),
          testProfile(key: kidsProfile, orientation: VideoOrientation.portrait),
        ],
      ),
      clips = FakeClipRepository(),
      thumbnails = FakeThumbnailRepository(),
      freeSpace = FakeFreeSpaceGateway(),
      movieBuilder = FakeMovieBuilder(),
      log = MemoryLogSink();

  final FakeClock clock;
  final FakeProfilesRepository profiles;
  final FakeClipRepository clips;

  /// The thumbnails the pages ask for (`ClipThumbnailView`).
  final FakeThumbnailRepository thumbnails;

  /// The phone's free space (unknown until a test says).
  final FakeFreeSpaceGateway freeSpace;

  /// What the app's movie job makes movies with.
  final FakeMovieBuilder movieBuilder;

  /// The clips' metadata reading the flow follows (idle unless a test
  /// starts it).
  final PausableBackfill backfill = PausableBackfill();

  /// The clips' cached facts the flow's transition counts read (empty
  /// unless a test fills [FakeClipMetadataCache.entries]).
  final FakeClipMetadataCache metadata = FakeClipMetadataCache();

  /// The system picker for music files (cancels unless a test scripts
  /// [FakeAudioPickerGateway.answers]).
  final FakeAudioPickerGateway audioPicker = FakeAudioPickerGateway();

  /// The screen held awake while a movie is made.
  final FakeWakelockGateway wakelock = FakeWakelockGateway();
  final MemoryLogSink log;

  final AppPaths paths = AppPaths.forTest(Directory('/osd'));

  /// [profile] has one clip on each of [days]; those of [tags] (by day)
  /// carry the tags given.
  void record(
    List<LocalDay> days, {
    ProfileKey profile = ProfileKey.defaultProfile,
    Map<LocalDay, List<String>> tags = const <LocalDay, List<String>>{},
  }) {
    ClipIndex index = clipIndexOf(profile, days);
    if (tags.isNotEmpty) {
      index = index.withClipTags(<String, List<String>>{
        for (final MapEntry<LocalDay, List<String>> entry in tags.entries)
          index.clipsOn(entry.key).single.relPath: entry.value,
      });
    }
    clips.publish(index);
  }

  /// [profile]'s clips now.
  ClipIndex indexOf([ProfileKey profile = ProfileKey.defaultProfile]) =>
      clips.snapshotOf(profile)!;

  /// The flow's cubit, opened with [source] (the Diary's month) and
  /// [tags] (the Diary's filter) or not.
  CreateMovieCubit cubit({MovieSource? source, TagFilter? tags}) =>
      CreateMovieCubit(
        source: source,
        tags: tags,
        profiles: profiles,
        clips: clips,
        clock: clock,
        freeSpace: freeSpace,
        backfill: backfill,
        metadata: metadata,
        audioPicker: audioPicker,
      );

  /// [page] in the flow, with [flow] (closed with the tree).
  Widget wrap(CreateMovieCubit flow, Widget page) =>
      BlocProvider<CreateMovieCubit>(create: (_) => flow, child: page);

  /// What the app root provides: the paths, the clips and their
  /// thumbnails, the app's profiles and the movie job.
  Widget above(Widget app) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider<AppPaths>.value(value: paths),
      RepositoryProvider<ClipRepository>.value(value: clips),
      RepositoryProvider<ClipMetadataCache>.value(value: metadata),
      RepositoryProvider<ThumbnailRepository>.value(value: thumbnails),
    ],
    child: MultiBlocProvider(
      providers: <BlocProvider<Object?>>[
        BlocProvider<ProfilesCubit>(
          create: (_) => ProfilesCubit(
            profiles: profiles,
            clips: clips,
            logger: memoryLogger(log),
          ),
        ),
        BlocProvider<MovieJobBloc>(
          create: (_) => MovieJobBloc(
            builder: movieBuilder,
            wakelock: wakelock,
            backfill: backfill,
            freeSpace: freeSpace,
            logger: memoryLogger(log),
          ),
        ),
      ],
      child: app,
    ),
  );

  Future<void> dispose() async {
    await backfill.dispose();
    await clips.close();
  }
}
