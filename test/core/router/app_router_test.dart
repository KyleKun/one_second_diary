// The router over the real app: the harness launches the whole app over fake
// gateways. The tests find each page by its root key,
// `ValueKey<AppRoute>(route)`, never by its content.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/clips/domain/undo_token.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_bottom_nav.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';

import '../../shared/harness/seeds.dart';
import '../../shared/harness/settle.dart';
import '../../shared/robots/app_robot.dart';
import '../../shared/robots/shell_robot.dart';
import '../../support/support.dart';

void main() {
  // The clip editor's sources, written by [launch].
  late EditClipArgs editVideo;
  late EditClipArgs editPhoto;
  // The app [launch] started.
  late AppRobot app;

  /// The app over [prefs]. An onboarded diary has the files the routes are
  /// opened with, so real pages find what they show: January 5's clip (the
  /// viewer), a movie (the player), a recording and a photo (the editor).
  Future<ShellRobot> launch(
    WidgetTester tester, {
    Map<String, Object>? prefs,
  }) async {
    final Map<String, Object> stored = prefs ?? legacyPrefs();
    app = await AppRobot.launch(
      tester,
      prefs: stored,
      seed: stored['showIntro'] != false
          ? null
          : (AppPaths paths) async {
              await seedClip(paths, ProfileKey.defaultProfile, january5);
              await seedMovie(paths, number: 3, day: january5);
              final File recording = await _temp(paths, 'REC.mp4');
              final File photo = await _temp(
                paths,
                'IMG.jpg',
                bytes: onePixelPng,
              );
              editVideo = EditClipArgs(
                source: VideoSource(
                  path: recording.path,
                  ownership: ClipOwnership.cameraTemp,
                ),
                day: january5,
                profile: ProfileKey.defaultProfile,
              );
              editPhoto = EditClipArgs(
                source: PhotoSource(
                  path: photo.path,
                  ownership: ClipOwnership.pickerCopy,
                ),
                day: january5,
                profile: ProfileKey.defaultProfile,
              );
            },
    );
    return app.shell;
  }

  // Onboarded iff showIntro == false; null means the intro.
  group('the onboarding gate', () {
    testWidgets('an onboarded diary opens on Today, and never shows '
        'onboarding or its orientation step again', (
      WidgetTester tester,
    ) async {
      final ShellRobot shell = await launch(tester);
      shell
        ..expectAt(AppRoute.today)
        ..expectNavVisible(visible: true);

      await shell.go(AppRoute.onboarding);
      shell.expectAt(AppRoute.today);

      await shell.go(AppRoute.onboardingOrientation);
      shell.expectAt(AppRoute.today);
    });

    testWidgets('a diary not onboarded opens on onboarding, without the nav, '
        'and leads nowhere else until onboarding is done', (
      WidgetTester tester,
    ) async {
      final ShellRobot shell = await launch(tester, prefs: freshInstallPrefs);
      shell
        ..expectAt(AppRoute.onboarding)
        ..expectNavVisible(visible: false);

      await shell.go(AppRoute.diary);
      shell.expectAt(AppRoute.onboarding);

      await tester.runAsync(
        () async => (await app.harness.storedPrefs).setBool('showIntro', false),
      );
      await shell.go(AppRoute.today);
      shell
        ..expectAt(AppRoute.today)
        ..expectNavVisible(visible: true);
    });

    testWidgets('the orientation step (O4) opens above the carousel, and back '
        'returns to it', (WidgetTester tester) async {
      final ShellRobot shell = await launch(tester, prefs: freshInstallPrefs);

      await shell.push(AppRoute.onboardingOrientation);
      shell
        ..expectAt(AppRoute.onboardingOrientation)
        ..expectShown(AppRoute.onboardingOrientation)
        ..expectNavVisible(visible: false);

      expect(await shell.pressBack(), isTrue);
      shell.expectAt(AppRoute.onboarding);
    });
  });

  group('the shell', () {
    testWidgets('each tab shows its page with its nav item active; a hidden '
        'tab keeps its state, with its tickers and heroes off', (
      WidgetTester tester,
    ) async {
      final ShellRobot shell = await launch(tester);
      final Element todayPage = shell.pageElement(AppRoute.today);
      // A hero in a hidden tab would clash with the same clip's hero on the
      // tab that shows when the root navigator pushes the viewer.
      bool heroesOn() =>
          todayPage.findAncestorWidgetOfExactType<HeroMode>()?.enabled ?? true;

      for (final AppRoute tab in ShellRobot.tabs.reversed) {
        await shell.tapTab(tab);
        shell
          ..expectAt(tab)
          ..expectActiveTab(tab)
          ..expectNavVisible(visible: true)
          ..expectShown(tab);
        if (tab == AppRoute.diary) {
          shell.expectHiddenAndStill(AppRoute.today);
          expect(heroesOn(), isFalse);
        }
      }

      expect(shell.pageElement(AppRoute.today), same(todayPage));
      expect(TickerMode.valuesOf(todayPage).enabled, isTrue);
      expect(heroesOn(), isTrue);
    });

    // Fixed pumps: settling would run the snackbar's countdown out.
    testWidgets('a tab switch hides the snackbar', (WidgetTester tester) async {
      final ShellRobot shell = await launch(tester);
      OsdSnackbar.show(
        shell.pageElement(AppRoute.today),
        kind: OsdSnackKind.success,
        title: 'Saved',
        duration: const Duration(seconds: 10),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(OsdSnackbar.surfaceKey), findsOneWidget);

      await tester.tap(find.byKey(OsdBottomNav.itemKey(1)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(OsdSnackbar.surfaceKey), findsNothing);
    });
  });

  group('full-screen routes', () {
    // The route and the arguments it is opened with (none: `AppRoute.push`).
    // Built after the launch wrote the editor's files.
    List<(AppRoute, RouteArgs?)> pages() => <(AppRoute, RouteArgs?)>[
      (AppRoute.record, recordJanuary5),
      (AppRoute.editClip, editVideo),
      (AppRoute.editClip, editPhoto),
      (AppRoute.viewer, viewJanuary5),
      (AppRoute.myMovies, null),
      (AppRoute.moviePlayer, playMovie3),
      (AppRoute.createMovie, null),
      (AppRoute.pickClips, null),
      (AppRoute.confirmMovie, null),
      (AppRoute.makingMovie, null),
      (AppRoute.movieCreated, null),
      (AppRoute.notifications, null),
      (AppRoute.preferences, null),
      (AppRoute.phoneCheck, null),
      (AppRoute.profiles, null),
      (AppRoute.about, null),
      (AppRoute.changelog, null),
      (AppRoute.thanks, null),
      (AppRoute.licenses, null),
      (AppRoute.support, null),
    ];

    testWidgets('each opens above the shell, without the nav, and back '
        'returns to the tab as it was', (WidgetTester tester) async {
      final ShellRobot shell = await launch(tester);
      await shell.tapTab(AppRoute.journey);

      for (final (AppRoute route, RouteArgs? args) in pages()) {
        if (args == null) {
          await shell.push(route);
        } else {
          expect(args.route, route);
          await shell.open(args);
        }

        shell
          ..expectAt(route)
          ..expectNavVisible(visible: false)
          ..expectShown(route);

        expect(await shell.pressBack(), isTrue);
        // The editor asks before a fresh take goes.
        if (route == AppRoute.editClip) await app.clipEditor.tapDiscard();
        shell
          ..expectAt(AppRoute.journey)
          ..expectActiveTab(AppRoute.journey)
          ..expectNavVisible(visible: true);
      }
    });

    // go_router must not read /settings/… as a page of the /settings tab.
    testWidgets('the /settings/… pages do not clash with the Settings tab', (
      WidgetTester tester,
    ) async {
      final ShellRobot shell = await launch(tester);

      await shell.push(AppRoute.profiles);
      shell
        ..expectAt(AppRoute.profiles)
        ..expectNavVisible(visible: false);
      await shell.pressBack();
      // Pushed from Today, it did not switch the tab below it.
      shell
        ..expectAt(AppRoute.today)
        ..expectActiveTab(AppRoute.today);

      await shell.tapTab(AppRoute.settings);
      await shell.push(AppRoute.about);
      await shell.push(AppRoute.changelog);
      shell.expectAt(AppRoute.changelog);
      await shell.pressBack();
      shell.expectAt(AppRoute.about);
      await shell.pressBack();
      shell
        ..expectAt(AppRoute.settings)
        ..expectActiveTab(AppRoute.settings);
    });
  });

  group('typed arguments', () {
    // A redirect inside a push would push the fallback tab into the tab
    // the user is on (a second Today page in the Diary, under the Diary's
    // nav item). So these routes only open through their RouteArgs.
    testWidgets('a route that needs arguments cannot be pushed without '
        'them', (WidgetTester tester) async {
      final ShellRobot shell = await launch(tester);
      await shell.tapTab(AppRoute.diary);

      for (final AppRoute route in <AppRoute>[
        AppRoute.record,
        AppRoute.editClip,
        AppRoute.viewer,
        AppRoute.moviePlayer,
      ]) {
        await expectLater(
          shell.push(route),
          throwsStateError,
          reason: route.path,
        );

        shell
          ..expectAt(AppRoute.diary)
          ..expectActiveTab(AppRoute.diary)
          ..expectOnePageOf(AppRoute.today)
          ..expectOnePageOf(AppRoute.diary)
          ..expectNoPageOf(route);
      }
    });

    // The last resort for a location without its arguments (a deep link,
    // a restored location): the whole stack is replaced, so the fallback
    // tab shows once, under its own nav item.
    testWidgets('a route gone to without its arguments, or with foreign ones, '
        'shows its fallback', (WidgetTester tester) async {
      final ShellRobot shell = await launch(tester);
      // (where it goes, the fallback, whether the fallback is a tab)
      final List<(Future<void> Function(), AppRoute, bool)> rows =
          <(Future<void> Function(), AppRoute, bool)>[
            (() => shell.go(AppRoute.record), AppRoute.today, true),
            (() => shell.go(AppRoute.editClip), AppRoute.today, true),
            (() => shell.go(AppRoute.viewer), AppRoute.diary, true),
            (() => shell.go(AppRoute.moviePlayer), AppRoute.myMovies, false),
            (
              () => shell.goWithExtra(AppRoute.confirmMovie, editVideo),
              AppRoute.journey,
              true,
            ),
          ];

      for (final (Future<void> Function() goThere, AppRoute fallback, bool tab)
          in rows) {
        await shell.go(AppRoute.settings);

        await goThere();

        shell.expectAt(fallback);
        if (tab) {
          shell
            ..expectActiveTab(fallback)
            ..expectOnePageOf(fallback);
        }
      }
    });
  });

  // What each route pops with reaches whoever opened it, also through a
  // hand-over (the camera replaced by the clip editor).
  group('results', () {
    final SavedClip saved = SavedClip(
      ref: ClipRef(
        profile: ProfileKey.defaultProfile,
        relPath: '2024-01-05-2.mp4',
      ),
      undoToken: const PublishedUndo(relPath: '2024-01-05-2.mp4'),
    );

    testWidgets('the clip editor pops with the SavedClip, and the viewer with '
        'the clip it shows last, to whoever opened them', (
      WidgetTester tester,
    ) async {
      final ShellRobot shell = await launch(tester);

      final RouteResult<SavedClip> edited = await shell
          .openForResult<SavedClip>(editVideo);
      await shell.popWith(saved);
      expect(edited.value, saved);
      shell.expectAt(AppRoute.today);

      await shell.tapTab(AppRoute.diary);
      final ClipRef january6 = ClipRef(
        profile: ProfileKey.defaultProfile,
        relPath: '2024-01-06.mp4',
      );
      final RouteResult<ClipRef> viewed = await shell.openForResult<ClipRef>(
        viewJanuary5,
      );
      await shell.popWith(january6);
      expect(viewed.value, january6);
      shell.expectAt(AppRoute.diary);
    });

    testWidgets('the camera hands on to the clip editor, and back with '
        '"Record again"; the chain ends at whoever opened the camera, with '
        'the SavedClip, or nothing when the editor is left unsaved', (
      WidgetTester tester,
    ) async {
      final ShellRobot shell = await launch(tester);
      await shell.tapTab(AppRoute.diary);

      final RouteResult<SavedClip> saving = await shell
          .openForResult<SavedClip>(recordJanuary5);
      shell.expectAt(AppRoute.record);
      await shell.replaceTopWith(editVideo);
      shell
        ..expectAt(AppRoute.editClip)
        ..expectNoPageOf(AppRoute.record);
      await shell.replaceTopWith(recordJanuary5);
      shell.expectAt(AppRoute.record);
      await shell.replaceTopWith(editVideo);
      await shell.popWith(saved);

      expect(saving.value, saved);
      shell
        ..expectAt(AppRoute.diary)
        ..expectActiveTab(AppRoute.diary);

      final RouteResult<SavedClip> leaving = await shell
          .openForResult<SavedClip>(recordJanuary5);
      await shell.replaceTopWith(editVideo);
      await shell.pressBack();
      await app.clipEditor.tapDiscard();

      expect(leaving.value, isNull);
      shell.expectAt(AppRoute.diary);
    });
  });

  group('the Create movie flow', () {
    testWidgets('its screens share one cubit, which closes when the flow '
        'is left', (WidgetTester tester) async {
      final ShellRobot shell = await launch(tester);
      await shell.tapTab(AppRoute.journey);

      await shell.push(AppRoute.createMovie);
      final CreateMovieCubit flow = cubitOn(shell, AppRoute.createMovie);
      await shell.push(AppRoute.pickClips);
      await shell.push(AppRoute.confirmMovie);

      expect(cubitOn(shell, AppRoute.pickClips), same(flow));
      expect(cubitOn(shell, AppRoute.confirmMovie), same(flow));
      expect(flow.state.source, isNull);

      await shell.pressBack();
      await shell.pressBack();
      expect(flow.isClosed, isFalse);
      await shell.pressBack();
      shell.expectAt(AppRoute.journey);
      expect(flow.isClosed, isTrue);
    });

    // A push inside the flow builds the flow again without the Diary's
    // arguments; the cubit must keep the ones the flow opened with, even
    // when no screen read it before that push.
    testWidgets("the Diary's Make movie opens the confirmation alone with the "
        'month, and the month stays after a push inside the flow', (
      WidgetTester tester,
    ) async {
      final ShellRobot shell = await launch(tester);
      await shell.tapTab(AppRoute.diary);
      const MovieSource january = MovieSource.month(year: 2024, month: 1);

      await shell.open(const CreateMovieArgs(source: january));
      shell.expectAt(AppRoute.confirmMovie);
      expect(cubitOn(shell, AppRoute.confirmMovie).state.source, january);
      // Only the confirmation is on the stack: back returns to the Diary.
      await shell.pressBack();
      shell.expectAt(AppRoute.diary);

      await shell.open(const CreateMovieArgs(source: january));
      await shell.push(AppRoute.makingMovie);
      expect(cubitOn(shell, AppRoute.makingMovie).state.source, january);
      expect(cubitOn(shell, AppRoute.confirmMovie).state.source, january);
    });
  });

  group('back', () {
    testWidgets('Android back pops a pushed page, then goes to Today from '
        'another tab, then leaves the app', (WidgetTester tester) async {
      final ShellRobot shell = await launch(tester);
      await shell.tapTab(AppRoute.diary);
      await shell.open(recordJanuary5);

      expect(await shell.pressBack(), isTrue);
      shell.expectAt(AppRoute.diary);

      expect(await shell.pressBack(), isTrue);
      shell
        ..expectAt(AppRoute.today)
        ..expectActiveTab(AppRoute.today);

      expect(await shell.pressBack(), isFalse);
    });

    // go_router builds `MaterialPage`s itself only under `material_ui`'s
    // `MaterialApp`, so the app builds them (`OsdPages`).
    testWidgets('on iOS the edge swipe pops a pushed page', (
      WidgetTester tester,
    ) async {
      final ShellRobot shell = await launch(tester);
      await shell.push(AppRoute.notifications);

      final TestGesture swipe = await tester.startGesture(const Offset(5, 400));
      await swipe.moveBy(const Offset(20, 0));
      await swipe.moveBy(const Offset(300, 0));
      await swipe.up();
      await settle(tester);

      shell
        ..expectNoPageOf(AppRoute.notifications)
        ..expectAt(AppRoute.today);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}

final LocalDay january5 = LocalDay(2024, 1, 5);

final RecordArgs recordJanuary5 = RecordArgs(
  day: january5,
  profile: ProfileKey.defaultProfile,
);

final ViewerArgs viewJanuary5 = ViewerArgs(
  clip: ClipRef(profile: ProfileKey.defaultProfile, relPath: '2024-01-05.mp4'),
);

const MoviePlayerArgs playMovie3 = MoviePlayerArgs(
  file: 'OSD-Movie-3-2024-01-05.mp4',
);

/// A file in the app's temp folder, as a camera or a picker writes one.
Future<File> _temp(
  AppPaths paths,
  String name, {
  List<int> bytes = fakeVideoBytes,
}) async {
  final File file = File('${paths.temporaryDir}/$name');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes);
  return file;
}

/// The flow cubit the page of [route] reads (covered by later pages or
/// not).
CreateMovieCubit cubitOn(ShellRobot shell, AppRoute route) =>
    shell.pageElement(route).read<CreateMovieCubit>();
