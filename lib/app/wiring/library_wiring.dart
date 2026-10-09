import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_backfill.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/originals_store.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/thumbnail_tier.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_change.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/domain/profiles_snapshot.dart';

/// Keeps the clip library current for the whole session:
///
/// - every profile's clip snapshots, the active one first, go to the metadata
///   backfill and the cell thumbnails;
/// - what the metadata cache knows (private clips, tags, clips not made by the
///   app) is in the library from its first snapshot, and so is each clip read,
///   marked private or tagged since;
/// - a new profile is scanned, and a deleted one leaves the index;
/// - the Originals folder's names are scanned at launch and on resume and
///   followed through every write there (`ClipIndex.hasSource`); a source whose
///   clip is gone is logged and left alone (the user may be mid-restore);
/// - on resume, changed folders are rescanned and the day is checked (timers do
///   not run while suspended); on pause, the metadata sidecar is saved.
///
/// Nothing here throws: a failure is logged and the wiring goes on.
class LibraryWiring {
  LibraryWiring({
    required this._profiles,
    required this._clips,
    required this._backfill,
    required this._thumbnails,
    required this._metadata,
    required this._midnight,
    required this._lifecycleStates,
    required this._logger,
    OriginalsStore? originals,
  }) : _originals = originals; // ignore: prefer_initializing_formals

  final ProfilesRepository _profiles;
  final ClipRepository _clips;
  final ClipMetadataBackfill _backfill;
  final ThumbnailRepository _thumbnails;
  final ClipMetadataCache _metadata;
  final MidnightTicker _midnight;
  final Stream<AppLifecycleState> _lifecycleStates;
  final AppLogger _logger;

  /// The kept originals; null when the app keeps none.
  final OriginalsStore? _originals;

  static const String _tag = 'APP';

  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  /// The canvas of each profile, from the latest profiles snapshot.
  final Map<ProfileKey, VideoOrientation> _canvases =
      <ProfileKey, VideoOrientation>{};

  /// The profiles whose clip snapshots are followed.
  final Set<ProfileKey> _watched = <ProfileKey>{};

  /// Follows the profiles, every profile's clip snapshots and the app
  /// lifecycle. Start it once the clip caches are loaded, before the clips
  /// are scanned.
  void start() {
    _clips
      ..privateClipsKnown(_metadata.privateRelPaths)
      ..clipTagsKnown(_metadata.tagsByRelPath)
      ..foreignClipsKnown(_metadata.foreignRelPaths);
    _subscriptions
      ..add(
        _metadata.privacyChanges.listen(
          (({String relPath, bool isPrivate}) change) =>
              _clips.privacyKnown(change.relPath, private: change.isPrivate),
        ),
      )
      ..add(
        _metadata.schemaChanges.listen(
          (({String relPath, bool isForeign}) change) =>
              _clips.schemaKnown(change.relPath, foreign: change.isForeign),
        ),
      )
      ..add(
        _metadata.tagChanges.listen(
          (({String relPath, List<String> tags}) change) =>
              _clips.tagsKnown(change.relPath, change.tags),
        ),
      )
      ..add(_profiles.watch().listen(_profilesChanged))
      ..add(_profiles.changes.listen(_profileAddedOrRemoved))
      ..add(_lifecycleStates.listen(_lifecycleChanged));
    final OriginalsStore? originals = _originals;
    if (originals != null) {
      _subscriptions.add(originals.sourcesChanged.listen(_clips.sourcesKnown));
      unawaited(_scanOriginals(originals));
    }
  }

  Future<void> dispose() async {
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  void _profilesChanged(ProfilesSnapshot snapshot) {
    for (final Profile profile in snapshot.profiles) {
      _canvases[profile.key] = profile.orientation;
    }
    _watch(snapshot.active.key);
    for (final Profile profile in snapshot.profiles) {
      _watch(profile.key);
    }
  }

  /// A new profile gets its clip index; a deleted one leaves the library.
  void _profileAddedOrRemoved(ProfileChange change) {
    switch (change) {
      case ProfileAdded(:final ProfileKey key):
        unawaited(_scan(key));
      case ProfileRemoved(:final ProfileKey key):
        _clips.profileRemoved(key);
    }
  }

  Future<void> _scan(ProfileKey profile) async {
    try {
      await _clips.rescan(profile);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not scan the new profile ${profile.albumLabel}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Lists the Originals folder's names (the store tells the library
  /// through `sourcesChanged`) and logs every source without a clip.
  Future<void> _scanOriginals(OriginalsStore originals) async {
    final Set<String> sources = await originals.scanNames();
    for (final String relPath in sources) {
      final ProfileKey profile = _profileOf(relPath);
      final ClipIndex? index = _clips.snapshotOf(profile);
      if (index == null) continue;
      final ClipRef? clip = ClipRef.tryParse(
        profile: profile,
        relPath: relPath,
      );
      if (clip == null || index.stampOf(clip) == null) {
        _logger.info(
          _tag,
          'The original of $relPath has no clip; left where it is',
        );
      }
    }
  }

  /// The profile a diary relPath belongs to: `Profiles/<key>/…`, else
  /// Default.
  static ProfileKey _profileOf(String relPath) {
    const String prefix = '${PathNames.profilesFolder}/';
    if (!relPath.startsWith(prefix)) return ProfileKey.defaultProfile;
    final int slash = relPath.lastIndexOf('/');
    return slash <= prefix.length
        ? ProfileKey.defaultProfile
        : ProfileKey(relPath.substring(prefix.length, slash));
  }

  /// Follows [profile]'s clip snapshots, once.
  void _watch(ProfileKey profile) {
    if (!_watched.add(profile)) return;
    _subscriptions.add(
      _clips
          .watch(profile)
          .listen(
            (ClipIndex index) => _clipsChanged(profile, index),
            // A failed scan: ClipRepository logged it and the screens show
            // it; the next snapshot comes through as usual.
            onError: (Object _) {},
          ),
    );
  }

  /// Every snapshot: both backfills look only at what changed since the
  /// previous one.
  void _clipsChanged(ProfileKey profile, ClipIndex index) {
    _backfill.enqueue(index);
    _thumbnails.backfill(
      index,
      tier: ThumbnailTier.cell,
      orientation: _canvases[profile] ?? VideoOrientation.landscape,
    );
  }

  void _lifecycleChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_rescanChanged(_profiles.active.key));
        if (_originals case final OriginalsStore originals) {
          unawaited(_scanOriginals(originals));
        }
        _midnight.check();
      case AppLifecycleState.paused:
        unawaited(_metadata.flush());
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _rescanChanged(ProfileKey active) async {
    try {
      await _clips.rescanChanged(active: active);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not look for clips changed while the app was away',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
