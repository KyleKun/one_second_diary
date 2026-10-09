import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/osd_artist.dart';

ClipProbe _probe({String? artist}) => ClipProbe(
  durationMs: 1500,
  hasAudio: true,
  hasSubtitleStream: false,
  artist: artist,
  album: 'Default',
  comment: null,
  locationTag: null,
  title: null,
  width: 1920,
  height: 1080,
  codec: 'h264',
  fps: 30,
);

void main() {
  // GOLDEN: the two markers are the clip contract with every install and with v1.7, which
  // joins raw only clips carrying the first.
  test('the schema markers are the exact v1.5 and v2 artist strings', () {
    expect(osdArtist, 'One Second Diary (v1.5)');
    expect(osdArtistV2, 'One Second Diary (v2)');
  });

  test('the schema comes from the artist tag: v1.5, v2, else other (not '
      'ours); isOsdV15 is schema v1.5', () {
    final Map<String?, ClipSchema> cases = <String?, ClipSchema>{
      osdArtist: ClipSchema.v15,
      osdArtistV2: ClipSchema.v2,
      'x $osdArtistV2 y': ClipSchema.v2,
      null: ClipSchema.other,
      '': ClipSchema.other,
      'One Second Diary': ClipSchema.other,
      'One Second Diary (v3)': ClipSchema.other,
      'Some Camera': ClipSchema.other,
    };
    for (final MapEntry<String?, ClipSchema>(:String? key, :ClipSchema value)
        in cases.entries) {
      expect(ClipSchema.fromArtist(key), value, reason: '$key');
      expect(_probe(artist: key).schema, value, reason: '$key');
      expect(_probe(artist: key).isOsdV15, value == ClipSchema.v15);
    }
    expect(ClipSchema.parse('v15'), ClipSchema.v15);
    expect(ClipSchema.parse('v2'), ClipSchema.v2);
    expect(ClipSchema.parse('other'), ClipSchema.other);
    expect(ClipSchema.parse('v1.5'), isNull);
    expect(ClipSchema.parse(null), isNull);
  });

  // A longer tag still counts. Older and foreign clips get normalised for
  // movies.
  test('a clip is v1.5+ when its artist tag contains the marker', () {
    final Map<String?, bool> cases = <String?, bool>{
      osdArtist: true,
      'x $osdArtist y': true,
      null: false,
      '': false,
      'One Second Diary - v1.5': false,
      'One Second Diary': false,
      'Some Camera': false,
    };
    for (final MapEntry<String?, bool>(:String? key, :bool value)
        in cases.entries) {
      expect(_probe(artist: key).isOsdV15, value, reason: '$key');
    }
  });
}
