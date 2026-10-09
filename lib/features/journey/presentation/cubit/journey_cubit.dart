import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
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
import 'package:one_second_diary/features/clips/domain/journey_stats.dart';
import 'package:one_second_diary/features/clips/domain/saved_place.dart';
import 'package:one_second_diary/features/journey/data/place_coordinates.dart';
import 'package:one_second_diary/features/journey/domain/geo_point.dart';
import 'package:one_second_diary/features/journey/domain/places_snapshot.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/diary_follower.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/journey_state.dart';
import 'package:one_second_diary/features/movies/data/movie_repository.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// The Journey tab: the active profile's statistics, tags and places,
/// derived from its clip index, the clip metadata, the saved places and
/// the looked-up coordinates, never from stored counters; and the movies
/// made.
class JourneyCubit extends Cubit<JourneyState> {
  JourneyCubit({
    required ProfilesRepository profiles,
    required ClipRepository clips,
    required this._metadata,
    required ClipMetadataBackfill backfill,
    required SavedPlaces savedPlaces,
    required PlaceCoordinates coordinates,
    required this._movies,
    required this._clock,
    required MidnightTicker midnight,
    required this._logger,
  }) : _savedPlaces = savedPlaces,
       _coordinates = coordinates,
       super(const JourneyState.loading()) {
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
    _days = midnight.days.listen((_) => _recompute());
    _savedChanges = savedPlaces.changes.listen((_) => _recompute());
    _coordinateChanges = coordinates.changes.listen((_) => _recompute());
    unawaited(refreshMovies());
  }

  static const String _tag = 'JOURNEY';

  final ClipMetadataCache _metadata;
  final SavedPlaces _savedPlaces;
  final PlaceCoordinates _coordinates;
  final MovieRepository _movies;
  final Clock _clock;
  final AppLogger _logger;
  late final DiaryFollower _diary;
  late final StreamSubscription<LocalDay> _days;
  late final StreamSubscription<void> _savedChanges;
  late final StreamSubscription<void> _coordinateChanges;

  /// Stops following at once (the midnight timer stops with it) and
  /// closes without waiting for the repositories' streams.
  @override
  Future<void> close() {
    _diary.close();
    unawaited(_days.cancel());
    unawaited(_savedChanges.cancel());
    unawaited(_coordinateChanges.cancel());
    return super.close();
  }

  /// Reads the movies again ("Movies made", the My movies row): after My
  /// movies, after a movie was made. A folder that can't be read keeps
  /// the last list.
  Future<void> refreshMovies() async {
    try {
      final List<MovieEntry> movies = await _movies.list();
      if (!isClosed) emit(state.copyWith(movies: movies));
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not list the movies',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// "Try again" on a diary that could not be read: reads the active
  /// profile's folder again; the stats show, or it says again that the
  /// diary can't be read (`ClipRepository` logged why).
  Future<void> readAgain() async {
    final ProfileKey? profile = _diary.profile;
    if (profile == null || state.status != JourneyStatus.failed) return;
    _loading();
    try {
      await _diary.rescan();
    } on AppException {
      if (!isClosed && _diary.profile == profile) _failed();
    }
  }

  void _loading() =>
      emit(JourneyState(status: JourneyStatus.loading, movies: state.movies));

  void _failed() {
    if (_diary.shown != null) return;
    emit(JourneyState(status: JourneyStatus.failed, movies: state.movies));
  }

  void _show(ClipIndex index) => _apply(index, _stateOf(index));

  /// The state of the snapshot shown again, when the metadata, the day or
  /// the places changed it.
  void _recompute() {
    final ClipIndex? index = _diary.shown;
    if (isClosed || index == null) return;
    final JourneyState next = _stateOf(index);
    if (next != state) _apply(index, next);
  }

  /// "Your life so far" is an estimate while clips' durations are unknown,
  /// and a place is missing while a clip's facts are: both follow the
  /// running backfill.
  void _apply(ClipIndex index, JourneyState next) {
    emit(next);
    if (next.stats!.lifeSoFarIsEstimate) unawaited(_diary.awaitBackfill());
  }

  JourneyState _stateOf(ClipIndex index) {
    ClipMeta? metaOf(ClipRef clip) =>
        _metadata.lookup(relPath: clip.relPath, stamp: index.stampOf(clip)!);
    return JourneyState(
      status: JourneyStatus.ready,
      stats: JourneyStats.of(
        index,
        today: LocalDay.fromDateTime(_clock.now()),
        metaOf: metaOf,
      ),
      clipCount: index.clipCount,
      tagCounts: index.tagCounts,
      places: PlacesSnapshot.of(
        index,
        metaOf: metaOf,
        coordinatesOf: _coordinatesOf,
      ),
      movies: state.movies,
    );
  }

  /// A saved place's fix under that name, else a looked-up name's.
  GeoPoint? _coordinatesOf(String fullName) {
    final SavedPlace? saved = _savedPlaces.find(fullName);
    if (saved != null && saved.hasCoordinates) {
      return GeoPoint(saved.latitude!, saved.longitude!);
    }
    return _coordinates.find(fullName);
  }
}
