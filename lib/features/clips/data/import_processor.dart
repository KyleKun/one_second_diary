import 'dart:async';
import 'dart:io';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/rendered_clip.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/platform/media_store_gateway.dart';
import 'package:one_second_diary/core/platform/wakelock_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_backfill.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/data/originals_store.dart';
import 'package:one_second_diary/features/clips/domain/clip_conversion.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_name_codec.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_write.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/imported_video.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

/// The format a profile's clips are saved in (`ClipFormat.parse` of
/// `PrefKeys.clipFormat`, `ClipFormat.legacy` when absent): the profiles
/// repository answers it; injected so the clips feature never reads a
/// profile preference itself.
typedef ProfileFormatOf = ClipFormat Function(ProfileKey profile);

/// The date stamp's text for [day] in [format], in the app language with
/// the phone's region (`DateStamp.text`), as the clip editor's preview
/// draws it. The sheet that starts a run passes it from its context.
typedef StampTextOf = String Function(LocalDay day, StampFormat format);

/// Turns the foreign videos of the diary folder into the app's own clips, one
/// by one through the engine's queue, in this order per file so nothing is
/// ever lost:
///
/// 1. render into scratch with the normal save command (`VideoRender`: not a
///    recording, trim 0 to the chosen length, the day's date stamp or none,
///    the profile's format and album, origin `import`; no subtitles, tags,
///    place or privacy). The original is only read;
/// 2. move the original beside the diary (`OriginalsStore`); a refused or
///    failed move leaves it where it is, deletes the render and skips the file
///    (logged, counted, with the reason);
/// 3. publish the render under the day name through `ClipStore` and write its
///    sidecar entry from the render.
///
/// On Android 11+ the originals belong to the file manager: one media-store
/// consent is asked for the whole batch first ([MediaStoreGateway
/// .requestWrite]); a declined request skips the whole batch with
/// [ImportSkipReason.moveRefused]. The wakelock is held and the metadata
/// backfill paused while it runs; a cancel ends after the file in flight,
/// keeping what was done. Not final so tests can fake it.
class ImportProcessor {
  ImportProcessor({
    required this._engine,
    required this._store,
    required this._clips,
    required this._metadata,
    required this._mediaStore,
    required this._wakelock,
    required this._backfill,
    required this._settings,
    required this._formatOf,
    required this._paths,
    required this._logger,
    required this._requiresWriteConsent,
    required this._prefs,
    required this._originals,
    EncodeSpeedOf? speedOf,
  }) : _speedOf = speedOf ?? _realTime;

  static double _realTime(ClipFormat _) => 1.0;

  final MediaEngine _engine;
  final ClipStore _store;
  final ClipRepository _clips;
  final ClipMetadataCache _metadata;
  final MediaStoreGateway _mediaStore;
  final WakelockGateway _wakelock;
  final ClipMetadataBackfill _backfill;
  final SettingsRepository _settings;
  final ProfileFormatOf _formatOf;
  final AppPaths _paths;
  final AppLogger _logger;

  /// Android 11 and later (scoped storage with per-file consent).
  final bool _requiresWriteConsent;

  /// The sheet's two remembered choices and the last quick cut.
  final PrefsStore _prefs;

  /// The folder the originals go to: its size and "Delete originals".
  final OriginalsStore _originals;

  /// The phone check's encode speed, for "about 4 min".
  final EncodeSpeedOf _speedOf;

  /// The sheet's choices as remembered: the first quick cut
  /// (`PrefKeys.lastQuickCutMs`, 1.5 s by default) unless "keep the whole
  /// video" was chosen, the date stamp on unless turned off.
  ImportChoices get choices => ImportChoices(
    keepWhole: _prefs.read(PrefKeys.importKeepWhole),
    dateStamp: _prefs.read(PrefKeys.importDateStamp),
    quickCutMs: _prefs.read(PrefKeys.lastQuickCutMs),
  );

  /// Remembers [choices] for the next time.
  Future<void> rememberChoices(ImportChoices choices) async {
    await _prefs.write(PrefKeys.importKeepWhole, choices.keepWhole);
    await _prefs.write(PrefKeys.importDateStamp, choices.dateStamp);
  }

  /// About how long processing [durationMs] of video of [profile] takes
  /// on this phone.
  Duration timeFor({required int durationMs, required ProfileKey profile}) {
    final double factor = _speedOf(_formatOf(profile));
    final double seconds = durationMs / 1000 / (factor <= 0 ? 1 : factor);
    return Duration(milliseconds: (seconds * 1000).round());
  }

  /// The bytes the Originals folder holds.
  Future<int> originalsSizeBytes() => _originals.sizeBytes();

  /// Deletes every original (the user confirmed); how many went.
  Future<int> deleteOriginals() => _originals.deleteAll();

  static const String _tag = 'IMPORT';

  /// Every foreign video the library knows, per [profiles] in that order:
  /// the indexed clips whose schema is not the app's (newest first, their
  /// length from the cache) and the date-named files with another
  /// extension found beside them.
  List<ImportedVideo> candidates(Iterable<ProfileKey> profiles) =>
      <ImportedVideo>[
        for (final ProfileKey profile in profiles) ..._candidatesOf(profile),
      ];

  List<ImportedVideo> _candidatesOf(ProfileKey profile) {
    final ClipIndex? index = _clips.snapshotOf(profile);
    if (index == null) return const <ImportedVideo>[];
    return <ImportedVideo>[
      for (final ClipRef clip in index.foreignClips)
        if (_cachedMeta(index, clip) case final ClipMeta? meta)
          ImportedVideo(
            profile: profile,
            relPath: clip.relPath,
            day: clip.day,
            clip: clip,
            durationMs: meta?.durationMs,
            colorTransfer: meta?.colorTransfer,
          ),
      for (final String relPath in _clips.foreignFilesOf(profile))
        if (_dayOf(relPath) case final LocalDay day)
          ImportedVideo(profile: profile, relPath: relPath, day: day),
    ];
  }

  /// [videos] with their lengths (and colour transfers), probing the ones
  /// the cache does not know (a file beside the clips); a file that
  /// cannot be probed keeps null and is skipped by [process].
  Future<List<ImportedVideo>> withDurations(List<ImportedVideo> videos) async {
    final List<ImportedVideo> known = <ImportedVideo>[];
    for (final ImportedVideo video in videos) {
      if (video.durationMs != null) {
        known.add(video);
        continue;
      }
      final ClipProbe? probe = await _probe(video);
      final int? durationMs = probe?.durationMs;
      known.add(
        durationMs == null
            ? video
            : video.withDuration(
                durationMs,
                colorTransfer: probe?.colorTransfer,
              ),
      );
    }
    return known;
  }

  /// Processes [videos] in order with [choices], [stampText] giving the
  /// day's stamp. Emits an [ImportProgress] per step, an [ImportVideoDone]
  /// or [ImportVideoSkipped] per video and one [ImportFinished] at the end,
  /// also after a cancel. Never throws: every failure is a skip.
  Stream<ImportEvent> process(
    List<ImportedVideo> videos, {
    required ImportChoices choices,
    required StampTextOf stampText,
    CancelToken? cancelToken,
  }) async* {
    final List<ClipRef> processed = <ClipRef>[];
    final Map<ImportedVideo, ImportSkipReason> skipped =
        <ImportedVideo, ImportSkipReason>{};
    bool cancelled = false;
    if (videos.isEmpty) {
      yield const ImportFinished(ImportReport.nothing);
      return;
    }
    if (_requiresWriteConsent &&
        !await _mediaStore.requestWrite(<String>[
          for (final ImportedVideo video in videos)
            _paths.absoluteFromVideos(video.relPath),
        ])) {
      _logger.warning(_tag, 'The user declined to move the originals');
      for (final ImportedVideo video in videos) {
        skipped[video] = ImportSkipReason.moveRefused;
        yield ImportVideoSkipped(
          video: video,
          reason: ImportSkipReason.moveRefused,
        );
      }
      yield ImportFinished(
        ImportReport(processed: processed, skipped: skipped, cancelled: false),
      );
      return;
    }
    await _wakelock.enable();
    _backfill.pause();
    try {
      for (final (int index, ImportedVideo video) in videos.indexed) {
        if (cancelToken?.isCancelled ?? false) {
          cancelled = true;
          break;
        }
        yield ImportProgress(index: index, total: videos.length, fraction: 0);
        final StreamController<double> fractions =
            StreamController<double>.broadcast();
        final Future<({ClipRef? clip, ImportSkipReason? reason})> work =
            _processOne(
              video,
              choices: choices,
              stampText: stampText,
              cancelToken: cancelToken,
              onProgress: fractions.add,
            );
        // The progress of the file in flight, until it ends.
        yield* fractions.stream
            .map(
              (double fraction) => ImportProgress(
                index: index,
                total: videos.length,
                fraction: fraction,
              ),
            )
            .takeUntil(work);
        final ({ClipRef? clip, ImportSkipReason? reason}) outcome = await work;
        await fractions.close();
        if (outcome.clip case final ClipRef clip) {
          processed.add(clip);
          yield ImportVideoDone(video: video, clip: clip);
        } else if (outcome.reason case final ImportSkipReason reason) {
          skipped[video] = reason;
          yield ImportVideoSkipped(video: video, reason: reason);
        } else {
          cancelled = true;
          break;
        }
      }
    } finally {
      _backfill.resume();
      await _wakelock.disable();
    }
    yield ImportFinished(
      ImportReport(
        processed: processed,
        skipped: skipped,
        cancelled: cancelled,
      ),
    );
  }

  /// One video: null clip and null reason means a cancel ended it.
  Future<({ClipRef? clip, ImportSkipReason? reason})> _processOne(
    ImportedVideo video, {
    required ImportChoices choices,
    required StampTextOf stampText,
    required CancelToken? cancelToken,
    required void Function(double fraction) onProgress,
  }) async {
    final String source = _paths.absoluteFromVideos(video.relPath);
    if (!await File(source).exists()) {
      return (clip: null, reason: ImportSkipReason.missing);
    }
    final ClipProbe? probe = video.durationMs == null
        ? await _probe(video)
        : null;
    final int? durationMs = video.durationMs ?? probe?.durationMs;
    if (durationMs == null) {
      return (clip: null, reason: ImportSkipReason.renderFailed);
    }
    final ClipFormat format = _formatOf(video.profile);
    final VideoRender request = VideoRender(
      sourcePath: source,
      fromRecording: false,
      trimStartMs: 0,
      trimEndMs: choices.trimEndMs(durationMs),
      outputFileName: ClipNameCodec.format(video.day),
      stampText: choices.dateStamp
          ? stampText(video.day, _settings.stampStyle.value.format)
          : '',
      stampStyle: _settings.stampStyle.value,
      legacyStampFont: _settings.legacyStampFont.value,
      location: const ClipLocation.off(),
      subtitles: '',
      format: format,
      albumLabel: video.profile.albumLabel,
      imported: true,
      // An HDR import is converted into the profile's range.
      sourceColorTransfer: video.colorTransfer ?? probe?.colorTransfer,
    );
    final RenderedClip rendered;
    try {
      rendered = await _engine.renderClip(
        request,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );
    } on CancelledException {
      return (clip: null, reason: null);
    } on AppException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not render the imported video ${video.relPath}',
        error: error,
        stackTrace: stackTrace,
      );
      return (clip: null, reason: ImportSkipReason.renderFailed);
    }
    try {
      final ClipWrite? write = await _store.saveProcessed(
        rendered: rendered,
        request: request,
        profile: video.profile,
        day: video.day,
        sourceRelPath: video.relPath,
        clip: video.clip,
      );
      if (write == null) {
        _logger.warning(
          _tag,
          'Left ${video.relPath} as it was: its original could not be moved',
        );
        return (clip: null, reason: ImportSkipReason.moveRefused);
      }
      _logger.info(
        _tag,
        'Processed ${video.relPath} into ${write.clip.relPath}',
      );
      return (clip: write.clip, reason: null);
    } on AppException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not publish the processed clip of ${video.relPath}',
        error: error,
        stackTrace: stackTrace,
      );
      return (clip: null, reason: ImportSkipReason.publishFailed);
    }
  }

  /// The engine's probe of [video]; null when it cannot be read (logged).
  Future<ClipProbe?> _probe(ImportedVideo video) async {
    try {
      return await _engine.probe(_paths.absoluteFromVideos(video.relPath));
    } on AppException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not read the length of ${video.relPath}',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// The cache entry of [clip] (its length, its colour transfer); null
  /// when the cache has none.
  ClipMeta? _cachedMeta(ClipIndex index, ClipRef clip) {
    final FileStamp? stamp = index.stampOf(clip);
    if (stamp == null) return null;
    return _metadata.lookup(relPath: clip.relPath, stamp: stamp);
  }

  /// The day a foreign file's name says (`2024-01-05.mov` → 2024-01-05).
  static LocalDay? _dayOf(String relPath) {
    final String name = PathNames.fileNameOf(relPath);
    final int dot = name.lastIndexOf('.');
    if (dot <= 0) return null;
    return ClipNameCodec.parse('${name.substring(0, dot)}.mp4')?.day;
  }
}

extension<T> on Stream<T> {
  /// This stream until [done] completes (its result or error ignored).
  Stream<T> takeUntil(Future<Object?> done) {
    final StreamController<T> controller = StreamController<T>();
    late final StreamSubscription<T> subscription;
    controller.onListen = () {
      subscription = listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      unawaited(
        done.then<void>(
          (_) => controller.close(),
          onError: (Object _) => controller.close(),
        ),
      );
    };
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }
}
