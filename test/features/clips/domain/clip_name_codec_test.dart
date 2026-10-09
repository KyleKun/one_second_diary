import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_name_codec.dart';

void main() {
  test(
    'the first clip of a day keeps the v1.x name; extra clips get a -N '
    'suffix, never _N or another dot, and every name written parses back',
    () {
      expect(ClipNameCodec.format(LocalDay(2024, 1, 5)), '2024-01-05.mp4');
      expect(
        ClipNameCodec.format(LocalDay(2024, 1, 5), ordinal: 1),
        '2024-01-05.mp4',
      );
      expect(
        ClipNameCodec.format(LocalDay(2024, 1, 5), ordinal: 2),
        '2024-01-05-2.mp4',
      );
      expect(
        ClipNameCodec.format(LocalDay(2024, 12, 31), ordinal: 11),
        '2024-12-31-11.mp4',
      );
      expect(
        () => ClipNameCodec.format(LocalDay(2024, 1, 5), ordinal: 0),
        throwsArgumentError,
      );

      expect(ClipNameCodec.parse('2024-01-05.mp4'), (
        day: LocalDay(2024, 1, 5),
        ordinal: 1,
      ));
      expect(ClipNameCodec.parse('2024-02-29-17.mp4'), (
        day: LocalDay(2024, 2, 29),
        ordinal: 17,
      ));

      // Every name format writes round-trips.
      for (final LocalDay day in <LocalDay>[
        LocalDay(2018, 1, 1),
        LocalDay(2024, 2, 29),
        LocalDay(2031, 12, 31),
      ]) {
        for (final int ordinal in <int>[1, 2, 9, 10, 123]) {
          final String name = ClipNameCodec.format(day, ordinal: ordinal);
          expect(ClipNameCodec.parse(name), (day: day, ordinal: ordinal));
        }
      }
    },
  );

  group('parse', () {
    test('rejects everything that is not exactly a clip name', () {
      const Map<String, String> rejected = <String, String>{
        '2024-01-05.MP4': 'upper-case extension (never written by the app)',
        '2024-01-05.mov': 'other container',
        '2024-01-05': 'no extension',
        '2024-01-05.mp4.mp4': 'double extension',
        '2024-01-05.edited.mp4': 'dotted name (Z MB-03)',
        '2024.01.05.mp4': 'dots instead of dashes',
        '.pending-1700000000-2024-01-05.mp4': 'Android media store pending',
        '.trashed-1700000000-2024-01-05.mp4': 'Android media store trashed',
        '2024-01-05_483920.mp4': 'v1.x movie temp copy',
        '2024-01-05_2.mp4': 'underscore suffix (collides with temps)',
        '2024-02-30.mp4': 'impossible date',
        '2023-02-29.mp4': 'not a leap year',
        '2024-13-01.mp4': 'month 13',
        '2024-1-05.mp4': 'unpadded month',
        '2024-01-05-1.mp4': 'ordinal 1 is the bare name',
        '2024-01-05-0.mp4': 'ordinal 0',
        '2024-01-05-02.mp4': 'zero-padded ordinal',
        '2024-01-05--2.mp4': 'double dash',
        '2024-01-05-2a.mp4': 'letters in the ordinal',
        '2024-01-05-99999999999999999999999.mp4': 'ordinal overflows int',
        ' 2024-01-05.mp4': 'leading space',
        '2024-01-05.mp4 ': 'trailing space',
        'Movies/2024-01-05.mp4': 'a path, not a basename',
        'OSD-Movie-3-2024-01-05.mp4': 'a movie',
        '': 'empty',
        '.mp4': 'extension only',
      };
      rejected.forEach((String name, String why) {
        expect(ClipNameCodec.parse(name), isNull, reason: '$name: $why');
      });
    });

    test('recognises the v1.x movie temp copies the orphan sweep removes', () {
      for (final String temp in <String>[
        '2024-01-05_483920.mp4',
        '2024-01-05_2.mp4',
        '2024-01-05_1.mp4',
      ]) {
        expect(ClipNameCodec.isLegacyMovieTemp(temp), isTrue, reason: temp);
        expect(ClipNameCodec.parse(temp), isNull, reason: temp);
      }
      for (final String other in <String>[
        '2024-01-05.mp4',
        '2024-01-05-2.mp4',
        '2024-01-05_1234567.mp4',
        '2024-01-05_.mp4',
        '2024-01-05_12.MP4',
        'trip/2024-01-05_12.mp4',
        'OSD-Movie-3-2024-01-05.mp4',
      ]) {
        expect(ClipNameCodec.isLegacyMovieTemp(other), isFalse, reason: other);
      }
    });
  });
}
