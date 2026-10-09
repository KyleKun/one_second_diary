import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/osd_artist.dart';
import 'package:one_second_diary/features/clips/data/clip_meta_of_probe.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';

ClipProbe _probe({
  String? artist = osdArtist,
  String? comment = 'origin=gallery',
  String? locationTag,
  String? synopsis,
  bool hasSubtitleStream = false,
}) => ClipProbe(
  durationMs: 1500,
  hasAudio: true,
  hasSubtitleStream: hasSubtitleStream,
  artist: artist,
  album: 'Default',
  comment: comment,
  locationTag: locationTag,
  synopsis: synopsis,
  title: null,
  width: 1080,
  height: 1920,
  codec: 'h264',
  fps: 30,
);

void main() {
  test('copies the stream facts and tags a movie plans from and decodes the '
      'location tag; v1.7\'s Null Island tag keeps the typed place and no '
      'coordinates; no tag is an empty place', () {
    expect(
      clipMetaOfProbe(
        _probe(hasSubtitleStream: true),
        subtitleText: 'Hello world',
      ),
      const ClipMeta(
        durationMs: 1500,
        hasAudio: true,
        hasSubtitleStream: true,
        subtitleText: 'Hello world',
        locationText: '',
        isOsdV15: true,
        width: 1080,
        height: 1920,
        codec: 'h264',
        origin: ClipOrigin.gallery,
        fps: 30,
        schema: ClipSchema.v15,
      ),
    );

    // The format facts come with the probe; a v2 marker reads as v2.
    final ClipMeta facts = clipMetaOfProbe(
      const ClipProbe(
        durationMs: 2000,
        hasAudio: true,
        hasSubtitleStream: false,
        artist: osdArtistV2,
        album: 'Default',
        comment: 'origin=osd_recording',
        locationTag: null,
        title: null,
        width: 3840,
        height: 2160,
        codec: 'hevc',
        fps: 60,
        channels: 2,
        pixelFormat: 'yuv420p',
        colorTransfer: 'bt709',
      ),
      subtitleText: '',
    );
    expect(facts.schema, ClipSchema.v2);
    expect(facts.isOsdV15, isFalse);
    expect((facts.fps, facts.channels), (60, 2));
    expect((facts.pixelFormat, facts.colorTransfer), ('yuv420p', 'bt709'));

    // The keyframes are the keyframe probe's answer; none when it failed.
    const ClipKeyframes keyframes = ClipKeyframes(
      frameCount: 45,
      indices: <int>[0, 10, 35],
    );
    expect(
      clipMetaOfProbe(
        _probe(),
        subtitleText: '',
        keyframes: keyframes,
      ).keyframes,
      keyframes,
    );
    expect(clipMetaOfProbe(_probe(), subtitleText: '').keyframes, isNull);

    final ClipMeta meta = clipMetaOfProbe(
      _probe(locationTag: '+35.71+139.79/Tokyo, Japan'),
      subtitleText: '',
    );

    expect(meta.locationText, 'Tokyo, Japan');
    expect(meta.latitude, 35.71);
    expect(meta.longitude, 139.79);

    // A Null Island tag keeps the typed place and no coordinates.
    {
      final ClipMeta meta = clipMetaOfProbe(
        _probe(locationTag: '+0+0/Grandma\'s house'),
        subtitleText: '',
      );

      expect(meta.locationText, "Grandma's house");
      expect(meta.latitude, isNull);
      expect(meta.longitude, isNull);

      // A probed clip without a geotag or an OSD tag says so ("" and false),
      // unlike an unprobed one (null).
      final ClipMeta bare = clipMetaOfProbe(
        _probe(artist: null, comment: null, locationTag: 'garbage'),
        subtitleText: '',
      );

      expect(bare.locationText, '');
      expect(bare.latitude, isNull);
      expect(bare.isOsdV15, isFalse);
      expect(bare.schema, ClipSchema.other);
      expect(bare.channels, isNull);
      expect(bare.origin, isNull);
      expect(bare.subtitleText, '');
    }
  });

  // A place typed or picked without a GPS fix is in the notes tag,
  // never in `location`: it reads back as the place, with no coordinates,
  // and a `location` tag wins when both are there.
  test('a place without a fix comes from the notes tag', () {
    final ClipMeta noted = clipMetaOfProbe(
      _probe(synopsis: 'device=Pixel 8;app=2.0.0;place=Home'),
      subtitleText: '',
    );
    expect(noted.locationText, 'Home');
    expect(noted.latitude, isNull);
    expect(noted.longitude, isNull);

    final ClipMeta both = clipMetaOfProbe(
      _probe(locationTag: '+35.71+139.79/Tokyo', synopsis: 'place=Home'),
      subtitleText: '',
    );
    expect(both.locationText, 'Tokyo');
    expect(both.latitude, 35.71);
  });
}
