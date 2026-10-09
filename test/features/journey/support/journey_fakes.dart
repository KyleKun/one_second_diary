import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/location/location_result.dart';
import 'package:one_second_diary/core/location/location_service.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_backfill.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/saved_places.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/saved_place.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';
import 'package:one_second_diary/features/journey/data/place_coordinates.dart';
import 'package:one_second_diary/features/journey/data/place_lookup.dart';
import 'package:one_second_diary/features/journey/domain/geo_point.dart';

/// A [SavedPlaces] over an in-memory list; [find] compares by fold.
/// [tellChanged] is the store reporting a write the test made to [places].
class FakeSavedPlaces extends Fake implements SavedPlaces {
  final List<SavedPlace> places = <SavedPlace>[];
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  @override
  Stream<void> get changes => _changes.stream;

  @override
  SavedPlace? find(String name) {
    final String key = SavedPlaceName.fold(name);
    for (final SavedPlace place in places) {
      if (SavedPlaceName.fold(place.name) == key) return place;
    }
    return null;
  }

  @override
  Future<SavedPlace> add(
    String name, {
    double? latitude,
    double? longitude,
  }) async {
    final SavedPlace place = SavedPlace(
      name: SavedPlaceName.clean(name),
      latitude: latitude,
      longitude: longitude,
    );
    places.add(place);
    tellChanged();
    return place;
  }

  @override
  Future<void> setCoordinates(
    String name, {
    required double latitude,
    required double longitude,
  }) async {
    final int at = places.indexWhere(
      (SavedPlace p) => SavedPlaceName.same(p.name, name),
    );
    if (at < 0) return;
    places[at] = places[at].copyWith(
      coordinates: () => (latitude: latitude, longitude: longitude),
    );
    tellChanged();
  }

  void tellChanged() => _changes.add(null);
}

/// A [LocationService] answering [result] to every fix.
class FakeLocationService extends Fake implements LocationService {
  LocationResult result = const LocationFailed(LocationFailure.noPosition);
  int fixes = 0;

  @override
  Future<LocationResult> locate({required String localeIdentifier}) async {
    fixes++;
    return result;
  }
}

/// A [PlaceCoordinates] over an in-memory map by `TagName.fold` key.
class FakePlaceCoordinates extends Fake implements PlaceCoordinates {
  final Map<String, GeoPoint> stored = <String, GeoPoint>{};
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  @override
  Stream<void> get changes => _changes.stream;

  @override
  GeoPoint? find(String fullName) => stored[TagName.fold(fullName)];

  @override
  Future<void> set(String fullName, GeoPoint at) async {
    stored[TagName.fold(fullName)] = at;
    _changes.add(null);
  }
}

/// A [PlaceLookup] answering [hits] by query, unknown for any other
/// (failed while [offline]); [requested] records every query asked.
class FakePlaceLookup extends Fake implements PlaceLookup {
  final Map<String, PlaceFound> hits = <String, PlaceFound>{};
  final List<String> requested = <String>[];
  bool offline = false;

  @override
  Future<PlaceLookupResult> find(
    String query, {
    required String localeIdentifier,
  }) async {
    requested.add(query);
    if (offline) return const PlaceLookupResult.failed();
    return hits[query] ?? const PlaceLookupResult.unknown();
  }
}

/// A [ClipMetadataCache] over an in-memory map of what the backfill has
/// learnt so far, by relPath; an entry describes the clip at any stamp.
class MapClipMetadataCache extends Fake implements ClipMetadataCache {
  final Map<String, ClipMeta> known = <String, ClipMeta>{};

  @override
  ClipMeta? lookup({required String relPath, required FileStamp stamp}) =>
      known[relPath];

  @override
  Set<String> get privateRelPaths => const <String>{};

  @override
  Stream<({String relPath, bool isPrivate})> get privacyChanges =>
      const Stream<({String relPath, bool isPrivate})>.empty();
}

/// A [ClipMetadataBackfill] the test drives: [enqueue] starts a run that
/// ends when the test calls [finish]; [whenIdle] completes at once while
/// nothing runs; [tellProgress] is the run telling what it learnt so far.
class ScriptedBackfill extends Fake implements ClipMetadataBackfill {
  final List<ClipIndex> enqueued = <ClipIndex>[];
  final StreamController<void> _progress = StreamController<void>.broadcast(
    sync: true,
  );
  Completer<void>? _running;

  @override
  Stream<void> get progress => _progress.stream;

  /// The run learnt more clips' metadata.
  void tellProgress() => _progress.add(null);

  /// Whether a run is in progress.
  bool get running => _running != null;

  @override
  void enqueue(ClipIndex index) {
    enqueued.add(index);
    _running ??= Completer<void>();
  }

  /// The run ends: everything queued was probed.
  void finish() {
    _running?.complete();
    _running = null;
  }

  @override
  Future<void> get whenIdle => _running?.future ?? Future<void>.value();
}
