import 'package:equatable/equatable.dart';

/// A clip's `location` metadata tag, and its one codec.
///
/// The tag is `<±lat><±lon>/<place>`, e.g. `+35.7148+139.7967/Tokyo, Japan`
/// (ISO 6709 coordinates followed by the place name). The MP4 muxer stores it
/// as the `©xyz` atom, so galleries can show where a clip was made, and the
/// app reads the place back for the Diary (`ClipProbe.locationTag` is
/// decoded with [parse], never by hand).
///
/// [format] must not change, quirks included: existing clips carry tags
/// written that way.
final class LocationTag extends Equatable {
  const LocationTag({
    required this.latitude,
    required this.longitude,
    required this.place,
  });

  /// The tag value for a geotag:
  ///
  /// - each coordinate is Dart's `double.toString()` with a `+` added unless
  ///   it already starts with `-` (so tiny values print in exponent form,
  ///   `+1e-7`);
  /// - an unknown (null) coordinate is `+0`. Clips from older installs carry
  ///   `+0+0` for a typed place without a fix; the save path writes no tag
  ///   at all without both coordinates, but [parse] still reads those tags;
  /// - every `"` in [place] becomes `\"`: the backslash is part of every
  ///   stored tag.
  static String format({
    required double? latitude,
    required double? longitude,
    required String place,
  }) =>
      '${_coordinate(latitude)}${_coordinate(longitude)}/'
      '${place.replaceAll('"', r'\"')}';

  /// Reads a tag back, or returns null when [tag] is not one. Never throws.
  ///
  /// Accepts what [format] writes (a bare `+0` is an unknown coordinate
  /// and reads as null; a real zero prints as `+0.0`) and the ISO 6709 tags
  /// cameras write (an optional altitude, and no place: `''`).
  static LocationTag? parse(String? tag) {
    final RegExpMatch? match = _pattern.firstMatch(tag ?? '');
    if (match == null) return null;
    return LocationTag(
      latitude: _parseCoordinate(match.group(1)!),
      longitude: _parseCoordinate(match.group(2)!),
      place: (match.group(3) ?? '').replaceAll(r'\"', '"'),
    );
  }

  /// Degrees north; null when the tag had no fix (`+0`).
  final double? latitude;

  /// Degrees east; null when the tag had no fix (`+0`).
  final double? longitude;

  /// The place name, geocoded or typed by the user; `''` when there is none.
  final String place;

  /// A null coordinate, as written in the tag.
  static const String _unknown = '+0';

  static const String _number = r'[+-]\d+(?:\.\d+)?(?:e[+-]?\d+)?';

  static final RegExp _pattern = RegExp(
    '^($_number)($_number)(?:$_number)?(?:/(.*))?\$',
    dotAll: true,
  );

  static String _coordinate(double? value) {
    if (value == null) return _unknown;
    final String text = value.toString();
    return text.startsWith('-') ? text : '+$text';
  }

  static double? _parseCoordinate(String text) =>
      text == _unknown ? null : double.parse(text);

  @override
  List<Object?> get props => <Object?>[latitude, longitude, place];
}
