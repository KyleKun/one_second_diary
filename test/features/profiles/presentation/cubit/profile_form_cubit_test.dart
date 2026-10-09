// "Edit profile" and "New profile": the form behind both sheets, over the
// real ProfilesRepository on a temporary diary. The display name may use
// any script; the folder key never changes; the canvas is written once; a
// new profile becomes the active one.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/profiles/data/device_media_profile_store.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_deletion.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/domain/profile_name_error.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_state.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_target.dart';

import '../../../../shared/fakes/fake_app_info_gateway.dart';
import '../../../../shared/fakes/fake_picker_gateway.dart';
import '../../../../shared/harness/seeds.dart';
import '../../../../support/support.dart';
import '../../../../support/track_1c/refusing_media_store_gateway.dart';
import '../../../../support/track_1c/refusing_shared_preferences.dart';

void main() {
  late AppPaths paths;
  late FakeMediaStoreGateway mediaStore;
  late FakePickerGateway picker;
  late MemoryLogSink log;
  late ProfilesRepository profiles;
  late DeviceMediaProfileStore deviceProfile;

  setUp(() async {
    paths = await createTestPaths();
    mediaStore = FakeMediaStoreGateway.onDisk(paths);
    picker = FakePickerGateway();
    log = MemoryLogSink();
  });

  DeviceMediaProfileStore deviceProfileOver(PrefsStore store) =>
      DeviceMediaProfileStore(
        prefs: store,
        appInfo: FakeAppInfoGateway(),
        deviceInfo: FakeDeviceInfoGateway(),
        logger: memoryLogger(log),
      );

  /// What the photo picker hands over: a small image in the cache.
  Future<String> pickedImage(AppPaths paths) async {
    final File file = File('${paths.temporaryDir}/image_picker_1.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(onePixelPng);
    return file.path;
  }

  Future<ProfileFormCubit> formOver(
    ProfileFormTarget target, {
    Map<String, Object>? prefs,
    PrefsStore? store,
  }) async {
    final PrefsStore opened = store ?? await openLegacyPrefs(prefs!);
    profiles = ProfilesRepository(
      prefs: opened,
      paths: paths,
      mediaStore: mediaStore,
      clock: FakeClock(DateTime(2024, 1, 5, 10)),
      logger: memoryLogger(log),
      defaultLabel: () => 'Default',
    );
    deviceProfile = deviceProfileOver(opened);
    final ProfileFormCubit cubit = ProfileFormCubit(
      target: target,
      profiles: profiles,
      picker: picker,
      deviceProfile: deviceProfile,
      isIOS: false,
      logger: memoryLogger(log),
    );
    addTearDown(cubit.close);
    await pumpEventQueue();
    return cubit;
  }

  group('a new profile (S6)', () {
    test('starts empty, with no orientation chosen (the choice is permanent) '
        'and no error shown yet; the name is checked as it is typed (a '
        'duplicate in any case, the Default label, a name cleared after '
        'typing); Create needs a valid name and an orientation', () async {
      final ProfileFormCubit form = await formOver(
        const NewProfileForm(),
        prefs: legacyPrefs(profiles: <String>['Default', 'Travel']),
      );
      expect(form.state.name, '');
      expect(form.state.orientation, isNull);
      expect(form.state.shownNameError, isNull);
      expect(form.state.canSave, isFalse);

      for (final (String name, ProfileNameError? error)
          in <(String, ProfileNameError?)>[
            ('  travel ', ProfileNameError.duplicate),
            ('default', ProfileNameError.reserved),
            ('   ', ProfileNameError.empty),
            ('Дача 🌲', null),
          ]) {
        form.nameChanged(name);
        expect(form.state.shownNameError, error, reason: name);
      }
      expect(form.state.canSave, isFalse);

      form.orientationPicked(VideoOrientation.portrait);

      expect(form.state.orientation, VideoOrientation.portrait);
      expect(form.state.canSave, isTrue);
    });

    test(
      'Create stores the trimmed name with its canvas and the photo picked '
      'for it, in private storage, and makes it the active profile',
      () async {
        final ProfileFormCubit form = await formOver(
          const NewProfileForm(),
          prefs: legacyPrefs(),
        );
        picker.photoAnswers.add(Picked(await pickedImage(paths)));
        final List<ProfileFormStatus> statuses = <ProfileFormStatus>[];
        form.stream.listen((ProfileFormState s) => statuses.add(s.status));

        await form.pickPhoto(PhotoOrigin.gallery);
        form
          ..nameChanged('  Viagem ✈ ')
          ..orientationPicked(VideoOrientation.portrait);
        await form.save();
        await pumpEventQueue();

        final Profile created = profiles.active;
        expect(created.displayName, 'Viagem ✈');
        expect(created.orientation, VideoOrientation.portrait);
        expect(form.state.created, created);
        expect(picker.photoRequests, <PhotoOrigin>[PhotoOrigin.gallery]);
        expect(created.avatarRelPath, startsWith('avatars/'));
        expect(
          File(paths.absoluteFromInternal(created.avatarRelPath!)).existsSync(),
          isTrue,
        );
        expect(
          statuses,
          containsAllInOrder(<ProfileFormStatus>[
            ProfileFormStatus.saving,
            ProfileFormStatus.saved,
          ]),
        );
      },
    );

    test('a refused Create says so every time and lists nothing; a photo '
        'that can\'t be stored after Create leaves the profile created and '
        'active, and is logged; the photo picker asks for the camera or the '
        'gallery, and a cancel, a refused permission (every time) or an '
        'unusable pick each say so', () async {
      final (PrefsStore store, _) = await openRefusingPrefs(
        legacyPrefs(),
        refused: <String>{'profiles'},
      );
      final ProfileFormCubit refused = await formOver(
        const NewProfileForm(),
        store: store,
      );
      final List<ProfileFormStatus> statuses = <ProfileFormStatus>[];
      refused.stream.listen((ProfileFormState s) => statuses.add(s.status));
      refused
        ..nameChanged('Kids')
        ..orientationPicked(VideoOrientation.landscape);

      await refused.save();
      await refused.save();
      await pumpEventQueue();

      expect(
        statuses.where((ProfileFormStatus s) => s != ProfileFormStatus.editing),
        <ProfileFormStatus>[
          ProfileFormStatus.saving,
          ProfileFormStatus.saveFailed,
          ProfileFormStatus.saving,
          ProfileFormStatus.saveFailed,
        ],
      );
      expect(profiles.profiles.map((Profile p) => p.displayName), <String>[
        'Default',
      ]);
      expect(log.lines, contains(contains('[PROFILES] Could not save')));

      final ProfileFormCubit form = await formOver(
        const NewProfileForm(),
        prefs: legacyPrefs(),
      );
      picker.photoAnswers.add(Picked('${paths.temporaryDir}/gone.png'));

      await form.pickPhoto(PhotoOrigin.camera);
      form
        ..nameChanged('Kids')
        ..orientationPicked(VideoOrientation.landscape);
      await form.save();

      expect(form.state.status, ProfileFormStatus.saved);
      expect(profiles.active.displayName, 'Kids');
      expect(profiles.active.avatarRelPath, isNull);
      expect(
        log.lines,
        contains(allOf(startsWith('[WARNING]'), contains('photo'))),
      );

      // The photo picker: a cancel changes nothing; a refused permission
      // says where the photo was to come from, every time; an unusable pick
      // says so too.
      picker.photoRequests.clear();
      final ProfileFormCubit picking = await formOver(
        const NewProfileForm(),
        prefs: legacyPrefs(),
      );

      await picking.pickPhoto(PhotoOrigin.camera);

      expect(picking.state.pickedPhoto, isNull);
      expect(picking.state.status, ProfileFormStatus.editing);

      final List<ProfileFormStatus> picks = <ProfileFormStatus>[];
      picking.stream.listen((ProfileFormState s) => picks.add(s.status));
      picker.photoAnswers.addAll(<PickerOutcome>[
        const PickDenied(),
        const PickDenied(),
        const PickUnavailable(),
      ]);

      await picking.pickPhoto(PhotoOrigin.camera);
      expect(picking.state.deniedOrigin, PhotoOrigin.camera);
      await picking.pickPhoto(PhotoOrigin.gallery);
      expect(picking.state.deniedOrigin, PhotoOrigin.gallery);
      await picking.pickPhoto(PhotoOrigin.gallery);
      await pumpEventQueue();

      expect(picker.photoRequests, <PhotoOrigin>[
        PhotoOrigin.camera,
        PhotoOrigin.camera,
        PhotoOrigin.gallery,
        PhotoOrigin.gallery,
      ]);
      expect(picks, <ProfileFormStatus>[
        ProfileFormStatus.pickingPhoto,
        ProfileFormStatus.photoDenied,
        ProfileFormStatus.pickingPhoto,
        ProfileFormStatus.photoDenied,
        ProfileFormStatus.pickingPhoto,
        ProfileFormStatus.photoUnavailable,
      ]);
    });
  });

  group('an existing profile (S5)', () {
    final List<ProfileSeed> travel = <ProfileSeed>[
      const ProfileSeed(
        'Travel',
        orientation: 'portrait',
        displayName: 'Viagem ✈',
        withPhoto: true,
      ),
    ];

    Future<ProfileFormCubit> editing(ProfileKey key) async {
      await seedProfilePhotos(paths, travel);
      return formOver(
        EditProfileForm(key),
        prefs: prefsWithProfiles(travel, selected: 1),
      );
    }

    test('Save renames it: only the display name changes, the folder key '
        'stays (Q-P1); it shows its name, photo and fixed canvas; its own '
        'name is no duplicate', () async {
      final ProfileFormCubit form = await editing(const ProfileKey('Travel'));
      expect(form.state.name, 'Viagem ✈');
      expect(form.state.orientation, VideoOrientation.portrait);
      expect(form.state.storedPhoto, 'avatars/seed-Travel.png');
      expect(form.state.canSave, isTrue);
      expect(form.state.canDelete, isTrue);

      form.nameChanged('VIAGEM ✈');
      expect(form.state.shownNameError, isNull);
      form.nameChanged('default');
      expect(form.state.shownNameError, ProfileNameError.reserved);
      form.nameChanged(' Trips ');
      await form.save();

      expect(form.state.status, ProfileFormStatus.saved);
      expect(
        profiles.profiles.map((Profile p) => (p.key, p.displayName)),
        <(ProfileKey, String)>[
          (ProfileKey.defaultProfile, 'Default'),
          (const ProfileKey('Travel'), 'Trips'),
        ],
      );
    });

    test(
      'a new photo replaces the old one on Save; Remove photo shows the '
      'initial again, and Save deletes the photo and keeps the name',
      () async {
        final ProfileFormCubit form = await editing(const ProfileKey('Travel'));
        picker.photoAnswers.add(Picked(await pickedImage(paths)));

        await form.pickPhoto(PhotoOrigin.gallery);
        await form.save();

        final String? photo = profiles.profiles.last.avatarRelPath;
        expect(photo, isNot('avatars/seed-Travel.png'));
        expect(File(paths.absoluteFromInternal(photo!)).existsSync(), isTrue);
        expect(
          File('${paths.internal}/avatars/seed-Travel.png').existsSync(),
          isFalse,
        );

        final ProfileFormCubit again = ProfileFormCubit(
          target: const EditProfileForm(ProfileKey('Travel')),
          profiles: profiles,
          picker: picker,
          deviceProfile: deviceProfile,
          isIOS: false,
          logger: memoryLogger(log),
        );
        addTearDown(again.close);
        again.removePhoto();
        expect(again.state.hasPhoto, isFalse);
        await again.save();

        expect(profiles.profiles.last.avatarRelPath, isNull);
        expect(profiles.profiles.last.displayName, 'Viagem ✈');
        expect(File(paths.absoluteFromInternal(photo)).existsSync(), isFalse);
      },
    );
  });

  group('deleting (S5)', () {
    const ProfileKey travel = ProfileKey('Travel');

    Future<ProfileFormCubit> deleting({PrefsStore? store}) async {
      await seedClip(paths, travel, LocalDay(2024, 1, 5));
      await seedClip(paths, travel, LocalDay(2024, 1, 6));
      return formOver(
        const EditProfileForm(travel),
        store:
            store ??
            await openLegacyPrefs(
              prefsWithProfiles(<ProfileSeed>[
                const ProfileSeed('Travel'),
              ], selected: 1),
            ),
      );
    }

    test('deletes the profile with its clips, Default active again when it '
        'was this one; clips the phone keeps (declined consent for a '
        'previous install\'s clips) are reported, and the profile goes '
        'anyway', () async {
      final ProfileFormCubit form = await deleting();
      final List<ProfileFormStatus> statuses = <ProfileFormStatus>[];
      form.stream.listen((ProfileFormState s) => statuses.add(s.status));

      await form.delete();
      await pumpEventQueue();

      expect(statuses, <ProfileFormStatus>[
        ProfileFormStatus.deleting,
        ProfileFormStatus.deleted,
      ]);
      expect(form.state.deletion, const ProfileDeletion(keptFiles: <String>[]));
      expect(profiles.profiles.map((Profile p) => p.key), <ProfileKey>[
        ProfileKey.defaultProfile,
      ]);
      expect(profiles.active.key, ProfileKey.defaultProfile);
      expect(Directory(paths.profileVideos(travel)).existsSync(), isFalse);

      paths = await createTestPaths();
      mediaStore = RefusingMediaStoreGateway.onDisk(
        paths,
        refusedDeletes: <String>{
          paths.absoluteFromVideos('Profiles/Travel/2024-01-06.mp4'),
        },
      );
      final ProfileFormCubit kept = await deleting();

      await kept.delete();

      expect(kept.state.status, ProfileFormStatus.deleted);
      expect(
        kept.state.deletion,
        const ProfileDeletion(
          keptFiles: <String>['Profiles/Travel/2024-01-06.mp4'],
        ),
      );
      expect(profiles.profiles, hasLength(1));
    });

    test(
      'Default is never deleted; a refused delete says so every time',
      () async {
        final ProfileFormCubit defaultForm = await formOver(
          const EditProfileForm(ProfileKey.defaultProfile),
          prefs: legacyPrefs(),
        );
        expect(defaultForm.state.name, 'Default');
        expect(defaultForm.state.canDelete, isFalse);

        await defaultForm.delete();

        expect(defaultForm.state.status, ProfileFormStatus.editing);
        expect(profiles.profiles, hasLength(1));

        final (PrefsStore store, _) = await openRefusingPrefs(
          prefsWithProfiles(<ProfileSeed>[const ProfileSeed('Travel')]),
          refused: <String>{'profiles'},
        );
        final ProfileFormCubit form = await deleting(store: store);
        final List<ProfileFormStatus> statuses = <ProfileFormStatus>[];
        form.stream.listen((ProfileFormState s) => statuses.add(s.status));

        await form.delete();
        await form.delete();
        await pumpEventQueue();

        expect(statuses, <ProfileFormStatus>[
          ProfileFormStatus.deleting,
          ProfileFormStatus.deleteFailed,
          ProfileFormStatus.deleting,
          ProfileFormStatus.deleteFailed,
        ]);
        expect(log.lines, contains(contains('[PROFILES] Could not delete')));
      },
    );
  });

  group('quality (decision D29)', () {
    final ClipFormat ultraPortrait = ClipFormatPreset.ultra.format(
      VideoOrientation.portrait,
    );

    test('a new profile has no quality until its canvas is chosen; then the '
        'phone check\'s pick on that canvas (Standard without a check), or '
        'the user\'s own pick, which follows a canvas change; Create writes '
        'it with the profile', () async {
      final ProfileFormCubit form = await formOver(
        const NewProfileForm(),
        prefs: legacyPrefs(),
      );
      expect(form.state.format, isNull);
      expect(form.state.recommendation, isNotNull);
      expect(form.state.recommendation!.checked, isFalse);

      form.orientationPicked(VideoOrientation.portrait);
      expect(
        form.state.format,
        ClipFormatPreset.standard.format(VideoOrientation.portrait),
      );

      form.formatPicked(
        ultraPortrait.withOrientation(VideoOrientation.landscape),
      );
      expect(form.state.format, ultraPortrait);
      form.orientationPicked(VideoOrientation.landscape);
      expect(
        form.state.format,
        ultraPortrait.withOrientation(VideoOrientation.landscape),
      );
      form.orientationPicked(VideoOrientation.portrait);

      form.nameChanged('Travel');
      await form.save();

      expect(form.state.status, ProfileFormStatus.saved);
      expect(form.state.created!.format, ultraPortrait);
      expect(profiles.active.format, ultraPortrait);
    });

    test('with a current phone check the pick is pre-selected for the '
        'canvas; an existing profile shows its own format, fixed', () async {
      final PrefsStore store = await openLegacyPrefs(
        legacyPrefs(
          profiles: <String>['Default', 'Travel'],
          orientations: <String, String>{'': 'landscape', 'Travel': 'portrait'},
          extra: <String, Object>{
            'clipFormat_Travel': '1440p30-hevc-stereo-sdr',
          },
        ),
      );
      await deviceProfileOver(store).write(
        DeviceMediaProfile(
          checkedAt: DateTime(2026, 10, 7),
          appVersion: '2.0.0',
          deviceModel: 'Google Pixel 8',
          encode: <String, EncodeResult>{
            '1080p30-h264-mono-sdr': const EncodeResult(
              ok: true,
              realtimeFactor: 3,
            ),
            '1080p30-hevc-mono-sdr': const EncodeResult(
              ok: true,
              realtimeFactor: 2,
            ),
          },
          camera: const CameraCapability(
            maxTier: ResolutionTier.p1080,
            fps60: false,
            channels: 2,
          ),
          freeBytes: 64 * 1000 * 1000 * 1000,
        ),
      );
      final ProfileFormCubit form = await formOver(
        const NewProfileForm(),
        store: store,
      );
      expect(form.state.recommendation!.checked, isTrue);

      form.orientationPicked(VideoOrientation.portrait);

      expect(
        form.state.format,
        ClipFormatPreset.smallerFiles.format(VideoOrientation.portrait),
      );

      final ProfileFormCubit edit = await formOver(
        const EditProfileForm(ProfileKey('Travel')),
        store: store,
      );
      expect(
        edit.state.format,
        ClipFormatPreset.high.format(VideoOrientation.portrait),
      );
      edit.formatPicked(ultraPortrait);
      expect(
        edit.state.format,
        ClipFormatPreset.high.format(VideoOrientation.portrait),
        reason: 'never changes',
      );
    });
  });
}
