import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/journey/domain/diary_place.dart';
import 'package:one_second_diary/features/journey/domain/places_snapshot.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// How the last name lookup went.
enum PlaceLookupOutcome {
  /// Every name was found.
  found,

  /// Some names were found, [PlacesMapState.lookupMissing] were not.
  partial,

  /// The geocoder knew none of the names.
  none,

  /// The geocoder could not answer.
  offline,
}

/// The Places page: the active profile's places, the year shown, the name
/// lookup and the pin being taken from the phone's position.
final class PlacesMapState extends Equatable {
  const PlacesMapState({
    required this.profile,
    required this.today,
    this.snapshot,
    this.year,
    this.locating = false,
    this.lookupOutcome,
    this.lookupMissing = 0,
    this.pinning,
  });

  final ProfileKey profile;

  /// Today, for "Record today's clip".
  final LocalDay today;

  /// The places; null while the diary is being read.
  final PlacesSnapshot? snapshot;

  /// The year shown; null for all time. Always one of [years] (or null).
  final int? year;

  /// The name lookup is running.
  final bool locating;

  /// How the last lookup went; null until one ran this session.
  final PlaceLookupOutcome? lookupOutcome;

  /// Names the last lookup could not find.
  final int lookupMissing;

  /// The place text "Use current location" is finding a fix for.
  final String? pinning;

  bool get loading => snapshot == null;

  /// The places of [year] (every place when null), most clips first.
  List<DiaryPlace> get places => snapshot?.inYear(year) ?? const <DiaryPlace>[];

  List<int> get years => snapshot?.years ?? const <int>[];

  PlacesMapState copyWith({
    PlacesSnapshot? snapshot,
    int? Function()? year,
    bool? locating,
    PlaceLookupOutcome? Function()? lookupOutcome,
    int? lookupMissing,
    String? Function()? pinning,
    LocalDay? today,
  }) => PlacesMapState(
    profile: profile,
    today: today ?? this.today,
    snapshot: snapshot ?? this.snapshot,
    year: year == null ? this.year : year(),
    locating: locating ?? this.locating,
    lookupOutcome: lookupOutcome == null ? this.lookupOutcome : lookupOutcome(),
    lookupMissing: lookupMissing ?? this.lookupMissing,
    pinning: pinning == null ? this.pinning : pinning(),
  );

  @override
  List<Object?> get props => <Object?>[
    profile,
    today,
    snapshot,
    year,
    locating,
    lookupOutcome,
    lookupMissing,
    pinning,
  ];
}
