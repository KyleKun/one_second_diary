import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/permissions/access_outcome.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/onboarding/domain/onboarding_permission.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/domain/profiles_snapshot.dart';

import '../../../../shared/fakes/fake_profile_clip_facts.dart';
import '../../../../support/support.dart';
import '../../support/onboarding_world.dart';

final LocalDay january5 = LocalDay(2024, 1, 5);

void main() {
  late OnboardingWorld world;

  setUp(() async {
    world = await OnboardingWorld.create();
  });

  OnboardingCubit open() {
    final OnboardingCubit cubit = world.cubit();
    addTearDown(cubit.close);
    return cubit;
  }

  /// Opens the flow at the orientation step with [orientation] picked.
  Future<OnboardingCubit> onO4(VideoOrientation orientation) async {
    final OnboardingCubit cubit = open();
    await cubit.leaveIntro();
    cubit.pickOrientation(orientation);
    return cubit;
  }

  /// Opens the flow at the permissions step, [orientation] picked on the orientation step.
  Future<OnboardingCubit> onO5(VideoOrientation orientation) async {
    final OnboardingCubit cubit = await onO4(orientation);
    await cubit.goToPermissions();
    return cubit;
  }

  Map<AppPermission, AppPermissionStatus> access() =>
      Map<AppPermission, AppPermissionStatus>.of(world.permissions.statuses);

  test('opens on the intro carousel with nothing chosen (D14), knowing the '
      'day it opened (O1\'s polaroid labels)', () {
    final OnboardingCubit cubit = open();

    expect(cubit.state.step, OnboardingStep.intro);
    expect(cubit.state.orientation, isNull);
    expect(cubit.state.status, OnboardingStatus.choosing);
    expect(cubit.state.today, january5);
    expect(cubit.state.permissions, isEmpty);
  });

  group('leaving the intro (Next on O3)', () {
    // A folder with no Default clip (a movie left behind) is no reason to
    // skip the orientation step.
    test('a fresh install, or a diary folder without Default clips, goes on '
        'to O4 and asks nothing yet', () async {
      final OnboardingCubit fresh = open();
      await fresh.leaveIntro();

      expect(fresh.state.step, OnboardingStep.orientation);
      expect(world.permissions.requestedTogether, isEmpty);

      world = await OnboardingWorld.create(diaryFolder: true);
      world.permissions.statuses.addAll(<AppPermission, AppPermissionStatus>{
        AppPermission.photos: AppPermissionStatus.granted,
        AppPermission.videos: AppPermissionStatus.granted,
      });
      await seedFile(world.paths, 'Movies/OSD-Movie-1-2024-01-05.mp4');
      final OnboardingCubit leftovers = open();

      await leftovers.leaveIntro();

      expect(leftovers.state.step, OnboardingStep.orientation);
      expect(leftovers.state.status, OnboardingStatus.choosing);
    });

    // A reinstall keeps the canvas every earlier clip was made for, and the
    // flow must not offer another one. A reinstall's clips cannot be listed
    // at launch without access to the gallery; once the user has answered,
    // the diary shows them.
    test('clips of a previous install fix the Default profile to landscape, '
        'skip O4 for the permissions step, and are listed again once the '
        'diary is made', () async {
      world = await OnboardingWorld.create(diaryFolder: true);
      await seedClip(world.paths, ProfileKey.defaultProfile, january5);
      await seedClip(
        world.paths,
        ProfileKey.defaultProfile,
        LocalDay(2024, 1, 6),
      );
      final OnboardingCubit cubit = open();

      await cubit.leaveIntro();

      expect(cubit.state.step, OnboardingStep.permissions);
      expect(cubit.state.status, OnboardingStatus.choosing);
      expect(world.prefs.read(PrefKeys.showIntro), isNull);

      await cubit.startDiary();

      expect(cubit.state.status, OnboardingStatus.done);
      expect(
        world.prefs.read(PrefKeys.orientation(ProfileKey.defaultProfile)),
        'landscape',
      );
      expect(world.prefs.read(PrefKeys.showIntro), isFalse);
      await expectLater(
        world.clips
            .watch(ProfileKey.defaultProfile)
            .map((ClipIndex index) => index.clipCount),
        emits(2),
      );
    });
  });

  group('O4', () {
    // Back returns to the intro, and Next opens the orientation step again,
    // with the choice kept.
    test('picks the orientation the user taps, and can change it; back '
        'returns to the intro keeping the choice', () async {
      final OnboardingCubit cubit = await onO4(VideoOrientation.portrait);
      expect(cubit.state.orientation, VideoOrientation.portrait);

      cubit.pickOrientation(VideoOrientation.landscape);
      expect(cubit.state.orientation, VideoOrientation.landscape);

      cubit.orientationClosed();
      expect(cubit.state.step, OnboardingStep.intro);

      await cubit.leaveIntro();
      expect(cubit.state.step, OnboardingStep.orientation);
      expect(cubit.state.orientation, VideoOrientation.landscape);
    });

    test('"Continue" opens the permissions step without writing or asking '
        'anything, and does nothing until an orientation is picked', () async {
      final OnboardingCubit cubit = open();
      await cubit.leaveIntro();

      await cubit.goToPermissions();
      expect(cubit.state.step, OnboardingStep.orientation);

      cubit.pickOrientation(VideoOrientation.portrait);
      await cubit.goToPermissions();

      expect(cubit.state.step, OnboardingStep.permissions);
      expect(cubit.state.status, OnboardingStatus.choosing);
      expect(world.prefs.read(PrefKeys.showIntro), isNull);
      expect(world.prefs.contains(PrefKeys.profiles), isFalse);
      expect(access(), isEmpty, reason: 'entering O5 asks nothing');
      expect(world.permissions.requestedTogether, isEmpty);
    });

    test('"Start my diary" does nothing before the permissions step', () async {
      final OnboardingCubit cubit = await onO4(VideoOrientation.portrait);

      await cubit.startDiary();

      expect(cubit.state.status, OnboardingStatus.choosing);
      expect(world.prefs.read(PrefKeys.showIntro), isNull);
    });
  });

  group('O5', () {
    List<OnboardingPermission> rows(OnboardingCubit cubit) =>
        cubit.state.shownRows;

    test('shows the rows this phone has: all five on Android 14, no '
        'microphone or notifications on Android 9, no gallery on an iPhone, '
        'no microphone with "Force native camera" on', () async {
      final OnboardingCubit android14 = await onO5(VideoOrientation.portrait);
      expect(rows(android14), OnboardingPermission.values);

      world = await OnboardingWorld.create(sdkInt: 28);
      final OnboardingCubit android9 = await onO5(VideoOrientation.portrait);
      expect(rows(android9), <OnboardingPermission>[
        OnboardingPermission.gallery,
        OnboardingPermission.camera,
        OnboardingPermission.location,
      ]);

      world = await OnboardingWorld.create(sdkInt: null);
      final OnboardingCubit iPhone = await onO5(VideoOrientation.portrait);
      expect(rows(iPhone), <OnboardingPermission>[
        OnboardingPermission.camera,
        OnboardingPermission.microphone,
        OnboardingPermission.notifications,
        OnboardingPermission.location,
      ]);

      world = await OnboardingWorld.create();
      await world.settings.forceNativeCamera.set(true);
      final OnboardingCubit nativeCamera = await onO5(
        VideoOrientation.portrait,
      );
      expect(
        rows(nativeCamera),
        isNot(contains(OnboardingPermission.microphone)),
      );
    });

    test(
      'a row already allowed shows "Allowed" on arrival, one blocked '
      'shows "Open settings", the rest wait for a tap; nothing is asked',
      () async {
        world.permissions.statuses[AppPermission.camera] =
            AppPermissionStatus.granted;
        world.permissions.statuses[AppPermission.notifications] =
            AppPermissionStatus.permanentlyDenied;
        world.permissions.statuses[AppPermission.microphone] =
            AppPermissionStatus.denied;

        final OnboardingCubit cubit = await onO5(VideoOrientation.portrait);

        expect(
          cubit.state.permissions,
          <OnboardingPermission, PermissionRowStatus>{
            OnboardingPermission.gallery: PermissionRowStatus.notAsked,
            OnboardingPermission.camera: PermissionRowStatus.granted,
            OnboardingPermission.microphone: PermissionRowStatus.notAsked,
            OnboardingPermission.notifications: PermissionRowStatus.blocked,
            OnboardingPermission.location: PermissionRowStatus.notAsked,
          },
        );
        expect(cubit.state.grantedCount, 1);
        expect(cubit.state.allGranted, isFalse);
        expect(world.permissions.requestedTogether, isEmpty);
      },
    );

    test(
      '"Allow" asks for that row alone: the prompt is up, then the row '
      'is allowed, or refused with the prompt still possible, or blocked',
      () async {
        world.permissions.answers[AppPermission.microphone] =
            AppPermissionStatus.denied;
        world.permissions.answers[AppPermission.location] =
            AppPermissionStatus.permanentlyDenied;
        final OnboardingCubit cubit = await onO5(VideoOrientation.portrait);
        final List<PermissionRowStatus?> camera = <PermissionRowStatus?>[];
        final StreamSubscription<OnboardingState> watching = cubit.stream
            .listen(
              (OnboardingState state) =>
                  camera.add(state.permissions[OnboardingPermission.camera]),
            );
        addTearDown(watching.cancel);

        await cubit.allow(OnboardingPermission.camera);
        await cubit.allow(OnboardingPermission.microphone);
        await cubit.allow(OnboardingPermission.location);

        expect(camera.take(2), <PermissionRowStatus>[
          PermissionRowStatus.requesting,
          PermissionRowStatus.granted,
        ]);
        expect(
          cubit.state.permissions[OnboardingPermission.microphone],
          PermissionRowStatus.denied,
        );
        expect(
          cubit.state.permissions[OnboardingPermission.location],
          PermissionRowStatus.blocked,
        );
        expect(world.permissions.requestedTogether, <Set<AppPermission>>[
          <AppPermission>{AppPermission.camera},
          <AppPermission>{AppPermission.microphone},
          <AppPermission>{AppPermission.location},
        ]);
        expect(cubit.state.grantedCount, 1);
        expect(world.prefs.read(PrefKeys.showIntro), isNull);

        // A refused row can be asked again.
        world.permissions.answers[AppPermission.microphone] =
            AppPermissionStatus.granted;
        await cubit.allow(OnboardingPermission.microphone);
        expect(
          cubit.state.permissions[OnboardingPermission.microphone],
          PermissionRowStatus.granted,
        );
      },
    );

    test(
      'a blocked row\'s button opens the system Settings, and the row '
      'turns "Allowed" when the app comes back with it granted there',
      () async {
        world.permissions.statuses[AppPermission.camera] =
            AppPermissionStatus.permanentlyDenied;
        final OnboardingCubit cubit = await onO5(VideoOrientation.portrait);
        expect(
          cubit.state.permissions[OnboardingPermission.camera],
          PermissionRowStatus.blocked,
        );

        await cubit.allow(OnboardingPermission.camera);

        expect(world.permissions.settingsOpened, isTrue);
        expect(world.permissions.requestedTogether, isEmpty);
        expect(
          cubit.state.permissions[OnboardingPermission.camera],
          PermissionRowStatus.blocked,
        );

        world.permissions.statuses[AppPermission.camera] =
            AppPermissionStatus.granted;
        await cubit.recheckPermissions();

        expect(
          cubit.state.permissions[OnboardingPermission.camera],
          PermissionRowStatus.granted,
        );
      },
    );

    test('every row allowed: "You\'re all set"', () async {
      world = await OnboardingWorld.create(sdkInt: null);
      final OnboardingCubit cubit = await onO5(VideoOrientation.portrait);

      for (final OnboardingPermission row in cubit.state.shownRows) {
        await cubit.allow(row);
      }

      expect(cubit.state.allGranted, isTrue);
      expect(cubit.state.grantedCount, 4);
    });

    test('back returns to O4 keeping the rows\' answers, and to the intro '
        'on the reinstall path', () async {
      final OnboardingCubit cubit = await onO5(VideoOrientation.portrait);
      await cubit.allow(OnboardingPermission.camera);

      cubit.permissionsClosed();
      expect(cubit.state.step, OnboardingStep.orientation);
      expect(cubit.state.orientation, VideoOrientation.portrait);

      await cubit.goToPermissions();
      expect(cubit.state.step, OnboardingStep.permissions);
      expect(
        cubit.state.permissions[OnboardingPermission.camera],
        PermissionRowStatus.granted,
      );

      world = await OnboardingWorld.create(diaryFolder: true);
      await seedClip(world.paths, ProfileKey.defaultProfile, january5);
      final OnboardingCubit reinstall = open();
      await reinstall.leaveIntro();
      expect(reinstall.state.step, OnboardingStep.permissions);

      reinstall.permissionsClosed();

      expect(reinstall.state.step, OnboardingStep.intro);
    });

    // The Default profile with the chosen canvas, the first-run counters,
    // the optional name, then showIntro = false; Today's card takes
    // Default's canvas at once.
    test('"Start my diary" makes the Default profile with the chosen '
        'orientation, stores the name typed on O4, trimmed, and completes '
        'onboarding; a blank name is no name: nothing is stored', () async {
      final List<ProfilesSnapshot> announced = <ProfilesSnapshot>[];
      final StreamSubscription<ProfilesSnapshot> watching = world.profiles
          .watch()
          .listen(announced.add);
      addTearDown(watching.cancel);
      final OnboardingCubit cubit = await onO4(VideoOrientation.portrait);
      cubit.nameChanged('  Kyle ');
      await cubit.goToPermissions();

      await cubit.startDiary();
      await pumpEventQueue();

      expect(cubit.state.status, OnboardingStatus.done);
      expect(world.prefs.read(PrefKeys.profiles), <String>['Default']);
      expect(
        world.prefs.read(PrefKeys.orientation(ProfileKey.defaultProfile)),
        'portrait',
      );
      expect(world.prefs.read(PrefKeys.videoCount), 0);
      expect(world.prefs.read(PrefKeys.movieCount), 1);
      expect(world.prefs.read(PrefKeys.showIntro), isFalse);
      expect(world.settings.userName.value, 'Kyle');
      expect(announced.last.active.key, ProfileKey.defaultProfile);
      expect(announced.last.active.orientation, VideoOrientation.portrait);

      // A blank name is no name: nothing is stored.
      world = await OnboardingWorld.create();
      final OnboardingCubit blank = await onO4(VideoOrientation.landscape);
      blank.nameChanged('   ');
      await blank.goToPermissions();

      await blank.startDiary();

      expect(world.prefs.contains(PrefKeys.userName), isFalse);
      expect(world.prefs.read(PrefKeys.showIntro), isFalse);
    });

    test('"Start my diary" runs once: taps and changes while it works are '
        'ignored', () async {
      final OnboardingCubit cubit = await onO4(VideoOrientation.portrait);
      cubit.nameChanged('Kyle');
      await cubit.goToPermissions();

      final Future<void> first = cubit.startDiary();
      cubit
        ..pickOrientation(VideoOrientation.landscape)
        ..nameChanged('Someone else');
      final Future<void> second = cubit.startDiary();
      await cubit.allow(OnboardingPermission.camera);
      await (first, second).wait;

      expect(cubit.state.orientation, VideoOrientation.portrait);
      expect(cubit.state.name, 'Kyle');
      expect(world.settings.userName.value, 'Kyle');
      expect(
        world.prefs.read(PrefKeys.orientation(ProfileKey.defaultProfile)),
        'portrait',
      );
      expect(
        cubit.state.permissions[OnboardingPermission.camera],
        PermissionRowStatus.notAsked,
        reason: 'no row is asked while the diary is being made',
      );
      expect(world.log.lines.join('\n'), isNot(contains('keeping it')));
    });
  });

  // The gallery row of the permissions step asks it with a tap; the finish asks it only when
  // that row was never tapped, so it is never asked twice.
  group('access to the gallery (Android)', () {
    test('asked once by its row, "Start my diary" never asks again, even '
        'refused: the diary is made without it', () async {
      world.permissions.answers[AppPermission.videos] =
          AppPermissionStatus.denied;
      final OnboardingCubit cubit = await onO5(VideoOrientation.portrait);

      await cubit.allow(OnboardingPermission.gallery);
      expect(
        cubit.state.permissions[OnboardingPermission.gallery],
        PermissionRowStatus.denied,
      );

      await cubit.startDiary();

      expect(cubit.state.status, OnboardingStatus.done);
      expect(cubit.state.access, isNull);
      expect(world.permissions.requestedTogether, <Set<AppPermission>>[
        <AppPermission>{AppPermission.photos, AppPermission.videos},
      ]);
      expect(world.prefs.read(PrefKeys.showIntro), isFalse);
    });

    test('never tapped, it is asked for as the diary is made, and granted '
        'goes on; iOS asks nothing at all', () async {
      final OnboardingCubit cubit = await onO5(VideoOrientation.portrait);
      expect(access(), isEmpty, reason: 'nothing is asked before');

      await cubit.startDiary();

      expect(access(), <AppPermission, AppPermissionStatus>{
        AppPermission.photos: AppPermissionStatus.granted,
        AppPermission.videos: AppPermissionStatus.granted,
      });
      expect(cubit.state.status, OnboardingStatus.done);

      world = await OnboardingWorld.create(sdkInt: null);
      final OnboardingCubit iPhone = await onO5(VideoOrientation.portrait);

      await iPhone.startDiary();

      expect(access(), isEmpty);
      expect(world.permissions.requestedTogether, isEmpty);
      expect(iPhone.state.status, OnboardingStatus.done);
    });

    // The diary works without it (the app's own clips on scoped storage):
    // after the explanation, "Not now" means "go on without it".
    test('refused at the finish, stops before the diary is made, shows it '
        'on the gallery row and says whether asking again can help; "Allow '
        'access" asks again, and "Not now" goes on without asking', () async {
      world.permissions.answers[AppPermission.videos] =
          AppPermissionStatus.denied;
      final OnboardingCubit cubit = await onO5(VideoOrientation.portrait);

      await cubit.startDiary();

      expect(cubit.state.status, OnboardingStatus.accessRefused);
      expect(cubit.state.access, AccessOutcome.denied);
      expect(
        cubit.state.permissions[OnboardingPermission.gallery],
        PermissionRowStatus.denied,
      );
      expect(world.prefs.contains(PrefKeys.profiles), isFalse);
      expect(world.prefs.read(PrefKeys.showIntro), isNull);

      world.permissions.answers[AppPermission.videos] =
          AppPermissionStatus.granted;
      await cubit.askAccessAgain();

      expect(access()[AppPermission.videos], AppPermissionStatus.granted);
      expect(cubit.state.status, OnboardingStatus.done);

      world = await OnboardingWorld.create();
      world.permissions.answers[AppPermission.videos] =
          AppPermissionStatus.denied;
      final OnboardingCubit withoutIt = await onO5(VideoOrientation.portrait);
      await withoutIt.startDiary();
      world.permissions.answers[AppPermission.videos] =
          AppPermissionStatus.granted;

      await withoutIt.continueSetup();

      expect(withoutIt.state.status, OnboardingStatus.done);
      expect(withoutIt.state.access, isNull);
      expect(access()[AppPermission.videos], AppPermissionStatus.denied);
      expect(world.prefs.read(PrefKeys.showIntro), isFalse);
    });

    test('blocked: "Open settings" opens the system Settings; the '
        'explanation stays while still refused, and goes once granted '
        'there, the row turning "Allowed"', () async {
      world.permissions.answers[AppPermission.videos] =
          AppPermissionStatus.permanentlyDenied;
      final OnboardingCubit cubit = await onO5(VideoOrientation.landscape);
      await cubit.startDiary();
      expect(cubit.state.access, AccessOutcome.blocked);
      expect(
        cubit.state.permissions[OnboardingPermission.gallery],
        PermissionRowStatus.blocked,
      );

      await cubit.openAccessSettings();
      await cubit.recheckAccess();

      expect(world.permissions.settingsOpened, isTrue);
      expect(cubit.state.status, OnboardingStatus.accessRefused);
      expect(cubit.state.access, AccessOutcome.blocked);

      world.permissions.statuses[AppPermission.videos] =
          AppPermissionStatus.granted;
      await cubit.recheckAccess();

      expect(cubit.state.status, OnboardingStatus.choosing);
      expect(cubit.state.access, isNull);
      expect(
        cubit.state.permissions[OnboardingPermission.gallery],
        PermissionRowStatus.granted,
      );
      expect(world.prefs.read(PrefKeys.showIntro), isNull);
    });

    test('on the reinstall path it is asked for at the finish; refused, '
        '"Not now" goes on without it', () async {
      world = await OnboardingWorld.create(diaryFolder: true);
      await seedClip(world.paths, ProfileKey.defaultProfile, january5);
      world.permissions.answers[AppPermission.photos] =
          AppPermissionStatus.denied;
      final OnboardingCubit cubit = open();

      await cubit.leaveIntro();
      expect(cubit.state.step, OnboardingStep.permissions);
      await cubit.startDiary();
      expect(cubit.state.status, OnboardingStatus.accessRefused);
      expect(world.prefs.read(PrefKeys.showIntro), isNull);

      await cubit.continueSetup();

      expect(cubit.state.status, OnboardingStatus.done);
      expect(
        world.prefs.read(PrefKeys.orientation(ProfileKey.defaultProfile)),
        'landscape',
      );
    });

    // permission_handler throws when a request is already running; the
    // finish must never stay at work because of it.
    test('a request the plugin fails counts as refused, never a finish or a '
        'row stuck at work; a check it fails decides the reinstall path '
        'from the diary folder alone', () async {
      world.permissions.failRequests = true;
      final OnboardingCubit cubit = await onO5(VideoOrientation.portrait);

      await cubit.allow(OnboardingPermission.camera);
      expect(
        cubit.state.permissions[OnboardingPermission.camera],
        PermissionRowStatus.denied,
      );

      await cubit.startDiary();

      expect(cubit.state.status, OnboardingStatus.accessRefused);
      expect(cubit.state.access, AccessOutcome.denied);

      world = await OnboardingWorld.create(diaryFolder: true);
      world.permissions.failChecks = true;
      final OnboardingCubit reinstall = open();

      await reinstall.leaveIntro();
      expect(reinstall.state.step, OnboardingStep.permissions, reason: 'no O4');
      await reinstall.startDiary();

      expect(reinstall.state.status, OnboardingStatus.done);
      expect(
        world.prefs.read(PrefKeys.orientation(ProfileKey.defaultProfile)),
        'landscape',
      );
    });
  });

  // Every write is idempotent and showIntro = false comes last, so a failure
  // (or a kill) anywhere before it leaves onboarding to be done again,
  // safely.
  group('a failed finish', () {
    // An in-progress status before each attempt, so the page's failure
    // listener fires on every failure.
    test('a write the phone refuses fails without completing onboarding, '
        'each attempt a new failure, and "Try again" finishes it', () async {
      world.platform.refused.add(PrefKeys.showIntro.name);
      final OnboardingCubit cubit = await onO5(VideoOrientation.portrait);
      final List<OnboardingStatus> seen = <OnboardingStatus>[];
      final StreamSubscription<OnboardingState> watching = cubit.stream.listen(
        (OnboardingState state) => seen.add(state.status),
      );
      addTearDown(watching.cancel);

      await cubit.startDiary();
      await cubit.continueSetup();
      await pumpEventQueue();

      expect(seen, <OnboardingStatus>[
        OnboardingStatus.finishing,
        OnboardingStatus.failed,
        OnboardingStatus.finishing,
        OnboardingStatus.failed,
      ]);
      expect(world.prefs.read(PrefKeys.showIntro), isNull);

      world.platform.refused.clear();
      await cubit.continueSetup();

      expect(cubit.state.status, OnboardingStatus.done);
      expect(world.prefs.read(PrefKeys.showIntro), isFalse);
      expect(
        world.prefs.read(PrefKeys.orientation(ProfileKey.defaultProfile)),
        'portrait',
      );
    });

    // The canvas is written once and never changed, so a relaunch after a
    // kill before showIntro finishes with it and never asks again.
    test('after a kill before showIntro, the relaunch skips O4 for the '
        'permissions step, finishes with the canvas already stored, and '
        'shows the name stored before the kill', () async {
      world.platform.refused.add(PrefKeys.showIntro.name);
      final OnboardingCubit killed = await onO4(VideoOrientation.portrait);
      killed.nameChanged('Kyle');
      await killed.goToPermissions();
      await killed.startDiary();
      world.platform.refused.clear();

      final OnboardingCubit relaunched = open();
      expect(relaunched.state.name, 'Kyle');
      await relaunched.leaveIntro();
      expect(relaunched.state.step, OnboardingStep.permissions);

      await relaunched.startDiary();

      expect(relaunched.state.status, OnboardingStatus.done);
      expect(
        world.prefs.read(PrefKeys.orientation(ProfileKey.defaultProfile)),
        'portrait',
      );
      expect(world.prefs.read(PrefKeys.showIntro), isFalse);
    });

    test('the flow closing while the finish runs (its route went away) '
        'lets the finish end quietly', () async {
      final OnboardingCubit cubit = world.cubit();
      await cubit.leaveIntro();
      cubit.pickOrientation(VideoOrientation.portrait);
      await cubit.goToPermissions();

      final Future<void> finishing = cubit.startDiary();
      await cubit.close();

      await expectLater(finishing, completes);
      expect(world.prefs.read(PrefKeys.showIntro), isFalse);
    });
  });

  group('the phone check (O6, PLAN_calibration §4)', () {
    test('"Continue" on the permissions step opens the phone check, writing '
        'nothing; back returns to the permissions step', () async {
      final OnboardingCubit cubit = await onO5(VideoOrientation.portrait);

      cubit.goToPhoneCheck();

      expect(cubit.state.step, OnboardingStep.phoneCheck);
      expect(cubit.state.status, OnboardingStatus.choosing);
      expect(world.prefs.read(PrefKeys.showIntro), isNull);

      cubit.phoneCheckClosed();
      expect(cubit.state.step, OnboardingStep.permissions);
      cubit.phoneCheckClosed();
      expect(
        cubit.state.step,
        OnboardingStep.permissions,
        reason: 'only from O6',
      );
    });

    test('"Use this" (or a pick, or Skip with Standard) makes the diary with '
        'the Default profile\'s format, on the canvas chosen whatever the '
        'format\'s; it stays through a retry after a refused access', () async {
      final OnboardingCubit cubit = await onO5(VideoOrientation.portrait);
      cubit.goToPhoneCheck();
      final ClipFormat ultra = ClipFormatPreset.ultra.format(
        VideoOrientation.landscape,
      );
      world.permissions.answers[AppPermission.videos] =
          AppPermissionStatus.denied;

      await cubit.startDiary(format: ultra);
      expect(cubit.state.status, OnboardingStatus.accessRefused);

      await cubit.continueSetup();

      expect(cubit.state.status, OnboardingStatus.done);
      expect(
        world.prefs.read(PrefKeys.clipFormat(ProfileKey.defaultProfile)),
        '2160p60-hevc-stereo-sdr',
      );
      expect(
        world.profiles.active.format,
        ultra.withOrientation(VideoOrientation.portrait),
      );

      world = await OnboardingWorld.create();
      final OnboardingCubit skipped = await onO5(VideoOrientation.landscape);
      await skipped.startDiary(
        format: ClipFormatPreset.standard.format(VideoOrientation.landscape),
      );
      expect(skipped.state.status, OnboardingStatus.done);
      expect(
        world.prefs.read(PrefKeys.clipFormat(ProfileKey.defaultProfile)),
        '1080p30-h264-mono-sdr',
      );
    });

    test('without a format (a build without the check) nothing is written '
        'and Default reads as legacy', () async {
      final OnboardingCubit cubit = await onO5(VideoOrientation.landscape);

      await cubit.startDiary();

      expect(cubit.state.status, OnboardingStatus.done);
      expect(
        world.prefs.contains(PrefKeys.clipFormat(ProfileKey.defaultProfile)),
        isFalse,
      );
      expect(world.profiles.active.format.isLegacy, isTrue);
    });

    test('a reinstall keeps the canvas and format Default\'s newest clips '
        'were made for (a portrait HEVC diary comes back portrait HEVC), '
        'skipping O4; the phone check\'s choice cannot change them', () async {
      world = await OnboardingWorld.create(diaryFolder: true);
      world.permissions.statuses.addAll(<AppPermission, AppPermissionStatus>{
        AppPermission.photos: AppPermissionStatus.granted,
        AppPermission.videos: AppPermissionStatus.granted,
      });
      await seedClip(world.paths, ProfileKey.defaultProfile, january5);
      world.clipFacts = FakeProfileClipFacts(
        facts: <ProfileKey, List<ClipMeta>>{
          ProfileKey.defaultProfile: <ClipMeta>[
            clipFacts(width: 1080, height: 1920, codec: 'hevc', channels: 2),
          ],
        },
      );
      final OnboardingCubit cubit = open();

      await cubit.leaveIntro();
      expect(cubit.state.step, OnboardingStep.permissions);
      cubit.goToPhoneCheck();
      await cubit.startDiary(
        format: ClipFormatPreset.ultra.format(VideoOrientation.landscape),
      );

      expect(cubit.state.status, OnboardingStatus.done);
      expect(
        world.prefs.read(PrefKeys.orientation(ProfileKey.defaultProfile)),
        'portrait',
      );
      expect(
        world.prefs.read(PrefKeys.clipFormat(ProfileKey.defaultProfile)),
        '1080p30-hevc-stereo-sdr',
      );
    });
  });
}
