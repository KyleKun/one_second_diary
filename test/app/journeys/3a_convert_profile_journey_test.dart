// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/commands/concat_command.dart';
import 'package:one_second_diary/core/media/policy/concat_list.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_meta_sidecar.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/stamped_clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/convert_profile_sheet.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/edit_profile_sheet.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/harness/seeds.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

/// December 1–3, 2023 in Default: legacy clips with every fact cached
/// (nothing to probe).
final List<LocalDay> _december = <LocalDay>[
  for (int day = 1; day <= 3; day++) LocalDay(2023, 12, day),
];

/// The new profile, named by the user.
const ProfileKey _ultra = ProfileKey('Ultra');

/// What ffmpeg writes wherever it is told to.
const List<int> _rendered = <int>[4, 2];

/// Today is January 5, 2024 (the harness's day): the movie's name.
const String _movie = 'OSD-Movie-1-2024-01-05.mp4';

void main() {
  late AppPaths paths;

  /// What each text input (`-i <file>.txt`, the concat list) held when its
  /// session ran: the job folder is gone once the movie is made.
  final Map<String, String> textInputs = <String, String>{};

  Future<AppRobot> launch(WidgetTester tester) => AppRobot.launch(
    tester,
    prefs: legacyPrefs(),
    seed: (AppPaths at) async {
      paths = at;
      for (final LocalDay day in _december) {
        await seedClip(at, ProfileKey.defaultProfile, day);
      }
      await seedClipMeta(at, <String, ClipMeta>{
        for (final LocalDay day in _december)
          '${day.fileStem}.mp4': const ClipMeta(
            durationMs: 1500,
            hasAudio: true,
            hasSubtitleStream: false,
            isOsdV15: true,
            width: 1920,
            height: 1080,
            codec: 'h264',
            fps: 30,
            channels: 1,
            pixelFormat: 'yuv420p',
            schema: ClipSchema.v15,
          ),
      });
    },
    configureGateways: (FakeGateways gateways) =>
        gateways.ffmpeg.onExecute = (List<String> arguments) async {
          for (final (int index, String argument) in arguments.indexed) {
            if (index > 0 &&
                arguments[index - 1] == '-i' &&
                argument.endsWith('.txt')) {
              textInputs[argument] = await File(argument).readAsString();
            }
          }
          // Every command's output comes before its final `-y`.
          final File output = File(arguments[arguments.length - 2]);
          await output.parent.create(recursive: true);
          await output.writeAsBytes(_rendered);
        },
  );

  bool canStart(WidgetTester tester) =>
      tester
          .widget<PrimaryButton>(find.byKey(ConvertProfileSheet.startKey))
          .onPressed !=
      null;

  /// The sidecar as the next launch reads it.
  Map<String, StampedClipMeta> sidecar() => ClipMetaSidecar.decode(
    File(
      '${paths.supportIndexDir}/${ClipMetadataCache.fileName}',
    ).readAsStringSync(),
  );

  // "Convert into a new profile": every clip of Default is re-rendered at the new
  // quality, the originals untouched; a movie of the new profile is then a plain
  // stream-copy join.
  testWidgets('Edit profile › Convert into a new profile renders the three '
      'clips of Default into "Ultra" (4K60 HEVC stereo), leaving Default as '
      'it was; a movie of Ultra joins them as they are', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await launch(tester);
    await app.settings.openProfiles();
    await app.harness.settleUntil(
      () => app.profiles.subtitleOf(ProfileKey.defaultProfile).contains('3'),
      reason: 'S4 counts the clips of Default',
    );

    await app.profiles.openEdit(ProfileKey.defaultProfile);
    await tester.ensureVisible(find.byKey(EditProfileSheet.convertKey));
    await tester.tap(find.byKey(EditProfileSheet.convertKey));
    await app.harness.settleUntil(
      () => find.byKey(ConvertProfileSheet.sheetKey).evaluate().isNotEmpty,
      reason: 'the convert sheet opens once Edit profile has closed',
    );
    // A never-checked phone pre-fills Ultra (the source already has
    // Standard); the user names the profile.
    await tester.enterText(find.byKey(ConvertProfileSheet.nameKey), 'Ultra');
    await app.harness.settleUntil(
      () => canStart(tester),
      reason: 'the estimate is in and the profile can be converted',
    );
    await tester.tap(find.byKey(ConvertProfileSheet.startKey));
    await app.harness.settleUntil(
      () => find.byKey(ConvertProfileSheet.doneKey).evaluate().isNotEmpty,
      reason: 'the three clips are converted',
    );
    expect(
      find.text(Strings.convertProfileDone(name: 'Ultra')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(ConvertProfileSheet.doneKey));
    await app.harness.settleUntil(
      () => find.byKey(ConvertProfileSheet.sheetKey).evaluate().isEmpty,
      reason: 'Done closes the sheet',
    );

    // The new profile, active, with its write-once format.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('profiles'), <String>['Default', 'Ultra']);
    expect(prefs.getInt('selectedProfileIndex'), 1);
    expect(prefs.getString('orientation_Ultra'), 'landscape');
    expect(prefs.getString('clipFormat_Ultra'), '2160p60-hevc-stereo-sdr');
    expect(app.profiles.activeTile, 'Ultra');

    // Every clip rendered into Ultra's folder; Default's files untouched.
    for (final LocalDay day in _december) {
      expect(
        File(
          '${paths.profileVideos(_ultra)}${day.fileStem}.mp4',
        ).readAsBytesSync(),
        _rendered,
      );
      expect(
        File('${paths.videos}${day.fileStem}.mp4').readAsBytesSync(),
        fakeVideoBytes,
      );
    }
    final List<List<String>> converts = app.harness.gateways.ffmpeg.executed
        .toList();
    expect(converts, hasLength(3));
    for (final List<String> convert in converts) {
      expect(convert, containsAllInOrder(<String>['-map_metadata', '0']));
      expect(convert, contains('artist=One Second Diary (v2)'));
      expect(convert, contains('album=Ultra'));
      expect(convert, containsAllInOrder(<String>['-tag:v', 'hvc1']));
      expect(convert.last, '-y');
    }

    // The sidecar carries the new clips' facts, so the next movie never
    // probes them.
    await app.harness.settleUntil(
      () => _december.every(
        (LocalDay day) =>
            sidecar().containsKey('Profiles/Ultra/${day.fileStem}.mp4'),
      ),
      reason: 'the converted clips are in the sidecar',
    );
    for (final LocalDay day in _december) {
      final ClipMeta meta =
          sidecar()['Profiles/Ultra/${day.fileStem}.mp4']!.meta;
      expect(
        (meta.codec, meta.fps, meta.channels, meta.schema, meta.isOsdV15),
        ('hevc', 60.0, 2, ClipSchema.v2, false),
      );
      expect((meta.width, meta.height), (3840, 2160));
      expect(meta.durationMs, 1500);
    }

    // A movie of Ultra's December is one ffmpeg run: the concat demuxer with a stream
    // copy of the clips at the profile's frame rate, no clip normalised first. In the
    // legacy format the engine would copy every clip into 1080p30 H.264 first.
    await app.shell.tapTab(AppRoute.diary);
    await app.shell.open(
      const CreateMovieArgs(source: MovieSource.month(year: 2023, month: 12)),
    );
    await app.harness.settleUntil(
      () => app.movies.canCreateMovie,
      reason: 'the diary was read',
    );
    final int before = app.harness.gateways.ffmpeg.executed.length;
    final int probedBefore = app.harness.gateways.ffmpeg.probed.length;
    await app.movies.tapCreateMovie();
    await app.harness.settleUntil(
      () => app.movies.createdShown && !app.movies.wakelock.enabled,
      reason: 'the movie is saved',
    );

    expect(
      app.harness.gateways.ffmpeg.probed,
      hasLength(probedBefore),
      reason: 'the plan was decided on the sidecar\'s facts, not a probe',
    );
    final List<List<String>> joins = app.harness.gateways.ffmpeg.executed
        .sublist(before);
    expect(joins, hasLength(1), reason: 'nothing was normalised first');
    final List<String> join = joins.single;
    final String listPath = join[join.indexOf('-i') + 1];
    final String chaptersPath = join[join.lastIndexOf('-i') + 1];
    final String outputPath = join[join.length - 2];
    expect(outputPath, startsWith('${paths.scratchDir}/movie-'));
    expect(outputPath, endsWith('/$_movie'));
    expect(
      join,
      ConcatCommand.build(
        listPath: listPath,
        outputPath: outputPath,
        fps: FrameRate.f60,
        title: 'December 2023',
        comment: 'profile=Ultra',
        description: 'clips=3;from=2023-12-01;to=2023-12-03',
        chaptersPath: chaptersPath,
      ),
    );
    expect(
      textInputs[listPath],
      ConcatList.content(<String>[
        for (final LocalDay day in _december)
          '${paths.profileVideos(_ultra)}${day.fileStem}.mp4',
      ]),
      reason: 'the converted clips as they are, no normalised copy',
    );
    expect(File('${paths.movies}$_movie').existsSync(), isTrue);
    app.expectNoPluginChannel();
  });
}
