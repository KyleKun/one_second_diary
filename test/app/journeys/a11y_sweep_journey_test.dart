import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_source_sheet.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_stats_bento.dart';
import 'package:one_second_diary/features/movies/domain/movie_file_name.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_grid_item.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_options_card.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/today/presentation/widgets/clip_actions_row.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/harness/seeds.dart';
import '../../shared/harness/settle.dart';
import '../../shared/robots/app_robot.dart';
import '../../shared/widgets/support/osd_widget_harness.dart';
import '../../support/support.dart';
import '../../theme/support/load_osd_fonts.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

/// `AppHarness.defaultNow`: Friday 5 January 2024.
final LocalDay _today = LocalDay(2024, 1, 5);

/// December's last days and January's first five, two clips today, and
/// one movie.
Future<void> _seedDiary(AppPaths paths) async {
  final List<LocalDay> days = <LocalDay>[
    for (int day = 28; day <= 31; day++) LocalDay(2023, 12, day),
    for (int day = 1; day <= 5; day++) LocalDay(2024, 1, day),
  ];
  for (final LocalDay day in days) {
    await seedClip(paths, _default, day);
  }
  await seedClip(paths, _default, _today, ordinal: 2);
  await seedClipMeta(paths, <String, ClipMeta>{
    for (final LocalDay day in days)
      '${day.fileStem}.mp4': const ClipMeta(durationMs: 2000),
  });
  await seedMovie(paths, number: 1, day: LocalDay(2024, 1, 2));
}

void main() {
  setUpAll(loadOsdFonts);

  /// A recording the clip editor opens on.
  late String recording;

  Future<AppRobot> launch(
    WidgetTester tester, {
    required bool dark,
    AppLanguage language = AppLanguage.en,
    Future<void> Function(AppPaths paths)? seed,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(
        extra: <String, Object>{'isDarkMode': dark, 'lang': language.name},
      ),
      seed: (AppPaths paths) async {
        final File video = File('${paths.temporaryDir}/REC_1.mp4');
        await video.create(recursive: true);
        await video.writeAsBytes(fakeVideoBytes);
        recording = video.path;
        await seed?.call(paths);
      },
      configureGateways: (FakeGateways gateways) =>
          gateways.players.duration = const Duration(seconds: 4),
    );
    tester.view.physicalSize = const Size(360, 640) * 3;
    addTearDown(tester.view.reset);
    await settle(tester);
    return app;
  }

  // The longest translations cut labels even at the design's text size.
  for (final AppLanguage language in <AppLanguage>[
    AppLanguage.de,
    AppLanguage.pt,
    AppLanguage.hu,
    AppLanguage.ru,
  ]) {
    testWidgets('${language.name}, 360 × 640 at text scale 1: the nav and '
        'S1, M1 and M3 show every label whole', (WidgetTester tester) async {
      final AppRobot app = await AppRobot.launch(
        tester,
        prefs: legacyPrefs(extra: <String, Object>{'lang': language.name}),
        seed: _seedDiary,
      );
      tester.view.physicalSize = const Size(360, 640) * 3;
      addTearDown(tester.view.reset);
      final _Sweep sweep = _Sweep(tester, guidelines: false);

      await app.shell.tapTab(AppRoute.settings);
      await sweep.check('the nav');
      await app.shell.open(const CreateMovieArgs());
      await sweep.check('M1');
      await sweep.tapVisible(find.byKey(MovieOptionsCard.pickVideosKey));
      await sweep.check('M3');

      sweep.expectClean();
    });
  }

  for (final AppLanguage language in <AppLanguage>[
    AppLanguage.de,
    AppLanguage.ru,
  ]) {
    testWidgets('${language.name}, 360 × 640 at text scale 2: Today, S3, S4, '
        'V1 and V2 show every label whole', (WidgetTester tester) async {
      final AppRobot app = await launch(
        tester,
        dark: true,
        language: language,
        seed: _seedDiary,
      );
      final _Sweep sweep = _Sweep(tester, guidelines: false);

      await sweep.check('T4');
      await app.settings.open();
      await app.settings.openPreferences();
      await sweep.check('S3');
      await app.shell.pressBack();
      await app.settings.openProfiles();
      await sweep.check('S4');
      await app.shell.pressBack();
      await app.shell.open(
        EditClipArgs(
          source: VideoSource(
            path: recording,
            ownership: ClipOwnership.cameraTemp,
          ),
          day: _today,
          profile: _default,
        ),
      );
      await app.clipEditor.waitForTheSource();
      await sweep.check('V1');
      await app.clipEditor.openLocationTab();
      await sweep.check('V2');

      sweep.expectClean();
    });
  }

  testWidgets('hu, 360 × 640 at text scale 1: T1 shows every label whole', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(extra: <String, Object>{'lang': 'hu'}),
    );
    tester.view.physicalSize = const Size(360, 640) * 3;
    addTearDown(tester.view.reset);
    final _Sweep sweep = _Sweep(tester, guidelines: false);

    await sweep.check('T1');

    sweep.expectClean();
    app.expectNoPluginChannel();
  });

  for (final bool dark in <bool>[true, false]) {
    final String theme = dark ? 'dark' : 'light';

    testWidgets('$theme, 360 × 640 at text scale 2: T1 lays out whole and '
        'meets the guidelines', (WidgetTester tester) async {
      final AppRobot app = await launch(tester, dark: dark);
      final _Sweep sweep = _Sweep(tester);

      await sweep.check('T1');

      sweep.expectClean();
      app.expectNoPluginChannel();
    });

    testWidgets('$theme, 360 × 640 at text scale 2: Today, the Diary, the '
        'viewer, Journey, the movie flow, My movies, the camera and the clip '
        'editor lay out whole and meet the guidelines', (
      WidgetTester tester,
    ) async {
      final AppRobot app = await launch(tester, dark: dark, seed: _seedDiary);
      final _Sweep sweep = _Sweep(tester);
      Future<void> back() => app.shell.pressBack();

      // Today with two clips, Add another's sheet, the profile sheet.
      await sweep.check('T4');
      await sweep.tapVisible(find.byKey(ClipActionsRow.addAnotherKey));
      expect(find.byKey(AddSourceSheet.bodyKey), findsOneWidget);
      await sweep.check('add-source sheet');
      await back();
      await app.today.tapProfileChip();
      await sweep.check('T6');
      await app.profileSheet.pressBack();

      // The Diary: the calendar, Memories, the viewer.
      await app.shell.tapTab(AppRoute.diary);
      await sweep.check('D1');
      await app.diary.showMemories();
      await sweep.check('D3');
      await app.diary.showCalendar();
      await app.shell.open(
        ViewerArgs(
          clip: ClipRef(profile: _default, relPath: '2024-01-04.mp4'),
        ),
      );
      await sweep.check('D4');
      await back();

      await app.shell.tapTab(AppRoute.journey);
      await app.harness.settleUntil(
        () => app.journey.hasNumber(JourneyTile.daysRecorded),
        reason: 'the diary was read',
      );
      await sweep.check('J1');

      // The movie flow, then the confirmation on a month.
      await app.shell.open(const CreateMovieArgs());
      await sweep.check('M1');
      await sweep.tapVisible(find.byKey(MovieOptionsCard.chooseMonthKey));
      await sweep.check('M2');
      await back();
      await sweep.tapVisible(find.byKey(MovieOptionsCard.pickVideosKey));
      await sweep.check('M3');
      await back();
      await back();
      await app.shell.open(
        const CreateMovieArgs(source: MovieSource.month(year: 2024, month: 1)),
      );
      await sweep.check('M5');
      await back();

      // My movies, a selection, its delete question and the rename dialog.
      final String movie = MovieFileName.format(
        number: 1,
        day: LocalDay(2024, 1, 2),
      );
      await app.shell.push(AppRoute.myMovies);
      await app.harness.settleUntil(
        () => find.byKey(MovieGridItem.itemKey(movie)).evaluate().isNotEmpty,
        reason: 'the Movies folder was read',
      );
      await sweep.check('M8');
      await app.movies.longPressMovie(movie);
      await sweep.check('M9 selection');
      await app.movies.tapDeleteMovies();
      await sweep.check('M9 delete question');
      await back();
      await app.movies.tapRename();
      await sweep.check('M10');
      await back();
      await back();
      await back();

      // The camera and its settings.
      await app.recording.open(RecordArgs(day: _today, profile: _default));
      await sweep.check('R1');
      await app.recording.openSettings();
      await sweep.check('R4');
      await back();
      await back();

      // The clip editor and its tabs.
      await app.shell.open(
        EditClipArgs(
          source: VideoSource(
            path: recording,
            ownership: ClipOwnership.cameraTemp,
          ),
          day: _today,
          profile: _default,
        ),
      );
      await app.clipEditor.waitForTheSource();
      await sweep.check('V1');
      await app.clipEditor.openLocationTab();
      await sweep.check('V2');
      await app.clipEditor.openGeneralTab();
      await app.clipEditor.openDateStamp();
      await sweep.check('V3');
      await back();
      await app.clipEditor.openSubtitlesTab();
      app.subtitleSheet.expectOpen();
      await sweep.check('V4');
      await app.subtitleSheet.pressBack();

      sweep.expectClean();
      app.expectNoPluginChannel();
    });
  }
}

/// A tap-target guideline less two exceptions: the calendar's day cells (a
/// seven-column grid can't make them 48 wide; their hit area is 48 tall)
/// and the colour swatches (hit cells take half of each gap), known by
/// their labels.
final class _TapTargets extends MinimumTapTargetGuideline {
  _TapTargets(Size size) : super(size: size, link: 'COMPONENTS.md §7.3');

  static final RegExp _dayCell = RegExp(', (recorded|no video|upcoming)');

  final Set<String> _swatches = <String>{
    Strings.colorWhite,
    Strings.colorBlack,
    Strings.colorCoral,
    Strings.colorRed,
    Strings.colorOrange,
    Strings.colorGold,
    Strings.colorYellow,
    Strings.colorGreen,
    Strings.colorTeal,
    Strings.colorSkyBlue,
    Strings.colorIndigo,
    Strings.colorLavender,
    Strings.colorPink,
    Strings.colorBrown,
    Strings.colorGrey,
    Strings.colorCustom,
  };

  @override
  bool shouldSkipNode(SemanticsNode node) {
    final String label = node.getSemanticsData().label;
    return super.shouldSkipNode(node) ||
        _dayCell.hasMatch(label) ||
        _swatches.contains(label);
  }
}

/// Checks screens one after the other and names every problem at the end.
final class _Sweep {
  _Sweep(this.tester, {this.guidelines = true});

  final WidgetTester tester;

  /// Whether the tap-target and contrast guidelines are checked too (the
  /// text size and theme sweeps), or only cut text (the language ones).
  final bool guidelines;
  final List<String> problems = <String>[];

  /// Names a row may cut by design (one line, ellipsis): a movie's (the
  /// user's, renamable; the seeded movie is titled by its day, which My
  /// movies writes as the language does, "Jan 2, 2024") and a profile's,
  /// Default's too ("По умолчанию").
  Set<String> get _userText => <String>{'Jan 2, 2024', Strings.defaultProfile};

  /// The screen as it shows now: no exception, no text cut off, the
  /// tap-target and text-contrast guidelines met.
  Future<void> check(String screen) async {
    await settle(tester);
    final Object? error = tester.takeException();
    if (error != null) problems.add('$screen: $error');
    try {
      expectNoTextCut(tester, screen: screen, userText: _userText);
    } on TestFailure catch (failure) {
      problems.add(failure.message ?? screen);
    }
    if (!guidelines) return;
    final SemanticsHandle semantics = tester.ensureSemantics();
    for (final AccessibilityGuideline guideline in <AccessibilityGuideline>[
      _TapTargets(const Size(48, 48)),
      _TapTargets(const Size(44, 44)),
      labeledTapTargetGuideline,
      textContrastGuideline,
    ]) {
      final Evaluation result = await guideline.evaluate(tester);
      if (!result.passed) problems.add('$screen: ${result.reason}');
    }
    semantics.dispose();
  }

  /// Scrolls [finder] into view (a large text size pushes it below the
  /// fold), then taps it.
  Future<void> tapVisible(Finder finder) async {
    await tester.ensureVisible(finder);
    await settle(tester);
    await tester.tap(finder);
    await settle(tester);
  }

  void expectClean() => expect(problems, isEmpty);
}
