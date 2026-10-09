import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/clip_probe_parser.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';

/// `ffprobe -v quiet -print_format json -show_format -show_streams` of a
/// v1.5-tagged clip with subtitles and a geotag (trimmed to the fields read).
const String osdClipJson = '''
{
    "streams": [
        {
            "index": 0,
            "codec_name": "h264",
            "profile": "High",
            "codec_type": "video",
            "width": 1920,
            "height": 1080,
            "pix_fmt": "yuv420p",
            "r_frame_rate": "30/1",
            "avg_frame_rate": "30/1",
            "duration": "1.500000"
        },
        {
            "index": 1,
            "codec_name": "aac",
            "codec_type": "audio",
            "sample_rate": "48000",
            "channels": 1,
            "r_frame_rate": "0/0"
        },
        {
            "index": 2,
            "codec_name": "mov_text",
            "codec_type": "subtitle",
            "r_frame_rate": "0/0"
        }
    ],
    "format": {
        "filename": "/storage/emulated/0/DCIM/OneSecondDiary/2024-01-05.mp4",
        "nb_streams": 3,
        "format_name": "mov,mp4,m4a,3gp,3g2,mj2",
        "duration": "1.533000",
        "size": "2211840",
        "tags": {
            "major_brand": "isom",
            "encoder": "Lavf61.7.100",
            "artist": "One Second Diary (v1.5)",
            "album": "Default",
            "comment": "origin=osd_recording",
            "location": "+35.7148+139.7967/Tokyo, Japan"
        }
    }
}
''';

void main() {
  test('reads a v1.5 clip: streams, duration, size, codec, fps, channels, '
      'pixel format and tags', () {
    expect(
      ClipProbeParser.parse(osdClipJson),
      const ClipProbe(
        durationMs: 1533,
        hasAudio: true,
        hasSubtitleStream: true,
        artist: 'One Second Diary (v1.5)',
        album: 'Default',
        comment: 'origin=osd_recording',
        locationTag: '+35.7148+139.7967/Tokyo, Japan',
        title: null,
        width: 1920,
        height: 1080,
        codec: 'h264',
        fps: 30,
        channels: 1,
        pixelFormat: 'yuv420p',
      ),
    );
  });

  // Format facts as an HDR import reports them; a stream that does not report them has
  // them unknown (never guessed).
  test("reads an import's channels, pixel format and colour transfer; "
      'absent is unknown', () {
    const String hdr = '''
{"streams": [
  {"codec_name": "hevc", "codec_type": "video", "width": 3840, "height": 2160,
   "pix_fmt": "yuv420p10le", "color_transfer": "arib-std-b67",
   "r_frame_rate": "60/1"},
  {"codec_name": "aac", "codec_type": "audio", "channels": 2}
], "format": {"duration": "2.000000"}}
''';

    final ClipProbe probe = ClipProbeParser.parse(hdr);

    expect(probe.channels, 2);
    expect(probe.pixelFormat, 'yuv420p10le');
    expect(probe.colorTransfer, 'arib-std-b67');
    expect(probe.fps, 60);
    expect(probe.schema, ClipSchema.other);

    final ClipProbe osd = ClipProbeParser.parse(osdClipJson);
    expect(osd.colorTransfer, isNull);
    expect(osd.schema, ClipSchema.v15);
    final ClipProbe empty = ClipProbeParser.parse(
      '{"streams": [], "format": {}}',
    );
    expect(empty.channels, isNull);
    expect(empty.pixelFormat, isNull);
    expect(empty.colorTransfer, isNull);
  });

  test('reads a pre-v1.5 clip: no audio, no subtitles, no tags; a file with '
      'no video stream or duration has those facts unknown', () {
    const String legacy = '''
{
  "streams": [
    {"index": 0, "codec_name": "hevc", "codec_type": "video",
     "width": 1280, "height": 720, "r_frame_rate": "30000/1001"}
  ],
  "format": {"duration": "2.002000", "size": "999"}
}
''';

    final ClipProbe probe = ClipProbeParser.parse(legacy);

    expect(probe.hasAudio, isFalse);
    expect(probe.hasSubtitleStream, isFalse);
    expect(probe.isOsdV15, isFalse);
    expect(probe.artist, isNull);
    expect(probe.codec, 'hevc');
    expect((probe.width, probe.height), (1280, 720));
    expect(probe.fps, closeTo(29.97, 0.001));
    expect(probe.durationMs, 2002);

    final ClipProbe empty = ClipProbeParser.parse(
      '{"streams": [], "format": {}}',
    );
    expect(empty.durationMs, isNull);
    expect(empty.width, isNull);
    expect(empty.codec, isNull);
    expect(empty.fps, isNull);
  });

  test('tag names are matched whatever their case', () {
    const String upper = '''
{"streams": [], "format": {"tags": {"ARTIST": "One Second Diary (v1.5)", "Title": "Summer"}}}
''';

    final ClipProbe probe = ClipProbeParser.parse(upper);

    expect(probe.isOsdV15, isTrue);
    expect(probe.title, 'Summer');
  });

  // A movie's tags, as the movie join writes them.
  test("reads a movie's title, comment and description", () {
    const String movieJson = '''
{"streams": [], "format": {"tags": {"title": "September 2026", "comment": "profile=Work", "description": "clips=25;from=2026-09-01;to=2026-09-28"}}}
''';

    final ClipProbe probe = ClipProbeParser.parse(movieJson);

    expect(probe.title, 'September 2026');
    expect(probe.comment, 'profile=Work');
    expect(probe.description, 'clips=25;from=2026-09-01;to=2026-09-28');
    expect(ClipProbeParser.parse(osdClipJson).description, isNull);
  });

  // A movie's chapters as `-show_chapters` prints them: times in seconds as strings,
  // the title under tags.
  test("reads a movie's chapters in order; a clip or an older movie has "
      'none', () {
    const String movieJson = '''
{"chapters": [
  {"id": 0, "time_base": "1/1000", "start": 0, "start_time": "0.000000",
   "end": 1500, "end_time": "1.500000",
   "tags": {"title": "August 27, 2023 · Berlin · eating bananas ; with friends"}},
  {"id": 1, "time_base": "1/1000", "start": 1500, "start_time": "1.500000",
   "end": 2533, "end_time": "2.533000", "tags": {}},
  {"id": 2, "start_time": "oops"}
], "streams": [], "format": {"tags": {"title": "August 2023"}}}
''';

    final ClipProbe probe = ClipProbeParser.parse(movieJson);

    expect(probe.chapters, const <MovieChapter>[
      MovieChapter(
        startMs: 0,
        endMs: 1500,
        title: 'August 27, 2023 · Berlin · eating bananas ; with friends',
      ),
      MovieChapter(startMs: 1500, endMs: 2533, title: ''),
    ]);
    expect(probe.title, 'August 2023');
    expect(ClipProbeParser.parse(osdClipJson).chapters, isEmpty);
    expect(
      ClipProbeParser.parse('{"streams": [], "format": {}}').chapters,
      isEmpty,
    );
  });

  test('output that is not ffprobe JSON is a FormatException', () {
    expect(() => ClipProbeParser.parse(''), throwsFormatException);
    expect(() => ClipProbeParser.parse('[1, 2]'), throwsFormatException);
  });

  // A clip's tags and the device note, as the save and the tags remux
  // write them; a clip without them has none.
  test("reads a clip's tags and its device note", () {
    const String taggedJson = '''
{"streams": [], "format": {"tags": {"artist": "One Second Diary (v1.5)", "keywords": "bread,sour dough", "synopsis": "device=Google Pixel 8;app=2.0.0;recorded=2026-10-06T14:33:21.000+02:00"}}}
''';

    final ClipProbe probe = ClipProbeParser.parse(taggedJson);

    expect(probe.keywords, 'bread,sour dough');
    expect(probe.tags, <String>['bread', 'sour dough']);
    expect(
      probe.synopsis,
      'device=Google Pixel 8;app=2.0.0;recorded=2026-10-06T14:33:21.000+02:00',
    );

    final ClipProbe untagged = ClipProbeParser.parse(osdClipJson);
    expect(untagged.keywords, isNull);
    expect(untagged.tags, isEmpty);
    expect(untagged.synopsis, isNull);
  });
}
