import 'dart:async';
import 'dart:io';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_notes_tag.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/rendered_clip.dart';
import 'package:one_second_diary/core/platform/app_info_gateway.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/device_info_gateway.dart';
import 'package:one_second_diary/core/platform/free_space_gateway.dart';
import 'package:one_second_diary/core/platform/wakelock_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/storage_budget.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_render_plan.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_backfill.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/clip_write.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

/// Renders the editor's clip with the media engine and files it in the diary via the clip store.
/// Not final so cubit tests can fake it.
class ClipSaver {
  ClipSaver({
    required this._engine,
    required this._store,
    required this._wakelock,
    required this._backfill,
    required this._freeSpace,
    required this._paths,
    required this._logger,
    required this._isIOS,
    required this._settings,
    required this._deviceInfo,
    required this._appInfo,
    required this._clock,
  });

  final MediaEngine _engine;
  final ClipStore _store;
  final WakelockGateway _wakelock;

  /// The phone's free space, checked against the save's budget before any work.
  final FreeSpaceGateway _freeSpace;

  /// The "Device info in videos" preference, read at each save.
  final SettingsRepository _settings;
  final DeviceInfoGateway _deviceInfo;
  final AppInfoGateway _appInfo;
  final Clock _clock;

  /// The clips' metadata backfill: its probes wait while a clip is saved, so
  /// they never compete with the render.
  final ClipMetadataBackfill _backfill;
  final AppPaths _paths;
  final AppLogger _logger;

  /// `Platform.isIOS` in the app (`LaunchCore`), as for the clip store, so
  /// tests run either layout on any host.
  final bool _isIOS;

  static const String _tag = 'SAVE';

  /// Renders [request] (made from [source]) and files it as the clip of [day] in [profile] that [mode] says.
  ///
  /// A clip replacing a private one is rendered private. Tags are exactly [request]'s (the editor prefills them, so empty means cleared). With "Device info in videos" on, the clip also notes the phone, app version and moment.
  /// A phone short of twice the clip's estimated size throws a [StorageShortException] before rendering. With "Keep original recordings" on, the store keeps a recording's temp as the source (a move, no space counted).
  ///
  /// [onProgress] gets the render's fraction (0–1); [onPublishing] fires once the render is done and the clip is being filed.
  Future<SavedClip> save({
    required ClipRenderRequest request,
    required ClipSource source,
    required ProfileKey profile,
    required LocalDay day,
    required ClipSaveMode mode,
    required CancelToken cancelToken,
    required void Function(double fraction) onProgress,
    required void Function() onPublishing,
  }) async {
    ClipRenderRequest render = switch (mode) {
      ReplaceClip(:final ClipRef clip) when _store.isPrivate(clip) =>
        request.asPrivate(),
      _ => request,
    };
    if (_settings.clipDeviceInfo.value) {
      render = render.withDeviceTag(
        ClipNotesTag.format(
          device: await _deviceInfo.description(),
          appVersion: await _appInfo.version(),
          recordedAt: _clock.now(),
        ),
      );
    }
    final StorageVerdict verdict = StorageBudget.check(
      needed: SaveSpaceEstimate(
        format: render.format,
        durationMs: _durationMsOf(render),
      ).neededBytes,
      free: await _freeSpace.freeBytes(),
    );
    if (verdict case StorageShort(:final int shortfallBytes)) {
      _logger.warning(
        _tag,
        'Refused the save of ${day.fileStem}: $shortfallBytes bytes short',
      );
      throw StorageShortException(shortfallBytes: shortfallBytes);
    }
    await _wakelock.enable();
    _backfill.pause();
    try {
      final RenderedClip rendered = await _engine.renderClip(
        render,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );
      if (cancelToken.isCancelled) {
        // The render ended as the cancel came in: drop what it wrote.
        await _deleteRender(rendered);
        cancelToken.throwIfCancelled();
      }
      onPublishing();
      final ClipWrite write = await _store.save(
        rendered: rendered,
        request: render,
        source: source,
        profile: profile,
        day: day,
        mode: mode,
        keepSource: _settings.keepOriginals.value,
      );
      return SavedClip.of(write);
    } on CancelledException {
      _logger.info(_tag, 'The save of ${day.fileStem} was cancelled');
      rethrow;
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not save the clip of ${day.fileStem} '
        '(${mode is ReplaceClip ? 'a replace' : 'a new clip'})',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      await _wakelock.disable();
      _backfill.resume();
    }
  }

  /// The length the clip of [request] will have.
  static int _durationMsOf(ClipRenderRequest request) => switch (request) {
    VideoRender(:final int trimStartMs, :final int trimEndMs) =>
      trimEndMs - trimStartMs,
    PhotoRender(:final double durationSeconds) =>
      (durationSeconds * 1000).round(),
  };

  /// The source's picture size in pixels, as the file stores it (the
  /// engine's probe), for the framing sheet; null when it cannot be read
  /// (logged). Never throws. [sourceFacts] with the transfer left out.
  Future<SourceSize?> sourceSize(String path) async {
    final SourceFacts? facts = await sourceFacts(path);
    return facts == null ? null : (width: facts.width, height: facts.height);
  }

  /// One probe of the source at [path]: its picture size, as the file
  /// stores it, and its colour transfer (`ClipProbe.colorTransfer`, which
  /// tells an HDR source), for the framing sheet and the save's range
  /// conversion; null when the file cannot be read (logged). Never throws.
  Future<SourceFacts?> sourceFacts(String path) async {
    try {
      final ClipProbe probe = await _engine.probe(path);
      final int? width = probe.width;
      final int? height = probe.height;
      if (width == null || height == null || width <= 0 || height <= 0) {
        return null;
      }
      return (width: width, height: height, colorTransfer: probe.colorTransfer);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not read the size of $path',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// The user left without saving: deletes [source] when the app owns it (camera temp, picker copy, platform export), never the user's gallery video or a kept original opened with "Edit again" (`ClipSource.owned` false).
  /// Like `ClipStore`, the label alone is not trusted: a file in the diary folder or outside the app's container stays, compared with links resolved. Never throws; a file that stays is logged.
  Future<void> discardSource(ClipSource source) async {
    if (!source.owned || !source.ownership.deletableAfterSave) return;
    try {
      final String file = await File(source.path).resolveSymbolicLinks();
      final String videos = await Directory(
        _paths.videos,
      ).resolveSymbolicLinks();
      final String container = await Directory(
        _appContainer,
      ).resolveSymbolicLinks();
      if (file.startsWith(AppPaths.withTrailingSlash(videos)) ||
          !file.startsWith(AppPaths.withTrailingSlash(container))) {
        _logger.warning(
          _tag,
          'Kept the discarded source ${source.path}: not an app temp',
        );
        return;
      }
      await File(file).delete();
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not delete the discarded source ${source.path}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// The folder holding everything private to the app, where the camera
  /// and picker plugins write their temps (`ClipStore`'s rule): the parent
  /// of `AppPaths.internal` on Android, two levels above it on iOS.
  String get _appContainer {
    final List<String> segments = _paths.internal.split('/')
      ..length -= _isIOS ? 2 : 1;
    return segments.join('/');
  }

  /// Deletes a render nobody publishes, with the folder the engine made
  /// for it when that is left empty.
  Future<void> _deleteRender(RenderedClip rendered) async {
    final File file = File(rendered.tempPath);
    try {
      await file.delete();
      if (file.parent.path.startsWith(
        AppPaths.withTrailingSlash(_paths.scratchDir),
      )) {
        await file.parent.delete();
      }
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not delete the cancelled render ${rendered.tempPath}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
