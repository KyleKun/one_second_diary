// The seeding helpers produce what the launched app reads (over the real
// launch, the way journeys use them).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';

import '../robots/app_robot.dart';
import 'seeds.dart';

void main() {
  final LocalDay day = LocalDay(2024, 1, 5);

  ClipIndex indexOf(ProfileKey profile) =>
      sl<ClipRepository>().snapshotOf(profile)!;

  testWidgets("several clips on one day, with the first clip's cached facts "
      '(subtitle, place) as the backfill would have left them', (
    WidgetTester tester,
  ) async {
    const String first = '2024-01-05.mp4';
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: prefsWithProfiles(const <ProfileSeed>[]),
      seed: (AppPaths paths) async {
        await seedDayClips(paths, ProfileKey.defaultProfile, day, count: 3);
        await seedClipMeta(paths, <String, ClipMeta>{
          first: const ClipMeta(
            durationMs: 1500,
            subtitleText: 'Walk around Asakusa',
            locationText: 'Tokyo, Japan',
          ),
        });
      },
    );
    await app.harness.settleUntil(
      () => sl<ClipRepository>().snapshotOf(ProfileKey.defaultProfile) != null,
      reason: 'the launch scanned the clips',
    );

    final List<ClipRef> clips = indexOf(ProfileKey.defaultProfile).clipsOn(day);
    expect(clips.map((ClipRef clip) => clip.relPath), <String>[
      first,
      '2024-01-05-2.mp4',
      '2024-01-05-3.mp4',
    ]);
    final ClipMeta? meta = sl<ClipMetadataCache>().lookup(
      relPath: first,
      stamp: indexOf(ProfileKey.defaultProfile).stampOf(clips.first)!,
    );
    expect(meta?.subtitleText, 'Walk around Asakusa');
    expect(meta?.locationText, 'Tokyo, Japan');
  });

  testWidgets('profiles with a display name and a photo', (
    WidgetTester tester,
  ) async {
    const List<ProfileSeed> named = <ProfileSeed>[
      ProfileSeed('Trip', orientation: 'portrait', withPhoto: true),
      ProfileSeed('kids', displayName: 'Kids'),
    ];
    late AppPaths seeded;
    await AppRobot.launch(
      tester,
      prefs: prefsWithProfiles(named, selected: 1),
      seed: (AppPaths paths) async {
        seeded = paths;
        await seedProfilePhotos(paths, named);
      },
    );

    final List<Profile> profiles = sl<ProfilesCubit>().state.profiles;
    expect(profiles.map((Profile p) => p.displayName), <String>[
      'Default',
      'Trip',
      'Kids',
    ]);
    expect(sl<ProfilesCubit>().state.active.key, const ProfileKey('Trip'));
    final String photo = profiles[1].avatarRelPath!;
    expect(File('${seeded.internal}/$photo').existsSync(), isTrue);
  });
}
