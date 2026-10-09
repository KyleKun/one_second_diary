import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/location/location_result.dart';
import 'package:one_second_diary/features/clips/domain/saved_place.dart';

/// Settings › Places: every saved place, most used first, the place whose
/// coordinates are being looked up (if any), and counters the page's
/// feedback follows.
final class PlacesState extends Equatable {
  const PlacesState({
    this.places = const <SavedPlace>[],
    this.loaded = false,
    this.locating,
    this.saveFailures = 0,
    this.locateFailures = 0,
    this.lastLocateFailure,
  });

  /// Most used first (`SavedPlaces.read`).
  final List<SavedPlace> places;

  /// Whether [places] has been read at least once (an empty list before
  /// that is "not read yet", not "no places").
  final bool loaded;

  /// The name of the place "Use current location" is finding a fix for.
  final String? locating;

  /// Grows each time a change could not be stored (the page says so).
  final int saveFailures;

  /// Grows each time "Use current location" found no fix; why is in
  /// [lastLocateFailure].
  final int locateFailures;

  final LocationFailure? lastLocateFailure;

  bool get hasPlaces => places.isNotEmpty;

  bool get isLocating => locating != null;

  /// The saved place named [name] (compared by fold), as the list knows it
  /// now, or null.
  SavedPlace? placeNamed(String name) {
    for (final SavedPlace place in places) {
      if (SavedPlaceName.same(place.name, name)) return place;
    }
    return null;
  }

  PlacesState copyWith({
    List<SavedPlace>? places,
    bool? loaded,
    String? locating,
    bool clearLocating = false,
    int? saveFailures,
    int? locateFailures,
    LocationFailure? lastLocateFailure,
  }) => PlacesState(
    places: places ?? this.places,
    loaded: loaded ?? this.loaded,
    locating: clearLocating ? null : (locating ?? this.locating),
    saveFailures: saveFailures ?? this.saveFailures,
    locateFailures: locateFailures ?? this.locateFailures,
    lastLocateFailure: lastLocateFailure ?? this.lastLocateFailure,
  );

  @override
  List<Object?> get props => <Object?>[
    places,
    loaded,
    locating,
    saveFailures,
    locateFailures,
    lastLocateFailure,
  ];
}
