// "Keep original recordings": the switch is stored
// and logged like the others, the row says about how much one recording
// adds at the active profile's quality, the "Original videos" group shows
// what the Originals folder holds (count and bytes) while the switch is on
// or the folder holds anything, and "Delete originals" empties the folder
// (a refused file stays counted).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/capture_quality.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/clips/data/import_flow.dart';
import 'package:one_second_diary/features/clips/data/originals_store.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/app_preference.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/preferences_cubit.dart';

import '../../../../support/support.dart';

class _NoSystemCamera extends Fake implements ImportFlow {
  @override
  Future<bool> systemCameraRequired() async => false;
}

void main() {
  late AppPaths paths;
  late MemoryLogSink log;
  late FakeMediaStoreGateway gallery;
  late OriginalsStore originals;
  late PrefsStore prefs;

  setUp(() async {
    paths = await createTestPaths();
    log = MemoryLogSink();
    gallery = FakeMediaStoreGateway.onDisk(paths);
    originals = OriginalsStore(
      paths: paths,
      gateway: gallery,
      logger: memoryLogger(log),
      isAndroid: true,
    );
    addTearDown(originals.dispose);
    prefs = await openLegacyPrefs(legacyPrefs()..['recordingSeconds'] = 3);
  });

  /// Keeps a recording of [bytes] as the source of the clip at [relPath],
  /// through the store (so its cached walk is invalidated).
  Future<void> keep(String relPath, List<int> bytes) async {
    final File temp = File('${paths.temporaryDir}/$relPath');
    await temp.parent.create(recursive: true);
    await temp.writeAsBytes(bytes);
    expect(
      await originals.keepSource(tempPath: temp.path, relPath: relPath),
      isNotNull,
    );
  }

  PreferencesCubit cubit({ClipFormat? format}) {
    final PreferencesCubit cubit = PreferencesCubit(
      settings: SettingsRepository(prefs: prefs),
      imports: _NoSystemCamera(),
      logger: memoryLogger(log),
      originals: originals,
      activeFormat: format == null ? null : () => format,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('off by default; on, stored under keepOriginals and logged with the '
      'line bug reports rely on', () async {
    final PreferencesCubit sut = cubit();
    expect(sut.state.isOn(AppPreference.keepOriginals), isFalse);

    await sut.set(AppPreference.keepOriginals, true);

    expect(sut.state.isOn(AppPreference.keepOriginals), isTrue);
    expect(SettingsRepository(prefs: prefs).keepOriginals.value, isTrue);
    expect(
      log.lines.last,
      endsWith('[PREFERENCES] - Keep original recordings was enabled'),
    );
  });

  test('load walks the folder once (cached per launch) and says about how '
      'much one recording adds: the format\'s capture bitrate (video and '
      'audio) over the camera\'s clip length; no format, no line', () async {
    final File kept = File(originals.absoluteOf('2024-01-05.mov'));
    await kept.parent.create(recursive: true);
    await kept.writeAsBytes(List<int>.filled(1000, 1));
    const ClipFormat ultra = ClipFormat(
      tier: ResolutionTier.p2160,
      orientation: VideoOrientation.portrait,
      codec: VideoCodec.hevc,
      fps: FrameRate.f60,
      channels: AudioChannels.stereo,
      range: DynamicRange.sdr,
    );
    final PreferencesCubit sut = cubit(format: ultra);
    expect(sut.state.originalsBytes, isNull);

    await sut.load();

    expect(sut.state.originalsBytes, 1000);
    final int bitsPerSecond =
        CaptureQuality.of(ultra).videoBitrate + CaptureQuality.audioBitrate;
    expect(sut.state.perRecordingBytes, (bitsPerSecond / 8 * 3).ceil());
    expect(sut.state.canDeleteOriginals, isTrue);

    // Another kept file does not change the cached size until a write
    // through the store; a cubit without a format shows no line.
    await File(originals.absoluteOf('2024-01-06.mov')).writeAsBytes(<int>[1]);
    final PreferencesCubit again = cubit();
    await again.load();
    expect(again.state.originalsBytes, 1000);
    expect(again.state.perRecordingBytes, isNull);
  });

  test('deleteOriginals empties the folder and shows the size left (0); '
      'nothing to delete afterwards', () async {
    final File kept = File(originals.absoluteOf('2024-01-05.mov'));
    await kept.parent.create(recursive: true);
    await kept.writeAsBytes(<int>[1, 2, 3]);
    final PreferencesCubit sut = cubit();
    await sut.load();
    expect(sut.state.canDeleteOriginals, isTrue);

    await sut.deleteOriginals();

    expect(kept.existsSync(), isFalse);
    expect(sut.state.originalsBytes, 0);
    expect(sut.state.deletingOriginals, isFalse);
    expect(sut.state.canDeleteOriginals, isFalse);
    expect(log.lines.last, contains('Deleted 1 original video(s)'));
  });

  test(
    'the "Original videos" group: count and bytes from one walk; shown '
    'while the switch is on or the folder holds anything, gone with the '
    'switch off and the folder empty; nothing to delete when empty',
    () async {
      final PreferencesCubit empty = cubit();
      await empty.load();
      expect(empty.state.originals, (count: 0, bytes: 0));
      expect(empty.state.showsOriginals, isFalse);
      expect(empty.state.canDeleteOriginals, isFalse);

      await empty.set(AppPreference.keepOriginals, true);
      expect(empty.state.showsOriginals, isTrue, reason: 'the switch is on');
      expect(empty.state.canDeleteOriginals, isFalse, reason: 'empty');
      await empty.set(AppPreference.keepOriginals, false);
      expect(empty.state.showsOriginals, isFalse);

      // A kept recording and a processed import's original.
      await keep('Profiles/Work/2024-01-05.mp4', <int>[1, 2, 3]);
      await keep('2024-01-06.mov', <int>[4, 5]);
      final PreferencesCubit sut = cubit();
      await sut.load();

      expect(sut.state.originals, (count: 2, bytes: 5));
      expect(sut.state.originalsCount, 2);
      expect(sut.state.originalsBytes, 5);
      expect(sut.state.isOn(AppPreference.keepOriginals), isFalse);
      expect(sut.state.showsOriginals, isTrue, reason: 'the folder holds some');
      expect(sut.state.canDeleteOriginals, isTrue);
    },
  );

  test('a refused delete keeps what stayed: the count and bytes left show, '
      'nothing is deleting, and Delete originals is still offered', () async {
    await keep('Profiles/Work/2024-01-05.mp4', <int>[1, 2]);
    await keep('2024-01-06.mp4', <int>[3, 4]);
    final PreferencesCubit sut = cubit();
    await sut.load();
    expect(sut.state.originals, (count: 2, bytes: 4));
    gallery.deleteResults.addAll(<bool>[true, false]);

    await sut.deleteOriginals();

    expect(sut.state.originals, (count: 1, bytes: 2));
    expect(sut.state.deletingOriginals, isFalse);
    expect(sut.state.canDeleteOriginals, isTrue);
    expect(sut.state.showsOriginals, isTrue);
    expect(log.lines.last, contains('Deleted 1 original video(s)'));
  });
}
