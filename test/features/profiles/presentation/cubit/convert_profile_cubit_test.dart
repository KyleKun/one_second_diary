// "Convert into a new profile": the pre-filled name and target, the
// estimate per target, the same quality refused, and "Convert" making the
// profile with the target format and running the converter into it,
// following its progress to the end (or a stop).

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/storage/storage_budget.dart';
import 'package:one_second_diary/features/clips/domain/clip_conversion.dart';
import 'package:one_second_diary/features/profiles/data/device_media_profile_store.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/domain/profile_name_error.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/convert_profile_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/convert_profile_state.dart';

import '../../../../shared/fakes/fake_app_info_gateway.dart';
import '../../../../shared/fakes/fake_profile_conversion_starter.dart';
import '../../../../support/support.dart';

void main() {
  late MemoryLogSink log;
  late FakeProfileConversionStarter converter;
  late ProfilesRepository profiles;

  const ProfileKey travel = ProfileKey('Travel');
  final ClipFormat ultra = ClipFormatPreset.ultra.format(
    VideoOrientation.portrait,
  );
  final ClipFormat high = ClipFormatPreset.high.format(
    VideoOrientation.portrait,
  );

  setUp(() {
    log = MemoryLogSink();
    converter = FakeProfileConversionStarter();
  });

  /// A diary with Default and a portrait "Travel" profile of [format].
  Future<ConvertProfileCubit> entryFor(
    ProfileKey source, {
    String travelFormat = '1080p30-h264-mono-sdr',
  }) async {
    final PrefsStore prefs = await openLegacyPrefs(
      legacyPrefs(
        profiles: <String>['Default', 'Travel'],
        orientations: <String, String>{'Travel': 'portrait'},
        extra: <String, Object>{'clipFormat_Travel': travelFormat},
      ),
    );
    profiles = ProfilesRepository(
      prefs: prefs,
      paths: await createTestPaths(),
      mediaStore: FakeMediaStoreGateway(),
      clock: FakeClock(DateTime(2026, 10, 7)),
      logger: memoryLogger(log),
      defaultLabel: () => 'Default',
    );
    final ConvertProfileCubit cubit = ConvertProfileCubit(
      source: source,
      profiles: profiles,
      converter: converter,
      deviceProfile: DeviceMediaProfileStore(
        prefs: prefs,
        appInfo: FakeAppInfoGateway(),
        deviceInfo: FakeDeviceInfoGateway(),
        logger: memoryLogger(log),
      ),
      isIOS: false,
      defaultNameOf: (String name, ClipFormat target) =>
          '$name ${target.tier.token}',
      logger: memoryLogger(log),
    );
    addTearDown(cubit.close);
    await pumpEventQueue();
    return cubit;
  }

  test('opens on the source profile with a pre-filled name and target '
      '(never checked: Ultra, on the source\'s canvas), and the estimate '
      'for it; a target picked re-estimates and renames until the user '
      'typed', () async {
    final ConvertProfileCubit entry = await entryFor(travel);

    expect(entry.state.source.key, travel);
    expect(entry.state.target, ultra);
    expect(entry.state.name, 'Travel 2160');
    expect(entry.state.nameError, isNull);
    expect(entry.state.estimate, converter.answer);
    expect(entry.state.status, ConvertProfileStatus.editing);
    expect(entry.state.canStart, isTrue);
    expect(converter.estimated, <(ProfileKey, ClipFormat)>[(travel, ultra)]);

    await entry.targetPicked(high.withOrientation(VideoOrientation.landscape));

    expect(entry.state.target, high, reason: 'on the source canvas');
    expect(entry.state.name, 'Travel 1440');
    expect(converter.estimated.last, (travel, high));

    entry.nameChanged('Trips');
    await entry.targetPicked(ultra);
    expect(entry.state.name, 'Trips');
  });

  test('the name is checked like any new name; the source\'s own quality '
      'is refused; an estimate that does not fit blocks Convert', () async {
    final ConvertProfileCubit entry = await entryFor(travel);

    entry.nameChanged('default');
    expect(entry.state.nameError, ProfileNameError.reserved);
    expect(entry.state.canStart, isFalse);
    entry.nameChanged('Travel');
    expect(entry.state.nameError, ProfileNameError.duplicate);
    entry.nameChanged('Trips');
    expect(entry.state.nameError, isNull);
    expect(entry.state.canStart, isTrue);

    await entry.targetPicked(
      ClipFormatPreset.standard.format(VideoOrientation.portrait),
    );
    expect(entry.state.sameQuality, isTrue);
    expect(entry.state.canStart, isFalse);
    expect(entry.state.estimate, isNull);
    expect(entry.state.status, ConvertProfileStatus.editing);

    converter.answer = const ConversionEstimate(
      clipCount: 12,
      totalDurationMs: 24000,
      estimatedTime: Duration(minutes: 3),
      neededBytes: 3000,
      verdict: StorageShort(shortfallBytes: 2000),
      sameFormat: false,
    );
    await entry.targetPicked(ultra);
    expect(entry.state.estimate!.canStart, isFalse);
    expect(entry.state.canStart, isFalse);
  });

  test('Convert makes the profile under the trimmed name with the target '
      'format, runs the converter into it, follows its progress and ends '
      'done with the report', () async {
    final ConvertProfileCubit entry = await entryFor(travel);
    entry.nameChanged('  Trips 4K ');
    final List<ConvertProfileStatus> seen = <ConvertProfileStatus>[];
    entry.stream.listen((ConvertProfileState state) => seen.add(state.status));

    await entry.start();
    await pumpEventQueue();

    final Profile created = profiles.profiles.last;
    expect(created.displayName, 'Trips 4K');
    expect(created.orientation, VideoOrientation.portrait);
    expect(created.format, ultra);
    expect(converter.jobs, <ConversionJob>[
      ConversionJob(source: travel, target: created.key, format: ultra),
    ]);
    expect(entry.state.created, created);
    expect(seen, <ConvertProfileStatus>[
      ConvertProfileStatus.starting,
      ConvertProfileStatus.running,
      ConvertProfileStatus.running,
      ConvertProfileStatus.done,
    ]);
    expect(entry.state.progress, converter.events.first);
    expect(entry.state.report?.done, 12);
    expect(entry.state.report?.complete, isTrue);
    expect(entry.state.isBusy, isFalse);
    expect(entry.state.isOver, isTrue);
  });

  test('Stop cancels the run: the state ends cancelled with what was done '
      '(the converter keeps it) and the new profile stays', () async {
    final ConvertProfileCubit entry = await entryFor(travel);
    final List<ConvertProfileStatus> seen = <ConvertProfileStatus>[];
    entry.stream.listen((ConvertProfileState state) => seen.add(state.status));

    await entry.start();
    expect(entry.state.status, ConvertProfileStatus.running);
    entry.cancel();
    await pumpEventQueue();

    expect(entry.state.status, ConvertProfileStatus.cancelled);
    expect(entry.state.report?.cancelled, isTrue);
    expect(entry.state.report?.done, 0);
    expect(profiles.profiles.map((Profile p) => p.displayName), <String>[
      'Default',
      'Travel',
      'Travel 2160',
    ]);
    expect(seen, isNot(contains(ConvertProfileStatus.done)));
    expect(entry.state.isOver, isTrue);
  });

  test('a name taken meanwhile, or a converter that fails, ends in '
      'startFailed, logged; the sheet stays', () async {
    final ConvertProfileCubit entry = await entryFor(travel);
    entry.nameChanged('Trips');
    await profiles.create(
      displayName: 'Trips',
      orientation: VideoOrientation.portrait,
    );

    await entry.start();

    expect(entry.state.status, ConvertProfileStatus.startFailed);
    expect(converter.jobs, isEmpty);
    expect(log.lines, anyElement(contains('[ERROR]')));

    converter.error = StateError('the engine is gone');
    final ConvertProfileCubit failing = await entryFor(travel);
    await failing.start();
    await pumpEventQueue();
    expect(failing.state.status, ConvertProfileStatus.startFailed);
    expect(failing.state.created, isNotNull, reason: 'the profile was made');
  });

  test('a source that already has the pick pre-fills the best preset '
      'instead; a source not listed is refused', () async {
    final ConvertProfileCubit entry = await entryFor(
      travel,
      travelFormat: ultra.toString(),
    );
    expect(entry.state.source.format, ultra);
    expect(entry.state.target, isNot(ultra));
    expect(entry.state.sameQuality, isFalse);

    await expectLater(
      () => entryFor(const ProfileKey('Nope')),
      throwsArgumentError,
    );
  });
}
