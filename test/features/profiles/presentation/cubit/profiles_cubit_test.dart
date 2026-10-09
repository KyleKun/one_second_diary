import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/fakes/clip_index_fixture.dart';
import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../shared/fakes/fake_profiles_repository.dart';
import '../../../../support/support.dart';
import '../../../../support/track_1c/refusing_shared_preferences.dart';

const ProfileKey work = ProfileKey('Work');

void main() {
  late FakeProfilesRepository profiles;
  late FakeClipRepository clips;
  late MemoryLogSink log;

  setUp(() {
    profiles = FakeProfilesRepository(
      profiles: <Profile>[
        testProfile(),
        testProfile(key: work, orientation: VideoOrientation.portrait),
      ],
      active: work,
    );
    clips = FakeClipRepository();
    log = MemoryLogSink();
  });

  tearDown(() async {
    await profiles.close();
    await clips.close();
  });

  ProfilesCubit cubit() => ProfilesCubit(
    profiles: profiles,
    clips: clips,
    logger: memoryLogger(log),
  );

  test('starts with every profile and the active one, counts not yet known; '
      'counts the clips of each profile as its diary is read; a diary that '
      'cannot be read keeps its count unknown and is logged; follows '
      'switches, new and deleted profiles', () async {
    final ProfilesCubit subject = cubit();
    addTearDown(subject.close);
    expect(subject.state.profiles, profiles.profiles);
    expect(subject.state.active.key, work);
    expect(subject.state.clipCountOf(ProfileKey.defaultProfile), isNull);
    expect(subject.state.status, ProfilesStatus.ready);

    clips.fail(work, const StorageException('unreadable'));
    clips.publish(
      clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[
        day(1),
        day(2),
        day(3),
      ]),
    );
    await pumpEventQueue();

    expect(subject.state.clipCountOf(work), isNull);
    expect(log.lines.single, contains('Could not count the clips of Work'));
    expect(subject.state.clipCountOf(ProfileKey.defaultProfile), 3);

    clips.publish(clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[day(1)]));
    await pumpEventQueue();

    expect(subject.state.clipCountOf(ProfileKey.defaultProfile), 1);

    // It follows switches, new and deleted profiles.
    const ProfileKey trip = ProfileKey('Trip');

    await profiles.activate(ProfileKey.defaultProfile);
    await pumpEventQueue();
    expect(subject.state.active.key, ProfileKey.defaultProfile);

    profiles.addProfile(testProfile(key: trip));
    clips.publish(clipIndexOf(trip, <LocalDay>[day(4), day(5)]));
    await pumpEventQueue();
    expect(subject.state.profiles.map((Profile p) => p.key), <ProfileKey>[
      ProfileKey.defaultProfile,
      work,
      trip,
    ]);
    expect(subject.state.clipCountOf(trip), 2);

    profiles.removeProfile(trip);
    await pumpEventQueue();
    expect(subject.state.profiles.map((Profile p) => p.key), <ProfileKey>[
      ProfileKey.defaultProfile,
      work,
    ]);
    expect(subject.state.clipCountOf(trip), isNull);
  });

  // Over the real repository: a switch is stored, a refused one says so on
  // every refusal, and the names are read again after a language change
  // (the repository's watch() does not re-emit when only Default's label
  // changes).
  test('activate makes the profile active; a switch the phone refuses keeps '
      'the active profile and says so, every time; the names are re-read '
      'after a language change', () async {
    String defaultLabel = 'Default';
    final Map<String, Object> twoProfiles = legacyPrefs(
      profiles: <String>['Default', 'Work'],
      orientations: <String, String>{'': 'landscape', 'Work': 'portrait'},
    );
    Future<ProfilesCubit> overPrefs(PrefsStore store) async {
      final ProfilesCubit subject = ProfilesCubit(
        profiles: ProfilesRepository(
          prefs: store,
          paths: await createTestPaths(),
          mediaStore: FakeMediaStoreGateway(),
          clock: FakeClock(DateTime(2024, 1, 5, 10)),
          logger: memoryLogger(MemoryLogSink()),
          defaultLabel: () => defaultLabel,
        ),
        clips: clips,
        logger: memoryLogger(log),
      );
      addTearDown(subject.close);
      await pumpEventQueue();
      return subject;
    }

    final ProfilesCubit stored = await overPrefs(
      await openLegacyPrefs(twoProfiles),
    );
    await stored.activate(work);
    await pumpEventQueue();

    expect(stored.state.active.key, work);
    expect(
      (await SharedPreferences.getInstance()).getInt('selectedProfileIndex'),
      1,
    );

    defaultLabel = 'Standard';
    stored.localeChanged();

    expect(stored.state.profiles.first.displayName, 'Standard');

    final (PrefsStore store, _) = await openRefusingPrefs(
      twoProfiles,
      refused: <String>{'selectedProfileIndex'},
    );
    final ProfilesCubit refused = await overPrefs(store);
    final List<ProfilesStatus> statuses = <ProfilesStatus>[];
    refused.stream.listen((ProfilesState state) => statuses.add(state.status));

    await refused.activate(work);
    await refused.activate(work);
    await pumpEventQueue();

    expect(refused.state.active.key, ProfileKey.defaultProfile);
    expect(refused.state.status, ProfilesStatus.activationFailed);
    expect(
      statuses.where(
        (ProfilesStatus s) => s == ProfilesStatus.activationFailed,
      ),
      hasLength(2),
    );
    expect(
      log.lines.where(
        (String line) => line.contains('Could not activate Work'),
      ),
      hasLength(2),
    );
  });
}

LocalDay day(int d) => LocalDay(2024, 1, d);
