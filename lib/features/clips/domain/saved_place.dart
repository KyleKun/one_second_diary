import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';

/// Why a typed place name can't be saved.
enum SavedPlaceError {
  /// Nothing left after trimming.
  empty,

  /// Longer than [SavedPlaceName.maxLength] once cleaned.
  tooLong,

  /// A saved place already has this name (compared by [SavedPlaceName.fold]).
  duplicate,
}

/// The rules of a saved place's name, and the one form names are compared
/// in.
///
/// A name is free text: trimmed, with runs of whitespace collapsed to one
/// space and format characters removed ([clean], the tag rule), 1 to
/// [maxLength] characters (the stamp is one line). Two names are the same
/// when their [fold] is (accents composed, lower-cased), and the casing
/// typed first is the one kept.
abstract final class SavedPlaceName {
  /// The longest place, as the place sheet's field allows.
  static const int maxLength = 60;

  /// Why [raw] (as typed) can't be saved next to [existing], or null when
  /// it can. [except] is a saved name the rename leaves out of the
  /// duplicate check (the place renamed).
  static SavedPlaceError? validate(
    String raw, {
    Iterable<String> existing = const <String>[],
    String? except,
  }) {
    final String cleaned = clean(raw);
    if (cleaned.isEmpty) return SavedPlaceError.empty;
    if (cleaned.length > maxLength) return SavedPlaceError.tooLong;
    final String key = fold(cleaned);
    final String? skip = except == null ? null : fold(except);
    for (final String name in existing) {
      final String other = fold(name);
      if (other == skip) continue;
      if (other == key) return SavedPlaceError.duplicate;
    }
    return null;
  }

  /// [raw] as a place is stored. May be empty.
  static String clean(String raw) => TagName.clean(raw);

  /// The form two names are compared in.
  static String fold(String name) => TagName.fold(name);

  /// Whether [a] and [b] name the same place.
  static bool same(String a, String b) => fold(a) == fold(b);
}

/// A place the user saved (Settings › Places, or "Save this place" in the
/// clip editor): its [name], the coordinates of the fix taken when it was
/// added (if any) and how often it was picked.
final class SavedPlace extends Equatable {
  const SavedPlace({
    required this.name,
    this.latitude,
    this.longitude,
    this.uses = 0,
  });

  final String name;

  final double? latitude;

  final double? longitude;

  /// How many clips were given this place.
  final int uses;

  /// Whether the clip's `location` tag can carry it: both coordinates.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// This place renamed, re-positioned (both coordinates, or neither) or
  /// used again.
  SavedPlace copyWith({
    String? name,
    ({double latitude, double longitude})? Function()? coordinates,
    int? uses,
  }) {
    final ({double latitude, double longitude})? position = coordinates == null
        ? (hasCoordinates ? (latitude: latitude!, longitude: longitude!) : null)
        : coordinates();
    return SavedPlace(
      name: name ?? this.name,
      latitude: position?.latitude,
      longitude: position?.longitude,
      uses: uses ?? this.uses,
    );
  }

  @override
  List<Object?> get props => <Object?>[name, latitude, longitude, uses];
}
