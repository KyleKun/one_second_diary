import 'dart:async';
import 'dart:convert';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';
import 'package:one_second_diary/features/journey/domain/geo_point.dart';

/// The coordinates looked up for place names the clips carry without a
/// fix (typed places), so "Place them on the map" runs once per name.
///
/// Stored as the `placeCoordinates` preference, a JSON object of
/// `TagName.fold` key to `{"lat": 38.72, "lon": -9.14}`. A value that
/// doesn't decode reads as empty, with one warning; a record that does
/// not, or is off the globe, is left out. [changes] fires after each
/// write.
class PlaceCoordinates {
  PlaceCoordinates({required this._prefs, required this._logger});

  final PrefsStore _prefs;
  final AppLogger _logger;

  static const String _tag = 'PLACES';

  final StreamController<void> _changes = StreamController<void>.broadcast();
  String? _reported;

  /// The last value decoded and what it held: [find] runs once per place
  /// on every snapshot.
  String? _decodedRaw;
  Map<String, GeoPoint> _decoded = const <String, GeoPoint>{};

  /// Fires after each change.
  Stream<void> get changes => _changes.stream;

  /// The coordinates stored for the place text [fullName], or null.
  GeoPoint? find(String fullName) => _stored()[TagName.fold(fullName)];

  /// Stores [at] for the place text [fullName]. Throws a
  /// `StorageException` when the phone refuses the write.
  Future<void> set(String fullName, GeoPoint at) async {
    final Map<String, GeoPoint> stored = Map<String, GeoPoint>.of(_stored());
    stored[TagName.fold(fullName)] = at;
    await _prefs.write(
      PrefKeys.placeCoordinates,
      jsonEncode(<String, Object?>{
        for (final MapEntry<String, GeoPoint> entry in stored.entries)
          entry.key: <String, double>{
            'lat': entry.value.lat,
            'lon': entry.value.lon,
          },
      }),
    );
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() => _changes.close();

  Map<String, GeoPoint> _stored() {
    final String stored = _prefs.read(PrefKeys.placeCoordinates);
    if (stored != _decodedRaw) {
      _decoded = Map<String, GeoPoint>.unmodifiable(_decodeAll(stored));
      _decodedRaw = stored;
    }
    return _decoded;
  }

  Map<String, GeoPoint> _decodeAll(String stored) {
    final Object? json;
    try {
      json = jsonDecode(stored);
    } on FormatException {
      _report(stored);
      return <String, GeoPoint>{};
    }
    if (json is! Map<String, Object?>) {
      _report(stored);
      return <String, GeoPoint>{};
    }
    final Map<String, GeoPoint> points = <String, GeoPoint>{};
    for (final MapEntry<String, Object?> entry in json.entries) {
      final GeoPoint? point = _decode(entry.value);
      if (point == null) {
        _report(stored);
      } else {
        points[entry.key] = point;
      }
    }
    return points;
  }

  static GeoPoint? _decode(Object? record) {
    if (record is! Map<String, Object?>) return null;
    final Object? lat = record['lat'];
    final Object? lon = record['lon'];
    if (lat is! num || lon is! num) return null;
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    return GeoPoint(lat.toDouble(), lon.toDouble());
  }

  void _report(String stored) {
    if (stored == _reported) return;
    _reported = stored;
    _logger.warning(_tag, 'Ignored an unreadable placeCoordinates preference');
  }
}
