import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';
import 'package:one_second_diary/features/journey/domain/diary_place.dart';
import 'package:one_second_diary/features/journey/domain/geo_point.dart';

/// Where a profile's clips were filmed, derived from its [ClipIndex] and the
/// clips' cached facts, never stored: the places, their countries and the
/// queries the Journey's Places tile and the Places page run on them.
final class PlacesSnapshot extends Equatable {
  const PlacesSnapshot({required this.places, required this.diaryClipCount});

  /// No clip has a place.
  const PlacesSnapshot.empty()
    : this(places: const <DiaryPlace>[], diaryClipCount: 0);

  /// The places of [index]. [metaOf] gives a clip's cached facts (null while
  /// the backfill has not reached it: that clip has no place yet).
  /// [coordinatesOf] gives the coordinates known for a place text whose
  /// clips carry none (a saved place's fix, a looked-up name), or null.
  ///
  /// Private clips are left out, as their captions are hidden everywhere.
  /// A place's coordinates are the mean of its clips' fixes, else
  /// [coordinatesOf]. Places come most clips first, ties by name; the first
  /// is [home].
  factory PlacesSnapshot.of(
    ClipIndex index, {
    required ClipMeta? Function(ClipRef clip) metaOf,
    required GeoPoint? Function(String fullName) coordinatesOf,
  }) {
    final Map<String, String> keys = <String, String>{};
    final Map<String, String> names = <String, String>{};
    final Map<String, List<ClipRef>> clips = <String, List<ClipRef>>{};
    final Map<String, List<GeoPoint>> fixes = <String, List<GeoPoint>>{};
    for (final ClipRef clip in index.newestFirst) {
      if (index.isPrivate(clip)) continue;
      final ClipMeta? meta = metaOf(clip);
      final String text = meta?.locationText?.trim() ?? '';
      if (text.isEmpty) continue;
      // Folded once per distinct text: most clips share a few places.
      final String key = keys.putIfAbsent(text, () => TagName.fold(text));
      names.putIfAbsent(key, () => text);
      (clips[key] ??= <ClipRef>[]).add(clip);
      final double? lat = meta?.latitude;
      final double? lon = meta?.longitude;
      if (lat != null && lon != null && !(lat == 0 && lon == 0)) {
        (fixes[key] ??= <GeoPoint>[]).add(GeoPoint(lat, lon));
      }
    }
    final List<DiaryPlace> places = <DiaryPlace>[];
    for (final MapEntry<String, List<ClipRef>> entry in clips.entries) {
      final String fullName = names[entry.key]!;
      final ({String name, String? country}) parts = DiaryPlace.split(fullName);
      final List<GeoPoint>? known = fixes[entry.key];
      final GeoPoint? at = known == null
          ? coordinatesOf(fullName)
          : GeoPoint.centroid(known);
      places.add(
        DiaryPlace(
          key: entry.key,
          fullName: fullName,
          name: parts.name,
          country: parts.country,
          at: at,
          clips: List<ClipRef>.unmodifiable(entry.value.reversed),
          pinned: known == null && at != null,
        ),
      );
    }
    places.sort(mostClipsFirst);
    if (places.isNotEmpty) {
      final DiaryPlace top = places.first;
      places[0] = DiaryPlace(
        key: top.key,
        fullName: top.fullName,
        name: top.name,
        country: top.country,
        at: top.at,
        clips: top.clips,
        home: true,
        pinned: top.pinned,
      );
    }
    return PlacesSnapshot(
      places: List<DiaryPlace>.unmodifiable(places),
      diaryClipCount: index.clipCount - index.privateCount,
    );
  }

  /// Every place, most clips first; the first is [home].
  final List<DiaryPlace> places;

  /// Every visible clip of the profile that could have a place (private
  /// clips left out), with or without one.
  final int diaryClipCount;

  bool get isEmpty => places.isEmpty;

  /// The place with the most clips; null without places.
  DiaryPlace? get home => places.isEmpty ? null : places.first;

  List<DiaryPlace> get mapped =>
      places.where((DiaryPlace p) => p.isMapped).toList();

  List<DiaryPlace> get unmapped =>
      places.where((DiaryPlace p) => !p.isMapped).toList();

  /// Whether any place is on the map.
  bool get hasMapped => places.any((DiaryPlace p) => p.isMapped);

  /// Clips with a place, every year.
  int get clipCount => clipCountOf(places);

  /// The years with clips that have a place, newest first.
  List<int> get years {
    final Set<int> set = <int>{
      for (final DiaryPlace p in places)
        for (final ClipRef c in p.clips) c.day.year,
    };
    return set.toList()..sort((int a, int b) => b.compareTo(a));
  }

  DiaryPlace? byKey(String key) {
    for (final DiaryPlace p in places) {
      if (p.key == key) return p;
    }
    return null;
  }

  /// The places with clips in [year] (every place when null), each keeping
  /// only that year's clips; most clips first.
  List<DiaryPlace> inYear(int? year) {
    if (year == null) return places;
    final List<DiaryPlace> kept = <DiaryPlace>[
      for (final DiaryPlace place in places)
        if (place.clips.any((ClipRef c) => c.day.year == year))
          place.withClips(
            List<ClipRef>.unmodifiable(<ClipRef>[
              for (final ClipRef c in place.clips)
                if (c.day.year == year) c,
            ]),
          ),
    ];
    return kept..sort(mostClipsFirst);
  }

  /// Places first filmed in [year].
  List<DiaryPlace> newIn(int year) =>
      places.where((DiaryPlace p) => p.first.year == year).toList();

  /// The places whose name or country holds [query] (folded); none for a
  /// blank query.
  List<DiaryPlace> search(String query) {
    final String q = TagName.fold(query);
    if (q.isEmpty) return const <DiaryPlace>[];
    return places
        .where(
          (DiaryPlace p) =>
              TagName.fold(p.name).contains(q) ||
              (p.countryKey?.contains(q) ?? false),
        )
        .toList();
  }

  /// [home], then every other mapped place of [places] by its first clip:
  /// the route a replay flies. Fewer than two stops when it can't fly.
  List<DiaryPlace> route(List<DiaryPlace> places) {
    final DiaryPlace? home = this.home;
    if (home == null || !home.isMapped) return const <DiaryPlace>[];
    final List<DiaryPlace> away =
        places.where((DiaryPlace p) => p.isMapped && p.key != home.key).toList()
          ..sort((DiaryPlace a, DiaryPlace b) => a.first.compareTo(b.first));
    return <DiaryPlace>[home, ...away];
  }

  /// Below this, "farthest from home" is the same town.
  static const double farthestMinKm = 50;

  /// The mapped place of [places] farthest from [home], or null when home
  /// is not on the map or none is [farthestMinKm] away.
  DiaryPlace? farthest(List<DiaryPlace> places) {
    final GeoPoint? from = home?.at;
    if (from == null) return null;
    DiaryPlace? best;
    double bestKm = 0;
    for (final DiaryPlace p in places) {
      final GeoPoint? at = p.at;
      if (at == null) continue;
      final double km = from.kmTo(at);
      if (best == null || km > bestKm) {
        best = p;
        bestKm = km;
      }
    }
    return best == null || bestKm < farthestMinKm ? null : best;
  }

  /// Kilometres from [home] to [place]; null when either is off the map.
  double? kmFromHome(DiaryPlace place) {
    final GeoPoint? from = home?.at;
    final GeoPoint? to = place.at;
    return from == null || to == null ? null : from.kmTo(to);
  }

  /// Where a globe starts over [places]: their middle and a zoom that fits
  /// them. A world-spanning diary faces its home side instead.
  (GeoPoint, double) framing(List<DiaryPlace> places) {
    final List<GeoPoint> points = <GeoPoint>[
      for (final DiaryPlace p in places) ?p.at,
    ];
    final GeoPoint? centre = GeoPoint.centroid(points);
    if (centre == null) return (const GeoPoint(22, -20), 1);
    final double spread = points.fold(
      .02,
      (double most, GeoPoint p) =>
          most > centre.angleTo(p) ? most : centre.angleTo(p),
    );
    if (spread > .9) {
      final GeoPoint anchor = home?.at ?? centre;
      return (GeoPoint(anchor.lat - 12, anchor.lon - 15), 1);
    }
    return (centre, (.5 / spread).clamp(1, 2.4));
  }

  /// The countries of [places], most clips first. A place without a
  /// country is in none.
  static List<PlaceCountry> countriesOf(List<DiaryPlace> places) {
    final Map<String, List<DiaryPlace>> byKey = <String, List<DiaryPlace>>{};
    for (final DiaryPlace p in places) {
      final String? key = p.countryKey;
      if (key == null) continue;
      (byKey[key] ??= <DiaryPlace>[]).add(p);
    }
    final List<PlaceCountry> countries = <PlaceCountry>[
      for (final MapEntry<String, List<DiaryPlace>> e in byKey.entries)
        PlaceCountry(
          key: e.key,
          name: e.value.first.country!,
          places: List<DiaryPlace>.unmodifiable(e.value..sort(mostClipsFirst)),
        ),
    ];
    return countries..sort((PlaceCountry a, PlaceCountry b) {
      final int byClips = b.clipCount.compareTo(a.clipCount);
      return byClips != 0 ? byClips : a.name.compareTo(b.name);
    });
  }

  static int clipCountOf(List<DiaryPlace> places) =>
      places.fold(0, (int sum, DiaryPlace p) => sum + p.clips.length);

  /// Every clip of [places], oldest first.
  static List<ClipRef> clipsOf(List<DiaryPlace> places) =>
      <ClipRef>[for (final DiaryPlace p in places) ...p.clips]
        ..sort((ClipRef a, ClipRef b) {
          final int byDay = a.day.compareTo(b.day);
          return byDay != 0 ? byDay : a.ordinal.compareTo(b.ordinal);
        });

  static int mostClipsFirst(DiaryPlace a, DiaryPlace b) {
    final int byClips = b.clips.length.compareTo(a.clips.length);
    return byClips != 0
        ? byClips
        : TagName.fold(a.name).compareTo(TagName.fold(b.name));
  }

  @override
  List<Object?> get props => <Object?>[places, diaryClipCount];
}
