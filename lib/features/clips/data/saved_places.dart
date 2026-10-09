import 'dart:async';
import 'dart:convert';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/clips/domain/saved_place.dart';

/// The places the user saved, offered as chips in the clip editor's place
/// sheet and managed in Settings › Places.
///
/// They are the `savedPlaces` preference, a JSON list of
/// `{"name": "Home", "lat": 48.85, "lon": 2.35, "uses": 3}` (the
/// coordinates optional). Names follow `SavedPlaceName`: one place per
/// fold, the casing typed first kept. A record that doesn't decode is left
/// out, with one warning; a value that isn't a list reads as none.
///
/// [changes] fires after each write, so lists on screen follow. Kept a
/// plain class (not final) so screen tests can fake it.
class SavedPlaces {
  SavedPlaces({required this._prefs, required this._logger});

  final PrefsStore _prefs;
  final AppLogger _logger;

  static const String _tag = 'PLACES';

  final StreamController<void> _changes = StreamController<void>.broadcast();
  String? _reported;

  /// Fires after each change.
  Stream<void> get changes => _changes.stream;

  /// Every saved place, most used first, then by name.
  List<SavedPlace> read() {
    final List<SavedPlace> places = _stored();
    places.sort(_mostUsedFirst);
    return List<SavedPlace>.unmodifiable(places);
  }

  /// The saved place named [name] (compared by fold), or null.
  SavedPlace? find(String name) {
    final String key = SavedPlaceName.fold(name);
    for (final SavedPlace place in _stored()) {
      if (SavedPlaceName.fold(place.name) == key) return place;
    }
    return null;
  }

  /// Whether a place named [name] is saved.
  bool has(String name) => find(name) != null;

  /// Saves [name] (cleaned) with [latitude] and [longitude] when both are
  /// given, and gives the place back. Throws an [ArgumentError] carrying
  /// the [SavedPlaceError] for a name `SavedPlaceName.validate` refuses:
  /// check first, and show the user why.
  Future<SavedPlace> add(
    String name, {
    double? latitude,
    double? longitude,
  }) async {
    final List<SavedPlace> places = _stored();
    _check(name, places);
    final bool positioned = latitude != null && longitude != null;
    final SavedPlace place = SavedPlace(
      name: SavedPlaceName.clean(name),
      latitude: positioned ? latitude : null,
      longitude: positioned ? longitude : null,
    );
    await _write(<SavedPlace>[...places, place]);
    return place;
  }

  /// Gives the place named [name] the name [newName] (cleaned), keeping its
  /// coordinates and uses. Throws an [ArgumentError] for a name
  /// `SavedPlaceName.validate` refuses (another place's name included);
  /// an unknown [name] changes nothing.
  Future<void> rename(String name, String newName) async {
    final List<SavedPlace> places = _stored();
    final int at = _indexOf(places, name);
    if (at < 0) return;
    _check(newName, places, except: places[at].name);
    places[at] = places[at].copyWith(name: SavedPlaceName.clean(newName));
    await _write(places);
  }

  /// Gives the place named [name] the coordinates of a fix.
  Future<void> setCoordinates(
    String name, {
    required double latitude,
    required double longitude,
  }) => _update(
    name,
    (SavedPlace place) => place.copyWith(
      coordinates: () => (latitude: latitude, longitude: longitude),
    ),
  );

  /// Takes the coordinates off the place named [name].
  Future<void> clearCoordinates(String name) => _update(
    name,
    (SavedPlace place) => place.copyWith(coordinates: () => null),
  );

  /// Forgets the place named [name]; the clips that carry it keep it.
  Future<void> remove(String name) async {
    final List<SavedPlace> places = _stored();
    final int at = _indexOf(places, name);
    if (at < 0) return;
    places.removeAt(at);
    await _write(places);
  }

  /// Counts one more use of the place named [name] (it was picked for a
  /// clip).
  Future<void> touch(String name) =>
      _update(name, (SavedPlace place) => place.copyWith(uses: place.uses + 1));

  Future<void> dispose() => _changes.close();

  Future<void> _update(
    String name,
    SavedPlace Function(SavedPlace) change,
  ) async {
    final List<SavedPlace> places = _stored();
    final int at = _indexOf(places, name);
    if (at < 0) return;
    places[at] = change(places[at]);
    await _write(places);
  }

  void _check(String name, List<SavedPlace> places, {String? except}) {
    final SavedPlaceError? error = SavedPlaceName.validate(
      name,
      existing: <String>[for (final SavedPlace place in places) place.name],
      except: except,
    );
    if (error != null) {
      throw ArgumentError.value(name, 'name', error.name);
    }
  }

  static int _indexOf(List<SavedPlace> places, String name) {
    final String key = SavedPlaceName.fold(name);
    return places.indexWhere(
      (SavedPlace place) => SavedPlaceName.fold(place.name) == key,
    );
  }

  static int _mostUsedFirst(SavedPlace a, SavedPlace b) {
    final int byUses = b.uses.compareTo(a.uses);
    if (byUses != 0) return byUses;
    return SavedPlaceName.fold(a.name).compareTo(SavedPlaceName.fold(b.name));
  }

  Future<void> _write(List<SavedPlace> places) async {
    await _prefs.write(
      PrefKeys.savedPlaces,
      jsonEncode(<Object?>[
        for (final SavedPlace place in places)
          <String, Object?>{
            'name': place.name,
            if (place.hasCoordinates) 'lat': place.latitude,
            if (place.hasCoordinates) 'lon': place.longitude,
            'uses': place.uses,
          },
      ]),
    );
    if (!_changes.isClosed) _changes.add(null);
  }

  /// The stored list, in stored order.
  List<SavedPlace> _stored() {
    final String stored = _prefs.read(PrefKeys.savedPlaces);
    final Object? json;
    try {
      json = jsonDecode(stored);
    } on FormatException {
      _report(stored);
      return <SavedPlace>[];
    }
    if (json is! List<Object?>) {
      _report(stored);
      return <SavedPlace>[];
    }
    final List<SavedPlace> places = <SavedPlace>[];
    final Set<String> seen = <String>{};
    for (final Object? record in json) {
      final SavedPlace? place = _decode(record);
      if (place == null || !seen.add(SavedPlaceName.fold(place.name))) {
        _report(stored);
        continue;
      }
      places.add(place);
    }
    return places;
  }

  static SavedPlace? _decode(Object? record) {
    if (record is! Map<String, Object?>) return null;
    final Object? name = record['name'];
    final Object? lat = record['lat'];
    final Object? lon = record['lon'];
    final Object? uses = record['uses'];
    if (name is! String || SavedPlaceName.validate(name) != null) return null;
    if ((lat == null) != (lon == null)) return null;
    if (lat is! num? || lon is! num?) return null;
    if (uses is! int?) return null;
    return SavedPlace(
      name: SavedPlaceName.clean(name),
      latitude: lat?.toDouble(),
      longitude: lon?.toDouble(),
      uses: uses == null || uses < 0 ? 0 : uses,
    );
  }

  void _report(String stored) {
    if (stored == _reported) return;
    _reported = stored;
    _logger.warning(_tag, 'Ignored an unreadable savedPlaces preference');
  }
}
