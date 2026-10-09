import 'dart:async';
import 'dart:io';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/media/types/clip_recipe.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/rendered_clip.dart';
import 'package:one_second_diary/core/platform/free_space_gateway.dart';
import 'package:one_second_diary/core/platform/wakelock_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/core/storage/storage_budget.dart';
import 'package:one_second_diary/features/clips/data/clip_meta_of_conversion.dart';
import 'package:one_second_diary/features/clips/data/clip_meta_of_save.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_backfill.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/data/conversion_manifest.dart';
import 'package:one_second_diary/features/clips/data/import_processor.dart';
import 'package:one_second_diary/features/clips/data/originals_store.dart';
import 'package:one_second_diary/features/clips/domain/clip_conversion.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/original_render_facts.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Where a clip's kept source is: the absolute path of the original recording
/// to convert from instead of the stamped clip, or null when there is none.
/// The [OriginalsStore] answers it in the app; a seam for tests.
typedef SourceOf = String? Function(ClipRef clip);

/// Converts every clip of a profile into a new profile at another quality:
/// the only way to change a profile's quality. The originals are never
/// touched.
///
/// - Over the engine's queue (one `MediaEngine.convertClip` at a time), in
///   date order, cancellable, with a per-clip progress and a running "n of N ·
///   about X left" from the phone check's speed ([EncodeSpeedOf]).
/// - Each clip is rendered into scratch and published into the new profile
///   under its mirrored name through `ClipStore.saveAt`, with a sidecar entry
///   from the render and the old entry's text facts (`clipMetaOfConversion`,
///   no probe); its tags travel in the file.
/// - A clip with a kept source AND a recipe in its sidecar entry is rendered
///   from that source with the recipe at the new format (the normal save
///   render; the date stamp in the app language, [StampTextOf]), so the
///   conversion loses nothing. The new profile's clip gets its own copy of the
///   source only when "Keep original recordings" is on and the storage budget
///   allows it; otherwise it has no source, and the report says so. A source
///   without a recipe (a reinstall) converts from the stamped clip.
/// - A [ConversionManifest] in the new folder records what is done, so a
///   killed app resumes where it stopped; a cancel keeps what was converted.
///   The manifest goes when the run completes.
/// - The wakelock is held and the metadata backfill paused while it runs.
/// - [estimateConversion] gives the count, total length, time and space,
///   checked against `StorageBudget`; the conversion is not offered when the
///   target equals the source format.
///
/// Not final so tests can fake it.
class ProfileConverter implements ProfileConversionStarter {
  ProfileConverter({
    required this._engine,
    required this._store,
    required this._clips,
    required this._metadata,
    required this._freeSpace,
    required this._wakelock,
    required this._backfill,
    required this._formatOf,
    required this._paths,
    required this._logger,
    EncodeSpeedOf? speedOf,
    SourceOf? sourceOf,
    OriginalsStore? originals,
    StampTextOf? stampTextOf,
    bool Function()? keepOriginals,
    bool Function()? legacyStampFont,
  }) : _speedOf = speedOf ?? _realTime,
       _originals = originals, // ignore: prefer_initializing_formals
       _sourceOf =
           sourceOf ??
           (originals == null
               ? _noSource
               : (ClipRef clip) => originals.sourcePathOf(clip.relPath)),
       _stampTextOf = stampTextOf, // ignore: prefer_initializing_formals
       _keepOriginals = keepOriginals ?? _off,
       _legacyStampFont = legacyStampFont ?? _off;

  final MediaEngine _engine;
  final ClipStore _store;
  final ClipRepository _clips;
  final ClipMetadataCache _metadata;
  final FreeSpaceGateway _freeSpace;
  final WakelockGateway _wakelock;
  final ClipMetadataBackfill _backfill;
  final ProfileFormatOf _formatOf;
  final AppPaths _paths;
  final AppLogger _logger;
  final EncodeSpeedOf _speedOf;
  final SourceOf _sourceOf;

  /// The kept originals, for the new profile's copies; null when the app
  /// keeps none.
  final OriginalsStore? _originals;

  /// The day's date stamp as the editor burns it; null when a render from
  /// a source is not possible (every clip then converts from its file).
  final StampTextOf? _stampTextOf;

  /// "Keep original recordings" and "Legacy font in videos", read at each
  /// run.
  final bool Function() _keepOriginals;
  final bool Function() _legacyStampFont;

  static const String _tag = 'CONVERT';

  /// A clip of unknown length counts as this while no length is known.
  static const int _nominalClipMs = 1000;

  static double _realTime(ClipFormat _) => 1.0;

  static String? _noSource(ClipRef _) => null;

  static bool _off() => false;

  @override
  Future<ConversionEstimate> estimateConversion({
    required ProfileKey source,
    required ClipFormat format,
  }) async {
    final ClipIndex index =
        _clips.snapshotOf(source) ?? await _clips.rescan(source);
    final List<ClipRef> clips = _inDateOrder(index);
    final int totalMs = _totalMs(index, clips);
    final int copies = _keepOriginals() ? await _sourceBytes(clips) : 0;
    final int needed =
        StorageBudget.convertBytes(format: format, totalDurationMs: totalMs) +
        copies;
    final ClipFormat current = _formatOf(source);
    return ConversionEstimate(
      clipCount: clips.length,
      totalDurationMs: totalMs,
      estimatedTime: _timeFor(totalMs, format),
      neededBytes: needed,
      verdict: StorageBudget.check(
        needed: needed,
        free: await _freeSpace.freeBytes(),
      ),
      sameFormat: current.withOrientation(format.orientation) == format,
      sourceCopyBytes: copies,
    );
  }

  @override
  Stream<ConversionEvent> convertProfile(
    ConversionJob job, {
    CancelToken? cancelToken,
  }) async* {
    final ClipIndex index =
        _clips.snapshotOf(job.source) ?? await _clips.rescan(job.source);
    final List<ClipRef> clips = _inDateOrder(index);
    final String manifestPath =
        '${_paths.profileVideos(job.target)}${ConversionManifest.fileName}';
    ConversionManifest manifest = await _manifestFor(manifestPath, job);
    final Set<String> done = manifest.done.toSet();
    final Map<ClipRef, ConversionSkipReason> skipped =
        <ClipRef, ConversionSkipReason>{};
    final _SourceTally sources = _SourceTally();
    bool cancelled = false;
    _logger.info(
      _tag,
      'Converting ${clips.length} clip(s) of ${job.source.albumLabel} into '
      '${job.target.albumLabel} (${job.format}); ${done.length} done before',
    );
    await _wakelock.enable();
    _backfill.pause();
    try {
      for (final ClipRef clip in clips) {
        if (done.contains(clip.relPath)) continue;
        if (cancelToken?.isCancelled ?? false) {
          cancelled = true;
          break;
        }
        final int remainingMs = _remainingMs(index, clips, done, skipped);
        yield ConversionProgress(
          done: done.length,
          total: clips.length,
          fraction: 0,
          remaining: _timeFor(remainingMs, job.format),
        );
        final StreamController<double> fractions =
            StreamController<double>.broadcast();
        final Future<({ClipRef? target, ConversionSkipReason? reason})> work =
            _convertOne(
              clip,
              index: index,
              job: job,
              sources: sources,
              cancelToken: cancelToken,
              onProgress: fractions.add,
            );
        yield* fractions.stream
            .map(
              (double fraction) => ConversionProgress(
                done: done.length,
                total: clips.length,
                fraction: fraction,
                remaining: _timeFor(
                  remainingMs - (fraction * _msOf(index, clip)).round(),
                  job.format,
                ),
              ),
            )
            .takeUntilDone(work);
        final ({ClipRef? target, ConversionSkipReason? reason}) outcome =
            await work;
        await fractions.close();
        if (outcome.target case final ClipRef target) {
          done.add(clip.relPath);
          manifest = manifest.withDone(clip.relPath);
          await _writeManifest(manifestPath, manifest);
          yield ConversionClipDone(source: clip, target: target);
        } else if (outcome.reason case final ConversionSkipReason reason) {
          skipped[clip] = reason;
          yield ConversionClipSkipped(source: clip, reason: reason);
        } else {
          cancelled = true;
          break;
        }
      }
    } finally {
      _backfill.resume();
      await _wakelock.disable();
    }
    final ConversionReport report = ConversionReport(
      done: done.length,
      total: clips.length,
      skipped: Map<ClipRef, ConversionSkipReason>.unmodifiable(skipped),
      cancelled: cancelled,
      sourcesCopied: sources.copied,
      sourcesSkipped: sources.skipped,
    );
    if (report.complete) await _deleteManifest(manifestPath);
    yield ConversionFinished(report);
  }

  /// One clip: null target and null reason means a cancel ended it.
  Future<({ClipRef? target, ConversionSkipReason? reason})> _convertOne(
    ClipRef clip, {
    required ClipIndex index,
    required ConversionJob job,
    required _SourceTally sources,
    required CancelToken? cancelToken,
    required void Function(double fraction) onProgress,
  }) async {
    final String name = PathNames.fileNameOf(clip.relPath);
    final ClipRef target = ClipRef(
      profile: job.target,
      relPath: '${_targetFolderRel(job.target)}$name',
    );
    final ClipMeta? meta = _metaOf(index, clip);
    final String? kept = _sourceOf(clip);
    final ClipRecipe? recipe = meta?.recipe;
    final StampTextOf? stampText = _stampTextOf;
    final bool fromSource =
        kept != null &&
        recipe != null &&
        stampText != null &&
        await File(kept).exists();
    final String source = fromSource
        ? kept
        : _paths.absoluteFromVideos(clip.relPath);
    if (!await File(source).exists()) {
      return (target: null, reason: ConversionSkipReason.missing);
    }
    final RenderedClip rendered;
    VideoRender? request;
    try {
      if (fromSource) {
        request = _requestFromSource(
          clip,
          source: kept,
          recipe: recipe,
          meta: meta,
          job: job,
          stampText: stampText,
          outputFileName: name,
        );
        rendered = await _engine.renderClip(
          request,
          cancelToken: cancelToken,
          onProgress: onProgress,
        );
      } else {
        rendered = await _engine.convertClip(
          sourcePath: source,
          outputFileName: name,
          format: job.format,
          albumLabel: job.target.albumLabel,
          durationMs: meta?.durationMs ?? await _probedMs(source),
          sourceChannels: meta?.channels,
          hasSubtitleStream: meta?.hasSubtitleStream ?? false,
          sourceColorTransfer: meta?.colorTransfer,
          cancelToken: cancelToken,
          onProgress: onProgress,
        );
      }
    } on CancelledException {
      return (target: null, reason: null);
    } on AppException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not convert ${clip.relPath}',
        error: error,
        stackTrace: stackTrace,
      );
      return (target: null, reason: ConversionSkipReason.renderFailed);
    }
    // The new profile's own source: a copy, before the clip is filed, so
    // its sidecar entry carries the recipe only when the copy is there.
    String? copy;
    if (fromSource) {
      copy = await _copySource(clip, source: kept, target: target);
      if (copy == null) {
        sources.skipped++;
      } else {
        sources.copied++;
      }
    }
    try {
      await _store.saveAt(
        rendered: rendered,
        format: job.format,
        clip: target,
        meta: request != null
            ? clipMetaOfSave(
                rendered: rendered,
                request: request,
                recipe: copy == null ? null : ClipRecipe.of(request),
              )
            : clipMetaOfConversion(
                previous: meta,
                rendered: rendered,
                format: job.format,
              ),
      );
      return (target: target, reason: null);
    } on AppException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not publish the converted ${clip.relPath}',
        error: error,
        stackTrace: stackTrace,
      );
      if (copy != null) {
        await _originals?.remove(copy);
        sources.copied--;
      }
      return (target: null, reason: ConversionSkipReason.publishFailed);
    }
  }

  /// The normal save render of [clip]'s [source] with its [recipe] at the
  /// job's format: the text facts come from [meta] (as the conversion
  /// copies them from the file), the stamp text from the app language.
  VideoRender _requestFromSource(
    ClipRef clip, {
    required String source,
    required ClipRecipe recipe,
    required ClipMeta? meta,
    required ConversionJob job,
    required StampTextOf stampText,
    required String outputFileName,
  }) {
    final ClipOrigin? origin = meta?.origin;
    final String place = meta?.locationText ?? '';
    return VideoRender(
      sourcePath: source,
      fromRecording: OriginalRenderFacts.fromRecording(origin),
      imported: OriginalRenderFacts.imported(origin),
      trimStartMs: recipe.trimStartMs,
      trimEndMs: recipe.trimEndMs,
      outputFileName: outputFileName,
      stampText: stampText(clip.day, recipe.stampStyle.format),
      stampStyle: recipe.stampStyle,
      legacyStampFont: _legacyStampFont(),
      location: place.isEmpty
          ? const ClipLocation.off()
          : ClipLocation(
              enabled: true,
              text: place,
              latitude: meta?.latitude,
              longitude: meta?.longitude,
            ),
      subtitles: meta?.subtitleText ?? '',
      format: job.format,
      albumLabel: job.target.albumLabel,
      frame: recipe.sourceFrame,
      isPrivate: meta?.isPrivate ?? false,
      tags: meta?.tags ?? const <String>[],
      mute: recipe.mute,
      sourceColorTransfer: recipe.sourceColorTransfer,
    );
  }

  /// Copies [clip]'s source as [target]'s, when "Keep original recordings"
  /// is on and the phone has room for the copy; null otherwise (logged
  /// when the copy itself failed).
  Future<String?> _copySource(
    ClipRef clip, {
    required String source,
    required ClipRef target,
  }) async {
    final OriginalsStore? originals = _originals;
    final String? original = originals?.originalRelPathOf(clip.relPath);
    if (originals == null || original == null || !_keepOriginals()) {
      return null;
    }
    final int bytes = await _lengthOf(source);
    if (StorageBudget.check(needed: bytes, free: await _freeSpace.freeBytes())
        case StorageShort(:final int shortfallBytes)) {
      _logger.warning(
        _tag,
        'No room to copy the original of ${clip.relPath}: '
        '$shortfallBytes bytes short',
      );
      return null;
    }
    return originals.copySource(
      originalRelPath: original,
      toRelPath: target.relPath,
    );
  }

  /// The bytes of the kept sources of [clips] (the estimate's copies).
  Future<int> _sourceBytes(List<ClipRef> clips) async {
    int total = 0;
    for (final ClipRef clip in clips) {
      final String? source = _sourceOf(clip);
      if (source != null) total += await _lengthOf(source);
    }
    return total;
  }

  static Future<int> _lengthOf(String path) async {
    try {
      return await File(path).length();
    } on FileSystemException {
      return 0;
    }
  }

  /// The length of a clip the cache has not read: the engine's probe, or
  /// a nominal second when the probe cannot say.
  Future<int> _probedMs(String source) async =>
      (await _engine.probe(source)).durationMs ?? _nominalClipMs;

  /// The manifest of this run, resumed when the one in the folder is of
  /// the same source and format; a fresh one otherwise.
  Future<ConversionManifest> _manifestFor(
    String path,
    ConversionJob job,
  ) async {
    final ConversionManifest? found = await ConversionManifest.read(path);
    if (found != null &&
        found.matches(source: job.source, format: job.format)) {
      return found;
    }
    return ConversionManifest(
      source: job.source,
      format: job.format.toString(),
      done: const <String>[],
    );
  }

  Future<void> _writeManifest(String path, ConversionManifest manifest) async {
    try {
      await manifest.write(path);
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not write the conversion manifest',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _deleteManifest(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Never written, or already gone.
    }
  }

  /// The visible clips of [index], oldest day first, ordinal order.
  static List<ClipRef> _inDateOrder(ClipIndex index) =>
      index.newestFirst.toList().reversed.toList();

  /// The target's folder relative to the videos folder (`''` for Default).
  static String _targetFolderRel(ProfileKey target) =>
      target.isDefault ? '' : '${PathNames.profilesFolder}/${target.value}/';

  ClipMeta? _metaOf(ClipIndex index, ClipRef clip) {
    final FileStamp? stamp = index.stampOf(clip);
    return stamp == null
        ? null
        : _metadata.lookup(relPath: clip.relPath, stamp: stamp);
  }

  /// [clip]'s length, or the average known length of the profile's clips.
  int _msOf(ClipIndex index, ClipRef clip) =>
      _metaOf(index, clip)?.durationMs ?? _averageMs(index);

  int _totalMs(ClipIndex index, List<ClipRef> clips) {
    final int average = _averageMs(index);
    int total = 0;
    for (final ClipRef clip in clips) {
      total += _metaOf(index, clip)?.durationMs ?? average;
    }
    return total;
  }

  int _remainingMs(
    ClipIndex index,
    List<ClipRef> clips,
    Set<String> done,
    Map<ClipRef, ConversionSkipReason> skipped,
  ) => _totalMs(index, <ClipRef>[
    for (final ClipRef clip in clips)
      if (!done.contains(clip.relPath) && !skipped.containsKey(clip)) clip,
  ]);

  /// The average length of the clips the cache knows; a nominal second
  /// when it knows none.
  int _averageMs(ClipIndex index) {
    int known = 0;
    int knownMs = 0;
    for (final ClipRef clip in index.newestFirst) {
      final int? ms = _metaOf(index, clip)?.durationMs;
      if (ms == null) continue;
      known++;
      knownMs += ms;
    }
    return known == 0 ? _nominalClipMs : (knownMs / known).round();
  }

  Duration _timeFor(int durationMs, ClipFormat format) {
    final double factor = _speedOf(format);
    final double seconds = durationMs / 1000 / (factor <= 0 ? 1 : factor);
    return Duration(milliseconds: (seconds * 1000).round().clamp(0, 1 << 40));
  }
}

/// How many of a run's kept sources were copied into the new profile, and
/// how many were not.
final class _SourceTally {
  int copied = 0;
  int skipped = 0;
}

extension<T> on Stream<T> {
  /// This stream until [done] completes (its result or error ignored).
  Stream<T> takeUntilDone(Future<Object?> done) {
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
