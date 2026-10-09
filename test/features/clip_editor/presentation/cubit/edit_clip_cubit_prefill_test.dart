// EditClipCubit and "Edit again": a recipe pre-fills
// the window, the framing, the stamp style and the mute, each clamped to
// the source; a source the editor does not own is never discarded; the
// source's size is read for the framing.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/clip_recipe.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clip_editor/domain/canvas_frame.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clips/data/saved_places.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
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
  const VideoSource original = VideoSource(
    path: '/originals/2024-01-05.mp4',
    ownership: ClipOwnership.cameraTemp,
    owned: false,
  );
  const StampStyle coral = StampStyle(
    format: StampFormat.written,
    rgb: 0xEF5558,
    outline: false,
  );
  const ClipFrame zoomed = ClipFrame(scale: 2, dx: 0.5, dy: 0.5);
  const ClipRecipe recipe = ClipRecipe(
    trimStartMs: 2000,
    trimEndMs: 4500,
    frame: zoomed,
    stampStyle: coral,
    mute: true,
    format: ClipFormat.legacy(VideoOrientation.landscape),
  );

  late FakeClipSaver saver;

  Future<EditClipCubit> editorOf(
    ClipSource source, {
    ClipRecipe? prefill,
  }) async {
    saver = FakeClipSaver();
    final EditClipCubit cubit = EditClipCubit(
      args: EditClipArgs(
        source: source,
        day: day,
        profile: ProfileKey.defaultProfile,
        prefill: prefill,
      ),
      settings: SettingsRepository(prefs: await openLegacyPrefs(legacyPrefs())),
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

  test(
    'a recipe pre-fills the stamp style, the mute, the framing on its '
    'canvas and, once the length is known, the window where it fits',
    () async {
      final EditClipCubit cubit = await editorOf(original, prefill: recipe);

      expect(cubit.state.draft.stamp, coral);
      expect(cubit.state.draft.mute, isTrue);
      expect(
        cubit.state.draft.frame,
        const CanvasFrame(canvas: VideoOrientation.landscape, frame: zoomed),
      );
      expect(cubit.state.draft.frameFor(VideoOrientation.portrait), isNull);

      cubit.sourceLoaded(const Duration(seconds: 8), aspectRatio: 16 / 9);
      expect(
        (cubit.state.trim?.startMs, cubit.state.trim?.endMs),
        (2000, 4500),
      );
    },
  );

  test('a recipe that no longer fits is dropped field by field: a window '
      'past the source opens as without one, a frame is clamped to the '
      'source once its size is known', () async {
    final EditClipCubit short = await editorOf(original, prefill: recipe);
    short.sourceLoaded(const Duration(milliseconds: 1800), aspectRatio: 16 / 9);
    expect((short.state.trim?.startMs, short.state.trim?.endMs), (0, 1800));

    // A 2× frame pushed to the corner of a source that fills the canvas:
    // the offset is as far as the clamp allows, so it survives; one past
    // the clamp comes back inside.
    saver = FakeClipSaver();
    final EditClipCubit framed = await editorOf(
      original,
      prefill: const ClipRecipe(
        trimStartMs: 0,
        trimEndMs: 1000,
        frame: ClipFrame(scale: 2, dx: 3, dy: -3),
        stampStyle: coral,
        mute: false,
        format: ClipFormat.legacy(VideoOrientation.landscape),
      ),
    );
    saver.sizes['/originals/2024-01-05.mp4'] = (width: 1920, height: 1080);
    framed.sourceLoaded(const Duration(seconds: 4), aspectRatio: 16 / 9);
    await pumpEventQueue();

    expect(framed.state.sourceSize, (width: 1920, height: 1080));
    expect(
      framed.state.draft.frameFor(VideoOrientation.landscape),
      const ClipFrame(scale: 2, dx: 0.5, dy: -0.5),
    );

    // A frame that is the default once clamped is none.
    saver = FakeClipSaver();
    final EditClipCubit plain = await editorOf(
      original,
      prefill: const ClipRecipe(
        trimStartMs: 0,
        trimEndMs: 1000,
        frame: ClipFrame(scale: 0.2, dx: 0.3),
        stampStyle: coral,
        mute: false,
        format: ClipFormat.legacy(VideoOrientation.landscape),
      ),
    );
    saver.sizes['/originals/2024-01-05.mp4'] = (width: 1920, height: 1080);
    plain.sourceLoaded(const Duration(seconds: 4), aspectRatio: 16 / 9);
    await pumpEventQueue();
    expect(plain.state.draft.frame, isNull);
  });

  test(
    'the source\'s size is read upright, the way the preview shows it, '
    'with its colour transfer; one that cannot be read stays unknown',
    () async {
      final EditClipCubit cubit = await editorOf(original);
      saver.sizes['/originals/2024-01-05.mp4'] = (width: 1920, height: 1080);
      saver.transfers['/originals/2024-01-05.mp4'] = 'arib-std-b67';
      // The player says the picture is upright (a phone held portrait).
      cubit.sourceLoaded(const Duration(seconds: 4), aspectRatio: 9 / 16);
      await pumpEventQueue();
      expect(cubit.state.sourceSize, (width: 1080, height: 1920));
      expect(cubit.state.sourceColorTransfer, 'arib-std-b67');

      final EditClipCubit unknown = await editorOf(original);
      unknown.sourceLoaded(const Duration(seconds: 4), aspectRatio: 16 / 9);
      await pumpEventQueue();
      expect(unknown.state.sourceSize, isNull);
      expect(unknown.state.sourceColorTransfer, isNull);
    },
  );

  test('without a recipe the editor opens with its defaults', () async {
    final EditClipCubit cubit = await editorOf(original);
    expect(cubit.state.draft.mute, isFalse);
    expect(cubit.state.draft.frame, isNull);
    cubit.sourceLoaded(const Duration(seconds: 8), aspectRatio: 16 / 9);
    expect(cubit.state.trim?.lengthMs, 1500);
  });
}
