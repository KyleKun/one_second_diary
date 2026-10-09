import 'dart:async';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_rewriter.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';

/// Mutes a saved clip, for good: its sound is replaced with a silent track by
/// a remux (`MuteCommands.silence`; picture, subtitles and other tags are
/// copied, the notes tag says `muted=1`), put in the clip's place through
/// [ClipRewriter]. The metadata cache mirrors it (`ClipMeta.isMuted`); a
/// reinstall reads it back from the file. Not final so tests can fake it.
class ClipAudio {
  ClipAudio({
    required MediaEngine engine,
    required MediaPublisher publisher,
    required ClipRepository repository,
    required ClipMetadataCache metadata,
    required ThumbnailRepository thumbnails,
    required AppPaths paths,
    required AppLogger logger,
  }) : this._(
         engine,
         repository,
         metadata,
         paths,
         logger,
         ClipRewriter(
           publisher: publisher,
           repository: repository,
           metadata: metadata,
           thumbnails: thumbnails,
           paths: paths,
         ),
       );

  ClipAudio._(
    this._engine,
    this._repository,
    this._metadata,
    this._paths,
    this._logger,
    this._rewriter,
  );

  final MediaEngine _engine;
  final ClipRepository _repository;
  final ClipMetadataCache _metadata;
  final AppPaths _paths;
  final ClipRewriter _rewriter;
  final AppLogger _logger;

  static const String _tag = 'MUTE';

  /// The end of the last mute asked for each clip, by relPath: a clip's
  /// writes run one after the other, so two taps never rewrite one file at
  /// once.
  final Map<String, Completer<void>> _writes = <String, Completer<void>>{};

  /// Whether [clip] is muted, as the metadata cache knows it (false for a
  /// clip not read yet).
  bool isMuted(ClipRef clip) => _cached(clip)?.isMuted ?? false;

  /// Replaces [clip]'s sound with silence; nothing to do when it is muted
  /// already.
  ///
  /// Throws `VideoProcessingException` when the probe or the remux failed
  /// and `MediaStoreException` when the gallery refused the new file; the
  /// clip is then as it was.
  Future<void> mute(ClipRef clip) async {
    final Completer<void>? previous = _writes[clip.relPath];
    final Completer<void> done = Completer<void>();
    _writes[clip.relPath] = done;
    try {
      // Never fails: a failed write is told to its own caller only.
      await previous?.future;
      await _mute(clip);
    } finally {
      if (identical(_writes[clip.relPath], done)) {
        _writes.remove(clip.relPath);
      }
      done.complete();
    }
  }

  Future<void> _mute(ClipRef clip) async {
    if (isMuted(clip)) return;
    try {
      // One probe: the notes tag (a typed place lives there) is not cached
      // and must survive, and the length is needed for the silent track.
      final ClipProbe probe = await _engine.probe(
        _paths.absoluteFromVideos(clip.relPath),
      );
      final int durationMs = switch (_cached(clip)?.durationMs) {
        final int cached when cached > 0 => cached,
        _ => probe.durationMs ?? 0,
      };
      if (durationMs <= 0) {
        // A silent track of no length is no track: the remux would fail
        // or write a clip without audio.
        throw VideoProcessingException(
          'No known length for ${clip.relPath}: cannot write its silence',
          returnCode: null,
          logTail: '',
        );
      }
      await _rewriter.replaceWith(
        clip,
        // The silent track in the clip's own layout (its profile's write-once
        // one), so a movie still joins it as a stream copy.
        remux: (String path) => _engine.remuxMute(
          clipPath: path,
          durationMs: durationMs,
          synopsis: probe.synopsis,
          channels: probe.channels == AudioChannels.stereo.count
              ? AudioChannels.stereo
              : AudioChannels.mono,
        ),
        patchMeta: (ClipMeta meta) => meta.withMuted(),
      );
      _logger.info(_tag, 'Muted ${clip.relPath}');
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not mute ${clip.relPath}',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  ClipMeta? _cached(ClipRef clip) {
    final FileStamp? stamp = _repository
        .snapshotOf(clip.profile)
        ?.stampOf(clip);
    return stamp == null
        ? null
        : _metadata.lookup(relPath: clip.relPath, stamp: stamp);
  }
}
