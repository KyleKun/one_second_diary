import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/location/location_result.dart';
import 'package:one_second_diary/core/location/location_service.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/features/clips/data/saved_places.dart';
import 'package:one_second_diary/features/clips/domain/saved_place.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/places_state.dart';

/// Settings › Places, and the Settings tab's place count.
///
/// [load] reads the saved places and keeps them fresh through
/// `SavedPlaces.changes` (the clip editor saves and counts uses too). A
/// name [add] or [rename] refuses is answered with why
/// (`SavedPlaceName.validate`), so the sheet shows it; a store that fails
/// is logged and counted in [PlacesState.saveFailures].
///
/// [useCurrentLocation] takes one fix through the `LocationService` (the
/// permission is asked just in time, as the clip editor does) and gives
/// it to the place; a failure is counted in [PlacesState.locateFailures]
/// with why.
class PlacesCubit extends Cubit<PlacesState> {
  PlacesCubit({
    required this._places,
    required this._locations,
    required this._logger,
  }) : super(const PlacesState());

  final SavedPlaces _places;
  final LocationService _locations;
  final AppLogger _logger;

  static const String _tag = 'PLACES';

  StreamSubscription<void>? _changes;

  /// Reads the places and follows the store.
  void load() {
    _changes ??= _places.changes.listen((_) => _refresh());
    _refresh();
  }

  void _refresh() {
    if (isClosed) return;
    emit(state.copyWith(places: _places.read(), loaded: true));
  }

  /// Saves [name]; why it can't be, or null once it is.
  Future<SavedPlaceError?> add(String name) async {
    final SavedPlaceError? error = SavedPlaceName.validate(
      name,
      existing: _names,
    );
    if (error != null) return error;
    await _store('save a place', () => _places.add(name));
    return null;
  }

  /// Renames the place [from] to [to]; why it can't be, or null once it
  /// is.
  Future<SavedPlaceError?> rename(String from, String to) async {
    final SavedPlaceError? error = SavedPlaceName.validate(
      to,
      existing: _names,
      except: from,
    );
    if (error != null) return error;
    await _store('rename a place', () => _places.rename(from, to));
    return null;
  }

  /// Forgets the place [name]; the clips that carry it keep it.
  Future<void> remove(String name) =>
      _store('remove a place', () => _places.remove(name));

  /// Takes the coordinates off the place [name].
  Future<void> clearCoordinates(String name) => _store(
    'remove the coordinates of a place',
    () => _places.clearCoordinates(name),
  );

  /// Gives the place [name] the coordinates of the phone's position now.
  /// One lookup at a time; [languageCode] names the fix's place (unused
  /// here, the service wants it).
  Future<void> useCurrentLocation(
    String name, {
    required String languageCode,
  }) async {
    if (state.isLocating) return;
    emit(state.copyWith(locating: name));
    try {
      final LocationResult result = await _locations.locate(
        localeIdentifier: languageCode,
      );
      if (isClosed) return;
      switch (result) {
        case LocationFound(:final position):
          await _store(
            'store the coordinates of a place',
            () => _places.setCoordinates(
              name,
              latitude: position.latitude,
              longitude: position.longitude,
            ),
          );
        case LocationFailed(:final failure):
          emit(
            state.copyWith(
              locateFailures: state.locateFailures + 1,
              lastLocateFailure: failure,
            ),
          );
      }
    } finally {
      if (!isClosed) emit(state.copyWith(clearLocating: true));
    }
  }

  List<String> get _names => <String>[
    for (final SavedPlace place in state.places) place.name,
  ];

  Future<void> _store(String what, Future<void> Function() write) async {
    try {
      await write();
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not $what',
        error: error,
        stackTrace: stackTrace,
      );
      if (!isClosed) {
        emit(state.copyWith(saveFailures: state.saveFailures + 1));
      }
    }
  }

  @override
  Future<void> close() async {
    await _changes?.cancel();
    return super.close();
  }
}
