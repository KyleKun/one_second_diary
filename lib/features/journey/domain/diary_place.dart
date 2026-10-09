import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';
import 'package:one_second_diary/features/journey/domain/geo_point.dart';

/// A place the diary's clips were filmed at: every clip whose place text
/// (`ClipMeta.locationText`, found or typed) folds to the same [key].
final class DiaryPlace extends Equatable {
  const DiaryPlace({
    required this.key,
    required this.fullName,
    required this.name,
    required this.country,
    required this.at,
    required this.clips,
    this.home = false,
    this.pinned = false,
  });

  /// `TagName.fold` of [fullName]: the place's identity.
  final String key;

  /// The place text as the clips carry it ("Lisbon, Portugal", "Grandma's").
  final String fullName;

  /// [fullName] before its last comma, or all of it.
  final String name;

  /// [fullName] after its last comma; null when it has none.
  final String? country;

  /// Where it is; null while the place has a name but no coordinates.
  final GeoPoint? at;

  /// Oldest first (by day, then ordinal); never empty.
  final List<ClipRef> clips;

  /// The place with the most clips in the diary.
  final bool home;

  /// [at] was given to the name (a saved place's fix, a lookup, a pin), not
  /// read from the clips, so it can be changed.
  final bool pinned;

  bool get isMapped => at != null;

  LocalDay get first => clips.first.day;

  LocalDay get last => clips.last.day;

  /// The newest clip, whose poster stands for the place.
  ClipRef get newest => clips.last;

  /// `TagName.fold` of [country]; null without one.
  String? get countryKey => switch (country) {
    final String c => TagName.fold(c),
    null => null,
  };

  /// This place with only [kept] of its clips (a year's).
  DiaryPlace withClips(List<ClipRef> kept) => DiaryPlace(
    key: key,
    fullName: fullName,
    name: name,
    country: country,
    at: at,
    clips: kept,
    home: home,
    pinned: pinned,
  );

  /// Splits "City, Country" at its last comma; a text without one, or
  /// with an empty side, is all name.
  static ({String name, String? country}) split(String fullName) {
    final int comma = fullName.lastIndexOf(',');
    if (comma < 0) return (name: fullName, country: null);
    final String name = fullName.substring(0, comma).trim();
    final String country = fullName.substring(comma + 1).trim();
    if (name.isEmpty || country.isEmpty) {
      return (name: fullName, country: null);
    }
    return (name: name, country: country);
  }

  @override
  List<Object?> get props => <Object?>[
    key,
    fullName,
    name,
    country,
    at,
    clips,
    home,
    pinned,
  ];
}

/// A country of the diary: the places whose [DiaryPlace.country] folds to
/// the same [key].
final class PlaceCountry extends Equatable {
  const PlaceCountry({
    required this.key,
    required this.name,
    required this.places,
  });

  final String key;

  /// As first seen (the place with the most clips).
  final String name;

  /// Most clips first.
  final List<DiaryPlace> places;

  int get clipCount =>
      places.fold(0, (int sum, DiaryPlace p) => sum + p.clips.length);

  /// Up to two initials of [name], for a badge ("United States" → "US",
  /// "Portugal" → "P").
  String get initials {
    final List<String> words = name
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList();
    return words.take(2).map((String w) => w[0].toUpperCase()).join();
  }

  @override
  List<Object?> get props => <Object?>[key, name, places];
}
