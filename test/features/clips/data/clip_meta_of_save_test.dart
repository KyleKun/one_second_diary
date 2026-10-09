import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/movie_plan.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/media/types/clip_recipe.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/movie_clip.dart';
import 'package:one_second_diary/core/media/types/rendered_clip.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clips/data/clip_meta_of_save.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';

PhotoRender _photo({required ClipLocation location}) => PhotoRender(
  photoPath: '/tmp/IMG_1.jpg',
  durationSeconds: 1.5,
  outputFileName: '2024-01-05.mp4',
  stampText: '05/01/2024',
  stampStyle: const StampStyle(
    format: StampFormat.written,
    rgb: 0,
    outline: false,
  ),
  legacyStampFont: false,
  location: location,
  subtitles: '',
  format: const ClipFormat.legacy(VideoOrientation.portrait),
  albumLabel: 'Default',
);

const RenderedClip _rendered = RenderedClip(
  tempPath: '/scratch/2024-01-05.mp4',
  durationMs: 1500,
  hasSubtitleStream: false,
  width: 1080,
  height: 1920,
);

VideoRender _recording() => const VideoRender(
  sourcePath: '/tmp/REC_1.mp4',
  fromRecording: true,
  trimStartMs: 0,
  trimEndMs: 2000,
  outputFileName: '2024-01-05.mp4',
  stampText: '05/01/2024',
  stampStyle: StampStyle(format: StampFormat.written, rgb: 0, outline: false),
  legacyStampFont: false,
  location: ClipLocation.off(),
  subtitles: '',
  format: ClipFormat.legacy(VideoOrientation.landscape),
  albumLabel: 'Default',
);

RenderedClip _renderedWith({
  required bool? hasAudio,
  ClipKeyframes? keyframes,
}) => RenderedClip(
  tempPath: '/scratch/2024-01-05.mp4',
  durationMs: 2000,
  hasSubtitleStream: false,
  width: 1920,
  height: 1080,
  hasAudio: hasAudio,
  keyframes: keyframes,
);

void main() {
  // The save keeps a recording's own audio (`-map 1:a?`), so a recording
  // made without a microphone has no audio stream. Claiming one makes every
  // movie join it as it is and lose its audio.
  test(
    'copies the engine\'s audio fact (a silent recording is normalised in '
    'a movie); a typed place without coordinates is not cached (pin D-4)',
    () {
      for (final bool? hasAudio in <bool?>[false, true, null]) {
        final ClipMeta meta = clipMetaOfSave(
          rendered: _renderedWith(hasAudio: hasAudio),
          request: _recording(),
        );

        expect(meta.hasAudio, hasAudio);
        // The legacy format's facts, known from the request: the
        // v1.5 marker, 30 fps, mono; the engine's answer wins when given.
        expect(meta.schema, ClipSchema.v15);
        expect(meta.isOsdV15, isTrue);
        expect((meta.fps, meta.channels), (30, 1));
        expect(meta.pixelFormat, isNull);
        expect(
          MoviePlan.needsNormalising(
            MovieClip(
              path: '/videos/2024-01-05.mp4',
              durationMs: meta.durationMs,
              isOsdV15: meta.isOsdV15,
              hasAudio: meta.hasAudio,
              hasSubtitleStream: meta.hasSubtitleStream,
              width: meta.width,
              height: meta.height,
              codec: meta.codec,
              fps: meta.fps,
              channels: meta.channels,
              pixelFormat: meta.pixelFormat,
              colorTransfer: meta.colorTransfer,
              schema: meta.schema,
            ),
            format: const ClipFormat.legacy(VideoOrientation.landscape),
          ),
          hasAudio != true,
          reason: '$hasAudio',
        );
      }

      // A typed place without coordinates is not tagged, so it is not cached
      // either (a probe would find no place).
      {
        final ClipMeta meta = clipMetaOfSave(
          rendered: _rendered,
          request: _photo(
            location: const ClipLocation(enabled: true, text: 'Home'),
          ),
        );

        expect(meta.locationText, '');
        expect(meta.latitude, isNull);
        expect(meta.longitude, isNull);
        expect(meta.subtitleText, '');
        expect(meta.hasSubtitleStream, isFalse);
        expect(meta.origin, ClipOrigin.galleryPhoto);
      }

      // What the engine reports about the render wins over the request.
      {
        final ClipMeta meta = clipMetaOfSave(
          rendered: const RenderedClip(
            tempPath: '/scratch/2024-01-05.mp4',
            durationMs: 2000,
            hasSubtitleStream: false,
            width: 1920,
            height: 1080,
            fps: 30,
            channels: 1,
            pixelFormat: 'yuv420p',
            schema: ClipSchema.v15,
          ),
          request: _recording(),
        );
        expect(meta.pixelFormat, 'yuv420p');
        expect(meta.schema, ClipSchema.v15);
      }

      // The keyframes are the engine's probe of the new file, as they are:
      // a failed probe leaves them unknown, never guessed from the save.
      {
        const ClipKeyframes probed = ClipKeyframes(
          frameCount: 60,
          indices: <int>[0, 10, 50],
        );
        expect(
          clipMetaOfSave(
            rendered: _renderedWith(hasAudio: true, keyframes: probed),
            request: _recording(),
          ).keyframes,
          probed,
        );
        expect(
          clipMetaOfSave(
            rendered: _renderedWith(hasAudio: true),
            request: _recording(),
          ).keyframes,
          isNull,
        );
      }
    },
  );

  // The recipe is the store's to give (only when the save kept the clip's
  // source): without one the entry carries none.
  test('carries the recipe when the save kept the source, none otherwise', () {
    final ClipRecipe? recipe = ClipRecipe.of(_recording());
    expect(recipe, isNotNull);
    expect(
      clipMetaOfSave(
        rendered: _rendered,
        request: _recording(),
        recipe: recipe,
      ).recipe,
      recipe,
    );
    expect(
      clipMetaOfSave(rendered: _rendered, request: _recording()).recipe,
      isNull,
    );
  });

  // The codec fact follows the request's format (an HEVC clip said `h264`
  // before, so every HEVC movie normalised every clip); so does the
  // engine's colour transfer (HLG for an HLG format).
  test('the codec and the colour transfer are the format\'s and the '
      'engine\'s', () {
    const ClipFormat hlg = ClipFormat(
      tier: ResolutionTier.p1080,
      orientation: VideoOrientation.landscape,
      codec: VideoCodec.hevc,
      fps: FrameRate.f30,
      channels: AudioChannels.stereo,
      range: DynamicRange.hlg,
    );
    final ClipMeta meta = clipMetaOfSave(
      rendered: const RenderedClip(
        tempPath: '/scratch/2024-01-05.mp4',
        durationMs: 2000,
        hasSubtitleStream: false,
        width: 1920,
        height: 1080,
        hasAudio: true,
        pixelFormat: 'yuv420p10le',
        colorTransfer: 'arib-std-b67',
        schema: ClipSchema.v2,
      ),
      request: const VideoRender(
        sourcePath: '/tmp/IMG_1.MOV',
        fromRecording: false,
        trimStartMs: 0,
        trimEndMs: 2000,
        outputFileName: '2024-01-05.mp4',
        stampText: '05/01/2024',
        stampStyle: StampStyle(
          format: StampFormat.written,
          rgb: 0,
          outline: false,
        ),
        legacyStampFont: false,
        location: ClipLocation.off(),
        subtitles: '',
        format: hlg,
        albumLabel: 'Default',
        sourceColorTransfer: 'arib-std-b67',
      ),
    );
    expect(meta.codec, 'hevc');
    expect(meta.colorTransfer, 'arib-std-b67');
    expect(meta.pixelFormat, 'yuv420p10le');
    expect(meta.schema, ClipSchema.v2);
    expect(
      MoviePlan.needsNormalising(
        MovieClip(
          path: '/videos/2024-01-05.mp4',
          durationMs: meta.durationMs,
          isOsdV15: meta.isOsdV15,
          hasAudio: meta.hasAudio,
          hasSubtitleStream: meta.hasSubtitleStream,
          width: meta.width,
          height: meta.height,
          codec: meta.codec,
          fps: meta.fps,
          channels: meta.channels,
          pixelFormat: meta.pixelFormat,
          colorTransfer: meta.colorTransfer,
          schema: meta.schema,
        ),
        format: hlg,
      ),
      isFalse,
      reason: 'an HLG clip joins an HLG movie raw',
    );
    expect(
      clipMetaOfSave(
        rendered: _renderedWith(hasAudio: true),
        request: _recording(),
      ).codec,
      'h264',
    );
  });
}
