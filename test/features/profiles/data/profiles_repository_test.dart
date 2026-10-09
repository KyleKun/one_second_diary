import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_change.dart';
import 'package:one_second_diary/features/profiles/domain/profile_clip_facts.dart';
import 'package:one_second_diary/features/profiles/domain/profile_deletion.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/domain/profile_name_error.dart';
import 'package:one_second_diary/features/profiles/domain/profiles_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/fakes/fake_profile_clip_facts.dart';
import '../../../support/support.dart';
import '../../../support/track_1c/refusing_media_store_gateway.dart';
import '../../../support/track_1c/refusing_shared_preferences.dart';

void main() {
  late PrefsStore prefs;
  late MemoryLogSink log;
  late AppPaths paths;
  late FakeClock clock;
  late FakeMediaStoreGateway mediaStore;

  setUp(() async {
    log = MemoryLogSink();
    paths = await createTestPaths();
    clock = FakeClock(DateTime(2024, 1, 5, 10));
    mediaStore = FakeMediaStoreGateway.onDisk(paths);
  });

  Future<File> pickedImage(List<int> bytes) async {
    final File file = File(
      '${paths.temporaryDir}/image_picker_${bytes.first}.jpg',
    );
    await file.parent.create(recursive: true);
    return file.writeAsBytes(bytes);
  }

  ProfilesRepository repositoryOver(
    PrefsStore store, {
    String Function()? defaultLabel,
    ProfileClipFacts? clipFacts,
  }) {
    prefs = store;
    return ProfilesRepository(
      prefs: store,
      paths: paths,
      mediaStore: mediaStore,
      clock: clock,
      logger: memoryLogger(log),
      defaultLabel: defaultLabel ?? () => 'Default',
      clipFacts: clipFacts,
    );
  }

  Future<ProfilesRepository> repositoryWith(Map<String, Object> values) async =>
      repositoryOver(await openLegacyPrefs(values));

  group('reading', () {
    test('index 0 is Default and the other entries are folder keys, each with '
        'its orientation_ canvas; missing or unknown is landscape; no stored '
        'list, or an empty one, is Default alone; reading writes '
        'nothing', () async {
      final ProfilesRepository repository = await repositoryWith(
        legacyPrefs(
          profiles: <String>['Default', 'Travel', 'Kids', 'Old'],
          orientations: <String, String>{
            '': 'portrait',
            'Travel': 'portrait',
            'Kids': 'sideways',
          },
        ),
      );

      expect(
        repository.profiles.map(
          (Profile p) => (p.key, p.displayName, p.orientation),
        ),
        <(ProfileKey, String, VideoOrientation)>[
          (ProfileKey.defaultProfile, 'Default', VideoOrientation.portrait),
          (const ProfileKey('Travel'), 'Travel', VideoOrientation.portrait),
          (const ProfileKey('Kids'), 'Kids', VideoOrientation.landscape),
          (const ProfileKey('Old'), 'Old', VideoOrientation.landscape),
        ],
      );

      for (final Map<String, Object> values in <Map<String, Object>>[
        freshInstallPrefs,
        <String, Object>{'profiles': <String>[]},
      ]) {
        final ProfilesRepository alone = await repositoryWith(values);

        expect(alone.profiles, <Profile>[
          const Profile(
            key: ProfileKey.defaultProfile,
            displayName: 'Default',
            orientation: VideoOrientation.landscape,
            avatarRelPath: null,
          ),
        ]);
        expect(alone.active.key, ProfileKey.defaultProfile);
        expect(
          (await SharedPreferences.getInstance()).getKeys(),
          values.keys.toSet(),
        );
      }
    });

    test('a later entry literally named "Default" is a normal profile in '
        'Profiles/Default/, shown as "Default (2)" (Z MB-05, Q-P2); a '
        'repeated entry is one profile, and an empty entry after index 0 '
        '(which would alias Default\'s folder) is not a profile', () async {
      final ProfilesRepository repository = await repositoryWith(
        legacyPrefs(
          profiles: <String>['Default', 'Travel', '', 'Travel', 'Default'],
        ),
      );

      expect(
        repository.profiles.map(
          (Profile p) => (p.key, p.isDefault, p.displayName),
        ),
        <(ProfileKey, bool, String)>[
          (ProfileKey.defaultProfile, true, 'Default'),
          (const ProfileKey('Travel'), false, 'Travel'),
          (const ProfileKey('Default'), false, 'Default (2)'),
        ],
      );
    });

    test('the active profile is selectedProfileIndex into the stored list; an '
        'index out of range is Default (flips G-5, I CL-19)', () async {
      Future<ProfileKey> activeAt(int index) async => (await repositoryWith(
        legacyPrefs(
          profiles: <String>['Default', 'Travel', 'Kids'],
          selectedProfileIndex: index,
        ),
      )).active.key;

      expect(await activeAt(2), const ProfileKey('Kids'));
      expect(await activeAt(0), ProfileKey.defaultProfile);
      expect(await activeAt(5), ProfileKey.defaultProfile);
      expect(await activeAt(-1), ProfileKey.defaultProfile);
    });

    test('display names and photos come from the profileMeta record, keyed by '
        'folder key; a corrupt record reads as no names and no photos, and '
        'is logged', () async {
      final ProfilesRepository repository = await repositoryWith(
        legacyPrefs(
          profiles: <String>['Default', 'Travel', 'Kids'],
          extra: <String, Object>{
            'profileMeta': jsonEncode(<String, Object>{
              '': <String, String>{
                'displayName': 'Home',
                'avatarRelPath': 'avatars/default-1.jpg',
              },
              'Travel': <String, String>{'displayName': 'Viagem ✈'},
            }),
          },
        ),
      );

      expect(
        repository.profiles.map(
          (Profile p) => (p.displayName, p.avatarRelPath),
        ),
        <(String, String?)>[
          ('Home', 'avatars/default-1.jpg'),
          ('Viagem ✈', null),
          ('Kids', null),
        ],
      );
      expect(log.lines, isEmpty);

      for (final String stored in <String>[
        'not json',
        '[1, 2]',
        '{"Travel": "Viagem"}',
        '{"Travel": {"displayName": 3, "avatarRelPath": true}}',
      ]) {
        final ProfilesRepository corrupt = await repositoryWith(
          legacyPrefs(
            profiles: <String>['Default', 'Travel'],
            extra: <String, Object>{'profileMeta': stored},
          ),
        );

        expect(
          corrupt.profiles.map((Profile p) => (p.displayName, p.avatarRelPath)),
          <(String, String?)>[('Default', null), ('Travel', null)],
          reason: stored,
        );
      }
      expect(log.lines, isNotEmpty);
      expect(
        log.lines,
        everyElement(allOf(startsWith('[WARNING]'), contains('[PROFILES]'))),
      );
    });
  });

  group('activate', () {
    test(
      'stores the index of the profile in the legacy list, a later "Default" '
      'found after index 0 (Z MB-05), and refuses a profile that is not '
      'listed; watch() gives the current profiles first, then each '
      'change',
      () async {
        const ProfileKey named = ProfileKey('Default');
        final ProfilesRepository repository = await repositoryWith(
          legacyPrefs(profiles: <String>['Default', 'Travel', 'Default']),
        );
        final List<ProfilesSnapshot> seen = <ProfilesSnapshot>[];
        final StreamSubscription<ProfilesSnapshot> subscription = repository
            .watch()
            .listen(seen.add);
        addTearDown(subscription.cancel);
        await pumpEventQueue();

        await repository.activate(named);
        expect(prefs.read(PrefKeys.selectedProfileIndex), 2);
        expect(repository.active.key, named);
        expect(repository.active.isDefault, isFalse);

        await repository.activate(ProfileKey.defaultProfile);
        expect(prefs.read(PrefKeys.selectedProfileIndex), 0);

        await expectLater(
          repository.activate(const ProfileKey('Kids')),
          throwsArgumentError,
        );
        expect(prefs.read(PrefKeys.selectedProfileIndex), 0);
        await pumpEventQueue();

        expect(seen.map((ProfilesSnapshot s) => s.active.key), <ProfileKey>[
          ProfileKey.defaultProfile,
          named,
          ProfileKey.defaultProfile,
        ]);
        expect(seen.last.profiles, repository.profiles);
      },
    );
  });

  group('create', () {
    test('makes the folder, writes the canvas once, appends the key and makes '
        'the new profile active (flips G-7, Q-P4); an empty stored list gets '
        'Default at index 0 first, as v1.7 did; the new profile is '
        'announced, for the clip index (CONTRACTS §9)', () async {
      final ProfilesRepository repository = await repositoryWith(
        <String, Object>{'profiles': <String>[]},
      );
      final List<ProfileChange> changes = <ProfileChange>[];
      final StreamSubscription<ProfileChange> subscription = repository.changes
          .listen(changes.add);
      addTearDown(subscription.cancel);

      final Profile created = await repository.create(
        displayName: 'Travel',
        orientation: VideoOrientation.portrait,
      );
      await pumpEventQueue();

      expect(created.key, const ProfileKey('Travel'));
      expect(created.orientation, VideoOrientation.portrait);
      expect(
        await Directory(paths.profileVideos(created.key)).exists(),
        isTrue,
      );
      expect(prefs.read(PrefKeys.orientation(created.key)), 'portrait');
      expect(prefs.read(PrefKeys.profiles), <String>['Default', 'Travel']);
      expect(prefs.read(PrefKeys.selectedProfileIndex), 1);
      expect(repository.active, created);
      expect(changes, <ProfileChange>[
        const ProfileAdded(ProfileKey('Travel')),
      ]);
    });

    test('a stored list whose first entry is not "Default" keeps every other '
        'profile, and creating one appends to it (flips G-6)', () async {
      final ProfilesRepository repository = await repositoryWith(
        legacyPrefs(profiles: <String>['Travel', 'Kids']),
      );
      expect(repository.profiles.map((Profile p) => p.key), <ProfileKey>[
        ProfileKey.defaultProfile,
        const ProfileKey('Kids'),
      ]);

      await repository.create(
        displayName: 'Work',
        orientation: VideoOrientation.landscape,
      );

      expect(prefs.read(PrefKeys.profiles), <String>['Travel', 'Kids', 'Work']);
    });

    test('keeps any display name and gives it a folder key under v1.7\'s rule '
        '(Q-P3), never reusing one: not a listed key (in any case), not a '
        'folder already on the phone, not one with a stored canvas', () async {
      await seedClip(paths, const ProfileKey('Kids'), LocalDay(2023, 5, 1));
      final ProfilesRepository repository = await repositoryWith(
        legacyPrefs(
          profiles: <String>['Default', 'travel'],
          orientations: <String, String>{'': 'landscape', 'Work': 'portrait'},
          extra: <String, Object>{
            // Renamed, so "Travel" is free as a display name.
            'profileMeta': '{"travel": {"displayName": "Trips"}}',
          },
        ),
      );

      Future<(String, String)> created(String name) async {
        final Profile profile = await repository.create(
          displayName: name,
          orientation: VideoOrientation.landscape,
        );
        return (profile.key.value, profile.displayName);
      }

      expect(await created('  José '), ('Jose', 'José'));
      expect(await created('Дача'), ('profile_1', 'Дача'));
      expect(await created('Travel'), ('Travel_2', 'Travel'));
      expect(await created('Kids'), ('Kids_2', 'Kids'));
      expect(await created('Work'), ('Work_2', 'Work'));
      expect(
        prefs.read(PrefKeys.orientation(const ProfileKey('Work'))),
        'portrait',
      );
      expect(
        await Directory(
          paths.profileVideos(const ProfileKey('profile_1')),
        ).exists(),
        isTrue,
      );
    });

    test('checks a new name against every name the profiles show now, '
        'Default\'s own and a renamed one included, and refuses a name the '
        'form would reject before touching anything', () async {
      final ProfilesRepository repository = await repositoryWith(
        legacyPrefs(
          profiles: <String>['Default', 'Travel', 'Kids'],
          extra: <String, Object>{
            'profileMeta': jsonEncode(<String, Object>{
              '': <String, String>{'displayName': 'Home'},
              'Travel': <String, String>{'displayName': 'Viagem'},
            }),
          },
        ),
      );

      expect(repository.validateNewName('home'), ProfileNameError.duplicate);
      expect(repository.validateNewName('VIAGEM'), ProfileNameError.duplicate);
      expect(repository.validateNewName('kids'), ProfileNameError.duplicate);
      expect(repository.validateNewName('Default'), ProfileNameError.reserved);
      expect(repository.validateNewName('Travel'), isNull);

      for (final String name in <String>['  ', 'kids', 'default']) {
        await expectLater(
          repository.create(
            displayName: name,
            orientation: VideoOrientation.landscape,
          ),
          throwsArgumentError,
          reason: name,
        );
      }
      expect(prefs.read(PrefKeys.profiles), <String>[
        'Default',
        'Travel',
        'Kids',
      ]);
    });

    test('a folder that cannot be made throws a StorageException and writes '
        'nothing; a refused write never leaves a listed profile without its '
        'canvas', () async {
      // A file where the Profiles folder should be.
      await seedFile(paths, 'Profiles');
      final ProfilesRepository blocked = await repositoryWith(legacyPrefs());

      await expectLater(
        blocked.create(
          displayName: 'Travel',
          orientation: VideoOrientation.portrait,
        ),
        throwsA(isA<StorageException>()),
      );
      expect(prefs.read(PrefKeys.profiles), <String>['Default']);
      expect(
        prefs.contains(PrefKeys.orientation(const ProfileKey('Travel'))),
        isFalse,
      );

      paths = await createTestPaths();
      for (final String refused in <String>['orientation_Travel', 'profiles']) {
        final (PrefsStore store, _) = await openRefusingPrefs(
          legacyPrefs(),
          refused: <String>{refused},
        );
        final ProfilesRepository repository = repositoryOver(store);

        await expectLater(
          repository.create(
            displayName: 'Travel',
            orientation: VideoOrientation.portrait,
          ),
          throwsA(isA<StorageException>()),
          reason: refused,
        );
        expect(prefs.read(PrefKeys.profiles), <String>['Default']);
        expect(repository.active.key, ProfileKey.defaultProfile);
      }
    });
  });

  test('rename changes the display name only: the key, folder, canvas and '
      'list stay (Q-P1); it refuses a name another profile shows, or a '
      'profile that does not exist, but a change of case of its own name is '
      'fine; Default taking its own label again goes back to the label of '
      'the current language', () async {
    String label = 'Default';
    final ProfilesRepository repository = repositoryOver(
      await openLegacyPrefs(
        legacyPrefs(
          profiles: <String>['Default', 'Travel', 'Kids'],
          orientations: <String, String>{'Travel': 'portrait'},
        ),
      ),
      defaultLabel: () => label,
    );
    const ProfileKey travel = ProfileKey('Travel');

    await repository.rename(key: travel, displayName: '  Viagem ✈ ');

    expect(
      repository.profiles[1],
      const Profile(
        key: travel,
        displayName: 'Viagem ✈',
        orientation: VideoOrientation.portrait,
        avatarRelPath: null,
      ),
    );
    expect(prefs.read(PrefKeys.profiles), <String>[
      'Default',
      'Travel',
      'Kids',
    ]);

    for (final (ProfileKey key, String name) in <(ProfileKey, String)>[
      (travel, 'kids'),
      (travel, 'Default'),
      (const ProfileKey('Work'), 'Job'),
    ]) {
      await expectLater(
        repository.rename(key: key, displayName: name),
        throwsArgumentError,
        reason: name,
      );
    }
    await repository.rename(key: travel, displayName: 'VIAGEM ✈');
    expect(repository.profiles[1].displayName, 'VIAGEM ✈');

    await repository.rename(
      key: ProfileKey.defaultProfile,
      displayName: 'Home',
    );
    expect(repository.active.displayName, 'Home');
    await repository.rename(
      key: ProfileKey.defaultProfile,
      displayName: 'default',
    );
    label = 'Padrão';
    expect(repository.active.displayName, 'Padrão');
    expect(
      prefs.read(PrefKeys.profileMeta),
      '{"Travel":{"displayName":"VIAGEM ✈"}}',
    );
  });

  test('a photo is copied into private storage under a new path each time '
      '(no image cache shows the old one), the old file deleted, the name '
      'kept; a previous photo already gone does not fail it; one that '
      'cannot be copied throws and keeps the current photo; removing it '
      'keeps the name and drops an empty record', () async {
    final ProfilesRepository repository = await repositoryWith(
      legacyPrefs(
        profiles: <String>['Default', 'Travel'],
        extra: <String, Object>{
          'profileMeta':
              '{"": {"avatarRelPath": "avatars/lost.jpg"}, '
              '"Travel": {"displayName": "Viagem"}}',
        },
      ),
    );
    const ProfileKey travel = ProfileKey('Travel');
    final File picked = await pickedImage(<int>[1, 2, 3]);

    await repository.setPhoto(
      key: ProfileKey.defaultProfile,
      imagePath: picked.path,
    );

    final String first = repository.active.avatarRelPath!;
    expect(first, startsWith('avatars/'));
    final File stored = File(paths.absoluteFromInternal(first));
    expect(stored.parent.path, paths.avatarsDir);
    expect(await stored.readAsBytes(), <int>[1, 2, 3]);
    expect(await picked.exists(), isTrue);

    clock.advance(const Duration(seconds: 1));
    await repository.setPhoto(
      key: ProfileKey.defaultProfile,
      imagePath: (await pickedImage(<int>[2])).path,
    );

    final String second = repository.active.avatarRelPath!;
    expect(second, isNot(first));
    expect(await File(paths.absoluteFromInternal(second)).readAsBytes(), <int>[
      2,
    ]);
    expect(await stored.exists(), isFalse);

    clock.advance(const Duration(seconds: 1));
    await expectLater(
      repository.setPhoto(
        key: ProfileKey.defaultProfile,
        imagePath: '${paths.temporaryDir}/gone.jpg',
      ),
      throwsA(isA<StorageException>()),
    );
    await expectLater(
      repository.setPhoto(
        key: const ProfileKey('Work'),
        imagePath: (await pickedImage(<int>[4])).path,
      ),
      throwsArgumentError,
    );
    expect(repository.active.avatarRelPath, second);
    expect(
      Directory(
        paths.avatarsDir,
      ).listSync().map((FileSystemEntity e) => e.path),
      <String>[paths.absoluteFromInternal(second)],
    );

    await repository.setPhoto(
      key: travel,
      imagePath: (await pickedImage(<int>[5])).path,
    );
    await repository.removePhoto(travel);
    await repository.removePhoto(ProfileKey.defaultProfile);

    expect(
      repository.profiles.map((Profile p) => (p.displayName, p.avatarRelPath)),
      <(String, String?)>[('Default', null), ('Viagem', null)],
    );
    expect(Directory(paths.avatarsDir).listSync(), isEmpty);
    expect(
      prefs.read(PrefKeys.profileMeta),
      '{"Travel":{"displayName":"Viagem"}}',
    );
  });

  group('delete', () {
    test('deletes every file of the profile through the media store, each in '
        'its own album, then forgets the profile, its canvas and its photo, '
        'and announces it; the name can be reused, with the new '
        'canvas', () async {
      const ProfileKey travel = ProfileKey('Travel');
      final File clip = await seedClip(paths, travel, LocalDay(2024, 1, 5));
      final File nested = await seedClip(
        paths,
        travel,
        LocalDay(2024, 1, 6),
        subFolder: 'rio',
      );
      final File junk = await seedFile(paths, 'Profiles/Travel/notes.txt');
      final File defaultClip = await seedClip(
        paths,
        ProfileKey.defaultProfile,
        LocalDay(2024, 1, 5),
      );
      final ProfilesRepository repository = await repositoryWith(
        legacyPrefs(
          profiles: <String>['Default', 'Travel', 'Kids'],
          orientations: <String, String>{'': 'landscape', 'Travel': 'portrait'},
          extra: <String, Object>{
            'profileMeta': '{"Travel": {"displayName": "Viagem"}}',
          },
        ),
      );
      await repository.setPhoto(
        key: travel,
        imagePath: (await pickedImage(<int>[1])).path,
      );
      final String photo = paths.absoluteFromInternal(
        repository.profiles[1].avatarRelPath!,
      );
      final List<ProfileChange> changes = <ProfileChange>[];
      final StreamSubscription<ProfileChange> changing = repository.changes
          .listen(changes.add);
      addTearDown(changing.cancel);

      final ProfileDeletion result = await repository.delete(travel);
      await pumpEventQueue();

      expect(result.isComplete, isTrue);
      expect(mediaStore.calls.toSet(), <MediaStoreCall>{
        DeleteCall(
          absolutePath: clip.path,
          album: 'OneSecondDiary/Profiles/Travel',
        ),
        DeleteCall(
          absolutePath: nested.path,
          album: 'OneSecondDiary/Profiles/Travel/rio',
        ),
        DeleteCall(
          absolutePath: junk.path,
          album: 'OneSecondDiary/Profiles/Travel',
        ),
      });
      expect(await Directory(paths.profileVideos(travel)).exists(), isFalse);
      expect(await defaultClip.exists(), isTrue);
      expect(await File(photo).exists(), isFalse);
      expect(prefs.read(PrefKeys.profiles), <String>['Default', 'Kids']);
      expect(prefs.contains(PrefKeys.orientation(travel)), isFalse);
      expect(prefs.read(PrefKeys.profileMeta), '{}');
      expect(changes, <ProfileChange>[const ProfileRemoved(travel)]);

      final Profile again = await repository.create(
        displayName: 'Travel',
        orientation: VideoOrientation.landscape,
      );

      expect(again.key, travel);
      expect(prefs.read(PrefKeys.orientation(travel)), 'landscape');
    });

    test('a file the media store refuses to delete is reported and stays; the '
        'profile is still removed (never hidden, B §10.3) but its canvas '
        'kept, so adding the found folder back keeps it portrait', () async {
      const ProfileKey travel = ProfileKey('Travel');
      await seedClip(paths, travel, LocalDay(2024, 1, 5));
      final File refused = await seedClip(paths, travel, LocalDay(2024, 1, 6));
      mediaStore = RefusingMediaStoreGateway.onDisk(
        paths,
        refusedDeletes: <String>{refused.path},
      );
      final ProfilesRepository repository = await repositoryWith(
        legacyPrefs(
          profiles: <String>['Default', 'Travel'],
          orientations: <String, String>{'': 'landscape', 'Travel': 'portrait'},
        ),
      );

      final ProfileDeletion result = await repository.delete(travel);

      expect(
        result,
        const ProfileDeletion(
          keptFiles: <String>['Profiles/Travel/2024-01-06.mp4'],
        ),
      );
      expect(await refused.exists(), isTrue);
      expect(prefs.read(PrefKeys.profiles), <String>['Default']);
      expect(
        log.lines,
        contains(
          allOf(
            startsWith('[WARNING]'),
            contains('[PROFILES]'),
            contains('Profiles/Travel/2024-01-06.mp4'),
          ),
        ),
      );

      expect(await repository.foundOnThisPhone(), <ProfileKey>[travel]);
      await repository.addFound(travel);

      expect(prefs.read(PrefKeys.orientation(travel)), 'portrait');
      expect(repository.profiles.last.orientation, VideoOrientation.portrait);
    });

    test('keeps the same profile active: deleting the active one falls back '
        'to Default, one above it shifts the index, one below leaves it '
        '(a1e8e72)', () async {
      Future<(int, ProfileKey)> afterDeleting(
        String deleted,
        int selected,
      ) async {
        final ProfilesRepository repository = await repositoryWith(
          legacyPrefs(
            profiles: <String>['Default', 'A', 'B', 'C'],
            selectedProfileIndex: selected,
          ),
        );
        await repository.delete(ProfileKey(deleted));
        return (
          prefs.read(PrefKeys.selectedProfileIndex),
          repository.active.key,
        );
      }

      expect(await afterDeleting('B', 2), (0, ProfileKey.defaultProfile));
      expect(await afterDeleting('A', 3), (2, const ProfileKey('C')));
      expect(await afterDeleting('C', 1), (1, const ProfileKey('A')));
      // A stale index read as Default stays Default.
      expect(await afterDeleting('A', 9), (0, ProfileKey.defaultProfile));
    });

    // Older installs accepted any name. ".." leads out of Profiles/, "/"
    // resolves to all of Profiles/, "Work/" and "/Work" to another profile's
    // folder: deleting one would delete those.
    test('never deletes Default, a profile that is not listed, or a v1.5 key '
        'with a ".." or an empty segment, so no other profile loses its '
        'clips', () async {
      final File defaultClip = await seedClip(
        paths,
        ProfileKey.defaultProfile,
        LocalDay(2024, 1, 5),
      );
      final File workClip = await seedClip(
        paths,
        const ProfileKey('Work'),
        LocalDay(2024, 1, 5),
      );
      final File orphan = await seedClip(
        paths,
        const ProfileKey('Old'),
        LocalDay(2024, 1, 5),
      );
      final List<String> v15Keys = <String>[
        '..',
        '/',
        'Work/',
        '/Work',
        'Mom//Dad',
      ];
      final ProfilesRepository repository = await repositoryWith(
        legacyPrefs(profiles: <String>['Default', 'Work', ...v15Keys]),
      );

      for (final ProfileKey key in <ProfileKey>[
        ProfileKey.defaultProfile,
        const ProfileKey('Old'),
        for (final String key in v15Keys) ProfileKey(key),
      ]) {
        await expectLater(
          repository.delete(key),
          throwsArgumentError,
          reason: key.value,
        );
      }

      expect(mediaStore.calls, isEmpty);
      for (final File clip in <File>[defaultClip, workClip, orphan]) {
        expect(await clip.exists(), isTrue, reason: clip.path);
      }
      expect(prefs.read(PrefKeys.profiles), <String>[
        'Default',
        'Work',
        ...v15Keys,
      ]);
    });

    test('a later profile named "Default" deletes only Profiles/Default/, '
        'never the real Default\'s clips (Z-03, Z MB-05)', () async {
      const ProfileKey named = ProfileKey('Default');
      final File namedClip = await seedClip(paths, named, LocalDay(2024, 1, 5));
      final File defaultClip = await seedClip(
        paths,
        ProfileKey.defaultProfile,
        LocalDay(2024, 1, 5),
      );
      final ProfilesRepository repository = await repositoryWith(
        legacyPrefs(
          profiles: <String>['Default', 'Travel', 'Default'],
          selectedProfileIndex: 2,
        ),
      );
      expect(repository.active.key, named);

      await repository.delete(named);

      expect(mediaStore.calls, <MediaStoreCall>[
        DeleteCall(
          absolutePath: namedClip.path,
          album: 'OneSecondDiary/Profiles/Default',
        ),
      ]);
      expect(await defaultClip.exists(), isTrue);
      expect(prefs.read(PrefKeys.profiles), <String>['Default', 'Travel']);
      expect(repository.active.key, ProfileKey.defaultProfile);
    });

    test('a folder that cannot be read throws a StorageException and keeps '
        'the profile', () async {
      const ProfileKey travel = ProfileKey('Travel');
      await seedClip(paths, travel, LocalDay(2024, 1, 5));
      final String folder = paths.profileVideos(travel);
      Process.runSync('chmod', <String>['000', folder]);
      addTearDown(() => Process.runSync('chmod', <String>['755', folder]));
      try {
        Directory(folder).listSync();
        markTestSkipped('This user can read a mode-000 folder (root?).');
        return;
      } on FileSystemException {
        // Unreadable, as intended.
      }
      final ProfilesRepository repository = await repositoryWith(
        legacyPrefs(profiles: <String>['Default', 'Travel']),
      );

      await expectLater(
        repository.delete(travel),
        throwsA(isA<StorageException>()),
      );

      expect(prefs.read(PrefKeys.profiles), <String>['Default', 'Travel']);
    });
  });

  group('found on this phone', () {
    // Older installs accepted any name: a listed "Mom/Dad" lives in
    // Profiles/Mom/Dad/, so Profiles/Mom/ holds its clips. Offering "Mom"
    // would make a second profile of them, and deleting that one would
    // delete Mom/Dad's clips.
    test('offers Profiles/ folders holding clips that the list does not name, '
        'never the parent folder of a listed v1.5 key with a "/", and '
        'registers nothing by itself (Q-P5)', () async {
      await seedClip(paths, const ProfileKey('Travel'), LocalDay(2024, 1, 5));
      await seedClip(paths, const ProfileKey('Kids'), LocalDay(2024, 1, 5));
      await seedClip(paths, const ProfileKey('Old'), LocalDay(2021, 3, 1));
      await seedClip(
        paths,
        const ProfileKey('Trip'),
        LocalDay(2022, 7, 1),
        subFolder: 'rio',
      );
      await seedClip(paths, const ProfileKey('Mom/Dad'), LocalDay(2024, 1, 5));
      await Directory('${paths.videos}Profiles/Empty').create();
      await seedFile(paths, 'Profiles/Junk/notes.txt');
      await seedFile(paths, 'Profiles/Junk/2024-01-05_123456.mp4');
      final List<String> listed = <String>[
        'Default',
        'Travel',
        'kids',
        'Mom/Dad',
      ];
      final ProfilesRepository repository = await repositoryWith(
        legacyPrefs(profiles: listed),
      );

      expect(await repository.foundOnThisPhone(), <ProfileKey>[
        const ProfileKey('Old'),
        const ProfileKey('Trip'),
      ]);
      expect(prefs.read(PrefKeys.profiles), listed);
    });

    test(
      'addFound lists the folder as it is: landscape unless it kept a '
      'canvas, not active, announced; adding it again changes nothing',
      () async {
        await seedClip(paths, const ProfileKey('Old'), LocalDay(2021, 3, 1));
        final ProfilesRepository repository = await repositoryWith(
          legacyPrefs(profiles: <String>['Default', 'Travel']),
        );
        final List<ProfileChange> changes = <ProfileChange>[];
        final StreamSubscription<ProfileChange> subscription = repository
            .changes
            .listen(changes.add);
        addTearDown(subscription.cancel);

        await repository.addFound(const ProfileKey('Old'));
        await repository.addFound(const ProfileKey('Old'));
        await pumpEventQueue();

        expect(prefs.read(PrefKeys.profiles), <String>[
          'Default',
          'Travel',
          'Old',
        ]);
        expect(
          prefs.contains(PrefKeys.orientation(const ProfileKey('Old'))),
          isFalse,
        );
        expect(
          repository.profiles.last.orientation,
          VideoOrientation.landscape,
        );
        expect(repository.active.key, ProfileKey.defaultProfile);
        expect(await repository.foundOnThisPhone(), isEmpty);
        expect(changes, <ProfileChange>[const ProfileAdded(ProfileKey('Old'))]);
      },
    );
  });

  group('format (decision D29)', () {
    const ProfileKey travel = ProfileKey('Travel');
    final ClipFormat ultraPortrait = ClipFormat.parse(
      '2160p60-hevc-stereo-sdr',
      VideoOrientation.portrait,
    )!;

    test('a profile reads its clipFormat_ on its canvas; absent, or not a '
        'canonical string, reads as legacy on that canvas', () async {
      final ProfilesRepository repository = await repositoryWith(
        legacyPrefs(
          profiles: <String>['Default', 'Travel', 'Kids'],
          orientations: <String, String>{'': 'landscape', 'Travel': 'portrait'},
          extra: <String, Object>{
            'clipFormat_Travel': '2160p60-hevc-stereo-sdr',
            'clipFormat_Kids': '8k-whatever',
          },
        ),
      );

      expect(repository.profiles.map((Profile p) => p.format), <ClipFormat>[
        const ClipFormat.legacy(VideoOrientation.landscape),
        ultraPortrait,
        const ClipFormat.legacy(VideoOrientation.landscape),
      ]);
      expect(
        repository.profiles[1].format.orientation,
        VideoOrientation.portrait,
      );
    });

    test('create writes clipFormat_<key> beside orientation_<key> (on the '
        'canvas chosen, whatever the format\'s), legacy when none is '
        'given; the key stays free of a stored format', () async {
      final ProfilesRepository repository = await repositoryWith(
        legacyPrefs(
          extra: <String, Object>{'clipFormat_Work': '1080p30-h264-mono-sdr'},
        ),
      );

      final Profile created = await repository.create(
        displayName: 'Travel',
        orientation: VideoOrientation.portrait,
        format: ultraPortrait.withOrientation(VideoOrientation.landscape),
      );
      final Profile plain = await repository.create(
        displayName: 'Kids',
        orientation: VideoOrientation.landscape,
      );
      final Profile work = await repository.create(
        displayName: 'Work',
        orientation: VideoOrientation.landscape,
      );

      expect(created.format, ultraPortrait);
      expect(
        prefs.read(PrefKeys.clipFormat(travel)),
        '2160p60-hevc-stereo-sdr',
      );
      expect(prefs.read(PrefKeys.orientation(travel)), 'portrait');
      expect(plain.format, const ClipFormat.legacy(VideoOrientation.landscape));
      expect(
        prefs.read(PrefKeys.clipFormat(const ProfileKey('Kids'))),
        '1080p30-h264-mono-sdr',
      );
      expect(work.key, const ProfileKey('Work_2'));
    });

    test('ensureFormat writes a format once: a stored one is kept and '
        'returned, on the profile\'s own canvas; a profile not listed is '
        'refused', () async {
      final ProfilesRepository repository = await repositoryWith(
        legacyPrefs(orientations: <String, String>{'': 'portrait'}),
      );

      final ClipFormat first = await repository.ensureFormat(
        ProfileKey.defaultProfile,
        ClipFormatPreset.high.format(VideoOrientation.landscape),
      );
      final ClipFormat second = await repository.ensureFormat(
        ProfileKey.defaultProfile,
        ClipFormatPreset.ultra.format(VideoOrientation.landscape),
      );

      expect(first, ClipFormatPreset.high.format(VideoOrientation.portrait));
      expect(second, first);
      expect(
        prefs.read(PrefKeys.clipFormat(ProfileKey.defaultProfile)),
        '1440p30-hevc-stereo-sdr',
      );
      expect(repository.active.format, first);
      await expectLater(
        repository.ensureFormat(travel, first),
        throwsArgumentError,
      );
    });

    test(
      'delete removes the format with the canvas when no file was kept',
      () async {
        await seedClip(paths, travel, LocalDay(2023, 5, 1));
        final ProfilesRepository repository = await repositoryWith(
          legacyPrefs(
            profiles: <String>['Default', 'Travel'],
            orientations: <String, String>{
              '': 'landscape',
              'Travel': 'portrait',
            },
            extra: <String, Object>{
              'clipFormat_Travel': '2160p60-hevc-stereo-sdr',
            },
          ),
        );

        await repository.delete(travel);

        expect(prefs.contains(PrefKeys.orientation(travel)), isFalse);
        expect(prefs.contains(PrefKeys.clipFormat(travel)), isFalse);
      },
    );

    test('addFound reads a found folder\'s canvas and format off its newest '
        'clips (a reinstall brings a portrait HEVC profile back as such), '
        'written once; a stored canvas is kept; unreadable clips, or no '
        'reader, write nothing (landscape, legacy)', () async {
      await seedClip(paths, const ProfileKey('Old'), LocalDay(2021, 3, 1));
      await seedClip(paths, const ProfileKey('Kept'), LocalDay(2021, 3, 1));
      await seedClip(paths, const ProfileKey('Blank'), LocalDay(2021, 3, 1));
      final FakeProfileClipFacts facts = FakeProfileClipFacts(
        facts: <ProfileKey, List<ClipMeta>>{
          const ProfileKey('Old'): <ClipMeta>[
            clipFacts(
              width: 2160,
              height: 3840,
              codec: 'hevc',
              fps: 60,
              channels: 2,
            ),
          ],
          const ProfileKey('Kept'): <ClipMeta>[
            clipFacts(width: 1080, height: 1920, codec: 'hevc'),
          ],
        },
      );
      final ProfilesRepository repository = repositoryOver(
        await openLegacyPrefs(
          legacyPrefs(
            orientations: <String, String>{
              '': 'landscape',
              'Kept': 'landscape',
            },
          ),
        ),
        clipFacts: facts,
      );

      await repository.addFound(const ProfileKey('Old'));
      await repository.addFound(const ProfileKey('Kept'));
      await repository.addFound(const ProfileKey('Blank'));

      expect(
        prefs.read(PrefKeys.orientation(const ProfileKey('Old'))),
        'portrait',
      );
      expect(
        prefs.read(PrefKeys.clipFormat(const ProfileKey('Old'))),
        '2160p60-hevc-stereo-sdr',
      );
      expect(repository.profiles[1].format, ultraPortrait);
      expect(
        prefs.read(PrefKeys.orientation(const ProfileKey('Kept'))),
        'landscape',
      );
      expect(
        prefs.contains(PrefKeys.clipFormat(const ProfileKey('Kept'))),
        isFalse,
      );
      expect(
        prefs.contains(PrefKeys.orientation(const ProfileKey('Blank'))),
        isFalse,
      );
      expect(
        repository.profiles.last.format,
        const ClipFormat.legacy(VideoOrientation.landscape),
      );
      expect(facts.asked, <ProfileKey>[
        const ProfileKey('Old'),
        const ProfileKey('Blank'),
      ]);
    });
  });
}
