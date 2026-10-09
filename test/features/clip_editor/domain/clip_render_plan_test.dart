// The render the editor's Save asks the media engine for: the trim window
// ending exactly where the selection ends, or the
// photo's length; the stamp as the preview shows it, the place, the
// subtitle, the profile's format and album, and the framing. The engine
// owns the ffmpeg arguments; this is only what goes into them.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clip_editor/domain/canvas_frame.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_length.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_render_plan.dart';
import 'package:one_second_diary/features/clip_editor/domain/edit_clip_draft.dart';
import 'package:one_second_diary/features/clip_editor/domain/trim_selection.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

void main() {
  final LocalDay day = LocalDay(2024, 1, 5);
  const StampStyle coral = StampStyle(
    format: StampFormat.written,
    rgb: 0xEF5558,
    outline: false,
  );
  const ClipRenderLook look = ClipRenderLook(
    stampText: 'January 5, 2024',
    format: ClipFormat.legacy(VideoOrientation.landscape),
  );
  const VideoSource recording = VideoSource(
    path: '/tmp/REC.mp4',
    ownership: ClipOwnership.cameraTemp,
  );

  EditClipDraft draft({
    ClipLength? length,
    ProfileKey profile = ProfileKey.defaultProfile,
    ClipLocation location = const ClipLocation.off(),
    String subtitles = '',
    bool mute = false,
    CanvasFrame? frame,
  }) => EditClipDraft(
    profile: profile,
    length:
        length ??
        TrimmedVideo(
          TrimSelection.initial(sourceMs: 4000).withLength(1000).movedTo(1200),
        ),
    stamp: coral,
    location: location,
    subtitles: subtitles,
    mute: mute,
    frame: frame,
  );

  test('a recording keeps its window exactly, in the profile\'s format', () {
    final ClipRenderRequest request = ClipRenderPlan.of(
      source: recording,
      day: day,
      mode: const AddClip(),
      draft: draft(),
      legacyStampFont: false,
      look: look,
    );

    expect(
      request,
      const VideoRender(
        sourcePath: '/tmp/REC.mp4',
        fromRecording: true,
        trimStartMs: 1200,
        trimEndMs: 2200,
        outputFileName: '2024-01-05.mp4',
        stampText: 'January 5, 2024',
        stampStyle: coral,
        legacyStampFont: false,
        location: ClipLocation.off(),
        subtitles: '',
        format: ClipFormat.legacy(VideoOrientation.landscape),
        albumLabel: 'Default',
      ),
    );
  });

  test('"Save without sound" reaches the request as mute (D28); off, the '
      'request is as before', () {
    ClipRenderRequest of({required bool mute}) => ClipRenderPlan.of(
      source: recording,
      day: day,
      mode: const AddClip(),
      draft: draft(mute: mute),
      legacyStampFont: false,
      look: look,
    );

    expect(of(mute: true).mute, isTrue);
    expect(of(mute: false).mute, isFalse);
    expect(of(mute: false), isA<VideoRender>());
  });

  test('a photo is held for its length, in seconds', () {
    final ClipRenderRequest request = ClipRenderPlan.of(
      source: const PhotoSource(
        path: '/tmp/IMG.jpg',
        ownership: ClipOwnership.pickerCopy,
      ),
      day: day,
      mode: const AddClip(),
      draft: draft(length: const HeldPhoto(1500)),
      legacyStampFont: false,
      look: look,
    );

    expect(
      request,
      const PhotoRender(
        photoPath: '/tmp/IMG.jpg',
        durationSeconds: 1.5,
        outputFileName: '2024-01-05.mp4',
        stampText: 'January 5, 2024',
        stampStyle: coral,
        legacyStampFont: false,
        location: ClipLocation.off(),
        subtitles: '',
        format: ClipFormat.legacy(VideoOrientation.landscape),
        albumLabel: 'Default',
      ),
    );
  });

  test('a replace renders under the name of the clip it replaces, in its '
      "profile's album, with the place, the subtitle and the format", () {
    const ProfileKey trip = ProfileKey('Trip');
    const ClipLocation tokyo = ClipLocation(
      enabled: true,
      text: 'Tokyo, Japan',
      latitude: 35.71,
      longitude: 139.79,
    );
    final ClipFormat ultra = ClipFormatPreset.ultra.format(
      VideoOrientation.portrait,
    );
    final VideoRender request =
        ClipRenderPlan.of(
              source: const VideoSource(
                path: '/pick/beach.mp4',
                ownership: ClipOwnership.userOriginal,
              ),
              day: day,
              mode: ReplaceClip(
                ClipRef(
                  profile: trip,
                  relPath: 'Profiles/Trip/2024-01-05-2.mp4',
                ),
              ),
              draft: draft(
                profile: trip,
                location: tokyo,
                subtitles: 'Rain later',
              ),
              legacyStampFont: true,
              look: ClipRenderLook(stampText: 'January 5, 2024', format: ultra),
            )
            as VideoRender;

    expect(request.outputFileName, '2024-01-05-2.mp4');
    expect(request.albumLabel, 'Trip');
    expect(request.fromRecording, isFalse);
    expect(request.trimEndMs, 2200);
    expect(request.location, tokyo);
    expect(request.subtitles, 'Rain later');
    expect(request.format, ultra);
    expect(request.orientation, VideoOrientation.portrait);
    expect(request.legacyStampFont, isTrue);
  });

  // "Edit again" on a processed import (`EditClipArgs.imported`): the
  // request says so, so the engine keeps `origin=import` and the import's
  // audio path; a pick or a recording never does.
  test('an import opened again renders as an import; a pick does not', () {
    const VideoSource original = VideoSource(
      path: '/originals/2024-01-05.mov',
      ownership: ClipOwnership.userOriginal,
      owned: false,
    );
    VideoRender render({required bool imported}) =>
        ClipRenderPlan.of(
              source: original,
              day: day,
              mode: ReplaceClip(
                ClipRef(
                  profile: ProfileKey.defaultProfile,
                  relPath: '2024-01-05.mp4',
                ),
              ),
              draft: draft(),
              legacyStampFont: false,
              look: look,
              imported: imported,
            )
            as VideoRender;

    expect(render(imported: true).imported, isTrue);
    expect(render(imported: true).fromRecording, isFalse);
    expect(render(imported: false).imported, isFalse);
  });

  test('a video whose length is not known yet has nothing to render (D-1)', () {
    expect(
      () => ClipRenderPlan.of(
        source: recording,
        day: day,
        mode: const AddClip(),
        draft: const EditClipDraft(
          profile: ProfileKey.defaultProfile,
          length: null,
          stamp: coral,
          location: ClipLocation.off(),
          subtitles: '',
        ),
        legacyStampFont: false,
        look: look,
      ),
      throwsStateError,
    );
  });

  group('framing', () {
    const ClipFrame zoomed = ClipFrame(scale: 2, dx: 0.5, dy: 0.5);
    const SourceSize fullHd = (width: 1920, height: 1080);

    ClipRenderRequest of({
      required CanvasFrame? frame,
      required ClipFormat format,
      SourceSize? sourceSize,
    }) => ClipRenderPlan.of(
      source: recording,
      day: day,
      mode: const AddClip(),
      draft: draft(frame: frame),
      legacyStampFont: false,
      look: ClipRenderLook(stampText: '05/01/2024', format: format),
      sourceSize: sourceSize,
    );

    test('the render takes the frame made for its canvas, with the source\'s '
        'size for the engine\'s filter, and none in the other canvas', () {
      const CanvasFrame framed = CanvasFrame(
        canvas: VideoOrientation.landscape,
        frame: zoomed,
      );

      final ClipRenderRequest landscape = of(
        frame: framed,
        format: const ClipFormat.legacy(VideoOrientation.landscape),
        sourceSize: fullHd,
      );
      expect(
        landscape.frame,
        const SourceFrame(frame: zoomed, sourceWidth: 1920, sourceHeight: 1080),
      );
      expect(landscape.crop, isNull, reason: 'the engine reads the frame');

      final ClipRenderRequest portrait = of(
        frame: framed,
        format: const ClipFormat.legacy(VideoOrientation.portrait),
        sourceSize: fullHd,
      );
      expect(portrait.frame, isNull);
      expect(portrait.crop, isNull);
    });

    test('a frame with bars keeps its fill; a source of unknown size goes '
        'without a frame (the engine\'s default fit); no frame means no '
        'frame and no crop', () {
      final ClipRenderRequest fitted = of(
        frame: const CanvasFrame(
          canvas: VideoOrientation.portrait,
          frame: ClipFrame(scale: 0.5625, fill: FrameFill.blur),
        ),
        format: const ClipFormat.legacy(VideoOrientation.portrait),
        sourceSize: fullHd,
      );
      expect(fitted.frame?.frame.fill, FrameFill.blur);
      expect(fitted.frame?.sourceWidth, 1920);
      expect(fitted.crop, isNull);

      final ClipRenderRequest unknown = of(
        frame: const CanvasFrame(
          canvas: VideoOrientation.landscape,
          frame: zoomed,
        ),
        format: const ClipFormat.legacy(VideoOrientation.landscape),
      );
      expect(unknown.frame, isNull);
      expect(unknown.crop, isNull);

      final ClipRenderRequest plain = of(
        frame: null,
        format: const ClipFormat.legacy(VideoOrientation.landscape),
        sourceSize: fullHd,
      );
      expect(plain.frame, isNull);
      expect(plain.crop, isNull);
    });
  });

  // HDR: the source's probed transfer reaches the
  // request, so the engine converts the range; none means SDR.
  test('the source\'s colour transfer rides along into the request', () {
    final ClipRenderRequest hdr = ClipRenderPlan.of(
      source: recording,
      day: day,
      mode: const AddClip(),
      draft: draft(),
      legacyStampFont: false,
      look: const ClipRenderLook(
        stampText: '05/01/2024',
        format: ClipFormat.legacy(VideoOrientation.landscape),
      ),
      sourceColorTransfer: 'smpte2084',
    );
    expect(hdr.sourceColorTransfer, 'smpte2084');
    expect(hdr.sourceIsHdr, isTrue);
    final ClipRenderRequest sdr = ClipRenderPlan.of(
      source: recording,
      day: day,
      mode: const AddClip(),
      draft: draft(),
      legacyStampFont: false,
      look: const ClipRenderLook(
        stampText: '05/01/2024',
        format: ClipFormat.legacy(VideoOrientation.landscape),
      ),
    );
    expect(sdr.sourceColorTransfer, isNull);
    expect(sdr.sourceIsHdr, isFalse);
  });
}
