// EditClipCubit: the Save. It renders what the user sees and ends with the
// SavedClip the editor pops with; it runs once however often Save is tapped;
// Cancel stops the render; a failure lets the user try again; leaving
// discards the source the app owns.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_render_plan.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_state.dart';
import 'package:one_second_diary/features/clips/data/saved_places.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../support/support.dart';
import '../../support/fake_clip_saver.dart';
import '../../support/fake_location_service.dart';
import '../../support/fake_recent_places.dart';

void main() {
  final LocalDay day = LocalDay(2024, 1, 5);
  const VideoSource recording = VideoSource(
    path: '/tmp/REC.mp4',
    ownership: ClipOwnership.cameraTemp,
  );
  const ClipRenderLook look = ClipRenderLook(
    stampText: '01/05/2024',
    format: ClipFormat.legacy(VideoOrientation.landscape),
  );

  late FakeClipSaver saver;

  Future<EditClipCubit> editorOf(
    ClipSource source, {
    ClipSaveMode mode = const AddClip(),
    Map<String, Object> prefs = const <String, Object>{},
  }) async {
    saver = FakeClipSaver();
    final EditClipCubit cubit = EditClipCubit(
      args: EditClipArgs(
        source: source,
        day: day,
        profile: ProfileKey.defaultProfile,
        mode: mode,
      ),
      settings: SettingsRepository(
        prefs: await openLegacyPrefs(legacyPrefs(extra: prefs)),
      ),
      clips: FakeClipRepository(),
      locations: FakeLocationService(),
      savedPlaces: SavedPlaces(
        prefs: await openLegacyPrefs(legacyPrefs()),
        logger: memoryLogger(MemoryLogSink()),
      ),
      metadata: FakeRecentPlaces(),
      saver: saver,
      logger: memoryLogger(MemoryLogSink()),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<EditClipCubit> loaded() async {
    final EditClipCubit cubit = await editorOf(recording);
    cubit.sourceLoaded(const Duration(seconds: 4), aspectRatio: 16 / 9);
    return cubit;
  }

  test(
    'Save renders what the user sees, and ends saved with the clip',
    () async {
      final EditClipCubit cubit = await loaded();
      await cubit.quickCut(1000);
      cubit.subtitlesChanged('Rain later');

      final Future<void> saving = cubit.save(look);

      expect(cubit.state.saveStatus, SaveStatus.rendering);
      expect(saver.calls.single.request, isA<VideoRender>());
      final VideoRender request = saver.calls.single.request as VideoRender;
      expect(request.trimStartMs, 0);
      expect(request.trimEndMs, 1500);
      expect(request.subtitles, 'Rain later');
      expect(request.stampStyle, isA<StampStyle>());
      expect(request.location, const ClipLocation.off());
      expect(saver.calls.single.source, recording);
      expect(saver.calls.single.day, day);

      saver.finish();
      await saving;

      expect(cubit.state.saveStatus, SaveStatus.saved);
      expect(cubit.state.saved, savedJanuary5);
    },
  );

  test('a stamp colour that cannot be read saves white', () async {
    final EditClipCubit cubit = await editorOf(
      recording,
      prefs: <String, Object>{'dateColor': 'garbage'},
    );
    cubit.sourceLoaded(const Duration(seconds: 4), aspectRatio: 16 / 9);

    final Future<void> saving = cubit.save(look);

    final VideoRender request = saver.calls.single.request as VideoRender;
    expect(request.stampStyle.rgb, 0xFFFFFF);
    saver.finish();
    await saving;
    expect(cubit.state.saveStatus, SaveStatus.saved);
  });

  // The render never reads as done before the clip is filed.
  test('shows how far the render is, at most 99 % until the clip is being '
      'filed, ignoring a report that is not a number (CL-18)', () async {
    final EditClipCubit cubit = await loaded();
    final Future<void> saving = cubit.save(look);

    saver.progress(.4);
    expect(cubit.state.saveProgress, .4);

    saver.progress(double.nan);
    expect(cubit.state.saveProgress, .4);

    saver.progress(1.4);
    expect(cubit.state.saveProgress, .99);

    saver.publishing();
    expect(cubit.state.saveStatus, SaveStatus.publishing);
    expect(cubit.state.saveProgress, 1);

    saver.finish();
    await saving;
  });

  test('a second tap while saving does nothing', () async {
    final EditClipCubit cubit = await loaded();

    final Future<void> first = cubit.save(look);
    await cubit.save(look);

    expect(saver.calls, hasLength(1));
    expect(cubit.state.canSave, isFalse);
    saver.finish();
    await first;
  });

  test('nothing is saved before the source reports its length (D-1)', () async {
    final EditClipCubit cubit = await editorOf(recording);

    await cubit.save(look);

    expect(saver.calls, isEmpty);
    expect(cubit.state.saveStatus, SaveStatus.idle);
  });

  group('Cancel', () {
    test('stops the render; the draft is kept and can be saved again; once '
        'the clip is being filed it is too late', () async {
      final EditClipCubit cubit = await loaded();
      await cubit.quickCut(2000);
      final Future<void> saving = cubit.save(look);

      cubit.cancelSave();
      expect(cubit.state.saveStatus, SaveStatus.cancelling);
      await saving;

      expect(cubit.state.saveStatus, SaveStatus.idle);
      expect(cubit.state.saveProgress, 0);
      expect(cubit.state.trim?.lengthMs, 2000);
      expect(cubit.state.canSave, isTrue);

      final Future<void> again = cubit.save(look);
      saver.publishing();
      cubit.cancelSave();

      expect(cubit.state.saveStatus, SaveStatus.publishing);
      saver.finish();
      await again;
      expect(cubit.state.saveStatus, SaveStatus.saved);
    });

    test('leaving the editor stops a render still running', () async {
      final EditClipCubit cubit = await loaded();
      final Future<void> saving = cubit.save(look);

      await cubit.close();
      await saving;

      expect(saver.running, isFalse);
    });
  });

  group('a failure', () {
    test('ends failed, and Save tries again from the start', () async {
      final EditClipCubit cubit = await loaded();
      final Future<void> first = cubit.save(look);
      saver.progress(.7);

      saver.fail();
      await first;

      expect(cubit.state.saveStatus, SaveStatus.failed);
      expect(cubit.state.saveProgress, 0);
      expect(cubit.state.canSave, isTrue);

      final List<SaveStatus> statuses = <SaveStatus>[];
      cubit.stream.listen(
        (EditClipState state) => statuses.add(state.saveStatus),
      );
      final Future<void> second = cubit.save(look);
      saver.fail();
      await second;
      await pumpEventQueue();

      // In progress before each attempt: the failure shows every time.
      expect(statuses, <SaveStatus>[SaveStatus.rendering, SaveStatus.failed]);
      expect(saver.calls, hasLength(2));
    });

    // A full phone is said as such, not as an error to report.
    test('says when the phone is full (ENOSPC), and judges the next one '
        'afresh', () async {
      final EditClipCubit cubit = await loaded();
      final Future<void> first = cubit.save(look);
      saver.fail(
        const FileSystemException(
          'Cannot write the clip',
          '/scratch/2024-01-05.mp4',
          OSError('No space left on device', 28),
        ),
      );
      await first;

      expect(cubit.state.saveStatus, SaveStatus.failed);
      expect(cubit.state.saveFailure, SaveFailure.outOfSpace);

      final Future<void> second = cubit.save(look);
      saver.fail();
      await second;

      expect(cubit.state.saveFailure, SaveFailure.unexpected);
    });
  });

  test('discarding gives the source up', () async {
    final EditClipCubit cubit = await loaded();

    await cubit.discard();

    expect(saver.discarded, <ClipSource>[recording]);
  });
}
