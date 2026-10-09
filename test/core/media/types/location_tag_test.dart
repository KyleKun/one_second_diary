import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/location_tag.dart';

void main() {
  // The `location=` value: the signed coordinates (a negative one keeps its
  // own sign, never "+-"), a slash and the place. Stored tags hold `"` as
  // `\"`. An unknown coordinate is "+0": callers never pass null (a typed
  // place alone writes no tag), but tags written this way by older installs
  // exist and must parse back.
  test('is byte-identical to the tag v1.7 handed ffmpeg', () {
    const List<(double?, double?, String, String)> cases =
        <(double?, double?, String, String)>[
          (35.7148, 139.7967, 'Tokyo, Japan', '+35.7148+139.7967/Tokyo, Japan'),
          (
            -23.55,
            -46.63,
            'São Paulo, Brazil',
            '-23.55-46.63/São Paulo, Brazil',
          ),
          (
            35.7148,
            139.7967,
            'Tokyo, "Japan"',
            r'+35.7148+139.7967/Tokyo, \"Japan\"',
          ),
          (
            48.8566,
            2.3522,
            'Paris, "France"',
            r'+48.8566+2.3522/Paris, \"France\"',
          ),
          (0.0, -0.0, "Val d'Isère", "+0.0-0.0/Val d'Isère"),
          (1e-7, -179.9999999, r'Back\slash', r'+1e-7-179.9999999/Back\slash'),
          (90.0, 180.0, '', '+90.0+180.0/'),
          (null, 12.5, 'Null Island', '+0+12.5/Null Island'),
          (null, null, 'Paris', '+0+0/Paris'),
        ];
    for (final (double? latitude, double? longitude, String place, String v17)
        in cases) {
      expect(
        LocationTag.format(
          latitude: latitude,
          longitude: longitude,
          place: place,
        ),
        v17,
        reason: '($latitude, $longitude, $place)',
      );
    }
  });

  // A Dart double always prints a decimal point (0.0 is "+0.0"), so a bare
  // "+0" can only be a null: a typed place with no fix (Null Island).
  test('"+0" is an unknown coordinate; "+0.0" is a real zero', () {
    expect(
      LocationTag.parse('+0+0/Paris'),
      const LocationTag(latitude: null, longitude: null, place: 'Paris'),
    );
    expect(
      LocationTag.parse('+0.0-0.0/Gulf of Guinea'),
      const LocationTag(
        latitude: 0.0,
        longitude: -0.0,
        place: 'Gulf of Guinea',
      ),
    );
  });

  // \" in the place is unescaped. Dart prints tiny doubles in exponent form
  // ("1e-7"), and the tag holds `value.toString()` as it comes.
  test('round-trips every place, backslashes and quotes included', () {
    const List<String> places = <String>[
      '',
      'Tokyo, Japan',
      'Tokyo, "Japan"',
      '"quoted"',
      r'a\b',
      r'ends with \"',
      r'\\"',
      "Val d'Isère / Savoie",
      '100% home',
    ];
    for (final (double latitude, double longitude) in <(double, double)>[
      (-33.8688, 151.2093),
      (1e-7, -1.5e-8),
    ]) {
      for (final String place in places) {
        final String tag = LocationTag.format(
          latitude: latitude,
          longitude: longitude,
          place: place,
        );
        expect(
          LocationTag.parse(tag),
          LocationTag(latitude: latitude, longitude: longitude, place: place),
          reason: tag,
        );
      }
    }
  });

  // Tags written by cameras and other apps (ISO 6709, optional altitude, no
  // place) can reach the probe for files a user copied into the folder.
  // Anything else is null; parse never throws.
  test('reads ISO 6709 tags from other writers; null for anything else', () {
    final Map<String?, LocationTag?> cases = <String?, LocationTag?>{
      '+35.6586+139.7454+040.000/': const LocationTag(
        latitude: 35.6586,
        longitude: 139.7454,
        place: '',
      ),
      '-12.5+045.25': const LocationTag(
        latitude: -12.5,
        longitude: 45.25,
        place: '',
      ),
      null: null,
      '': null,
      'Tokyo': null,
      '+35.7/Tokyo': null,
      '35.7+139.7/Tokyo': null,
      '+abc+def/x': null,
    };
    for (final MapEntry<String?, LocationTag?>(:String? key, :value)
        in cases.entries) {
      expect(LocationTag.parse(key), value, reason: '$key');
    }
  });
}
