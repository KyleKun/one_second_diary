import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/location/location_result.dart';
import 'package:one_second_diary/core/location/location_service.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_backfill.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/saved_places.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/saved_place.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';
import 'package:one_second_diary/features/journey/data/place_coordinates.dart';
import 'package:one_second_diary/features/journey/data/place_lookup.dart';
import 'package:one_second_diary/features/journey/domain/diary_place.dart';
import 'package:one_second_diary/features/journey/domain/geo_point.dart';
import 'package:one_second_diary/features/journey/domain/places_snapshot.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/diary_follower.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/places_map_state.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// The Places page: the active profile's places (`PlacesSnapshot`) kept in
/// step with the clip library, the metadata backfill, the saved places
/// and the looked-up coordinates; the year shown; the name lookup; and the
/// pins the user gives typed places.
class PlacesMapCubit extends Cubit<PlacesMapState> {
  PlacesMapCubit({
    required ProfilesRepository profiles,
    required ClipRepository clips,
    required this._metadata,
    required ClipMetadataBackfill backfill,
    required SavedPlaces savedPlaces,
    required PlaceCoordinates coordinates,
    required this._lookup,
    required this._locations,
    required Clock clock,
    required MidnightTicker midnight,
    required this._logger,
  }) : _savedPlaces = savedPlaces,
       _coordinates = coordinates,
       _clock = clock,
       super(
         PlacesMapState(
           profile: profiles.active.key,
           today: LocalDay.fromDateTime(clock.now()),
         ),
       ) {
    _diary = DiaryFollower(
      profiles: profiles,
      clips: clips,
      backfill: backfill,
      onLoading: _loading,
      onIndex: _show,
      onFailed: _failed,
      onMetadata: _recompute,
    );
    // Assigned before it starts: its first callbacks reach `_diary`.
    _diary.start();
    _days = midnight.days.listen((_) => emit(state.copyWith(today: _today)));
    _savedChanges = savedPlaces.changes.listen((_) => _recompute());
    _coordinateChanges = coordinates.changes.listen((_) => _recompute());
  }

  static const String _tag = 'PLACES';

  final ClipMetadataCache _metadata;
  final SavedPlaces _savedPlaces;
  final PlaceCoordinates _coordinates;
  final PlaceLookup _lookup;
  final LocationService _locations;
  final Clock _clock;
  final AppLogger _logger;
  late final DiaryFollower _diary;
  late final StreamSubscription<LocalDay> _days;
  late final StreamSubscription<void> _savedChanges;
  late final StreamSubscription<void> _coordinateChanges;

  @override
  Future<void> close() {
    _diary.close();
    unawaited(_days.cancel());
    unawaited(_savedChanges.cancel());
    unawaited(_coordinateChanges.cancel());
    return super.close();
  }

  /// Shows [year]'s places, or every place with null; a year without
  /// places is ignored.
  void setYear(int? year) {
    if (year != null && !state.years.contains(year)) return;
    emit(state.copyWith(year: () => year));
  }

  /// Whether the geocoder can be asked about [place]: "City, Country"
  /// names only. A name without a country ("Home") is the user's own.
  static bool canLookUp(DiaryPlace place) => place.country != null;

  /// Looks every unmapped "City, Country" name up once, in the app
  /// language [languageCode], and stores a hit whose country agrees with
  /// the name's; one run at a time. Only counts reach the normal log: the
  /// names are verbose lines. A run outlives a profile switch (the names
  /// are shared), but its outcome is not shown for the other profile.
  Future<void> placeOnMap({required String languageCode}) async {
    final List<DiaryPlace> names = (state.snapshot?.unmapped ?? <DiaryPlace>[])
        .where(canLookUp)
        .toList();
    if (state.locating || names.isEmpty) return;
    final ProfileKey profile = state.profile;
    emit(state.copyWith(locating: true));
    int found = 0;
    bool offline = false;
    for (final DiaryPlace place in names) {
      final PlaceLookupResult result = await _lookup.find(
        place.fullName,
        localeIdentifier: languageCode,
      );
      if (isClosed) return;
      // Offline, every name would fail the same slow way.
      if (result is PlaceLookupFailed) {
        offline = true;
        break;
      }
      if (result is PlaceFound &&
          _sameCountry(place, result) &&
          await _storeLookup(place.fullName, result.at)) {
        found++;
      } else {
        _logger.verbose(_tag, 'Not placed: ${place.fullName}');
      }
      if (isClosed) return;
    }
    final int missing = names.length - found;
    if (missing == 0) {
      _logger.info(_tag, 'Placed every one of ${names.length} place names');
    } else {
      _logger.warning(
        _tag,
        '$missing of ${names.length} place names could not be placed',
      );
    }
    if (state.profile != profile) {
      emit(state.copyWith(locating: false));
      return;
    }
    emit(
      state.copyWith(
        locating: false,
        lookupOutcome: () => missing == 0
            ? PlaceLookupOutcome.found
            : found == 0
            ? (offline ? PlaceLookupOutcome.offline : PlaceLookupOutcome.none)
            : PlaceLookupOutcome.partial,
        lookupMissing: missing,
      ),
    );
  }

  /// A hit is kept when the geocoder's country for the spot folds to the
  /// name's, or when it gave none to check against.
  static bool _sameCountry(DiaryPlace place, PlaceFound result) {
    final String? country = result.country;
    return country == null || TagName.fold(country) == place.countryKey;
  }

  /// Where the geocoder puts [query], for the user to confirm.
  Future<PlaceLookupResult> search(
    String query, {
    required String languageCode,
  }) => _lookup.find(query, localeIdentifier: languageCode);

  /// Gives the place text [fullName] the spot [at], as a saved place so the
  /// next clip tagged with that name carries the coordinates too. Whether
  /// it was stored; a refused write is logged.
  Future<bool> pin(String fullName, GeoPoint at) async {
    try {
      final SavedPlace? saved = _savedPlaces.find(fullName);
      if (saved != null) {
        await _savedPlaces.setCoordinates(
          fullName,
          latitude: at.lat,
          longitude: at.lon,
        );
      } else if (SavedPlaceName.validate(fullName) == null) {
        await _savedPlaces.add(fullName, latitude: at.lat, longitude: at.lon);
      } else {
        await _coordinates.set(fullName, at);
      }
      return true;
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not store a pin',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Pins [fullName] where the phone is now (the permission asked just in
  /// time); why no fix came, or null once pinned. One fix at a time.
  Future<LocationFailure?> pinCurrentLocation(
    String fullName, {
    required String languageCode,
  }) async {
    if (state.pinning != null) return LocationFailure.noPosition;
    emit(state.copyWith(pinning: () => fullName));
    try {
      final LocationResult result = await _locations.locate(
        localeIdentifier: languageCode,
      );
      if (isClosed) return LocationFailure.noPosition;
      switch (result) {
        case LocationFound(:final position):
          final bool stored = await pin(
            fullName,
            GeoPoint(position.latitude, position.longitude),
          );
          return stored ? null : LocationFailure.noPosition;
        case LocationFailed(:final failure):
          return failure;
      }
    } finally {
      if (!isClosed) emit(state.copyWith(pinning: () => null));
    }
  }

  /// Whether [at] was stored for the looked-up [fullName]; a refused
  /// write is logged.
  Future<bool> _storeLookup(String fullName, GeoPoint at) async {
    try {
      await _coordinates.set(fullName, at);
      return true;
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not store a looked-up place',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  LocalDay get _today => LocalDay.fromDateTime(_clock.now());

  void _loading() => emit(_startOver(_diary.profile!));

  /// A profile switch starts over (all time, no outcome yet); a lookup
  /// still running stays reported.
  PlacesMapState _startOver(ProfileKey profile) => PlacesMapState(
    profile: profile,
    today: _today,
    locating: state.locating,
    pinning: state.pinning,
  );

  /// `ClipRepository` logged why and sends its next snapshot when a
  /// rescan works; the page keeps loading until then.
  void _failed() =>
      _logger.warning(_tag, 'The diary could not be read: no places yet');

  void _show(ClipIndex index) => _apply(index, _snapshotOf(index));

  /// The places of the snapshot shown again, when the metadata or the
  /// places' coordinates changed them.
  void _recompute() {
    final ClipIndex? index = _diary.shown;
    if (isClosed || index == null) return;
    final PlacesSnapshot next = _snapshotOf(index);
    if (next != state.snapshot) _apply(index, next);
  }

  /// The year shown stays while it still has places. A clip whose facts
  /// the backfill has not reached has no place yet, so the places follow
  /// the running backfill.
  void _apply(ClipIndex index, PlacesSnapshot snapshot) {
    final PlacesMapState base = index.profile == state.profile
        ? state
        : _startOver(index.profile);
    final int? year = base.year;
    emit(
      base.copyWith(
        snapshot: snapshot,
        year: () => year != null && snapshot.years.contains(year) ? year : null,
      ),
    );
    final bool incomplete = index.newestFirst.any(
      (ClipRef clip) => _metaOf(index, clip) == null,
    );
    if (incomplete) unawaited(_diary.awaitBackfill());
  }

  PlacesSnapshot _snapshotOf(ClipIndex index) => PlacesSnapshot.of(
    index,
    metaOf: (ClipRef clip) => _metaOf(index, clip),
    coordinatesOf: _coordinatesOf,
  );

  ClipMeta? _metaOf(ClipIndex index, ClipRef clip) =>
      _metadata.lookup(relPath: clip.relPath, stamp: index.stampOf(clip)!);

  /// A saved place's fix under that name, else a looked-up name's.
  GeoPoint? _coordinatesOf(String fullName) {
    final SavedPlace? saved = _savedPlaces.find(fullName);
    if (saved != null && saved.hasCoordinates) {
      return GeoPoint(saved.latitude!, saved.longitude!);
    }
    return _coordinates.find(fullName);
  }
}
