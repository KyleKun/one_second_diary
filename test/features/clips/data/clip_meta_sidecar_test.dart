import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/clip_recipe.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clips/data/clip_meta_sidecar.dart';
import 'package:one_second_diary/features/clips/data/stamped_clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';

const FileStamp _stamp = FileStamp(sizeBytes: 1234, modifiedMs: 1700000000000);

StampedClipMeta _entry(ClipMeta meta) =>
    StampedClipMeta(stamp: _stamp, meta: meta);

void main() {
  // Absent = not read yet (the backfill probes the clip), [] = read and
  // none; both must come back as they went, or a reinstall would show tags
  // the user removed, or forget which clips were already read.
  test("a clip's tags survive the sidecar: tags as given, none as [], not "
      'read yet as absent', () {
    final Map<String, StampedClipMeta> entries = <String, StampedClipMeta>{
      'trip/2024-01-05.mp4': _entry(
        const ClipMeta(
          durationMs: 1500,
          tags: <String>['bread', 'sour dough', '雨'],
        ),
      ),
      '2024-01-06.mp4': _entry(const ClipMeta(tags: <String>[])),
      '2024-01-07.mp4': _entry(const ClipMeta(durationMs: 1000)),
    };

    final String json = ClipMetaSidecar.encode(entries);
    final Map<String, StampedClipMeta> decoded = ClipMetaSidecar.decode(json);

    expect(decoded['trip/2024-01-05.mp4']!.meta.tags, <String>[
      'bread',
      'sour dough',
      '雨',
    ]);
    expect(decoded['2024-01-06.mp4']!.meta.tags, isEmpty);
    expect(decoded['2024-01-07.mp4']!.meta.tags, isNull);
    expect(decoded, entries);
    expect(json, contains('"tags":["bread","sour dough","雨"]'));
    expect(json, contains('"tags":[]'));

    // A sidecar an older build wrote has no tags key: not read yet.
    const String older =
        '{"version": 1, "clips": {"2024-01-05.mp4": '
        '{"size": 1234, "mtime": 1700000000000, "durationMs": 1500}}}';
    expect(ClipMetaSidecar.decode(older)['2024-01-05.mp4']!.meta.tags, isNull);
  });

  // Where a clip can be cut for a movie with transitions. Both keys or
  // nothing: a count without the keyframes (or one that is not a list of
  // whole numbers) says nothing, so the backfill reads the clip again.
  test("a clip's frame count and keyframes survive the sidecar as `frames` "
      'and `keyframes`; absent or malformed is not read yet', () {
    final Map<String, StampedClipMeta> entries = <String, StampedClipMeta>{
      '2024-01-05.mp4': _entry(
        const ClipMeta(
          durationMs: 2000,
          keyframes: ClipKeyframes(frameCount: 60, indices: <int>[0, 10, 50]),
        ),
      ),
      '2024-01-06.mp4': _entry(const ClipMeta(durationMs: 1000)),
    };

    final String json = ClipMetaSidecar.encode(entries);

    expect(json, contains('"frames":60,"keyframes":[0,10,50]'));
    expect(json, isNot(contains('"frames":null')));
    expect(ClipMetaSidecar.decode(json), entries);

    const String malformed =
        '{"version": 1, "clips": {'
        '"a.mp4": {"size": 1, "mtime": 1, "frames": 60}, '
        '"b.mp4": {"size": 1, "mtime": 1, "keyframes": [0, 10]}, '
        '"c.mp4": {"size": 1, "mtime": 1, "frames": 60, "keyframes": [0, "x"]}, '
        '"d.mp4": {"size": 1, "mtime": 1, "frames": "60", "keyframes": [0]}}}';
    final Map<String, StampedClipMeta> decoded = ClipMetaSidecar.decode(
      malformed,
    );
    for (final String name in <String>['a.mp4', 'b.mp4', 'c.mp4', 'd.mp4']) {
      expect(decoded[name]!.meta.keyframes, isNull, reason: name);
    }
  });

  // The format facts: additive keys of the version 1
  // sidecar, each absent until read, so an older sidecar still reads and
  // an unknown schema name is unknown.
  test("a clip's fps, channels, pixel format, colour transfer and schema "
      'survive the sidecar; absent or unknown is not read yet', () {
    final Map<String, StampedClipMeta> entries = <String, StampedClipMeta>{
      '2024-01-05.mp4': _entry(
        const ClipMeta(
          durationMs: 2000,
          fps: 59.94,
          channels: 2,
          pixelFormat: 'yuv420p10le',
          colorTransfer: 'arib-std-b67',
          schema: ClipSchema.v2,
        ),
      ),
      '2024-01-06.mp4': _entry(
        const ClipMeta(fps: 30, channels: 1, schema: ClipSchema.v15),
      ),
      '2024-01-07.mp4': _entry(const ClipMeta(durationMs: 1000)),
    };

    final String json = ClipMetaSidecar.encode(entries);

    expect(
      json,
      contains(
        '"fps":59.94,"channels":2,"pixelFormat":"yuv420p10le",'
        '"colorTransfer":"arib-std-b67","schema":"v2"',
      ),
    );
    expect(json, contains('"fps":30.0,"channels":1,"schema":"v15"'));
    expect(json, isNot(contains('"schema":null')));
    expect(ClipMetaSidecar.decode(json), entries);

    const String older =
        '{"version": 1, "clips": {'
        '"a.mp4": {"size": 1, "mtime": 1, "durationMs": 1500}, '
        '"b.mp4": {"size": 1, "mtime": 1, "schema": "v3", "fps": "30", '
        '"channels": 2.5, "future": true}}}';
    final Map<String, StampedClipMeta> decoded = ClipMetaSidecar.decode(older);
    expect(decoded['a.mp4']!.meta.schema, isNull);
    expect(decoded['a.mp4']!.meta.fps, isNull);
    expect(decoded['b.mp4']!.meta.schema, isNull);
    expect(decoded['b.mp4']!.meta.fps, isNull);
    expect(decoded['b.mp4']!.meta.channels, isNull);
  });

  // The recipe is an additive object under its own key a clip without a source has none, an older sidecar reads as none,
  // and a malformed one reads as none rather than a guess.
  test('a clip\'s recipe round-trips under "recipe", absent for a clip '
      'without one; an unknown or malformed recipe reads as none', () {
    const ClipRecipe recipe = ClipRecipe(
      trimStartMs: 500,
      trimEndMs: 2000,
      frame: ClipFrame(scale: 1.5, dx: 0.1, dy: 0, fill: FrameFill.blur),
      sourceWidth: 1920,
      sourceHeight: 1080,
      stampStyle: StampStyle(
        format: StampFormat.written,
        rgb: 0xEF5558,
        outline: false,
      ),
      mute: true,
      format: ClipFormat.legacy(VideoOrientation.landscape),
    );
    final Map<String, StampedClipMeta> entries = <String, StampedClipMeta>{
      '2024-01-05.mp4': _entry(
        const ClipMeta(
          durationMs: 1500,
          schema: ClipSchema.v15,
          recipe: recipe,
        ),
      ),
      '2024-01-06.mp4': _entry(const ClipMeta(durationMs: 1000)),
    };

    final String json = ClipMetaSidecar.encode(entries);

    expect(
      json,
      contains(
        '"recipe":{"trimStartMs":500,"trimEndMs":2000,'
        '"frame":{"scale":1.5,"dx":0.1,"dy":0.0,"fill":"blur"},'
        '"source":{"width":1920,"height":1080},'
        '"stamp":{"format":"written","rgb":15685976,"outline":false},'
        '"mute":true,"format":"1080p30-h264-mono-sdr",'
        '"orientation":"landscape"}',
      ),
    );
    expect(json, isNot(contains('"recipe":null')));
    expect(ClipMetaSidecar.decode(json), entries);

    const String odd =
        '{"version": 1, "clips": {'
        '"a.mp4": {"size": 1, "mtime": 1, "recipe": {"trimStartMs": 0}}, '
        '"b.mp4": {"size": 1, "mtime": 1, "recipe": "none"}}}';
    final Map<String, StampedClipMeta> decoded = ClipMetaSidecar.decode(odd);
    expect(decoded['a.mp4']!.meta.recipe, isNull);
    expect(decoded['b.mp4']!.meta.recipe, isNull);
    expect(decoded['a.mp4']!.meta.durationMs, isNull);
  });
}
