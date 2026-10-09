// "Found on this phone": folders under Profiles/ that hold clips but that
// no profile lists, after a reinstall without the preferences or a delete
// the phone refused, offered back and never added silently.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/found_profiles_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/found_profiles_state.dart';

import '../../../../support/support.dart';
import '../../../../support/track_1c/refusing_media_store_gateway.dart';
import '../../../../support/track_1c/refusing_shared_preferences.dart';

void main() {
  late AppPaths paths;
  late FakeMediaStoreGateway mediaStore;
  late MemoryLogSink log;
  late ProfilesRepository profiles;

  setUp(() async {
    paths = await createTestPaths();
    mediaStore = FakeMediaStoreGateway.onDisk(paths);
    log = MemoryLogSink();
  });

  Future<FoundProfilesCubit> foundOver(PrefsStore store) async {
    profiles = ProfilesRepository(
      prefs: store,
      paths: paths,
      mediaStore: mediaStore,
      clock: FakeClock(DateTime(2024, 1, 5, 10)),
      logger: memoryLogger(log),
      defaultLabel: () => 'Default',
    );
    final FoundProfilesCubit cubit = FoundProfilesCubit(
      profiles: profiles,
      logger: memoryLogger(log),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('offers the folders with clips that no profile lists, once read; '
      '"Add back" lists one as a profile, not active, and the offer goes; '
      'a profile deleted while the phone kept some of its clips is offered '
      'back', () async {
    const ProfileKey travel = ProfileKey('Travel');
    await seedClip(paths, const ProfileKey('Old trip'), LocalDay(2023, 5, 1));
    final String kept = (await seedClip(
      paths,
      travel,
      LocalDay(2023, 5, 1),
    )).path;
    mediaStore = RefusingMediaStoreGateway.onDisk(
      paths,
      refusedDeletes: <String>{kept},
    );
    final FoundProfilesCubit found = await foundOver(
      await openLegacyPrefs(
        legacyPrefs(profiles: <String>['Default', 'Travel']),
      ),
    );
    expect(found.state.status, FoundProfilesStatus.loading);

    await found.load();

    expect(found.state.folders, <ProfileKey>[const ProfileKey('Old trip')]);
    expect(found.state.status, FoundProfilesStatus.ready);

    await found.addBack(const ProfileKey('Old trip'));

    expect(profiles.profiles.map((Profile p) => p.key), <ProfileKey>[
      ProfileKey.defaultProfile,
      travel,
      const ProfileKey('Old trip'),
    ]);
    expect(profiles.active.key, ProfileKey.defaultProfile);
    expect(found.state.folders, isEmpty);

    final Future<void> offered = expectLater(
      found.stream.map((FoundProfilesState s) => s.folders),
      emitsThrough(<ProfileKey>[travel]),
    );
    await profiles.delete(travel);
    await offered;
  });

  test('a refused "Add back" says so every time and keeps the offer', () async {
    await seedClip(paths, const ProfileKey('Old trip'), LocalDay(2023, 5, 1));
    final (PrefsStore store, _) = await openRefusingPrefs(
      legacyPrefs(),
      refused: <String>{'profiles'},
    );
    final FoundProfilesCubit found = await foundOver(store);
    await found.load();
    final List<FoundProfilesStatus> statuses = <FoundProfilesStatus>[];
    found.stream.listen((FoundProfilesState s) => statuses.add(s.status));

    await found.addBack(const ProfileKey('Old trip'));
    await found.addBack(const ProfileKey('Old trip'));
    await pumpEventQueue();

    expect(statuses, <FoundProfilesStatus>[
      FoundProfilesStatus.adding,
      FoundProfilesStatus.addFailed,
      FoundProfilesStatus.adding,
      FoundProfilesStatus.addFailed,
    ]);
    expect(found.state.folders, <ProfileKey>[const ProfileKey('Old trip')]);
    expect(log.lines, contains(contains('[PROFILES] Could not add back')));
  });
}
