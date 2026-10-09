// ClipRecipe: how a clip was made from its source, stored in the sidecar for "Edit
// again". The JSON round-trips; anything malformed reads as no recipe, never a guess.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_recipe.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

void main() {
  final ClipRecipe framed = ClipRecipe(
    trimStartMs: 1200,
    trimEndMs: 2700,
    frame: const ClipFrame(scale: 1.5, dx: 0.1, dy: -0.2, fill: FrameFill.blur),
    stampStyle: const StampStyle(
      format: StampFormat.written,
      rgb: 0xEF5558,
      outline: false,
    ),
    mute: true,
    format: ClipFormatPreset.high.format(VideoOrientation.portrait),
  );
  const ClipRecipe plain = ClipRecipe(
    trimStartMs: 0,
    trimEndMs: 1500,
    frame: null,
    stampStyle: StampStyle(
      format: StampFormat.numeric,
      rgb: 0xFFFFFF,
      outline: true,
    ),
    mute: false,
    format: ClipFormat.legacy(VideoOrientation.landscape),
  );

  test('writes the plan\'s keys and reads them back, through a JSON string; '
      'a default framing has no frame key', () {
    expect(plain.toJson(), <String, Object?>{
      'trimStartMs': 0,
      'trimEndMs': 1500,
      'stamp': <String, Object?>{
        'format': 'numeric',
        'rgb': 16777215,
        'outline': true,
        'size': 'medium',
      },
      'mute': false,
      'format': '1080p30-h264-mono-sdr',
      'orientation': 'landscape',
    });
    expect(framed.toJson()['frame'], <String, Object?>{
      'scale': 1.5,
      'dx': 0.1,
      'dy': -0.2,
      'fill': 'blur',
    });
    expect(framed.toJson()['format'], '1440p30-hevc-stereo-sdr');

    for (final ClipRecipe recipe in <ClipRecipe>[plain, framed]) {
      final Object? decoded = jsonDecode(jsonEncode(recipe.toJson()));
      expect(ClipRecipe.fromJson(decoded), recipe);
    }
  });

  test('anything malformed reads as no recipe: a missing or mistyped key, '
      'an unknown format, orientation, fill or stamp format, a window that '
      'ends before it starts; an unknown key is ignored', () {
    final Map<String, Object?> good = plain.toJson();
    Map<String, Object?> with_(String key, Object? value) => <String, Object?>{
      ...good,
      key: value,
    };
    Map<String, Object?> without(String key) =>
        <String, Object?>{...good}..remove(key);

    final Map<String, Map<String, Object?>> bad =
        <String, Map<String, Object?>>{
          'no start': without('trimStartMs'),
          'string start': with_('trimStartMs', '0'),
          'negative start': with_('trimStartMs', -1),
          'end before start': with_('trimEndMs', 0),
          'no stamp': without('stamp'),
          'stamp format unknown': with_('stamp', <String, Object?>{
            'format': 'roman',
            'rgb': 1,
            'outline': true,
          }),
          'no mute': without('mute'),
          'format unknown': with_('format', '1080p25-h264-mono-sdr'),
          'no orientation': without('orientation'),
          'orientation unknown': with_('orientation', 'square'),
          'frame mistyped': with_('frame', <String, Object?>{'scale': 'big'}),
          'fill unknown': with_('frame', <String, Object?>{
            'scale': 1,
            'dx': 0,
            'dy': 0,
            'fill': 'mirror',
          }),
          'scale zero': with_('frame', <String, Object?>{
            'scale': 0,
            'dx': 0,
            'dy': 0,
            'fill': 'black',
          }),
        };
    for (final MapEntry<String, Map<String, Object?>> row in bad.entries) {
      expect(ClipRecipe.fromJson(row.value), isNull, reason: row.key);
    }
    expect(ClipRecipe.fromJson(null), isNull);
    expect(ClipRecipe.fromJson('recipe'), isNull);
    expect(ClipRecipe.fromJson(<String, Object?>{}), isNull);

    expect(ClipRecipe.fromJson(with_('subtitles', 'ignored')), plain);
    // Whole-number frame values come back from JSON as ints.
    expect(
      ClipRecipe.fromJson(
        with_('frame', <String, Object?>{
          'scale': 2,
          'dx': 0,
          'dy': 0,
          'fill': 'black',
        }),
      )?.frame,
      const ClipFrame(scale: 2),
    );
  });

  // The stamp's text size (owner request 2026-10-07) is additive: a recipe
  // written before it, or by a build with a size this one does not know,
  // reads as medium (the size those clips were burned with), never as no
  // recipe; a known token round-trips.
  test('the stamp size round-trips; a stamp without one, or with an unknown '
      'or mistyped one, is medium', () {
    const ClipRecipe large = ClipRecipe(
      trimStartMs: 0,
      trimEndMs: 1500,
      frame: null,
      stampStyle: StampStyle(
        format: StampFormat.numeric,
        rgb: 0xFFFFFF,
        outline: true,
        size: StampSize.large,
      ),
      mute: false,
      format: ClipFormat.legacy(VideoOrientation.landscape),
    );
    final Map<String, Object?> json = large.toJson();
    expect((json['stamp']! as Map<String, Object?>)['size'], 'large');
    expect(ClipRecipe.fromJson(jsonDecode(jsonEncode(json))), large);
    expect(ClipRecipe.fromJson(json), isNot(plain));

    Map<String, Object?> stampWith(Object? size) => <String, Object?>{
      ...plain.toJson(),
      'stamp': <String, Object?>{
        'format': 'numeric',
        'rgb': 16777215,
        'outline': true,
        if (size != 'absent') 'size': size,
      },
    };
    for (final Object? size in <Object?>['absent', 'huge', 48, null, '']) {
      expect(ClipRecipe.fromJson(stampWith(size)), plain, reason: '$size');
    }
    expect(
      ClipRecipe.fromJson(stampWith('small'))?.stampStyle.size,
      StampSize.small,
    );
  });

  // The converter renders from the source with the frame's upright source size (no probe):
  // the size goes with the frame, never without one, and a malformed size only drops the size.
  test('of() takes a video render\'s window, frame (with its source size), '
      'stamp, mute and format; a photo has no recipe; the source size '
      'round-trips with the frame and reads as none when malformed', () {
    const StampStyle style = StampStyle(
      format: StampFormat.numeric,
      rgb: 0xFFFFFF,
      outline: true,
    );
    const ClipFormat format = ClipFormat.legacy(VideoOrientation.portrait);
    const VideoRender video = VideoRender(
      sourcePath: '/tmp/REC.mov',
      fromRecording: true,
      trimStartMs: 300,
      trimEndMs: 1800,
      outputFileName: '2024-01-05.mp4',
      stampText: '05/01/2024',
      stampStyle: style,
      legacyStampFont: false,
      location: ClipLocation.off(),
      subtitles: 'Hi',
      format: format,
      albumLabel: 'Default',
      frame: SourceFrame(
        frame: ClipFrame(scale: 2, dx: 0.25),
        sourceWidth: 1080,
        sourceHeight: 1920,
      ),
      mute: true,
    );

    final ClipRecipe? recipe = ClipRecipe.of(video);

    expect(
      recipe,
      const ClipRecipe(
        trimStartMs: 300,
        trimEndMs: 1800,
        frame: ClipFrame(scale: 2, dx: 0.25),
        sourceWidth: 1080,
        sourceHeight: 1920,
        stampStyle: style,
        mute: true,
        format: format,
      ),
    );
    expect(recipe!.sourceFrame, video.frame);
    expect(recipe.toJson()['source'], <String, Object?>{
      'width': 1080,
      'height': 1920,
    });
    expect(
      ClipRecipe.fromJson(jsonDecode(jsonEncode(recipe.toJson()))),
      recipe,
    );
    expect(plain.toJson().containsKey('source'), isFalse);
    expect(
      ClipRecipe.of(
        const PhotoRender(
          photoPath: '/tmp/photo.png',
          durationSeconds: 1.5,
          outputFileName: '2024-01-05.mp4',
          stampText: '05/01/2024',
          stampStyle: style,
          legacyStampFont: false,
          location: ClipLocation.off(),
          subtitles: '',
          format: format,
          albumLabel: 'Default',
        ),
      ),
      isNull,
    );

    final Map<String, Object?> json = recipe.toJson();
    final ClipRecipe? sizeless = ClipRecipe.fromJson(<String, Object?>{
      ...json,
      'source': <String, Object?>{'width': 0, 'height': 'tall'},
    });
    expect(sizeless?.frame, const ClipFrame(scale: 2, dx: 0.25));
    expect(sizeless?.sourceFrame, isNull);
  });

  // The source's probed transfer rides along, an additive key written only when there is
  // one, so the converter renders from an HDR source with the right conversion.
  test('sourceColorTransfer: taken from the request, written only when '
      'set, read back; a mistyped value reads as SDR, not as no recipe', () {
    final ClipRecipe? hdr = ClipRecipe.of(
      const VideoRender(
        sourcePath: '/c/IMG_1.MOV',
        fromRecording: false,
        trimStartMs: 0,
        trimEndMs: 1500,
        outputFileName: '2024-01-05.mp4',
        stampText: '',
        stampStyle: StampStyle(
          format: StampFormat.numeric,
          rgb: 0xFFFFFF,
          outline: true,
        ),
        legacyStampFont: false,
        location: ClipLocation.off(),
        subtitles: '',
        format: ClipFormat.legacy(VideoOrientation.landscape),
        albumLabel: 'Default',
        sourceColorTransfer: 'arib-std-b67',
      ),
    );
    expect(hdr?.sourceColorTransfer, 'arib-std-b67');
    expect(hdr!.toJson()['sourceColorTransfer'], 'arib-std-b67');
    expect(plain.toJson().containsKey('sourceColorTransfer'), isFalse);
    expect(ClipRecipe.fromJson(jsonDecode(jsonEncode(hdr.toJson()))), hdr);
    expect(
      ClipRecipe.fromJson(<String, Object?>{
        ...plain.toJson(),
        'sourceColorTransfer': 7,
      }),
      plain,
    );
  });
}
