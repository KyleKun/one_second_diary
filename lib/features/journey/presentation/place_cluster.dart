import 'dart:math' as math;

import 'package:one_second_diary/features/journey/domain/diary_place.dart';
import 'package:one_second_diary/features/journey/domain/geo_point.dart';
import 'package:one_second_diary/features/journey/domain/places_snapshot.dart';

/// One marker on the globe: a mapped place, or nearby places stacked at
/// the current zoom.
final class PlaceCluster {
  PlaceCluster(this.lead) : members = <DiaryPlace>[lead];

  /// The place with the most clips; the marker sits on it.
  final DiaryPlace lead;
  final List<DiaryPlace> members;

  GeoPoint get at => lead.at!;

  bool get single => members.length == 1;

  int get clips => PlacesSnapshot.clipCountOf(members);

  /// The widest angle from [lead] to a member, in radians.
  double get spread => members.fold(
    0,
    (double most, DiaryPlace p) => math.max(most, at.angleTo(p.at!)),
  );

  bool contains(String key) => members.any((DiaryPlace p) => p.key == key);

  /// Greedy: each mapped place of [places], most clips first, joins the
  /// first cluster whose lead is closer than [threshold] radians, or starts
  /// its own.
  static List<PlaceCluster> of(
    List<DiaryPlace> places, {
    required double threshold,
  }) {
    final List<PlaceCluster> clusters = <PlaceCluster>[];
    for (final DiaryPlace place in places) {
      final GeoPoint? at = place.at;
      if (at == null) continue;
      PlaceCluster? joined;
      for (final PlaceCluster c in clusters) {
        if (c.at.angleTo(at) < threshold) {
          joined = c;
          break;
        }
      }
      if (joined != null) {
        joined.members.add(place);
      } else {
        clusters.add(PlaceCluster(place));
      }
    }
    return clusters;
  }
}
